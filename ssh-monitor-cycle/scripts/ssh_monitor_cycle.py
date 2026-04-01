#!/usr/bin/env python3

import os
import pty
import select
import shlex
import signal
import fcntl
import struct
import subprocess
import sys
import termios
import textwrap
import time
import tty


SSH_CONFIG = os.path.expanduser("~/.ssh/config")
VIEW_SECONDS = int(os.environ.get("VIEW_SECONDS", "30"))
HOST_SWITCH_DELAY = float(os.environ.get("HOST_SWITCH_DELAY", "1"))
SSH_CONNECT_TIMEOUT = int(os.environ.get("SSH_CONNECT_TIMEOUT", "10"))
HOSTS_OVERRIDE = os.environ.get("HOSTS", "").strip()
SSH_PUBKEY = os.path.expanduser(os.environ.get("SSH_PUBKEY", "~/.ssh/id_ed25519.pub"))
AUTO_COPY_ID = os.environ.get("AUTO_COPY_ID", "0") == "1"

PAGE_UP = b"\x1b[5~"
PAGE_DOWN = b"\x1b[6~"
CTRL_C = b"\x03"
CTRL_BACKSLASH = b"\x1c"
CTRL_R = b"\x12"
CTRL_S = b"\x13"
PHASE_MARKER_PREFIX = b"__SSH_MONITOR_PHASE__ "

COPY_ID_PROMPTED = set()


def usage() -> int:
    print(
        textwrap.dedent(
            """\
            用法:
              ./ssh_monitor_cycle.sh

            环境变量:
              VIEW_SECONDS      htop/nvtop 每次展示时长，默认 30 秒
              HOST_SWITCH_DELAY 每台主机切换前等待时长，默认 1 秒
              SSH_CONNECT_TIMEOUT SSH 连接超时，默认 10 秒
              HOSTS             可选，手动指定主机列表，空格分隔
              SSH_PUBKEY        ssh-copy-id 使用的公钥，默认 ~/.ssh/id_ed25519.pub
              AUTO_COPY_ID      设为 1 时，登录失败后尝试 ssh-copy-id，默认 0

            运行时按键:
              PageDown          立即切到下一台
              PageUp            立即切到上一台
              Ctrl-S            停在当前界面
              Ctrl-R            从停驻状态恢复自动轮播
              Ctrl-C            退出脚本
            """
        ),
        end="",
    )
    return 0


def collect_hosts() -> list[str]:
    if HOSTS_OVERRIDE:
        return [item for item in HOSTS_OVERRIDE.split() if item]

    if not os.path.isfile(SSH_CONFIG):
        raise FileNotFoundError(f"未找到 SSH 配置: {SSH_CONFIG}")

    hosts: list[str] = []
    seen: set[str] = set()
    with open(SSH_CONFIG, "r", encoding="utf-8") as fh:
        for raw_line in fh:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if not line.lower().startswith("host "):
                continue
            parts = line.split()[1:]
            for part in parts:
                if "*" in part or "?" in part:
                    continue
                if part not in seen:
                    seen.add(part)
                    hosts.append(part)
    return hosts


def choose_gpu_monitor(host: str) -> str:
    if host == "nano" or host == "agx" or host.startswith("nx"):
        return "jtop"
    return "nvtop"


def remote_script() -> str:
    return textwrap.dedent(
        """\
        set -euo pipefail

        view_seconds="${VIEW_SECONDS:-30}"
        gpu_monitor="${GPU_MONITOR:-nvtop}"
        host_alias="${MONITOR_HOST_ALIAS:-unknown}"
        remote_name="$(hostname)"
        hold_mode="${HOLD_MODE:-0}"
        hold_tool="${HOLD_TOOL:-}"

        install_htop() {
          if command -v htop >/dev/null 2>&1; then
            return 0
          fi

          echo "[$(hostname)] htop 未安装，尝试自动安装"

          if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y htop
          elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y htop
          elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y htop
          elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -Sy --noconfirm htop
          elif command -v zypper >/dev/null 2>&1; then
            sudo zypper --non-interactive install htop
          elif command -v apk >/dev/null 2>&1; then
            sudo apk add htop
          else
            echo "[$(hostname)] 无法识别包管理器，跳过 htop 安装"
            return 1
          fi

          command -v htop >/dev/null 2>&1
        }

        run_monitor() {
          local tool="$1"

          if command -v "$tool" >/dev/null 2>&1; then
            timeout --foreground --signal=INT "${view_seconds}s" "$tool" || true
          else
            echo "[$(hostname)] 未安装 $tool，等待 ${view_seconds}s"
            sleep "$view_seconds"
          fi
        }

        clear
        echo "Connected at $(date '+%F %T')"
        echo "Host alias: ${host_alias}"
        echo "Remote host: ${remote_name}"
        if [[ "$hold_mode" == "1" ]]; then
          echo "Hold mode: ${hold_tool}"
          echo "Keys: PageDown next | PageUp prev | Ctrl-R resume | Ctrl-C quit"
        else
          echo "Cycle once: htop ${view_seconds}s -> ${gpu_monitor} ${view_seconds}s"
          echo "Keys: PageDown next | PageUp prev | Ctrl-S hold | Ctrl-C quit"
        fi
        sleep 1

        install_htop || echo "[$(hostname)] htop 安装失败，将继续后续流程"

        if [[ "$hold_mode" == "1" && -n "$hold_tool" ]]; then
          echo "__SSH_MONITOR_PHASE__ ${hold_tool}"
          if command -v "$hold_tool" >/dev/null 2>&1; then
            "$hold_tool" || true
          else
            echo "[$(hostname)] 未安装 $hold_tool，保持停驻等待"
            while true; do
              sleep 3600
            done
          fi
          clear
          exit 0
        fi

        echo "__SSH_MONITOR_PHASE__ htop"
        run_monitor htop
        clear
        echo "__SSH_MONITOR_PHASE__ ${gpu_monitor}"
        run_monitor "$gpu_monitor"
        clear
        """
    )


def build_ssh_command(host: str, hold_tool: str | None = None) -> list[str]:
    env_prefix = (
        f"VIEW_SECONDS={VIEW_SECONDS} "
        f"GPU_MONITOR={choose_gpu_monitor(host)} "
        f"MONITOR_HOST_ALIAS={shlex.quote(host)} "
    )
    if hold_tool is not None:
        env_prefix += "HOLD_MODE=1 "
        env_prefix += f"HOLD_TOOL={shlex.quote(hold_tool)} "
    command = env_prefix + "bash -lc " + shlex.quote(remote_script())
    return [
        "ssh",
        "-tt",
        "-o",
        f"ConnectTimeout={SSH_CONNECT_TIMEOUT}",
        host,
        command,
    ]


def has_passwordless_ssh(host: str) -> bool:
    result = subprocess.run(
        [
            "ssh",
            "-o",
            "BatchMode=yes",
            "-o",
            f"ConnectTimeout={SSH_CONNECT_TIMEOUT}",
            host,
            "exit",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0


def try_copy_id(host: str) -> bool:
    if not os.path.isfile(SSH_PUBKEY):
        print(f"[{host}] 未找到公钥: {SSH_PUBKEY}", file=sys.stderr)
        return False

    print(f"[{host}] 当前还不能免密登录，开始执行 ssh-copy-id")
    print(f"[{host}] 请按提示输入远端密码，完成后后续轮询将复用该公钥")
    result = subprocess.run(["ssh-copy-id", "-i", SSH_PUBKEY, host], check=False)
    return result.returncode == 0


def maybe_offer_copy_id(host: str) -> None:
    if has_passwordless_ssh(host):
        return
    if host in COPY_ID_PROMPTED:
        return

    COPY_ID_PROMPTED.add(host)
    print()
    answer = input(f"[{host}] 当前是密码登录，还没有免密。是否现在执行 ssh-copy-id，便于后续免密登录？[y/N]: ")
    if answer.strip() in {"y", "Y", "yes", "YES", "是", "确认", "继续"}:
        if try_copy_id(host):
            print(f"[{host}] ssh-copy-id 完成，后续轮询将优先复用公钥")
        else:
            print(f"[{host}] ssh-copy-id 执行失败")
    else:
        print(f"[{host}] 跳过 ssh-copy-id")


def get_terminal_dimensions() -> tuple[int, int]:
    try:
        cols, rows = os.get_terminal_size(sys.stdout.fileno())
        return rows, cols
    except OSError:
        return 24, 80


def sync_pty_window_size(fd: int) -> None:
    rows, cols = get_terminal_dimensions()
    winsize = struct.pack("HHHH", rows, cols, 0, 0)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, winsize)


class RawTerminal:
    def __init__(self) -> None:
        self.fd = sys.stdin.fileno()
        self.attrs = None

    def __enter__(self) -> "RawTerminal":
        self.attrs = termios.tcgetattr(self.fd)
        tty.setraw(self.fd)
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        if self.attrs is not None:
            termios.tcsetattr(self.fd, termios.TCSADRAIN, self.attrs)


def terminate_process(proc: subprocess.Popen[bytes]) -> None:
    if proc.poll() is not None:
        return
    proc.terminate()
    try:
        proc.wait(timeout=1.5)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(timeout=1.5)


def extract_action(buffer: bytearray, paused_mode: bool) -> tuple[str | None, bytes]:
    forward = bytearray()
    sequences = {
        PAGE_UP: "prev",
        PAGE_DOWN: "next",
        CTRL_C: "quit",
        CTRL_BACKSLASH: "quit",
    }
    if paused_mode:
        sequences[CTRL_R] = "resume"
    else:
        sequences[CTRL_S] = "pause"

    while buffer:
        matched = False
        for seq, action in sequences.items():
            if buffer.startswith(seq):
                del buffer[: len(seq)]
                return action, bytes(forward)
            if seq.startswith(buffer):
                return None, bytes(forward)
        forward.append(buffer[0])
        del buffer[0]
        matched = True
        if not matched:
            break

    return None, bytes(forward)


def consume_output(data: bytes, pending: bytearray, current_tool: str | None) -> tuple[bytes, str | None]:
    pending.extend(data)
    forward = bytearray()

    while True:
        marker_index = pending.find(PHASE_MARKER_PREFIX)
        if marker_index == -1:
            forward.extend(pending)
            pending.clear()
            break

        if marker_index > 0:
            forward.extend(pending[:marker_index])
            del pending[:marker_index]

        newline_index = pending.find(b"\n")
        if newline_index == -1:
            break

        marker_line = bytes(pending[: newline_index + 1])
        del pending[: newline_index + 1]
        if marker_line.startswith(PHASE_MARKER_PREFIX):
            current_tool = marker_line[len(PHASE_MARKER_PREFIX) :].strip().decode("utf-8", errors="replace")
        else:
            forward.extend(marker_line)

    return bytes(forward), current_tool


def run_host_session(host: str, hold_tool: str | None = None) -> tuple[int, str | None, str | None]:
    master_fd, slave_fd = pty.openpty()
    sync_pty_window_size(slave_fd)
    proc = subprocess.Popen(
        build_ssh_command(host, hold_tool=hold_tool),
        stdin=slave_fd,
        stdout=slave_fd,
        stderr=slave_fd,
        close_fds=True,
    )
    os.close(slave_fd)

    stdin_fd = sys.stdin.fileno()
    stdout_fd = sys.stdout.fileno()
    input_buffer = bytearray()
    action = None
    resize_pending = False
    paused_mode = hold_tool is not None
    current_tool = hold_tool
    output_pending = bytearray()

    def handle_sigwinch(signum, frame) -> None:
        nonlocal resize_pending
        resize_pending = True

    previous_sigwinch = signal.getsignal(signal.SIGWINCH)
    signal.signal(signal.SIGWINCH, handle_sigwinch)

    try:
        with RawTerminal():
            sync_pty_window_size(master_fd)
            while True:
                if proc.poll() is not None:
                    break

                if resize_pending:
                    sync_pty_window_size(master_fd)
                    resize_pending = False

                readable, _, _ = select.select([master_fd, stdin_fd], [], [], 0.1)

                if master_fd in readable:
                    try:
                        data = os.read(master_fd, 4096)
                    except OSError:
                        data = b""
                    if data:
                        display_data, current_tool = consume_output(data, output_pending, current_tool)
                        if display_data:
                            os.write(stdout_fd, display_data)

                if stdin_fd in readable:
                    chunk = os.read(stdin_fd, 128)
                    if not chunk:
                        action = "quit"
                        terminate_process(proc)
                        break

                    input_buffer.extend(chunk)
                    action, forward = extract_action(input_buffer, paused_mode=paused_mode)
                    if forward:
                        os.write(master_fd, forward)
                    if action is not None:
                        terminate_process(proc)
                        break

            while True:
                try:
                    data = os.read(master_fd, 4096)
                except OSError:
                    break
                if not data:
                    break
                display_data, current_tool = consume_output(data, output_pending, current_tool)
                if display_data:
                    os.write(stdout_fd, display_data)

            if output_pending:
                os.write(stdout_fd, bytes(output_pending))
                output_pending.clear()
    finally:
        signal.signal(signal.SIGWINCH, previous_sigwinch)
        os.close(master_fd)

    return proc.wait(), action, current_tool


def run_cycle(hosts: list[str]) -> int:
    index = 0
    host_count = len(hosts)

    while True:
        host = hosts[index]
        print("\033[2J\033[H", end="")
        print(f"========== {host} ==========")
        print(f"开始时间: {time.strftime('%F %T')}")
        print(f"进度: {index + 1}/{host_count}")
        print("按键: PageDown 下一台 | PageUp 上一台 | Ctrl-S 停驻当前界面 | Ctrl-C 退出")
        sys.stdout.flush()

        status, action, current_tool = run_host_session(host)
        print()

        if action == "next":
            print(f"[{host}] 已切到下一台")
            index = (index + 1) % host_count
            time.sleep(0.2)
            continue
        if action == "prev":
            print(f"[{host}] 已切到上一台")
            index = (index - 1 + host_count) % host_count
            time.sleep(0.2)
            continue
        if action == "quit":
            print(f"[{host}] 已退出脚本")
            return 0
        if action == "pause":
            hold_tool = current_tool or choose_gpu_monitor(host)
            print(f"[{host}] 已停驻在 {hold_tool} 界面。按 Ctrl-R 恢复自动轮播。")
            while True:
                hold_status, hold_action, _ = run_host_session(host, hold_tool=hold_tool)
                print()
                if hold_action == "resume":
                    print(f"[{host}] 已恢复自动轮播")
                    break
                if hold_action == "next":
                    print(f"[{host}] 已切到下一台")
                    index = (index + 1) % host_count
                    time.sleep(0.2)
                    hold_status = None
                    break
                if hold_action == "prev":
                    print(f"[{host}] 已切到上一台")
                    index = (index - 1 + host_count) % host_count
                    time.sleep(0.2)
                    hold_status = None
                    break
                if hold_action == "quit":
                    print(f"[{host}] 已退出脚本")
                    return 0
                print(f"[{host}] 停驻会话结束，重新进入停驻模式")
            if hold_action == "resume":
                continue
            if hold_action in {"next", "prev"}:
                continue

        if status != 0:
            if AUTO_COPY_ID:
                print(f"[{host}] 直接登录失败，尝试执行 ssh-copy-id")
                if try_copy_id(host):
                    retry_status, retry_action, retry_current_tool = run_host_session(host)
                    print()
                    if retry_action == "quit":
                        print(f"[{host}] 已退出脚本")
                        return 0
                    if retry_action == "next":
                        print(f"[{host}] 已切到下一台")
                        index = (index + 1) % host_count
                        time.sleep(0.2)
                        continue
                    if retry_action == "prev":
                        print(f"[{host}] 已切到上一台")
                        index = (index - 1 + host_count) % host_count
                        time.sleep(0.2)
                        continue
                    if retry_action == "pause":
                        hold_tool = retry_current_tool or choose_gpu_monitor(host)
                        print(f"[{host}] 已停驻在 {hold_tool} 界面。按 Ctrl-R 恢复自动轮播。")
                        while True:
                            hold_status, hold_action, _ = run_host_session(host, hold_tool=hold_tool)
                            print()
                            if hold_action == "resume":
                                print(f"[{host}] 已恢复自动轮播")
                                break
                            if hold_action == "next":
                                print(f"[{host}] 已切到下一台")
                                index = (index + 1) % host_count
                                time.sleep(0.2)
                                hold_status = None
                                break
                            if hold_action == "prev":
                                print(f"[{host}] 已切到上一台")
                                index = (index - 1 + host_count) % host_count
                                time.sleep(0.2)
                                hold_status = None
                                break
                            if hold_action == "quit":
                                print(f"[{host}] 已退出脚本")
                                return 0
                            print(f"[{host}] 停驻会话结束，重新进入停驻模式")
                        if hold_action == "resume":
                            continue
                        if hold_action in {"next", "prev"}:
                            continue
                    if retry_status == 0:
                        maybe_offer_copy_id(host)
                        print(f"[{host}] 本轮完成，{HOST_SWITCH_DELAY}s 后切到下一台")
                        time.sleep(HOST_SWITCH_DELAY)
                        index = (index + 1) % host_count
                        continue
            else:
                print(f"[{host}] 直接登录失败。默认不会自动执行 ssh-copy-id。")
                print(f"[{host}] 如果需要在失败后自动配置免密，请用 AUTO_COPY_ID=1 重新运行。")

            print(f"[{host}] 执行失败，{HOST_SWITCH_DELAY}s 后切到下一台")
            time.sleep(HOST_SWITCH_DELAY)
            index = (index + 1) % host_count
            continue

        maybe_offer_copy_id(host)
        print(f"[{host}] 本轮完成，{HOST_SWITCH_DELAY}s 后切到下一台")
        time.sleep(HOST_SWITCH_DELAY)
        index = (index + 1) % host_count


def main(argv: list[str]) -> int:
    if len(argv) > 1 and argv[1] in {"-h", "--help"}:
        return usage()
    if len(argv) > 1:
        return usage() or 1

    try:
        hosts = collect_hosts()
    except FileNotFoundError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    if not hosts:
        print(f"在 {SSH_CONFIG} 中没有找到可用 Host", file=sys.stderr)
        return 1

    return run_cycle(hosts)


if __name__ == "__main__":
    sys.exit(main(sys.argv))

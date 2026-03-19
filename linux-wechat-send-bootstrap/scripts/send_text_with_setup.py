#!/usr/bin/env python3
import json
import os
import sys
import time
from argparse import Namespace


def require_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"缺少环境变量: {name}")
    return value


REPO_ROOT = require_env("PYWXDUMP_REPO_ROOT")
sys.path.insert(0, os.path.join(REPO_ROOT, "tools"))

import linux_wx_chat_daemon as daemon  # noqa: E402


def build_args() -> Namespace:
    return Namespace(
        target=require_env("PYWXDUMP_TARGET"),
        key_file=require_env("PYWXDUMP_KEY_FILE"),
        db_dir=require_env("PYWXDUMP_DB_DIR"),
        output=require_env("PYWXDUMP_OUTPUT_DIR"),
        display="",
        xauthority="",
        window_class="wechat",
        window_mode="main",
        interval=30,
        format="text",
        webhook=None,
        all_chats=False,
        no_image_analysis=True,
        no_video_analysis=True,
        no_voice_asr=True,
        no_link_docs=True,
        ollama_url="https://coding.dashscope.aliyuncs.com/apps/anthropic/v1",
        vision_model="qwen3.5-plus",
        vision_api_key_env="OPENAI_API_KEY",
        summary_base_url="https://coding.dashscope.aliyuncs.com/apps/anthropic/v1",
        summary_model="qwen3.5-plus",
        summary_api_key_env="OPENAI_API_KEY",
        asr_url="http://localhost:8001/api/asr/transcribe",
        video_frame_count=3,
        link_hook_cmd="python3 tools/link_doc_hook.py",
        link_doc_root="/home/ivan/DATAS/wechat_ivan",
        link_domains=",".join(daemon.monitor.DEFAULT_DOC_DOMAINS),
        link_hook_timeout=180,
        post_send_delay_ms=1200,
        send_timeout=30,
        send_step_delay_ms=150,
        send_paste_settle_ms=150,
        no_send_gui_prompts=True,
        send_gui_countdown_seconds=0,
        send_gui_notify_timeout_ms=2000,
        main_window_warm_state_path=os.path.expanduser("~/.local/state/pywxdump/main_window_warm_targets.json"),
        send_diagnostics_path=os.path.expanduser("~/.local/state/pywxdump/linux_wx_send_diagnostics.jsonl"),
        command="send-text",
    )


def attempt_search(args: Namespace, wx_monitor, main_window):
    target_title = wx_monitor.target_display or args.target
    search_terms = daemon.build_main_window_search_terms(args, wx_monitor) or [args.target]
    last_verification = {"matched": False, "title": "", "raw": ""}

    for term in search_terms:
        daemon.activate_window(main_window.window_id, display=args.display, xauthority=args.xauthority)
        time.sleep(0.2)
        daemon.focus_search_and_clear(main_window, display=args.display, xauthority=args.xauthority)
        time.sleep(0.3)
        daemon.paste_text(term, display=args.display, xauthority=args.xauthority)
        time.sleep(0.5)
        daemon.key("Return", display=args.display, xauthority=args.xauthority)
        time.sleep(1.0)

        verification = daemon.verify_main_window_target(args, wx_monitor, main_window, target_title)
        print("VERIFY=" + json.dumps({"term": term, **verification}, ensure_ascii=False))
        if verification.get("matched"):
            return term, verification
        last_verification = verification

    raise SystemExit("主界面右侧标题校验未命中，新消息未发送: " + json.dumps(last_verification, ensure_ascii=False))


def main() -> int:
    if not os.environ.get("OPENAI_API_KEY", "").strip():
        raise SystemExit("交互式 bash 中未发现 OPENAI_API_KEY，请检查 ~/.bashrc")

    args = build_args()
    text = require_env("PYWXDUMP_TEXT")

    wx_monitor = daemon.build_monitor(args, doc_enabled=False)
    daemon.setup_monitor(wx_monitor, announce=False)

    main_window = daemon.discover_main_window(
        class_name=args.window_class,
        display=args.display,
        xauthority=args.xauthority,
    )
    if not main_window:
        raise SystemExit("未找到微信主窗口")

    previous_window_id = daemon.active_window_id(display=args.display, xauthority=args.xauthority) or ""
    previous_window_title = daemon.active_window_title(display=args.display, xauthority=args.xauthority) or ""

    print(f"MAIN_WINDOW={main_window.window_id}:{main_window.title}")
    print(f"TARGET={wx_monitor.target_display} ({wx_monitor.target_username})")
    print(f"BEFORE_LAST_LOCAL_ID={wx_monitor.last_local_id}")

    search_term, verification = attempt_search(args, wx_monitor, main_window)

    session = {
        "window": main_window,
        "window_mode": "main",
        "switch_mode": "warm_search_enter_refocus",
        "target_verified": True,
        "verified_title": verification.get("title") or (wx_monitor.target_display or args.target),
        "verification_mode": "vision_header",
        "post_verify_only": False,
        "search_term": search_term,
    }
    session = daemon.attach_restore_window_session(session, previous_window_id, previous_window_title)

    result = daemon.send_text_via_session(args, wx_monitor, session, text, origin="send_text_command")
    print("RESULT=" + json.dumps(result, ensure_ascii=False))
    return 0 if result.get("status") == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())

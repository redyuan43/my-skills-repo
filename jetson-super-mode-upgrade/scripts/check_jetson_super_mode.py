#!/usr/bin/env python3
"""
Inspect the current Jetson Orin Nano / NX Super Mode state and suggest next steps.

This script is intentionally read-only:
- It only reads files and runs diagnostic commands
- It does not modify boot entries, specs, or power modes
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import re
import shutil
import subprocess
from dataclasses import asdict, dataclass
from typing import Dict, List, Optional, Tuple


GPU_DEVFREQ_DIR = "/sys/devices/platform/17000000.gpu/devfreq_dev"
BOOTLOADER_PKG = "nvidia-l4t-bootloader"


@dataclass
class Report:
    state: str
    summary: str
    recommendations: List[str]
    warnings: List[str]
    facts: Dict[str, object]


def read_text(path: str) -> Optional[str]:
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            return handle.read().strip()
    except OSError:
        return None


def read_realpath(path: str) -> Optional[str]:
    try:
        return os.path.realpath(path)
    except OSError:
        return None


def read_int(path: str) -> Optional[int]:
    text = read_text(path)
    if text is None or not text:
        return None
    try:
        return int(text.split()[0])
    except ValueError:
        return None


def parse_freqs(text: Optional[str]) -> List[int]:
    if not text:
        return []
    freqs: List[int] = []
    for chunk in text.split():
        try:
            freqs.append(int(chunk))
        except ValueError:
            continue
    return freqs


def sudo_available() -> bool:
    sudo_bin = shutil.which("sudo")
    if not sudo_bin:
        return False
    result = subprocess.run(
        [sudo_bin, "-n", "true"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    return result.returncode == 0


def run_command(command: List[str], sudo_fallback: bool = False) -> Tuple[Optional[str], Optional[str], int]:
    candidates = []
    if sudo_fallback and sudo_available():
        candidates.append(["sudo", "-n", *command])
    candidates.append(command)

    last_stderr: Optional[str] = None
    last_code = 127
    for candidate in candidates:
        result = subprocess.run(
            candidate,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )
        if result.returncode == 0:
            return result.stdout.strip(), result.stderr.strip() or None, 0
        last_stderr = result.stderr.strip() or None
        last_code = result.returncode
    return None, last_stderr, last_code


def extract_semver(text: Optional[str]) -> Optional[str]:
    if not text:
        return None
    match = re.search(r"\b\d+\.\d+\.\d+\b", text)
    if match:
        return match.group(0)
    return None


def parse_nvpmodel_mode(output: Optional[str]) -> Optional[str]:
    if not output:
        return None
    match = re.search(r"NV Power Mode:\s*([A-Z0-9_]+)", output)
    if match:
        return match.group(1)
    return None


def parse_nvbootctrl_current_version(output: Optional[str]) -> Optional[str]:
    if not output:
        return None
    for line in output.splitlines():
        if line.startswith("Current version:"):
            return line.split(":", 1)[1].strip()
    return None


def parse_dpkg_version(output: Optional[str]) -> Optional[str]:
    if not output:
        return None
    return output.strip() or None


def parse_nv_boot_control(text: Optional[str]) -> Tuple[Optional[str], Optional[str]]:
    if not text:
        return None, None
    tnspec = None
    compatible_spec = None
    for line in text.splitlines():
        if line.startswith("TNSPEC "):
            tnspec = line.split(" ", 1)[1].strip()
        elif line.startswith("COMPATIBLE_SPEC "):
            compatible_spec = line.split(" ", 1)[1].strip()
    return tnspec, compatible_spec


def parse_extlinux(text: Optional[str]) -> Tuple[Optional[str], bool, Optional[str]]:
    if not text:
        return None, False, None

    default_label = None
    has_super_label = False
    super_fdt = None
    current_label = None

    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        upper = line.upper()
        if upper.startswith("DEFAULT "):
            default_label = line.split(None, 1)[1].strip()
        elif upper.startswith("LABEL "):
            current_label = line.split(None, 1)[1].strip()
            if current_label == "super":
                has_super_label = True
        elif upper.startswith("FDT ") and current_label == "super":
            super_fdt = line.split(None, 1)[1].strip()
    return default_label, has_super_label, super_fdt


def inspect() -> Report:
    compatible = read_text("/proc/device-tree/compatible")
    if compatible is not None:
        compatible = compatible.replace("\x00", "")

    model = read_text("/proc/device-tree/model")
    if model is not None:
        model = model.replace("\x00", "")

    nvpmodel_conf = read_realpath("/etc/nvpmodel.conf")
    available_freqs = parse_freqs(read_text(f"{GPU_DEVFREQ_DIR}/available_frequencies"))
    gpu_max_available = max(available_freqs) if available_freqs else None
    gpu_min_freq = read_int(f"{GPU_DEVFREQ_DIR}/min_freq")
    gpu_max_freq = read_int(f"{GPU_DEVFREQ_DIR}/max_freq")
    gpu_cur_freq = read_int(f"{GPU_DEVFREQ_DIR}/cur_freq")

    nvpmodel_out, _, _ = run_command(["nvpmodel", "-q", "--verbose"])
    nvpmodel_mode = parse_nvpmodel_mode(nvpmodel_out)

    nvbootctrl_out, _, _ = run_command(["nvbootctrl", "dump-slots-info"], sudo_fallback=True)
    nvbootctrl_current = parse_nvbootctrl_current_version(nvbootctrl_out)

    dpkg_out, _, _ = run_command(
        ["dpkg-query", "-W", "-f=${Version}", BOOTLOADER_PKG]
    )
    installed_bootloader_pkg = parse_dpkg_version(dpkg_out)
    installed_bootloader_semver = extract_semver(installed_bootloader_pkg)
    running_bootloader_semver = extract_semver(nvbootctrl_current)

    nv_boot_control_text = read_text("/etc/nv_boot_control.conf")
    tnspec, compatible_spec = parse_nv_boot_control(nv_boot_control_text)

    extlinux_text = read_text("/boot/extlinux/extlinux.conf")
    extlinux_default, extlinux_has_super_label, extlinux_super_fdt = parse_extlinux(extlinux_text)

    super_confs = sorted(glob.glob("/etc/nvpmodel/*super*.conf"))
    super_dtbs = sorted(glob.glob("/boot/*super*.dtb"))
    super_capsules = sorted(glob.glob("/opt/ota_package/t23x/*super*.Cap"))

    compatible_is_super = bool(compatible and "-super" in compatible)
    nvpmodel_conf_is_super = bool(nvpmodel_conf and "super" in nvpmodel_conf.lower())
    nvpmodel_mode_is_super = bool(nvpmodel_mode and "SUPER" in nvpmodel_mode)
    spec_is_super = any(
        value and "-super-" in value.lower()
        for value in [tnspec, compatible_spec]
    )
    gpu_has_super_ceiling = bool(gpu_max_available and gpu_max_available > 918000000)
    gpu_locked_to_top = bool(
        gpu_max_available
        and gpu_min_freq == gpu_max_available
        and gpu_max_freq == gpu_max_available
    )
    running_bootloader_matches_pkg = bool(
        running_bootloader_semver
        and installed_bootloader_semver
        and running_bootloader_semver == installed_bootloader_semver
    )

    warnings: List[str] = []
    recommendations: List[str] = []

    if installed_bootloader_semver and running_bootloader_semver and not running_bootloader_matches_pkg:
        warnings.append(
            "running bootloader version differs from installed package version"
        )

    if nvpmodel_mode_is_super and not gpu_has_super_ceiling:
        warnings.append(
            "nvpmodel reports a super mode, but the GPU frequency table is still capped at 918 MHz"
        )

    if compatible_is_super and not spec_is_super:
        warnings.append(
            "device tree is already super, but nv_boot_control spec is not marked as super"
        )

    if not any([super_confs, super_dtbs, super_capsules]):
        state = "NO_SUPER_ARTIFACTS"
        summary = "Super Mode artifacts are missing from the system image."
        recommendations.extend(
            [
                "Upgrade JetPack/L4T to a release that ships super nvpmodel configs, super DTBs, and super capsules.",
                "Re-run this checker after the artifacts appear under /etc/nvpmodel, /boot, and /opt/ota_package/t23x.",
            ]
        )
    elif compatible_is_super and gpu_has_super_ceiling:
        if nvpmodel_mode_is_super and gpu_locked_to_top:
            state = "FULL_SUPER"
            summary = "Real Super Mode is enabled and the GPU is pinned to the top available frequency."
            recommendations.append("No upgrade action is required. You can start benchmarking larger models now.")
        else:
            state = "SUPER_READY_NOT_PINNED"
            summary = "Super Mode is available, but the machine is not fully pinned to the top GPU frequency yet."
            recommendations.extend(
                [
                    "Run 'sudo nvpmodel -m 0' to switch to MAXN_SUPER if needed.",
                    "Run 'sudo jetson_clocks' to pin clocks before benchmarking.",
                ]
            )
    elif compatible_is_super and not gpu_has_super_ceiling:
        state = "SUPER_DTB_ONLY"
        summary = "The board already boots a super DTB, but the GPU frequency table still looks like the non-super path."
        recommendations.extend(
            [
                "Inspect /etc/nv_boot_control.conf and confirm TNSPEC / COMPATIBLE_SPEC are set to the matching *-super- variant.",
                "Run 'sudo /opt/nvidia/l4t-bootloader-config/nv-l4t-bootloader-config.sh -l' to sync EFI platform compat spec.",
                "Run 'sudo DEBIAN_FRONTEND=noninteractive dpkg-reconfigure nvidia-l4t-bootloader' to trigger the super capsule update.",
                "Reboot again and re-run this checker.",
            ]
        )
    elif (nvpmodel_conf_is_super or nvpmodel_mode_is_super or spec_is_super) and not compatible_is_super:
        state = "RUNTIME_ONLY_OR_PENDING_REBOOT"
        summary = "Some software knobs already point to super, but the active boot chain is not using a super DTB yet."
        recommendations.extend(
            [
                "Check /boot/extlinux/extlinux.conf and make sure a 'super' label exists with FDT pointing to *-nv-super.dtb.",
                "Set DEFAULT to the super entry while keeping the original primary entry for rollback.",
                "Reboot once, then re-run this checker.",
            ]
        )
    else:
        state = "NORMAL_MODE"
        summary = "The board is still on the normal path."
        recommendations.extend(
            [
                "Confirm the system image already contains super configs, DTBs, and capsules.",
                "Start with the first-stage extlinux super DTB switch, then re-run this checker after reboot.",
            ]
        )

    if not extlinux_has_super_label and super_dtbs:
        warnings.append("super DTB files exist, but extlinux.conf does not expose a 'super' boot label")

    facts = {
        "model": model,
        "compatible": compatible,
        "nvpmodel_conf": nvpmodel_conf,
        "nvpmodel_mode": nvpmodel_mode,
        "gpu_available_frequencies": available_freqs,
        "gpu_max_available": gpu_max_available,
        "gpu_min_freq": gpu_min_freq,
        "gpu_max_freq": gpu_max_freq,
        "gpu_cur_freq": gpu_cur_freq,
        "nvbootctrl_current_version": nvbootctrl_current,
        "installed_bootloader_package_version": installed_bootloader_pkg,
        "running_bootloader_matches_package": running_bootloader_matches_pkg,
        "tnspec": tnspec,
        "compatible_spec": compatible_spec,
        "extlinux_default": extlinux_default,
        "extlinux_has_super_label": extlinux_has_super_label,
        "extlinux_super_fdt": extlinux_super_fdt,
        "super_artifacts": {
            "nvpmodel_super_confs": super_confs,
            "super_dtbs": super_dtbs,
            "super_capsules": super_capsules,
        },
    }

    return Report(
        state=state,
        summary=summary,
        recommendations=recommendations,
        warnings=warnings,
        facts=facts,
    )


def print_human(report: Report) -> None:
    print("Jetson Super Mode Inspector")
    print(f"STATE: {report.state}")
    print(f"SUMMARY: {report.summary}")
    print("")

    if report.warnings:
        print("WARNINGS:")
        for item in report.warnings:
            print(f"- {item}")
        print("")

    print("KEY FACTS:")
    fact_order = [
        "model",
        "compatible",
        "nvpmodel_conf",
        "nvpmodel_mode",
        "gpu_max_available",
        "gpu_min_freq",
        "gpu_max_freq",
        "gpu_cur_freq",
        "nvbootctrl_current_version",
        "installed_bootloader_package_version",
        "running_bootloader_matches_package",
        "tnspec",
        "compatible_spec",
        "extlinux_default",
        "extlinux_has_super_label",
        "extlinux_super_fdt",
    ]
    for key in fact_order:
        value = report.facts.get(key)
        if value is not None:
            print(f"- {key}: {value}")
    print(f"- gpu_available_frequencies: {report.facts['gpu_available_frequencies']}")
    print(f"- super_artifacts: {report.facts['super_artifacts']}")
    print("")

    print("NEXT STEPS:")
    for idx, item in enumerate(report.recommendations, start=1):
        print(f"{idx}. {item}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Inspect Jetson Super Mode state")
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print the full report as JSON instead of a human-readable summary.",
    )
    args = parser.parse_args()

    report = inspect()
    if args.json:
        print(json.dumps(asdict(report), indent=2, sort_keys=True))
    else:
        print_human(report)


if __name__ == "__main__":
    main()

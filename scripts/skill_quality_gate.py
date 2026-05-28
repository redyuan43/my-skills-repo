#!/usr/bin/env python3
"""Unified quality gate for skills repository.

Scans top-level `SKILL.md` files and generates a reproducible quality score
for structure, documentation completeness, executability, and static risk checks.
The tool is non-destructive and default behavior is static analysis only.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, List, Sequence, Tuple


WEIGHTS = {
    "structure": 40,
    "documentation": 30,
    "executability": 20,
    "risk": 10,
}

DOC_KEYWORDS = {
    "purpose": ["用途", "功能", "description", "use case", "触发", "适用场景", "功能描述"],
    "trigger": ["触发", "场景", "When", "when", "适用于", "use when", "适合"],
    "example": ["示例", "example", "用法", "usage", "```", "bash "],
    "safety": ["危险", "风险", "确认", "确认是否", "确认继续", "风险提示", "高风险"],
}

RISK_PATTERNS = [
    (re.compile(r"\brm\s+[^\n]*\s+-rf\s+/"), "rm -rf /"),
    (re.compile(r"\bdd\s+"), "dd command"),
    (re.compile(r"\bmkfs\b"), "mkfs command"),
    (re.compile(r"\bparted\b"), "parted command"),
    (re.compile(r"\bsystemctl\s+(start|stop|enable|disable|restart|daemon-reload)\b"), "systemctl control"),
    (re.compile(r"\bmkfs\.|\bfdisk\b|\bparted\b"), "disk operation"),
    (re.compile(r"\btee\s+(/etc|/root|/boot)"), "direct writes under system paths"),
    (re.compile(r"\bsudo\s+"), "sudo command"),
    (re.compile(r"\bssh-copy-id\b"), "ssh-copy-id"),
    (re.compile(r"\bgit\s+(push|reset)\b"), "git state mutation"),
    (re.compile(r"\btailscale\s+(up|set|logout)\b"), "tailscale state mutation"),
    (re.compile(r"\b(curl|wget)\b[^\n|]*\|\s*(bash|sh)\b"), "pipe remote script to shell"),
    (re.compile(r"\b(npm|pnpm|yarn)\s+.*\s(-g|--global)\b"), "global package install"),
    (re.compile(r"\bsystemctl\s+set-default\b"), "system default target mutation"),
]


@dataclass
class SkillCheck:
    name: str
    score: int
    max_score: int
    status: str
    message: str


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        try:
            return path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            return ""


def has_any(text: str, keywords: Sequence[str]) -> bool:
    lowered = text.lower()
    return any(key.lower() in lowered for key in keywords)


def run_cmd(args: Sequence[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        list(args),
        cwd=str(cwd),
        capture_output=True,
        text=True,
        check=False,
    )


def check_bash_syntax(script: Path) -> Tuple[bool, str]:
    proc = run_cmd(["bash", "-n", str(script)], script.parent)
    if proc.returncode == 0:
        return True, ""
    return False, (proc.stderr or proc.stdout or "syntax check failed").strip()


def check_executability(paths: Iterable[Path], parallel: int) -> Tuple[int, List[str]]:
    script_paths = list(paths)
    if not script_paths:
        return 12, []

    def worker(path: Path) -> Tuple[str, bool, str]:
        ok, message = check_bash_syntax(path)
        return str(path), ok, message

    issues: List[str] = []
    if parallel > 1:
        with ThreadPoolExecutor(max_workers=max(1, parallel)) as pool:
            futures = [pool.submit(worker, p) for p in script_paths]
            results = [f.result() for f in futures]
    else:
        results = [worker(p) for p in script_paths]

    passed = 0
    for script_name, ok, detail in results:
        if ok:
            passed += 1
        else:
            issues.append(f"{script_name}: {detail}")

    score = int(round(12 * (passed / len(script_paths))))
    return score, issues


def syntax_check_items(script_files: Sequence[Path], parallel: int) -> Tuple[int, List[str]]:
    return check_executability(script_files, parallel)


def check_risk_patterns(text: str) -> Tuple[int, List[str]]:
    hits: List[str] = []
    for pattern, label in RISK_PATTERNS:
        if pattern.search(text):
            hits.append(label)
    # 2 points deduction per hit, total floor to 0.
    score = max(0, 10 - 2 * len(set(hits)))
    return score, hits


def discover_skills(root: Path) -> List[Path]:
    return [
        path
        for item in sorted(root.iterdir())
        if item.is_dir()
        and not item.name.startswith(".")
        and (item / "SKILL.md").exists()
        and not (item.name == "__pycache__")
        for path in [(item / "SKILL.md")]
    ]


def score_skill(skill_md: Path, parallel: int, with_safe_check: bool) -> dict:
    skill_dir = skill_md.parent
    name = skill_dir.name
    doc_text = read_text(skill_md)
    script_dir = skill_dir / "scripts"
    agents_file = skill_dir / "agents" / "openai.yaml"
    references_dir = skill_dir / "references"
    eval_items = skill_dir / "eval" / "val" / "items.json"
    script_files = (
        sorted([p for p in script_dir.iterdir() if p.is_file()]) if script_dir.exists() else []
    )
    selftest = script_dir / "selftest.sh"
    checks: List[SkillCheck] = []

    # structure: 40
    structure = 0
    has_scripts_dir = script_dir.exists()
    has_script_files = len(script_files) > 0
    has_selftest = selftest.exists()
    has_agents = agents_file.exists()
    has_eval = eval_items.exists()
    has_gate_reference = (references_dir / "gate_checklist.md").exists()
    has_rejected_edits = (references_dir / "rejected_edits.md").exists()
    has_optimizer_memory = (references_dir / "optimizer_memory.md").exists()
    structure_checks = [
        SkillCheck(
            name="has_skill_md",
            score=16,
            max_score=16,
            status="pass",
            message="SKILL.md exists",
        ),
        SkillCheck(
            name="has_scripts_dir",
            score=5 if has_scripts_dir else 0,
            max_score=5,
            status="pass" if has_scripts_dir else "warn",
            message="scripts directory exists" if has_scripts_dir else "scripts directory missing",
        ),
        SkillCheck(
            name="has_script_files",
            score=5 if has_script_files else 0,
            max_score=5,
            status="pass" if has_script_files else "warn",
            message="has script files" if has_script_files else "no script files",
        ),
        SkillCheck(
            name="has_selftest",
            score=8 if has_selftest else 0,
            max_score=8,
            status="pass" if has_selftest else "warn",
            message="selftest.sh exists" if has_selftest else "selftest.sh missing",
        ),
        SkillCheck(
            name="has_openai_yaml",
            score=4 if has_agents else 0,
            max_score=4,
            status="pass" if has_agents else "warn",
            message="agents/openai.yaml exists" if has_agents else "agents/openai.yaml missing",
        ),
        SkillCheck(
            name="has_eval_items",
            score=2 if has_eval else 0,
            max_score=2,
            status="pass" if has_eval else "warn",
            message="eval/val/items.json exists" if has_eval else "eval/val/items.json missing",
        ),
    ]
    structure = sum(item.score for item in structure_checks)
    checks.extend(structure_checks)

    # documentation: 30
    docs_map = {
        "has_purpose": has_any(doc_text, DOC_KEYWORDS["purpose"]),
        "has_trigger": has_any(doc_text, DOC_KEYWORDS["trigger"]),
        "has_example": has_any(doc_text, DOC_KEYWORDS["example"]),
        "has_safety": has_any(doc_text, DOC_KEYWORDS["safety"]),
    }
    docs_checks = [
        SkillCheck(
            name="doc_has_purpose",
            score=6 if docs_map["has_purpose"] else 0,
            max_score=6,
            status="pass" if docs_map["has_purpose"] else "warn",
            message="purpose/use case description present" if docs_map["has_purpose"] else "missing purpose/use case description",
        ),
        SkillCheck(
            name="doc_has_trigger",
            score=6 if docs_map["has_trigger"] else 0,
            max_score=6,
            status="pass" if docs_map["has_trigger"] else "warn",
            message="trigger scenario description present"
            if docs_map["has_trigger"]
            else "missing trigger scenario description",
        ),
        SkillCheck(
            name="doc_has_example",
            score=8 if docs_map["has_example"] else 0,
            max_score=8,
            status="pass" if docs_map["has_example"] else "warn",
            message="example commands present" if docs_map["has_example"] else "missing example commands",
        ),
        SkillCheck(
            name="doc_has_safety",
            score=4 if docs_map["has_safety"] else 0,
            max_score=4,
            status="pass" if docs_map["has_safety"] else "warn",
            message="safety/confirm guidance present"
            if docs_map["has_safety"]
            else "safety/confirm guidance missing",
        ),
        SkillCheck(
            name="has_gate_checklist",
            score=3 if has_gate_reference else 0,
            max_score=3,
            status="pass" if has_gate_reference else "warn",
            message="references/gate_checklist.md exists"
            if has_gate_reference
            else "references/gate_checklist.md missing",
        ),
        SkillCheck(
            name="has_rejected_edits",
            score=2 if has_rejected_edits else 0,
            max_score=2,
            status="pass" if has_rejected_edits else "warn",
            message="references/rejected_edits.md exists"
            if has_rejected_edits
            else "references/rejected_edits.md missing",
        ),
        SkillCheck(
            name="has_optimizer_memory",
            score=1 if has_optimizer_memory else 0,
            max_score=1,
            status="pass" if has_optimizer_memory else "warn",
            message="references/optimizer_memory.md exists"
            if has_optimizer_memory
            else "references/optimizer_memory.md missing",
        ),
    ]
    documentation = sum(item.score for item in docs_checks)
    checks.extend(docs_checks)

    # executability: 20
    sh_scripts = [p for p in script_files if p.suffix == ".sh"]
    syntax_score, syntax_issues = syntax_check_items(sh_scripts, parallel)
    selftest_exec = os.access(selftest, os.X_OK) if has_selftest else False
    selftest_text = read_text(selftest) if has_selftest else ""
    supports_safe = bool(re.search(r"(^|\s)--safe(\s|$)", selftest_text))

    selftest_exec_score = 4 if has_selftest and selftest_exec else 0
    if with_safe_check and has_selftest and supports_safe:
        safe_score = 4
    elif with_safe_check:
        safe_score = 0
    else:
        safe_score = 4 if has_selftest else 0

    executability = syntax_score + selftest_exec_score + safe_score
    exec_checks = [
        SkillCheck(
            name="shell_syntax",
            score=syntax_score,
            max_score=12,
            status="pass" if syntax_score == 12 else "warn",
            message="all shell scripts pass bash -n"
            if syntax_score == 12 and sh_scripts
            else ("no shell scripts found" if not sh_scripts else "some shell scripts fail bash -n"),
        ),
        SkillCheck(
            name="selftest_executable",
            score=selftest_exec_score,
            max_score=4,
            status="pass" if selftest_exec else "warn",
            message="selftest.sh executable" if selftest_exec else "selftest.sh not executable",
        ),
        SkillCheck(
            name="selftest_safe",
            score=safe_score,
            max_score=4,
            status="pass" if safe_score == 4 else ("warn" if has_selftest else "info"),
            message=(
                "selftest.sh exposes --safe"
                if safe_score == 4
                else (
                    "--safe not detected in selftest.sh"
                    if has_selftest
                    else "selftest.sh missing"
                )
            ),
        ),
    ]
    checks.extend(exec_checks)

    # risk: 10
    scripts_blob = "\n".join(read_text(p) for p in script_files)
    risk_score, risk_hits = check_risk_patterns(scripts_blob)
    risk_checks = [
        SkillCheck(
            name="risk_scan",
            score=risk_score,
            max_score=10,
            status="pass" if risk_score == 10 else "warn",
            message="no obvious risk patterns" if risk_score == 10 else f"risk hits: {', '.join(sorted(set(risk_hits)))}",
        )
    ]
    checks.extend(risk_checks)

    total = structure + documentation + executability + risk_score

    issues: List[str] = []
    suggestions: List[str] = []
    if not has_script_files:
        suggestions.append("Add a scripts/ directory with reproducible helper scripts.")
    if not has_selftest:
        suggestions.append("Add scripts/selftest.sh for lightweight smoke validation.")
    if not docs_map["has_safety"]:
        suggestions.append("Add explicit dangerous-operation confirmation guidance in SKILL.md.")
    if not supports_safe and with_safe_check and has_selftest:
        suggestions.append("Expose a --safe mode for non-destructive self-testing.")
    if risk_hits:
        issues.append(f"Risk patterns detected: {', '.join(sorted(set(risk_hits)))}")
    if syntax_issues:
        issues.extend([f"Syntax issue: {issue}" for issue in syntax_issues[:20]])

    return {
        "name": name,
        "path": str(skill_dir),
        "score": {
            "total": int(total),
            "structure": int(structure),
            "documentation": int(documentation),
            "executability": int(executability),
            "risk": int(risk_score),
        },
        "checks": [
            {
                "name": item.name,
                "score": item.score,
                "max_score": item.max_score,
                "status": item.status,
                "message": item.message,
            }
            for item in checks
        ],
        "issues": issues,
        "suggestions": suggestions,
        "safe_check_supported": has_selftest and supports_safe,
        "weights": WEIGHTS,
    }


def format_table(results: List[dict], min_score: int) -> str:
    header = [
        "skill",
        "path",
        "total",
        "structure",
        "documentation",
        "executability",
        "risk",
        "safe",
        "status",
    ]
    rows = []
    for item in results:
        score = item["score"]
        status = "PASS" if score["total"] >= min_score else "FAIL"
        rows.append(
            [
                item["name"],
                item["path"],
                str(score["total"]),
                str(score["structure"]),
                str(score["documentation"]),
                str(score["executability"]),
                str(score["risk"]),
                "yes" if item["safe_check_supported"] else "no",
                status,
            ]
        )

    widths = [len(h) for h in header]
    for row in rows:
        for idx, value in enumerate(row):
            widths[idx] = max(widths[idx], len(value))

    def row_to_line(row: Sequence[str]) -> str:
        return "| " + " | ".join(value.ljust(widths[i]) for i, value in enumerate(row)) + " |"

    separator = "| " + " | ".join("-" * widths[i] for i, _ in enumerate(header)) + " |"
    lines = [row_to_line(header), separator]
    lines.extend(row_to_line(row) for row in rows)
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run a full quality scan for all top-level skills."
    )
    parser.add_argument(
        "--root", default=".", help="Repository root path, default is current directory."
    )
    parser.add_argument("--parallel", type=int, default=4, help="Parallel workers for syntax checks.")
    parser.add_argument(
        "--min-score",
        type=int,
        default=70,
        help="Fail if any skill or average score is below this threshold.",
    )
    parser.add_argument(
        "--with-safe-check",
        action="store_true",
        help="Deduct points when selftest.sh does not expose --safe.",
    )
    parser.add_argument(
        "--format",
        choices=["table", "json"],
        default="table",
        help="Output format.",
    )
    parser.add_argument("--json", default="", help="Optional path to write a JSON report.")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    skill_files = discover_skills(root)
    results = [score_skill(skill, args.parallel, args.with_safe_check) for skill in skill_files]

    avg = round(sum(item["score"]["total"] for item in results) / len(results), 2) if results else 0.0
    failed = [item for item in results if item["score"]["total"] < args.min_score]

    summary = {
        "generated_at": datetime.now(tz=timezone.utc).isoformat(),
        "root": str(root),
        "summary": {
            "skill_count": len(results),
            "avg_score": avg,
            "min_score": min((item["score"]["total"] for item in results), default=0),
            "max_score": max((item["score"]["total"] for item in results), default=0),
            "failed_count": len(failed),
            "failed_skills": sorted(item["name"] for item in failed),
        },
        "results": results,
        "options": {
            "parallel": args.parallel,
            "with_safe_check": args.with_safe_check,
            "min_score": args.min_score,
        },
    }

    if args.format == "json":
        payload = json.dumps(summary, ensure_ascii=False, indent=2)
        print(payload)
        if args.json:
            Path(args.json).write_text(payload, encoding="utf-8")
    else:
        print(format_table(results, args.min_score))
        print(
            f"Summary: total={len(results)}, avg={avg}, "
            f"min={summary['summary']['min_score']}, max={summary['summary']['max_score']}, "
            f"failed={len(failed)}"
        )
        print(f"Failed skills: {', '.join(summary['summary']['failed_skills']) or '-'}")
        if args.json:
            Path(args.json).write_text(
                json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
            )
            print(f"JSON report written: {args.json}")

    # Keep strict by default to make this usable in CI.
    if failed or avg < args.min_score:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

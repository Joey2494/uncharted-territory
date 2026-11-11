"""统一执行第九周行为回归；支持源码 Godot 或已经导出的游戏 EXE。"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path

SUITES = (
    "test_secret_door", "test_room_progress", "test_gate_lifecycle",
    "test_gate_integration", "test_level02_layout",
    "test_energy_relay", "test_level02_integration", "test_level02_navigation",
    "test_campaign_flow", "test_export_presentation",
)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    engine = parser.add_mutually_exclusive_group(required=True)
    engine.add_argument("--godot", type=Path)
    engine.add_argument("--game", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    executable = (args.game or args.godot).resolve(strict=True)
    repo = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    results = []
    for suite in SUITES:
        command = [str(executable), "--headless", "--fixed-fps", "60"]
        if args.godot:
            command += ["--path", str(repo)]
        command += (["--", "--week09-test", suite] if args.game else
                    ["--script", f"res://tests/dungeon/{suite}.gd"])
        # 导出版从它自己的目录启动，不添加源码路径，保证确实检查 PCK 中的资源。
        result = subprocess.run(command, cwd=executable.parent if args.game else repo,
                                capture_output=True, text=True, encoding="utf-8",
                                errors="replace", timeout=180)
        text = result.stdout + result.stderr
        (output / f"{suite}.log").write_text(text, encoding="utf-8")
        summary = re.findall(r"(?m)^\w+:\s+(\d+) checks,\s+(\d+) failures", text)
        valid = (result.returncode == 0 and len(summary) == 1 and
                 int(summary[0][0]) > 0 and int(summary[0][1]) == 0 and
                 not re.search(r"(?m)^(?:SCRIPT ERROR|ERROR):", text))
        row = {"suite": suite, "passed": valid, "exit_code": result.returncode,
               "checks": int(summary[0][0]) if summary else None,
               "failures": int(summary[0][1]) if summary else None}
        results.append(row)
        print(json.dumps(row), flush=True)
    (output / "results.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
    raise SystemExit(0 if all(row["passed"] for row in results) else 1)


if __name__ == "__main__":
    main()

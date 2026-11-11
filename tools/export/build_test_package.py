"""从固定 Git 提交构建 Windows 测试包；不读取工作区未提交资源、不覆盖已有输出。"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
from datetime import datetime
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED


def run(args: list[str], cwd: Path, log: Path | None = None, timeout: int = 1200) -> str:
    """保留每一步完整日志，并同时检查返回值与 Godot 错误文本。"""
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=timeout)
    output = result.stdout + result.stderr
    if log:
        log.write_text(output, encoding="utf-8")
    if result.returncode or re.search(r"(?m)^(?:SCRIPT ERROR|ERROR):", output):
        raise RuntimeError(f"执行失败：{args[0]}；日志：{log}\n{output[-4000:]}")
    return output.strip()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path, help="仓库外、尚不存在的输出目录")
    parser.add_argument("--commit", default="HEAD")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    if output == repo or repo in output.parents:
        raise ValueError("输出目录必须在源码仓库之外")
    engine = args.godot.resolve(strict=True)
    commit = run(["git", "rev-parse", "--verify", args.commit + "^{commit}"], repo)
    version = "week09-" + commit[:7]
    output.mkdir(parents=True, exist_ok=False)
    stage, package, logs = (output / part for part in ("source", "game", "logs"))
    stage.mkdir()
    package.mkdir()
    logs.mkdir()
    archive = output / "source.zip"
    run(["git", "archive", "--format=zip", "--output=" + str(archive), commit], repo)
    with ZipFile(archive) as source:
        source.extractall(stage)
    # 仅改隔离构建副本；用户本地 project.godot / .import 原样保留。
    project = stage / "project.godot"
    content = project.read_text(encoding="utf-8-sig")
    if content.count('[application]\n') != 1 or content.count('run/main_scene="res://Main.tscn"') != 1:
        raise ValueError("源码主场景配置已变化，请先更新构建入口规则")
    content = re.sub(r'^config/version=.*\n?', '', content, flags=re.M)
    content = content.replace("[application]\n", f'[application]\nconfig/version="{version}"\n', 1)
    content = content.replace('run/main_scene="res://Main.tscn"', 'run/main_scene="res://tools/export/PackageEntry.tscn"')
    # 编辑器自带 ICU 断行数据，release 默认不携带；中文按词换行必须显式导出。
    if "[internationalization]" not in content:
        content += "\n[internationalization]\nlocale/include_text_server_data=true\n"
    elif re.search(r"^locale/include_text_server_data=", content, re.M):
        content = re.sub(r"^locale/include_text_server_data=.*$", "locale/include_text_server_data=true", content, flags=re.M)
    else:
        content = content.replace("[internationalization]\n", "[internationalization]\nlocale/include_text_server_data=true\n", 1)
    project.write_text(content, encoding="utf-8")
    shutil.copyfile(stage / "tools/export/windows-test.cfg", stage / "export_presets.cfg")
    engine_version = run([str(engine), "--version"], stage)
    run([str(engine), "--headless", "--path", str(stage), "--editor", "--import", "--quit"], stage, logs / "import.log")
    exe = package / "UnchartedTerritory.exe"
    run([str(engine), "--headless", "--path", str(stage), "--export-release", "Windows Test", str(exe)], stage, logs / "export.log")
    if not exe.is_file() or not exe.with_suffix(".pck").is_file():
        raise RuntimeError("导出缺少 EXE 或 PCK")
    # 运行导出程序自身，用空工作目录排除错误读取源码目录的可能。
    smoke = run([str(exe), "--headless", "--fixed-fps", "60", "--", "--week09-test", "smoke"], package, logs / "package-smoke.log", timeout=60)
    if "PACKAGE_SMOKE: 0 failures" not in smoke:
        raise RuntimeError("导出程序未完成冒烟测试，拒绝生成交付压缩包")
    metadata = {"version": version, "source_commit": commit, "engine": engine_version,
                "built_at": datetime.now().astimezone().isoformat(), "target": "Windows x64",
                "validation": "导出程序内加载两关并开始游戏；自动化验证不等同于人工难度验收"}
    (package / "version.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
    (package / "试玩说明.txt").write_text(
        f"未知之境 · 第九周测试包\n版本：{version}\n源码提交：{commit}\n\n"
        "解压整个目录，双击 UnchartedTerritory.exe；exe 与 pck 必须放在一起，无需安装 Godot。\n"
        "WASD/方向键移动，Shift 疾跑，鼠标左键近战，Q 能量冲击，Space 闪避。\n"
        "角色朝移动方向攻击；E 拾取/交互，R 药剂，F 强化符文，ESC 暂停。\n"
        "第一关开始后入口门会开启。通关条件是击败守门者并实际进入出口。\n"
        "第一关结算选择前往第二关；第二关也支持重开和返回第一关。角落指南提供规则。\n"
        "两关独立整备，不继承背包或生命；无存档。第二关守门者仍使用现有 Boss 占位。\n"
        "本包包含白盒与自动化验收资源，美术、战斗难度和后续内容仍可继续迭代。\n",
        encoding="utf-8-sig")
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(package.iterdir()) if p.is_file()}
    (package / "SHA256.json").write_text(json.dumps(hashes, ensure_ascii=False, indent=2), encoding="utf-8")
    bundle = output / f"UnchartedTerritory-{version}-Windows-x64.zip"
    with ZipFile(bundle, "w", ZIP_DEFLATED) as target:
        for file in sorted(package.iterdir()):
            target.write(file, "UnchartedTerritory/" + file.name)
    (output / "bundle.sha256").write_text(hashlib.sha256(bundle.read_bytes()).hexdigest() + "  " + bundle.name + "\n", encoding="ascii")
    print(json.dumps({**metadata, "package": str(bundle), "unpacked": str(package), "logs": str(logs)}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

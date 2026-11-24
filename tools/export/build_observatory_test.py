"""从已提交源码构建含四关战役的 Windows 测试包，在解压后的交付物内运行回归。"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
from tempfile import TemporaryDirectory
from zipfile import ZIP_DEFLATED, ZipFile

from build_test_package import run

SUITES = {
    "test_level04_menu": "0 failures",
    "test_level04_campaign": "LEVEL04_CAMPAIGN:",
    "test_level04_geometry": "/ 0 failed",
    "test_level04_instruments": "/ 0 failed",
    "test_level04_combat": "failed=0",
    "test_level04_camera_run": "level04 camera run:",
    "test_level04_dome_visibility": "restored island pieces = 5 of 5",
    "test_level04_routes": "0 failures; input_walk=false",
}

LAUNCHES = {
    "boot": ([], "res://Main.tscn"),
    "boot-practice": (["--", "--observatory"], "res://scenes/dungeon/Level04Practice.tscn"),
}

def verify(exe, logs, userdata):
    env = dict(os.environ, APPDATA=str(userdata))
    userdata.mkdir(parents=True)
    for name, (args, scene) in LAUNCHES.items():
        boot = subprocess.run([str(exe), "--headless", "--verbose", "--max-fps", "60", "--quit-after", "360", *args],
                              cwd=exe.parent, env=env, capture_output=True, timeout=60)
        launch = (boot.stdout + boot.stderr).decode("utf-8", errors="replace")
        path = logs / (name + ".log")
        path.write_text(launch, encoding="utf8")
        if boot.returncode or f"Completed load for: '{scene}'" not in launch or "ERROR:" in launch:
            raise RuntimeError(f"发行包启动检查失败，检查 {path}")
    runs = [(suite, [], marker) for suite, marker in SUITES.items()]
    runs.extend(("test_level04_routes", [f"--walk-mask={n}"], "0 failures; input_walk=true")
                for n in (0, 1, 2, 4, 8, 15))
    runs.append(("test_level04_routes", ["--walk-mask=0", "--west-first"], "0 failures; input_walk=true"))
    runs.append(("test_level04_camera_run", ["--east"], "level04 camera run:"))
    runs.append(("test_level04_campaign_routes", ["--walk"], "0 failures; input_walk=true"))
    for suite, extra, marker in runs:
        name = suite + "".join(arg.replace("--walk-mask=", "-walk-").replace("--", "-") for arg in extra)
        cmd = [str(exe), "--headless", "--fixed-fps", "60", "--", "--observatory-test", suite, *extra]
        with (logs / (name + ".log")).open("w", encoding="utf-8") as log:
            res = subprocess.run(cmd, cwd=exe.parent, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        report = (logs / (name + ".log")).read_text(encoding="utf8", errors="replace")
        if (res.returncode or marker not in report or "ERROR:" in report or "\nFAIL " in report
                or (suite == "test_level04_campaign" and "0 failures" not in report)):
            raise RuntimeError(f"{name} 未通过，检查 {logs / (name + '.log')}")
        print(name, "OK", flush=True)
    return len(LAUNCHES) + len(runs)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    if output == repo or repo in output.parents:
        raise ValueError("请选择源码目录以外的新目录")
    git_sha = run(["git","rev-parse","HEAD"], repo)
    output.mkdir(parents=True,exist_ok=False)
    with TemporaryDirectory(prefix="obs-build-") as scratch:
        build(repo, git_sha, output, Path(scratch), str(args.godot.resolve(strict=True)))

def build(repo, git_sha, output, scratch, engine):
    stage, game, logs = scratch/"source", output/"Windows", output/"logs"
    for path in (stage,game,logs): path.mkdir()
    source = scratch / "source.zip"
    run(["git","archive","--format=zip","--output="+str(source),git_sha],repo)
    with ZipFile(source) as archive: archive.extractall(stage)
    cfg = stage / "project.godot"
    content = cfg.read_text(encoding="utf-8-sig")
    entry = 'run/main_scene="res://scenes/ui/LoadingEntry.tscn"'
    if content.count(entry) != 1: raise RuntimeError("请检查战役入口")
    cfg.write_text(content.replace(entry,'run/main_scene="res://tools/export/PackageEntry.tscn"')
                   +'\n[internationalization]\nlocale/include_text_server_data=true\n',encoding="utf8")
    shutil.copyfile(stage/"tools/export/windows-test.cfg", stage/"export_presets.cfg")
    run([engine,"--headless","--path",str(stage),"--editor","--import","--quit"],stage,logs/"import.log")
    exe = game/"Observatory.exe"
    run([engine,"--headless","--path",str(stage),"--export-release","Windows Test",str(exe)],stage,logs/"export.log")
    if not exe.with_suffix(".pck").is_file(): raise RuntimeError("导出缺少 PCK")
    (game/"试玩说明.txt").write_text(
        "未知之境 · 四关战役测试包\n解压整个 Windows 文件夹，双击 Observatory.exe 进入主菜单。\n"
        "开始游戏 → 确认角色 → 关卡选择。选择第四关卡片进入正式战役，也可从第三关结算继续。\n"
        "选关页另有第四关独立试玩，也可运行 Observatory.exe -- --observatory 直接进入。\n"
        "试玩沿用已选角色，本局拾取和消费有效，通关不写入战役进度或永久钱包。\n\n"
        "在 C 分度大厅选择东翼校准曝光柜，或西翼清除栈道守卫。两翼完成后，从任一侧进入试车场。\n"
        "Tab 查看观测站路线，M 查看任务地图；悬停封锁标记查看原因。Esc 暂停。\n"
        "WASD 移动，Shift 奔跑，空格闪避，J 普攻，K 法术，L 角色技能，E 就近交互。"
        "R 生命药剂，F 强化，G 守护，P 商店。读片与密码柜支持鼠标操作。\n"
        "第四关通过 J 区升降台后结算。\n源码提交 "+git_sha+"\n",
        encoding="utf-8-sig")
    bundle = output/f"Observatory-{git_sha[:7]}-Windows-x64.zip"
    with ZipFile(bundle,"w",ZIP_DEFLATED,compresslevel=4) as archive:
        for file in sorted(game.iterdir()): archive.write(file, "Windows/"+file.name)
    with ZipFile(bundle) as archive: archive.extractall(scratch/"verified")
    checks = verify(scratch/"verified/Windows/Observatory.exe",logs,scratch/"qa-user")
    with bundle.open("rb") as stream:
        digest = hashlib.file_digest(stream,"sha256").hexdigest()
    (output/"verification.json").write_text(json.dumps(
        {"commit":git_sha,"engine":run([engine,"--version"],stage),"zip":bundle.name,"sha256":digest,
         "package_checks":checks},ensure_ascii=False,indent=2),encoding="utf8")
    print(bundle, digest)

if __name__ == "__main__":
    main()

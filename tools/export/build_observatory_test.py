"""从已经提交的第四关源码构建独立 Windows 试玩，在解压后的交付物内运行回归。"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
from zipfile import ZIP_DEFLATED, ZipFile

from build_test_package import run

SUITES = {
    "test_level04_menu": "0 failures",
    "test_level04_geometry": "/ 0 failed",
    "test_level04_instruments": "/ 0 failed",
    "test_level04_combat": "0 failures",
    "test_level04_camera_run": "level04 camera run:",
    "test_level04_dome_visibility": "restored island pieces = 5 of 5",
    "test_level04_routes": "0 failures; input_walk=false",
}

def verify(exe, logs, userdata):
    env = dict(os.environ, APPDATA=str(userdata))
    userdata.mkdir(parents=True)
    # 无用户参数启动，确认玩家双击后的默认入口也来自发行包。
    boot = subprocess.run([str(exe),"--headless","--verbose","--quit-after","30"],cwd=exe.parent,
                          env=env,capture_output=True,timeout=60)
    launch = (boot.stdout+boot.stderr).decode("utf-8",errors="replace")
    (logs/"boot.log").write_text(launch,encoding="utf8")
    if boot.returncode or "Level04Preview" not in launch or "SCRIPT ERROR:" in launch:
        raise RuntimeError("导出程序默认入口检查失败，请查看 boot.log")
    runs = [(suite, [], marker) for suite, marker in SUITES.items()]
    runs.extend(("test_level04_routes", [f"--walk-mask={n}"], "0 failures; input_walk=true")
                for n in (0, 1, 2, 4, 8, 15))
    for suite, extra, marker in runs:
        name = suite + (extra[0].replace("--walk-mask=", "-walk-") if extra else "")
        cmd = [str(exe), "--headless", "--fixed-fps", "60", "--", "--observatory-test", suite, *extra]
        with (logs / (name + ".log")).open("w", encoding="utf-8") as log:
            res = subprocess.run(cmd, cwd=exe.parent, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        report = (logs / (name + ".log")).read_text(encoding="utf8", errors="replace")
        if res.returncode or marker not in report or any(s in report for s in ("SCRIPT ERROR:", "ERROR:", "\nFAIL ")):
            raise RuntimeError(f"{name} 未通过，检查 {logs / (name + '.log')}")
        print(name, "OK", flush=True)

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
    stage, game, logs = (output / p for p in ("source","Windows","logs"))
    output.mkdir(parents=True,exist_ok=False)
    for path in (stage,game,logs): path.mkdir()
    source = output / "source.zip"
    run(["git","archive","--format=zip","--output="+str(source),git_sha],repo)
    with ZipFile(source) as archive: archive.extractall(stage)
    cfg = stage / "project.godot"
    content = cfg.read_text(encoding="utf-8-sig")
    entry = 'run/main_scene="res://Main.tscn"'
    if content.count(entry) != 1: raise RuntimeError("请检查战役入口")
    cfg.write_text(content.replace(entry,'run/main_scene="res://tools/export/PackageEntry.tscn"')
                   +'\n[observatory]\nstart_in_preview=true\n'
                   +'\n[internationalization]\nlocale/include_text_server_data=true\n',encoding="utf8")
    shutil.copyfile(stage/"tools/export/windows-test.cfg", stage/"export_presets.cfg")
    engine = str(args.godot.resolve(strict=True))
    run([engine,"--headless","--path",str(stage),"--editor","--import","--quit"],stage,logs/"import.log")
    exe = game/"Observatory.exe"
    run([engine,"--headless","--path",str(stage),"--export-release","Windows Test",str(exe)],stage,logs/"export.log")
    if not exe.with_suffix(".pck").is_file(): raise RuntimeError("导出缺少 PCK")
    (game/"试玩说明.txt").write_text(
        "未知之境 · 第四关 日晷观测站\n解压整个 Windows 文件夹，双击 Observatory.exe。\n"
        "金色地线通往升降台，青色菱形通往可选房。Tab 查看路线，Esc 暂停，可查看背包、重开或返回选关。\n"
        "WASD 移动，Shift 奔跑，空格闪避，J 普攻，K 法术，L 角色技能，E 就近交互。"
        "R 生命药剂，F 强化，G 守护，P 商店。读片与密码柜支持鼠标操作。\n"
        "本次试玩独立开局，沿用选定角色，通过升降台后结算。\n源码提交 "+git_sha+"\n",
        encoding="utf-8-sig")
    bundle = output/f"Observatory-{git_sha[:7]}-Windows-x64.zip"
    with ZipFile(bundle,"w",ZIP_DEFLATED,compresslevel=4) as archive:
        for file in sorted(game.iterdir()): archive.write(file, "Windows/"+file.name)
    with ZipFile(bundle) as archive: archive.extractall(output/"verified")
    verify(output/"verified/Windows/Observatory.exe",logs,output/"qa-user")
    with bundle.open("rb") as stream:
        digest = hashlib.file_digest(stream,"sha256").hexdigest()
    (output/"verification.json").write_text(json.dumps(
        {"commit":git_sha,"engine":run([engine,"--version"],stage),"zip":bundle.name,"sha256":digest,
         "package_checks":len(SUITES)+7},ensure_ascii=False,indent=2),encoding="utf8")
    print(bundle, digest)

if __name__ == "__main__":
    main()

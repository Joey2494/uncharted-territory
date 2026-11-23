@echo off
setlocal
if not defined GODOT_EXE set "GODOT_EXE=D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_EXE%" (
 echo Set GODOT_EXE to Godot 4.7.2.
 pause
 exit /b 1
)
start "" "%GODOT_EXE%" --path "%~dp0." res://scenes/dungeon/Level03Run.tscn

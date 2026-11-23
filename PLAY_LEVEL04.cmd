@echo off
setlocal
if not defined GODOT_EXE set "GODOT_EXE=D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_EXE%" (
 echo Set GODOT_EXE to your Godot 4 executable.
 pause
 exit /b 1
)
start "" "%GODOT_EXE%" --path "%~dp0." res://addons/ziyuan_level04/Prototype.tscn

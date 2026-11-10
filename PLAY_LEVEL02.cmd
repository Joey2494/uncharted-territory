@echo off
setlocal
if not defined GODOT_EXE set "GODOT_EXE=D:\software\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_EXE%" (
  echo Godot was not found. Set GODOT_EXE to your Godot 4 executable.
  pause
  exit /b 1
)
start "" "%GODOT_EXE%" --path "%~dp0." res://tests/scenes/Level02Preview.tscn

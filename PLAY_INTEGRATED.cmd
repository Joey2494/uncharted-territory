@echo off
setlocal
if defined GODOT_EXE if exist "%GODOT_EXE%" goto launch
for %%G in ("%~dp0..\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" "D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe") do if exist "%%~G" (
 set "GODOT_EXE=%%~G"
 goto launch
)
for %%G in (godot.exe godot4.exe) do for /f "delims=" %%P in ('where %%G 2^>nul') do (
 set "GODOT_EXE=%%P"
 goto launch
)
echo Set GODOT_EXE to your Godot 4.7 executable, then run this launcher again.
pause
exit /b 1
:launch
start "" "%GODOT_EXE%" --path "%~dp0."

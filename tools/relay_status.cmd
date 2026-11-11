@echo off
chcp 65001 >nul
python "%~dp0relay_status.py" %*
if errorlevel 1 pause

@echo off
title DroneFlames Test Builder
cd /d "%~dp0"
echo ===================================================
echo   DroneFlames Reborn - Test Version Builder
echo ===================================================
python build_test.py %*
pause

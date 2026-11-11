@echo off
chcp 65001 >nul
echo ===================================================
echo   DroneFlames Reborn - Build & Packaging
echo   Author: Reborn Team
echo ===================================================
echo.

where python >nul 2>nul
if %ERRORLEVEL% equ 0 (
    python "%~dp0build.py"
    pause
    exit /b %ERRORLEVEL%
)

echo [Notice] Python not found in PATH, trying direct Inno Setup compilation...
set "ISCC_PATH=C:\Users\mxka\AppData\Local\Programs\Inno Setup 6\ISCC.exe"
if not exist "%ISCC_PATH%" set "ISCC_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if not exist "%ISCC_PATH%" set "ISCC_PATH=C:\Program Files\Inno Setup 6\ISCC.exe"

if not exist "%ISCC_PATH%" (
    echo [Error] Inno Setup 6 not found!
    pause
    exit /b 1
)

"%ISCC_PATH%" /DOutDir="%~dp0dist" "%~dp0installer.iss"
pause

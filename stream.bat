@echo off
cd /d "%~dp0"
setlocal enabledelayedexpansion

title Stream Server v3.0

for /f %%i in ('where py 2^>nul') do set PY=%%i
if not defined PY for /f %%i in ('where python 2^>nul') do set PY=%%i
if not defined PY (
    echo Python not found. Install Python 3.10+ from python.org
    pause
    exit /b 1
)

echo Installing dependencies...
cd server
"%PY%" -m pip install -q -r requirements.txt 2>nul

echo Starting Stream Server...
"%PY%" server.py

if errorlevel 1 (
    echo Server exited with code %errorlevel%
    pause
)

endlocal

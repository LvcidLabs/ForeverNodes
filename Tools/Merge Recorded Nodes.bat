@echo off
rem Adds the nodes recorded in game to Forever Nodes' bundled list (Data.lua).
rem /reload or log out first: the game only saves recorded spots then.
title Forever Nodes - merge recorded nodes
cd /d "%~dp0"
python merge_recorded.py --apply
if errorlevel 1 (
    echo.
    echo Something went wrong. If Python is not installed, get it from python.org.
)
echo.
pause

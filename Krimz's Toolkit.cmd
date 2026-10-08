@echo off
rem Opens Krimz's Toolkit. It asks for admin rights - click "Yes".
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0Toolkit.ps1"


@echo off
:: install_windows.cmd
:: Copyright (c) 2024 PiSaucer
:: Licensed under the MIT License

:: Run install_windows.ps1 as Administrator
powershell.exe -NoProfile -Command "Start-Process PowerShell.exe -Verb RunAs -Wait -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0install_windows.ps1""'"

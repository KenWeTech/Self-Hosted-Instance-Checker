@echo off
setlocal

:: Set the target folder location
set "TargetFolder=%~dp0"

:: Run SelfHostedInstancesChecker.ps1 and wait for it to finish
powershell.exe -ExecutionPolicy Bypass -File "%~dp0SelfHostedInstancesChecker.ps1" "%TargetFolder%"


echo All tasks completed!
timeout /t 3 >nul
exit

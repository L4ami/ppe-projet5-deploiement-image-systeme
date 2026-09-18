@echo off
REM =====================================================================
REM  Projet 5 - Lanceur de la post-installation (installation automatisee)
REM  Appele par autounattend.xml a la premiere ouverture de session.
REM  Role : copier le kit de deploiement depuis le media vers C:\Deploiement
REM         puis lancer le script PowerShell de configuration.
REM =====================================================================
setlocal
set "MEDIA=%~dp0"
echo.
echo  === Media de configuration detecte : %MEDIA%
echo.
if not exist "C:\Deploiement" md "C:\Deploiement"
xcopy "%MEDIA%*" "C:\Deploiement\" /E /I /Y /Q >nul
echo  === Kit de deploiement copie dans C:\Deploiement
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Deploiement\p5-post-install.ps1"
endlocal

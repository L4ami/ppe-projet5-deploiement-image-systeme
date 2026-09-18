@echo off
REM =====================================================================
REM  Projet 5 - Lanceur de la post-installation (restauration d'image)
REM  Appele par sysprep-unattend.xml apres restauration d'une image
REM  Clonezilla. Les logiciels sont deja presents dans l'image : on saute
REM  l'etape 7 avec -SansLogiciels, il ne reste que l'identite du poste.
REM =====================================================================
setlocal
set "MEDIA=%~dp0"
echo.
echo  === Media de configuration detecte : %MEDIA%
echo.
if not exist "C:\Deploiement" md "C:\Deploiement"
xcopy "%MEDIA%*" "C:\Deploiement\" /E /I /Y /Q >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Deploiement\p5-post-install.ps1" -SansLogiciels
endlocal

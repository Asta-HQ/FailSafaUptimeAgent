@echo off
SETLOCAL EnableDelayedExpansion

:: Administrator-Rechte prüfen
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Fehler: Bitte fuehre diese Batch-Datei als Administrator aus! (Rechtsklick -> Als Administrator ausfuehren)
    pause
    exit /b 1
)

SET "REPO_NAME=Asta-HQ/FailSafaUptimeAgent"
SET "INSTALL_DIR=C:\Program Files\FailsafeAgent"
SET "INSTALL_PATH=%INSTALL_DIR%\failsafe_agent.exe"

SET "TOKEN="
SET "SERVER="

:: Argumente parsen
:parse_args
if "%~1"=="" goto after_parse
if "%~1"=="--token" (
    set "TOKEN=%~2"
    shift
    shift
    goto parse_args
)
if "%~1"=="--server" (
    set "SERVER=%~2"
    shift
    shift
    goto parse_args
)
echo Unbekannter Parameter: %~1
pause
exit /b 1
:after_parse

:: Ordner erstellen, falls nicht vorhanden
if not exist "%INSTALL_DIR%" (
    mkdir "%INSTALL_DIR%"
)

echo Erkenne System-Architektur...
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set "ARCH=amd64"
) else if "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
    set "ARCH=arm64"
) else (
    echo Nicht unterstuetzte Architektur: %PROCESSOR_ARCHITECTURE%
    pause
    exit /b 1
)

set "ASSET_NAME=failsafe_agent-windows-%ARCH%.exe"
set "DOWNLOAD_URL=https://github.com/%REPO_NAME%/releases/latest/download/%ASSET_NAME%"

echo Lade neusten Agenten herunter von GitHub (%ASSET_NAME%)...
powershell -Command "Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%INSTALL_PATH%'"

if not exist "%INSTALL_PATH%" (
    echo Fehler beim Herunterladen des Agenten!
    pause
    exit /b 1
)

echo Binary erfolgreich unter %INSTALL_PATH% gespeichert!

:: Service nur installieren, wenn ein Token übergeben wurde
if not "%TOKEN%"=="" (
    echo Richte Windows-Dienst ein...
    
    :: Dienst erstellen (falls er schon existiert, vorher löschen)
    sc query FailsafeAgent >nul 2>&1
    if %errorLevel% equ 0 (
        sc stop FailsafeAgent >nul 2>&1
        sc delete FailsafeAgent >nul 2>&1
    )

    set "SERVICE_ARGS=--token %TOKEN%"
    if not "%SERVER%"=="" (
        set "SERVICE_ARGS=!SERVICE_ARGS! --server %SERVER!"
    )

    :: Windows-Dienst registrieren
    sc create FailsafeAgent binPath= "\"%INSTALL_PATH%\" %SERVICE_ARGS%" start= auto DisplayName= "Failsafe Uptime Agent"
    sc description FailsafeAgent "Uptime Monitoring Agent for Failsafe"
    
    :: Dienst direkt starten
    sc start FailsafeAgent
    
    echo Failsafe Agent wurde als Windows-Dienst installiert und gestartet!
) else (
    echo Hinweis: Kein --token angegeben. Der Windows-Dienst wurde NICHT installiert.
    echo Du kannst den Agenten jetzt manuell ausfuehren mit:
    echo   "%INSTALL_PATH%" --token "dein-token"
)

pause
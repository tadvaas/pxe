@echo off
wpeinit
echo [INFO] Network initialized with wpeinit.
if errorlevel 1 (
    echo [ERROR] Failed to initialize the network with wpeinit.
    pause
    exit /b 1
)

:: Retry loop for network share
:check_share
echo [INFO] Attempting to map network share...
net use Z: \\192.168.0.26\shared\win11 /persistent:no > nul 2>&1
if errorlevel 1 (
    echo [ERROR] Failed to map network share. Retrying in 30 seconds...
    ping -n 31 127.0.0.1 > nul
    goto check_share
)

echo [INFO] Network share mapped successfully.

Z:\setup.exe /unattend:X:\Windows\System32\unattend.xml
echo [INFO] Windows setup has been started successfully.

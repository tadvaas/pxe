@echo off
wpeinit
echo [%time%] [INFO] Waiting for network to initialize...

:: Check network connectivity by pinging the gateway
:check_network
ping -n 1 192.168.0.1 > nul 2>&1
if errorlevel 1 (
    echo [%time%] [ERROR] Network not ready. Retrying in 10 seconds...
    timeout /t 10 > nul
    goto check_network
)

echo [%time%] [INFO] Network initialized successfully.

:: Retry loop for network share
:check_share
echo [%time%] [INFO] Attempting to map network share...
net use Z: \\192.168.0.26\shared\win11 /persistent:no > nul 2>&1
if errorlevel 1 (
    echo [%time%] [ERROR] Failed to map network share. Retrying in 30 seconds...
    ping -n 31 127.0.0.1 > nul
    goto check_share
)

echo [%time%] [INFO] Network share mapped successfully.

:: Start Windows setup
Z:\setup.exe /unattend:X:\Windows\System32\unattend.xml
echo [%time%] [INFO] Windows setup has been started successfully.

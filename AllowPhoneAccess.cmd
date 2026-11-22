@echo off
REM Allows phones on the same network to reach the Global Village backend ports.
REM Right-click and "Run as administrator", or approve the UAC prompt.

netsh advfirewall firewall add rule name="GlobalVillage API" dir=in action=allow protocol=TCP localport=3000-3004
netsh advfirewall firewall add rule name="GlobalVillage Web" dir=in action=allow protocol=TCP localport=7357

echo.
echo Done. Phones on the same WiFi can now reach this PC (ports 3000-3004, 7357).
echo Press any key to close...
pause >nul

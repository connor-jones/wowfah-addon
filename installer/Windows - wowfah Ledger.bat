@echo off
rem wowfah Ledger for Windows: installs or updates the addon, and finds your saved ledger file.
rem It only copies the WowfahLedger folder into World of Warcraft\_forever_\Interface\AddOns.
rem Nothing is downloaded and nothing else on your computer is changed. Open this file in Notepad to read it.
setlocal EnableExtensions EnableDelayedExpansion
title wowfah Ledger
set "HERE=%~dp0"
set "SRC=!HERE!WowfahLedger"
set "WOW="
set "FL=_forever_"

echo.
echo   wowfah Ledger
echo   =============
echo.

call :find
if not defined WOW goto :ask
goto :menu

:ask
echo   World of Warcraft was not found automatically.
echo.
echo   1. Open the Battle.net app and select World of Warcraft.
echo   2. Click the cog next to Play, then "Show in Explorer".
echo   3. Drag the "World of Warcraft" folder onto this window and press Enter.
echo.
set "ASK="
set /p "ASK=  Folder: "
if not defined ASK goto :fail
set "ASK=!ASK:"=!"
call :try "!ASK!"
if not defined WOW (
  echo.
  echo   That folder has no _forever_ folder inside it, so WoW Forever is not installed there.
  goto :fail
)

:menu
echo   Game found: !WOW!\!FL!
echo.
echo   1  Install or update the addon
echo   2  Find my ledger file and open the upload page
echo   3  Close
echo.
set "PICK=1"
set /p "PICK=  Choose 1, 2 or 3 and press Enter [1]: "
if "!PICK!"=="2" goto :upload
if "!PICK!"=="3" goto :end
goto :install

:install
if not exist "!SRC!\WowfahLedger.toc" (
  echo.
  echo   The WowfahLedger folder is not next to this file.
  echo   Unzip the whole download first: right click the zip, Extract All. Then run this again.
  goto :fail
)
set "DEST=!WOW!\!FL!\Interface\AddOns"
if not exist "!DEST!\" mkdir "!DEST!" 2>nul
if exist "!DEST!\WowfahLedger\" rmdir /s /q "!DEST!\WowfahLedger" 2>nul
xcopy "!SRC!" "!DEST!\WowfahLedger\" /E /I /Q /Y >nul 2>nul
if not exist "!DEST!\WowfahLedger\WowfahLedger.toc" (
  echo.
  echo   Windows would not let the files be copied to:
  echo   !DEST!
  echo   Close the game, then right click this file and choose "Run as administrator".
  goto :fail
)
echo.
echo   Installed to !DEST!\WowfahLedger
echo.
echo   Next:
echo     1. Start the game, or type /reload if it is already running.
echo     2. On the character screen click AddOns and make sure wowfah Ledger is ticked.
echo        If it is greyed out, tick "Load out of date AddOns".
echo     3. In game, type /wowfah
echo.
echo   Keep this folder. Run this file again and choose 2 when you want to upload your ledger.
goto :end

:upload
set "FOUND="
set "MANY="
for /f "delims=" %%F in ('dir /b /s "!WOW!\!FL!\WTF\Account\WowfahLedger.lua" 2^>nul') do (
  if defined FOUND set "MANY=1"
  if not defined FOUND set "FOUND=%%F"
)
if not defined FOUND (
  echo.
  echo   No ledger file yet. The game writes it when you log out or type /sync
  echo   with the addon turned on. Do that, then choose 2 again.
  goto :end
)
echo.
echo   Your ledger file:
echo   !FOUND!
if defined MANY echo   You have more than one game account. Each has its own file in WTF\Account.
echo.
echo   A folder window is opening with the file selected, and the upload page is opening in your browser.
echo   Drag the file onto the page.
start "" explorer.exe /select,"!FOUND!"
start "" "https://wowfah.com/ledger/upload"
goto :end

:find
for /f "tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft" /v InstallPath 2^>nul ^| find /i "InstallPath"') do call :try "%%B"
for /f "tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\Blizzard Entertainment\World of Warcraft" /v InstallPath 2^>nul ^| find /i "InstallPath"') do call :try "%%B"
call :try "%ProgramFiles(x86)%\World of Warcraft"
call :try "%ProgramFiles%\World of Warcraft"
for %%L in (C D E F G H I J) do (
  call :try "%%L:\World of Warcraft"
  call :try "%%L:\Games\World of Warcraft"
  call :try "%%L:\Blizzard\World of Warcraft"
  call :try "%%L:\Battle.net\World of Warcraft"
  call :try "%%L:\Program Files (x86)\World of Warcraft"
)
exit /b

:try
rem Sets WOW when the folder given (or the one above it) holds the Forever game folder (_forever_, or forever).
if defined WOW exit /b
set "P=%~1"
if not defined P exit /b
if "!P:~-1!"=="\" set "P=!P:~0,-1!"
if exist "!P!\forever\Interface\" set "WOW=!P!" & set "FL=forever"
if exist "!P!\_forever_\" set "WOW=!P!" & set "FL=_forever_"
if defined WOW exit /b
for %%D in ("!P!\..") do (
  if exist "%%~fD\forever\Interface\" set "WOW=%%~fD" & set "FL=forever"
  if exist "%%~fD\_forever_\" set "WOW=%%~fD" & set "FL=_forever_"
)
exit /b

:fail
echo.
echo   Nothing was changed. You can also install by hand: https://wowfah.com/addon
:end
echo.
pause
endlocal

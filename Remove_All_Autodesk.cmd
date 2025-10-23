@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: =========================================
:: Remove All Autodesk Software (Windows)
:: =========================================

:: 0) Self-elevate to Administrator if needed
net session >nul 2>&1
if %errorlevel% NEQ 0 (
  echo [*] Elevating to administrator...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

:: 1) Setup logging
set "STAMP=%DATE:~10,4%-%DATE:~4,2%-%DATE:~7,2%_%TIME:~0,2%-%TIME:~3,2%"
set "STAMP=%STAMP: =0%"
set "LOG=%~dp0Autodesk_Uninstall_%STAMP%.log"
echo [*] Logging to: %LOG%
echo ==== Autodesk Uninstall Log %DATE% %TIME% ==== > "%LOG%"

:: 2) Stop common Autodesk services and processes
echo [*] Stopping Autodesk services... | tee >> "%LOG%"
for %%S in (
  AdskLicensingService
  AutodeskDesktopAppService
  AutodeskGenuineService
) do (
  sc query "%%S" >nul 2>&1 && (
    sc stop "%%S" >> "%LOG%" 2>&1
    sc config "%%S" start= disabled >> "%LOG%" 2>&1
  )
)

echo [*] Killing common Autodesk processes... | tee >> "%LOG%"
for %%P in (
  AdAppMgr.exe
  AdAppMgrSvc.exe
  AdskLicensingAgent.exe
  AdskIdentityManager.exe
  AutodeskDesktopApp.exe
  GenuineService.exe
) do (
  taskkill /F /IM "%%P" >> "%LOG%" 2>&1
)

:: 3) Use PowerShell to find and uninstall all Autodesk entries
echo [*] Discovering and uninstalling Autodesk products... | tee >> "%LOG%"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Continue';" ^
  "$paths = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall';" ^
  "$items = foreach($p in $paths){ if(Test-Path $p){ Get-ChildItem $p | ForEach-Object { try { Get-ItemProperty $_.PSPath } catch {} } } };" ^
  "$targets = $items | Where-Object { $_.DisplayName -or $_.Publisher } | Where-Object { ($_.Publisher -match 'Autodesk') -or ($_.DisplayName -match '^Autodesk') } | Sort-Object DisplayName -Unique;" ^
  "if(-not $targets){ Write-Host 'No Autodesk products found.'; exit 0 }" ^
  "$targets | ForEach-Object {" ^
  "  $name=$_.DisplayName; $quiet=$_.QuietUninstallString; $uninst=$_.UninstallString;" ^
  "  if([string]::IsNullOrWhiteSpace($name)){ $name='(Unnamed Autodesk entry)' }" ^
  "  if($quiet){ $cmd=$quiet }" ^
  "  elseif($uninst){" ^
  "    if($uninst -match '(?i)msiexec\.exe'){ if($uninst -match '({[0-9A-F-]+})'){ $code=$matches[1]; $cmd = 'msiexec /x ' + $code + ' /qn /norestart' } else { $cmd = $uninst + ' /qn /norestart' } }" ^
  "    else { if($uninst -notmatch '(?i)/quiet|/qn|/silent|/S'){ $cmd = $uninst + ' /quiet /norestart' } else { $cmd = $uninst } }" ^
  "  } else { $cmd=$null }" ^
  "  if($cmd){" ^
  "    Write-Host ('[Uninstall] ' + $name + ' -> ' + $cmd);" ^
  "    try { Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $cmd -Wait -PassThru | Out-Null } catch { Write-Warning ('Failed to launch uninstaller for ' + $name + ': ' + $_) }" ^
  "  } else { Write-Warning ('No uninstall string for ' + $name) }" ^
  "}" ^
  "Write-Host 'Autodesk uninstall phase complete.' " >> "%LOG%" 2>&1

:: 4) Remove common leftover folders (best-effort)
echo [*] Removing common Autodesk folders... | tee >> "%LOG%"

set "DIRS=C:\Program Files\Autodesk
C:\Program Files (x86)\Autodesk
%ProgramFiles%\Common Files\Autodesk Shared
%ProgramFiles(x86)%\Common Files\Autodesk Shared
%ProgramData%\Autodesk
%AppData%\Autodesk
%LocalAppData%\Autodesk
%Public%\Documents\Autodesk"

for %%D in (%DIRS%) do (
  set "TARGET=%%~D"
  if exist "!TARGET!" (
    echo [del] "!TARGET!" >> "%LOG%"
    attrib -r -s -h /s /d "!TARGET!" >nul 2>&1
    rmdir /s /q "!TARGET!" >> "%LOG%" 2>&1
  )
)

:: 5) Clean Autodesk registry keys (best-effort; safe to skip if locked)
echo [*] Cleaning Autodesk registry keys... | tee >> "%LOG%"
for %%K in (
  "HKLM\SOFTWARE\Autodesk"
  "HKLM\SOFTWARE\WOW6432Node\Autodesk"
  "HKCU\SOFTWARE\Autodesk"
) do (
  reg query %%K >nul 2>&1 && reg delete %%K /f >> "%LOG%" 2>&1
)

:: 6) Optional: clear temp caches that often lock installers
echo [*] Clearing temp caches... | tee >> "%LOG%"
for %%T in ("%TEMP%\*.*" "%WINDIR%\Temp\*.*") do (
  del /f /q /s %%T >nul 2>&1
)

echo.
echo [✔] Autodesk removal routine finished. A reboot is recommended.
echo     Log file: %LOG%
echo.
pause
endlocal

:: --- simple 'tee' helper for echo mirroring to console and log
:: usage: echo something | tee >> "logfile"
goto :eof
:tee
setlocal enabledelayedexpansion
set "line="
for /f "usebackq delims=" %%L in (`more`) do (
  set "line=%%L"
  echo !line!
)
endlocal & exit /b

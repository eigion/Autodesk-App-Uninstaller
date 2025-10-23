@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: =======================================================
:: Remove Autodesk (Interactive) - Windows 10/11 x64
:: - Self-elevates to admin
:: - Lists Autodesk software with indices
:: - User selects 1,2,5,6... or A (all)
:: - Uses silent uninstall where possible
:: - Optional cleanup of leftovers (folders + registry)
:: - Logs everything to a timestamped file
:: =======================================================

:: 0) Self-elevate to Administrator if needed
net session >nul 2>&1
if %errorlevel% NEQ 0 (
  echo [*] Elevating to administrator...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

:: 1) Prep timestamp + log
for /f "tokens=1-4 delims=/ " %%a in ("%date%") do set _d=%%d-%%b-%%c
set "_t=%time::=-%"
set "STAMP=%_d%_%_t: =0%"
set "STAMP=%STAMP:.=-%"
set "LOG=%~dp0Autodesk_Uninstall_%STAMP%.log"
echo ==== Autodesk Interactive Uninstall Log %DATE% %TIME% ==== > "%LOG%"
echo [*] Logging to: %LOG%
echo.

:: 2) Stop common Autodesk services/processes (best-effort)
echo [*] Stopping Autodesk services...
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

echo [*] Killing common Autodesk processes...
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

:: 3) Hand off to PowerShell for menu + uninstall + cleanup
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Continue';" ^
  "$log = [IO.Path]::GetFullPath('%LOG%');" ^
  "function Write-Log([string]$msg){ $line=('['+(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')+'] '+$msg); $line | Tee-Object -FilePath $log -Append }" ^
  "Write-Log '--- Inventorying Autodesk products ---';" ^
  "$roots = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall';" ^
  "$raw = foreach($r in $roots){ if(Test-Path $r){ Get-ChildItem $r | ForEach-Object{ try{ Get-ItemProperty $_.PSPath }catch{} } } };" ^
  "$apps = $raw | Where-Object { ($_.DisplayName -or $_.Publisher) -and ( $_.Publisher -match 'Autodesk' -or $_.DisplayName -match '^Autodesk' ) } | Sort-Object DisplayName | Select-Object DisplayName,Publisher,QuietUninstallString,UninstallString;" ^
  "if(-not $apps){ Write-Log 'No Autodesk products found. Exiting.'; exit 0 }" ^
  "$list = @(); $i=1; $apps | ForEach-Object{ $list += [PSCustomObject]@{ Index=$i; Name=$_.DisplayName; Pub=$_.Publisher; QUn=$_.QuietUninstallString; Un=$_.UninstallString }; $i++ };" ^
  "" ^
  "Write-Host '';" ^
  "Write-Host 'Autodesk software detected:' -ForegroundColor Cyan;" ^
  "$list | ForEach-Object { '{0,3}. {1}' -f $_.Index, $_.Name } | Write-Host;" ^
  "Write-Host '';" ^
  "$sel = Read-Host 'Enter numbers (e.g., 1,2,5,6) or A for ALL (Q to quit)';" ^
  "if([string]::IsNullOrWhiteSpace($sel)){ Write-Log 'No selection given. Exiting.'; exit 0 }" ^
  "if($sel -match '^(?i)q$'){ Write-Log 'User quit.'; exit 0 }" ^
  "if($sel -match '^(?i)a$'){ $chosen = $list } else { " ^
  "  $idx = $sel -split '[,; ]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ } | Sort-Object -Unique;" ^
  "  if(-not $idx){ Write-Log 'No valid indices parsed. Exiting.'; exit 1 }" ^
  "  $max = $list[-1].Index;" ^
  "  $bad = $idx | Where-Object { $_ -lt 1 -or $_ -gt $max };" ^
  "  if($bad){ Write-Log ('Invalid selection(s): '+ ($bad -join ', ')); exit 1 }" ^
  "  $chosen = foreach($n in $idx){ $list | Where-Object { $_.Index -eq $n } }" ^
  "}" ^
  "" ^
  "Write-Host ''; Write-Host 'Selected for removal:' -ForegroundColor Yellow;" ^
  "$chosen | ForEach-Object { ' - {0}' -f $_.Name } | Write-Host;" ^
  "$ok = Read-Host 'Proceed to uninstall the above? (Y/N)';" ^
  "if($ok -notmatch '^(?i)y$'){ Write-Log 'User canceled at confirmation.'; exit 0 }" ^
  "" ^
  "function Build-UninstallCmd([string]$qun,[string]$un){ " ^
  "  if($qun){ return $qun } " ^
  "  if([string]::IsNullOrWhiteSpace($un)){ return $null } " ^
  "  if($un -match '(?i)msiexec\.exe'){ " ^
  "     if($un -match '({[0-9A-F-]+})'){ return ('msiexec /x ' + $matches[1] + ' /qn /norestart') }" ^
  "     if($un -notmatch '(?i)/qn|/quiet'){ return ($un + ' /qn /norestart') } else { return $un }" ^
  "  } else { " ^
  "     if($un -notmatch '(?i)/quiet|/qn|/silent|/S'){ return ($un + ' /quiet /norestart') } else { return $un }" ^
  "  }" ^
  "}" ^
  "" ^
  "Write-Log ('--- Uninstall phase for ' + $chosen.Count + ' item(s) ---');" ^
  "$fail=@(); $okCnt=0;" ^
  "foreach($app in $chosen){ " ^
  "  $cmd = Build-UninstallCmd $app.QUn $app.Un;" ^
  "  if(-not $cmd){ Write-Log ('[SKIP] No uninstall string for: ' + $app.Name); $fail += $app.Name; continue }" ^
  "  Write-Log ('[Uninstall] ' + $app.Name + ' -> ' + $cmd);" ^
  "  try{ Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $cmd -Wait; $ec=$LASTEXITCODE }catch{ $ec=1 }" ^
  "  if($ec -ne 0){ Write-Log ('[FAIL] ' + $app.Name + ' (exit ' + $ec + ')'); $fail += $app.Name } else { Write-Log ('[OK] ' + $app.Name); $okCnt++ }" ^
  "}" ^
  "" ^
  "Write-Log ('Uninstall phase complete: OK=' + $okCnt + ', FAIL=' + $($fail.Count));" ^
  "if($fail){ Write-Host ''; Write-Host 'Some items failed to remove:' -ForegroundColor Red; $fail | ForEach-Object { ' - ' + $_ } | Write-Host }" ^
  "" ^
  "$ans = Read-Host 'Also remove leftover Autodesk folders & registry keys? (Y/N)';" ^
  "if($ans -match '^(?i)y$'){ " ^
  "  Write-Log '--- Cleanup leftovers (folders/registry) ---';" ^
  "  $dirs = @(" ^
  "    'C:\Program Files\Autodesk'," ^
  "    'C:\Program Files (x86)\Autodesk'," ^
  "    (Join-Path $env:ProgramFiles 'Common Files\Autodesk Shared')," ^
  "    (Join-Path ${env:ProgramFiles(x86)} 'Common Files\Autodesk Shared')," ^
  "    (Join-Path $env:ProgramData 'Autodesk')," ^
  "    (Join-Path $env:APPDATA 'Autodesk')," ^
  "    (Join-Path $env:LOCALAPPDATA 'Autodesk')," ^
  "    (Join-Path $env:PUBLIC 'Documents\Autodesk')" ^
  "  ) | Where-Object { $_ }" ^
  "  foreach($d in $dirs){ if(Test-Path $d){ " ^
  "     Write-Log ('[DEL DIR] ' + $d);" ^
  "     try{ attrib -r -s -h $d -Recurse -ErrorAction SilentlyContinue; Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }catch{}" ^
  "  }}" ^
  "  $regs = 'HKLM:\SOFTWARE\Autodesk','HKLM:\SOFTWARE\WOW6432Node\Autodesk','HKCU:\SOFTWARE\Autodesk';" ^
  "  foreach($k in $regs){ if(Test-Path $k){ Write-Log ('[DEL REG] ' + $k); try{ Remove-Item -LiteralPath $k -Recurse -Force -ErrorAction SilentlyContinue }catch{} } }" ^
  "  Write-Log 'Cleanup complete.' " ^
  "} else { Write-Log 'Cleanup skipped by user.' }" ^
  "" ^
  "Write-Log '--- Done. Reboot is recommended. ---';" ^
  "Write-Host ''; Write-Host ('Log file: ' + $log);" ^
  "" 

echo.
echo [✔] Finished. Review the log if needed:
echo     %LOG%
echo Reboot is recommended.
echo.
pause
endlocal

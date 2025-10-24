<# 
  Autodesk Remover (Standalone, Interactive) — PowerShell 5.1 compatible
  Run PowerShell as Administrator
#>

# -------- Preflight --------
$wid = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$prp = New-Object System.Security.Principal.WindowsPrincipal($wid)
$IsAdmin = $prp.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
  Write-Host "[x] Please run PowerShell as Administrator." -ForegroundColor Red
  Read-Host "Press Enter to exit"
  exit 1
}

Write-Host "ExecutionPolicy (Process/User/Machine): " -NoNewline
Write-Host ("{0}/{1}/{2}" -f 
  (Get-ExecutionPolicy -Scope Process),
  (Get-ExecutionPolicy -Scope CurrentUser),
  (Get-ExecutionPolicy -Scope LocalMachine)) -ForegroundColor Yellow

# Let this session run the script (doesn't persist)
try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop } catch {}

# -------- Logging --------
$Stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogDir = Join-Path $env:USERPROFILE "Documents"
$Log    = Join-Path $LogDir "Autodesk_Uninstall_$Stamp.log"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }
Start-Transcript -Path $Log -Append | Out-Null
Write-Host "`nLog: $Log" -ForegroundColor Cyan

# -------- Inventory Autodesk entries --------
$roots = @(
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

$items = foreach ($r in $roots) {
  if (Test-Path $r) {
    Get-ChildItem $r | ForEach-Object {
      try { Get-ItemProperty $_.PSPath } catch {}
    }
  }
}

$apps = $items | Where-Object { $_.DisplayName -or $_.Publisher } |
  Where-Object { $_.Publisher -match '^Autodesk' -or $_.DisplayName -match '^Autodesk' } |
  Sort-Object DisplayName

if (-not $apps) {
  Write-Host "No Autodesk products found." -ForegroundColor Yellow
  Stop-Transcript | Out-Null
  Read-Host "Press Enter to exit"
  exit 0
}

# Index for selection
$list = @(); $i = 1
foreach ($a in $apps) {
  $list += [pscustomobject]@{
    Index = $i
    Name  = $a.DisplayName
    Pub   = $a.Publisher
    QUn   = $a.QuietUninstallString
    Un    = $a.UninstallString
  }
  $i++
}

Write-Host "`nAutodesk software detected:" -ForegroundColor Cyan
$list | ForEach-Object { "{0,3}. {1}" -f $_.Index, $_.Name } | Write-Host

$sel = Read-Host "`nEnter numbers (e.g., 1,2,5) or A for ALL (Q to quit)"
if ([string]::IsNullOrWhiteSpace($sel) -or $sel -match '^(?i)q$') {
  Write-Host "Quit."
  Stop-Transcript | Out-Null
  Read-Host "Press Enter to exit"
  exit 0
}

if ($sel -match '^(?i)a$') {
  $chosen = $list
} else {
  $idx = $sel -split '[,; ]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object {[int]$_} | Sort-Object -Unique
  if (-not $idx) { Write-Host "[x] No valid indices parsed." -ForegroundColor Red; Stop-Transcript | Out-Null; Read-Host "Enter to exit"; exit 1 }
  $max = $list[-1].Index
  $bad = $idx | Where-Object { $_ -lt 1 -or $_ -gt $max }
  if ($bad) { Write-Host ("[x] Invalid selection(s): {0}" -f ($bad -join ', ')) -ForegroundColor Red; Stop-Transcript | Out-Null; Read-Host "Enter to exit"; exit 1 }
  $chosen = foreach ($n in $idx) { $list | Where-Object { $_.Index -eq $n } }
}

Write-Host "`nSelected for removal:" -ForegroundColor Yellow
$chosen | ForEach-Object { " - {0}" -f $_.Name } | Write-Host

# -------- Optional prep actions --------
function Stop-AdskServices {
  param([int]$TimeoutSec = 15)
  $svcs = @('AdskLicensingService','AdAppMgrSvc','AGSService')
  foreach ($s in $svcs) {
    $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
    if ($svc) {
      try {
        Write-Host ("Stopping service: {0}" -f $s)
        Stop-Service -Name $s -ErrorAction SilentlyContinue
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
          $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
          if ($svc -and $svc.Status -eq 'Stopped') { break }
          Start-Sleep -Seconds 1
        }
        Set-Service -Name $s -StartupType Disabled -ErrorAction SilentlyContinue
      } catch {}
    }
  }
}

function Handle-AdskProcesses {
  param([ValidateSet('None','Auto','Force')] [string]$Mode = 'None')
  if ($Mode -eq 'None') { return }
  $names = @('AdAppMgr','AdAppMgrSvc','AdskLicensingAgent','AdskLicensingService','AdskIdentityManager','AutodeskDesktopApp','GenuineService')
  foreach ($n in $names) {
    $procs = Get-Process -Name $n -ErrorAction SilentlyContinue
    if (-not $procs) { continue }
    foreach ($p in $procs) {
      try {
        if ($Mode -eq 'Auto') {
          if ($p.MainWindowHandle -and $p.CloseMainWindow()) { Start-Sleep 2 }
          if (-not $p.HasExited) { $p.Kill() }
        } elseif ($Mode -eq 'Force') {
          $p.Kill()
        }
      } catch {}
    }
  }
}

function Build-UninstallCmd {
  param([string]$QuietUninstall, [string]$Uninstall, [bool]$AddSilent = $true)
  if ($QuietUninstall) { return $QuietUninstall }
  if ([string]::IsNullOrWhiteSpace($Uninstall)) { return $null }
  if ($Uninstall -match '(?i)msiexec\.exe') {
    if ($Uninstall -match '({[0-9A-F-]+})') {
      $cmd = 'msiexec /x ' + $matches[1]
      if ($AddSilent) { $cmd += ' /qn /norestart' }
      return $cmd
    }
    if ($AddSilent -and $Uninstall -notmatch '(?i)/qn|/quiet') {
      return ($Uninstall + ' /qn /norestart')
    }
    return $Uninstall
  } else {
    if ($AddSilent -and $Uninstall -notmatch '(?i)/quiet|/qn|/silent|/S') {
      return ($Uninstall + ' /quiet /norestart')
    }
    return $Uninstall
  }
}

# Prompts
$doStop = Read-Host "Stop Autodesk services first? (Y/N) [default=N]"
if ($doStop -match '^(?i)y$') { Stop-AdskServices }

$killMode = Read-Host "Process handling: (N)one, (A)uto, (F)orce [default=N]"
switch -Regex ($killMode) {
  '^(?i)a$' { $killMode = 'Auto' }
  '^(?i)f$' { $killMode = 'Force' }
  default   { $killMode = 'None' }
}
Handle-AdskProcesses -Mode $killMode

$ok = Read-Host "Proceed to uninstall now? (Y/N)"
if ($ok -notmatch '^(?i)y$') {
  Write-Host "Canceled."
  Stop-Transcript | Out-Null
  Read-Host "Press Enter to exit"
  exit 0
}

# -------- Uninstall loop --------
$AddSilentFlags = $true
$fail = @(); $okCnt = 0

foreach ($app in $chosen) {
  $cmd = Build-UninstallCmd -QuietUninstall $app.QUn -Uninstall $app.Un -AddSilent:$AddSilentFlags
  if (-not $cmd) {
    Write-Warning "[SKIP] No uninstall string for: $($app.Name)"
    $fail += $app.Name
    continue
  }

  # Parse command safely
  $file = $null; $args = ''
  if ($cmd.StartsWith('"')) {
    $end = $cmd.IndexOf('"', 1)
    $file = $cmd.Substring(1, $end - 1)
    $args = $cmd.Substring($end + 1).Trim()
  } else {
    $parts = $cmd.Split(' ', 2)
    $file  = $parts[0]
    if ($parts.Count -gt 1) { $args = $parts[1] }
  }

  Write-Host "`n[Uninstall] $($app.Name)" -ForegroundColor Green
  Write-Host "  Command: $file $args"

  $exit = 0
  try {
    $proc = Start-Process -FilePath $file -ArgumentList $args -PassThru -Wait -ErrorAction Stop
    $exit = $proc.ExitCode
  } catch {
    $exit = 1
    Write-Warning ("  -> Exception: " + $_.Exception.Message)
  }

  if ($exit -ne 0) {
    Write-Warning ("  -> Failed (exit {0})" -f $exit)
    $fail += $app.Name
  } else {
    Write-Host "  -> Completed"
    $okCnt++
  }
}

Write-Host "`nUninstall phase complete: OK=$okCnt, FAIL=$($fail.Count)" -ForegroundColor Cyan
if ($fail) { Write-Host "Failed items:" -ForegroundColor Red; $fail | ForEach-Object { " - $_" } | Write-Host }

# -------- Optional cleanup --------
$cln = Read-Host "`nAlso remove leftover Autodesk folders & registry keys? (Y/N) [default=N]"
if ($cln -match '^(?i)y$') {
  Write-Host "Cleaning leftovers..." -ForegroundColor Yellow
  $dirs = @(
    'C:\Program Files\Autodesk',
    'C:\Program Files (x86)\Autodesk',
    (Join-Path $env:ProgramFiles 'Common Files\Autodesk Shared'),
    (Join-Path ${env:ProgramFiles(x86)} 'Common Files\Autodesk Shared'),
    (Join-Path $env:ProgramData 'Autodesk'),
    (Join-Path $env:APPDATA 'Autodesk'),
    (Join-Path $env:LOCALAPPDATA 'Autodesk'),
    (Join-Path $env:PUBLIC 'Documents\Autodesk')
  ) | Where-Object { $_ }

  foreach ($d in $dirs) {
    if (Test-Path $d) {
      try {
        attrib -r -s -h $d -Recurse -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  [DEL DIR] $d"
      } catch {
        Write-Warning "  [DEL DIR FAIL] $d : $($_.Exception.Message)"
      }
    }
  }

  $regs = @('HKLM:\SOFTWARE\Autodesk','HKLM:\SOFTWARE\WOW6432Node\Autodesk','HKCU:\SOFTWARE\Autodesk')
  foreach ($k in $regs) {
    if (Test-Path $k) {
      try { Remove-Item -LiteralPath $k -Recurse -Force -ErrorAction SilentlyContinue; Write-Host "  [DEL REG] $k" }
      catch { Write-Warning "  [DEL REG FAIL] $k : $($_.Exception.Message)" }
    }
  }
} else {
  Write-Host "Cleanup skipped."
}

Write-Host "`nDone. Reboot is recommended." -ForegroundColor Cyan
Write-Host "Transcript: $Log"
Stop-Transcript | Out-Null
Read-Host "Press Enter to exit"

# Autodesk Remover (Interactive, Windows · PowerShell 5.1 Compatible)

An interactive **PowerShell** tool to remove **Autodesk** software from Windows.  
It enumerates installed Autodesk apps, lets you select **single**, **multiple**, or **all** (e.g., `1,2,5` or `A`), optionally stops Autodesk services/processes, launches each vendor’s uninstaller, and can perform leftover cleanup (folders + registry). A transcript log is saved to **Documents**.

> **Safety first**
>
> - This can remove Autodesk apps system-wide. **Back up** templates, families, palettes, add-ins, and license info.  
> - Cleanup is optional and best-effort. Reboot after completion.

---

## What’s inside

- `Autodesk_Remover_Standalone.ps1` — the standalone, **PowerShell 5.1–compatible** script (no ternary/safe-nav operators; works on stock Win10/11).
- (Optional) You can add your own wrapper `.cmd` if you prefer launching from Command Prompt; the `.ps1` is all you need.

---

## Features

- **Interactive picker**: choose indices like `1,2,5` or `A` for all; `Q` to quit.
- **Vendor uninstallers**: uses `QuietUninstallString` when available; adds silent flags conservatively.
- **Optional pre-uninstall handling**:
  - Stop **Autodesk services** (Licensing, Desktop App, Genuine) with timeout.
  - **Process handling**: None / Auto (graceful→kill) / Force.
- **Optional cleanup**: removes common Autodesk directories and registry keys.
- **Transcript logging**: writes a timestamped log to **Documents**.

---

## Requirements

- **OS**: Windows 10 or 11 (x64)
- **Shell**: Windows PowerShell **5.1** (default on Win10/11)
- **Privileges**: Run **as Administrator**

---

## Quick Start

1. Download `Autodesk_Remover_Standalone.ps1` to a local folder (e.g., `C:\Tools` or `D:\AI_Playground`).
2. Open **PowerShell (Admin)**:
   - Start menu → type “PowerShell” → right-click **Windows PowerShell** → **Run as administrator**.
3. Run the script:
   ```powershell
   cd D:\path\to         # change to your folder
   Unblock-File .\Autodesk_Remover_Standalone.ps1
   powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Autodesk_Remover_Standalone.ps1

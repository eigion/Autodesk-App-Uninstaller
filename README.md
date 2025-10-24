# Autodesk Remover (Interactive, Windows)

An interactive **Windows batch + PowerShell** tool to uninstall **Autodesk** software. It inventories installed Autodesk apps, lets you select **single**, **multiple**, or **all** (e.g., `1,2,5,6` or `A`), confirms, runs **silent uninstallers**, and optionally **cleans leftovers** (folders + registry). All actions are **timestamp-logged**.

> **Use with care.** This can remove Autodesk apps system-wide. Back up custom content (templates, families, palettes, add-ins, license files) before running.

---

## Features

- **Interactive picker** — choose `1,2,5,6`… or `A` (all), `Q` (quit)
- **Admin self-elevation** — prompts for elevation automatically
- **Graceful shutdown** — stops Autodesk services/processes first
- **Silent uninstall** — prioritizes `QuietUninstallString` and augments with quiet flags if needed
- **Optional cleanup** — removes common Autodesk directories and registry keys
- **Detailed logging** — timestamped log saved next to the script

---

## Requirements

- **OS:** Windows 10/11 (64-bit)
- **Permissions:** Local Administrator (the script self-elevates if needed)

---

## Quick Start

1. Download `Remove_Autodesk_Interactive.cmd` to a local folder.
2. **Right-click → Run as administrator.**
3. Review the detected list, then enter:
   - `1,2,5,6` to remove specific entries
   - `A` for **All**
   - `Q` to quit
4. Confirm when prompted.
5. Choose whether to perform **leftover cleanup** (folders + registry).
6. **Reboot** when finished.

**Log file:** created beside the script, e.g.  
`Autodesk_Uninstall_YYYY-MM-DD_HH-MM-SS.log`

---

## What Gets Removed

- Any installed product where **Publisher = Autodesk** or **DisplayName** begins with **Autodesk** (e.g., AutoCAD, Revit, 3ds Max, Inventor, Desktop App, Licensing).
- *(Optional)* Common leftovers:
  - `C:\Program Files\Autodesk`
  - `C:\Program Files (x86)\Autodesk`
  - `...\Common Files\Autodesk Shared`
  - `%ProgramData%\Autodesk`, `%AppData%\Autodesk`, `%LocalAppData%\Autodesk`
  - `%Public%\Documents\Autodesk`
- *(Optional)* Registry keys:
  - `HKLM\SOFTWARE\Autodesk`
  - `HKLM\SOFTWARE\WOW6432Node\Autodesk`
  - `HKCU\SOFTWARE\Autodesk`

> Cleanup is **optional**. Skip it if you plan to keep any Autodesk product or shared libraries.



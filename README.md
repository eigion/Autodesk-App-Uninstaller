# Autodesk-Apps-remover-
Remove all Autodesk apps from Windows in one go: stops services, runs silent uninstallers, cleans leftovers, and logs everything.


Remove All Autodesk (Windows Batch)

A single Windows batch script to completely remove all Autodesk software from a machine—ideal when decommissioning, transferring a laptop, or prepping a clean install.

What it does

Elevates to Administrator (self-elevation).

Stops Autodesk services and background processes.

Uninstalls everything with Publisher = Autodesk or DisplayName starting with Autodesk (uses quiet/silent flags when possible; falls back to the vendor uninstaller).

Cleans leftovers: common folders in Program Files, ProgramData, and user profiles.

Prunes registry keys under HKLM/HKCU\Software\Autodesk.

Logs all actions to a timestamped file in the script directory.

⚠️ Warning

This removes all Autodesk apps for all users (AutoCAD, Revit, 3ds Max, Inventor, Desktop App, Licensing components, etc.).

Back up custom content (templates, tool palettes, add-ins, license info) before running.

A reboot is strongly recommended after completion.

Supported platforms

Windows 10/11, 64-bit

Admin privileges required (the script self-elevates if needed)

Usage

Download Remove_All_Autodesk.cmd.

Right-click → Run as administrator.

Wait for the routine to finish, then restart Windows.

Log file: created next to the script, e.g. Autodesk_Uninstall_2025-10-23_12-05.log.

What gets removed

Installed products whose Publisher is Autodesk or DisplayName begins with Autodesk.

Folders (best-effort):

C:\Program Files\Autodesk

C:\Program Files (x86)\Autodesk

...\Common Files\Autodesk Shared

%ProgramData%\Autodesk

%AppData%\Autodesk

%LocalAppData%\Autodesk

%Public%\Documents\Autodesk

Registry keys:

HKLM\SOFTWARE\Autodesk

HKLM\SOFTWARE\WOW6432Node\Autodesk

HKCU\SOFTWARE\Autodesk

ℹ️ Some legacy or non-standard installers may ignore silent flags. The script still launches their uninstallers; you might briefly see an uninstall window.

Customization

Keep a product (e.g., Fusion 360): adjust the PowerShell filter to exclude it by name.

Dry-run mode: convert Start-Process ... -Wait lines to Write-Host to only list actions (add a boolean flag if you want a toggle).

Additional services/processes: append names to the for %%S / for %%P lists.

Troubleshooting

Leftover folders won’t delete: reboot and run the script again; ensure no Autodesk processes are running.

Uninstaller missing: rare, but you can manually remove the entry and clean folders/registry (the script already attempts this).

Corporate images: run in a local admin shell; EDR/AV may prompt to allow registry/file deletions.

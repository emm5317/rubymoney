# Packaging (WiX)

## MSI Contents

- `budgetd.exe` installed to `C:\Program Files\BudgetApp\budgetd.exe`
- `migrations\` folder installed alongside the executable
- Start Menu shortcut: `Budget Service`

## Build Script

Run:

```powershell
powershell -ExecutionPolicy Bypass -File C:\dev\budgetexcel\installer\build.ps1
```

Outputs:

- `installer\wix\output\BudgetApp.msi`

## Notes

- Startup task is not created by default.
- The service creates its own data/config folders under `%LOCALAPPDATA%\BudgetApp` on first run.
- MSI is per-machine; install/uninstall requires elevation.
- Shortcut target explicitly points to `budgetd.exe` with working directory set to `C:\Program Files\BudgetApp`.

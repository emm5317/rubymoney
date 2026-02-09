# Packaging (WiX)

## Goals

- MSI installs `budgetd.exe`.
- Optional Start Menu shortcut "Budget Service".
- Optional startup task to run on login.
- App data directories created on first run.

## Artifacts

- `installer/wix/BudgetApp.wxs`
- `installer/wix/BudgetApp.wixproj` or build script
- `service/cmd/budgetd` build output

## Build Script

Provide `installer/build.ps1` that:

- Builds `budgetd.exe` for Windows.
- Collects files for WiX.
- Runs WiX to generate MSI.

## Installation Layout

- Program files:
- `budgetd.exe`

- Local app data:
- `%LOCALAPPDATA%\BudgetApp\data\`
- `%LOCALAPPDATA%\BudgetApp\config\`
- `%LOCALAPPDATA%\BudgetApp\secrets\`

## Uninstall

- Remove program files and shortcuts.
- Leave user data in `%LOCALAPPDATA%` by default.

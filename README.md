# AutoMove-UserFolders

AutoMove-UserFolders is a PowerShell script designed to automatically relocate standard Windows user folders (Desktop, Documents, Downloads, Pictures, Music, Videos) from the system drive (C:) to the most suitable internal partition.

The script is intended for Windows 11 environments and must be executed with Administrator privileges.

---

## What the Script Does

The script performs the following actions:

1. Requires Administrator privileges.
2. Enumerates local user profiles found in `C:\Users`.
3. Displays a numbered list of available users.
4. Prompts for selection of the user profile to migrate.
5. Calculates the total size of the folders that will be moved:
   - Desktop
   - Documents
   - Downloads
   - Pictures
   - Music
   - Videos
6. Detects available internal drives:
   - Includes only Fixed disks (DriveType = 3)
   - Excludes:
     - C:
     - USB drives
     - Network mapped drives
     - Optical drives
7. Selects the internal drive with the largest available free space.
8. Verifies that the selected drive has enough free space for the migration.
9. If validation fails at any point, it displays:
moving impossible

10. If validation succeeds:
 - Creates the required folder structure (`X:\Users\Username`)
 - Moves folder contents
 - Updates the user's registry "User Shell Folders" paths
11. Instructs the user to log off and log back in.

---

## Safety Rules

The script will NOT proceed if:

- Only drive C: exists
- No internal fixed drives are available
- The selected drive does not have sufficient free space
- An invalid user selection is made

Only internal partitions are allowed as migration targets.

---

## Requirements

- Windows 11
- PowerShell 5.1 or newer
- Administrator privileges
- Public GitHub repository (if using remote execution)

---

## Usage

### Method 1 — Run from Local File

1. Open PowerShell as Administrator.
2. Navigate to the script directory.
3. Run:

```powershell
.\AutoMove-UserFolders.ps1

### Method 2 — Run Directly from GitHub (IRM + IEX)

Run PowerShell as Administrator and execute:

irm https://raw.githubusercontent.com/tehnium/AutoMove-UserFolders/main/AutoMove-UserFolders.ps1 | iex

This downloads and executes the script directly from GitHub.

## Important Notes

The selected user should not be actively logged in during migration.

A logoff/login is required after completion.

The script does not move AppData or the entire user profile.

No rollback mechanism is included.

Always ensure backups exist before performing profile migrations.

## Disclaimer

Use at your own risk. Test in a controlled environment before deploying in production systems.

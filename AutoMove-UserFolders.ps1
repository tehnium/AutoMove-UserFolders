# Requires Administrator
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "Run as Administrator."
    exit
}

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class KnownFolder {
    [DllImport("shell32.dll")]
    public static extern int SHSetKnownFolderPath(
        [MarshalAs(UnmanagedType.LPStruct)] Guid rfid,
        uint dwFlags,
        IntPtr hToken,
        [MarshalAs(UnmanagedType.LPWStr)] string pszPath);
}
"@

$Folders = @{
    "Desktop"   = "B4BFCC3A-DB2C-424C-B029-7FE99A87C641"
    "Documents" = "FDD39AD0-238F-46AF-ADB4-6C85480369C7"
    "Downloads" = "374DE290-123F-4565-9164-39C4925E467B"
    "Pictures"  = "33E28130-4E1E-4676-835A-98395C3BC3BB"
    "Music"     = "4BD8D571-6D19-48D3-BE97-422220080E43"
    "Videos"    = "18989B1D-99B5-455B-841C-AB7C74E4DDFC"
}

# Enumerare utilizatori
$Excluded = @("Public","Default","Default User","All Users")
$Users = Get-ChildItem "C:\Users" -Directory |
    Where-Object { $Excluded -notcontains $_.Name }

if ($Users.Count -eq 0) {
    Write-Host "moving impossible"
    exit
}

Write-Host "Select user to move:`n"
for ($i=0; $i -lt $Users.Count; $i++) {
    Write-Host "$($i+1)) $($Users[$i].Name)"
}

$Selection = Read-Host "`nEnter number"
if (-not ($Selection -match '^\d+$') -or
    [int]$Selection -lt 1 -or
    [int]$Selection -gt $Users.Count) {
    Write-Host "moving impossible"
    exit
}

$UserName = $Users[[int]$Selection-1].Name
$UserProfile = "C:\Users\$UserName"

# Calcul dimensiune totală
$TotalSize = 0
foreach ($Folder in $Folders.Keys) {
    $Path = Join-Path $UserProfile $Folder
    if (Test-Path $Path) {
        $Size = (Get-ChildItem $Path -Recurse -ErrorAction SilentlyContinue |
                Measure-Object Length -Sum).Sum
        if ($Size) { $TotalSize += $Size }
    }
}

# Drive-uri interne Fixed, fără C:
$Drives = Get-CimInstance Win32_LogicalDisk |
    Where-Object {
        $_.DriveType -eq 3 -and
        $_.DeviceID -ne "C:"
    }

if ($Drives.Count -eq 0) {
    Write-Host "moving impossible"
    exit
}

$BestDrive = $Drives | Sort-Object FreeSpace -Descending | Select-Object -First 1

if ($BestDrive.FreeSpace -lt $TotalSize) {
    Write-Host "moving impossible"
    exit
}

$TargetBase = "$($BestDrive.DeviceID)\Users\$UserName"

if (!(Test-Path $TargetBase)) {
    New-Item -ItemType Directory -Path $TargetBase -Force | Out-Null
}

# Obține token utilizator
$User = Get-LocalUser -Name $UserName
$SID = $User.SID.Value

$UserAccount = New-Object System.Security.Principal.NTAccount($UserName)
$UserSID = $UserAccount.Translate([System.Security.Principal.SecurityIdentifier])
$hToken = [IntPtr]::Zero

foreach ($Folder in $Folders.Keys) {

    $Source = Join-Path $UserProfile $Folder
    $Target = Join-Path $TargetBase $Folder

    if (!(Test-Path $Target)) {
        New-Item -ItemType Directory -Path $Target -Force | Out-Null
    }

    if (Test-Path $Source) {
        Move-Item $Source $Target -Force -ErrorAction SilentlyContinue
    }

    $Guid = New-Object Guid $Folders[$Folder]
    [KnownFolder]::SHSetKnownFolderPath($Guid, 0, $hToken, $Target) | Out-Null
}

Write-Host "`nFolders successfully relocated to $($BestDrive.DeviceID)"
Write-Host "User must log off and log back in."

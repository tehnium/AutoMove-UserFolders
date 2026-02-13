# =========================
# AutoMove-UserFolders FINAL
# =========================

# Require Administrator
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "Run as Administrator."
    exit
}

$Folders = @{
    "Desktop"   = "{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}"
    "Documents" = "{FDD39AD0-238F-46AF-ADB4-6C85480369C7}"
    "Downloads" = "{374DE290-123F-4565-9164-39C4925E467B}"
    "Pictures"  = "{33E28130-4E1E-4676-835A-98395C3BC3BB}"
    "Music"     = "{4BD8D571-6D19-48D3-BE97-422220080E43}"
    "Videos"    = "{18989B1D-99B5-455B-841C-AB7C74E4DDFC}"
}

# Enumerare profiluri reale din ProfileList
$ProfileList = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
$Profiles = Get-ChildItem $ProfileList | ForEach-Object {
    $Path = (Get-ItemProperty $_.PSPath).ProfileImagePath
    if ($Path -like "C:\Users\*") {
        [PSCustomObject]@{
            SID  = $_.PSChildName
            Path = $Path
            Name = Split-Path $Path -Leaf
        }
    }
} | Where-Object {
    $_.Name -notin @("Public","Default","Default User","All Users")
}

if ($Profiles.Count -eq 0) {
    Write-Host "moving impossible"
    exit
}

Write-Host "Select user to move:`n"
for ($i=0; $i -lt $Profiles.Count; $i++) {
    Write-Host "$($i+1)) $($Profiles[$i].Name)"
}

$Selection = Read-Host "`nEnter number"

if (-not ($Selection -match '^\d+$') -or
    [int]$Selection -lt 1 -or
    [int]$Selection -gt $Profiles.Count) {
    Write-Host "moving impossible"
    exit
}

$User = $Profiles[[int]$Selection-1]
$UserProfile = $User.Path
$SID = $User.SID

# Calcul dimensiune
$TotalSize = 0
foreach ($Folder in $Folders.Keys) {
    $Path = Join-Path $UserProfile $Folder
    if (Test-Path $Path) {
        $Size = (Get-ChildItem $Path -Recurse -ErrorAction SilentlyContinue |
                Measure-Object Length -Sum).Sum
        if ($Size) { $TotalSize += $Size }
    }
}

# Detectare drive intern
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

$TargetBase = "$($BestDrive.DeviceID)\Users\$($User.Name)"
New-Item -ItemType Directory -Path $TargetBase -Force | Out-Null

# =========================
# Migrate folders (overwrite duplicates only)
# =========================

foreach ($Folder in $Folders.Keys) {

    $Source = Join-Path $UserProfile $Folder
    $Target = Join-Path $TargetBase $Folder

    if (Test-Path $Source) {

        New-Item -ItemType Directory -Path $Target -Force | Out-Null

        robocopy "$Source" "$Target" /E /MOVE /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null

        if (Test-Path $Source) {
            Remove-Item $Source -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    else {
        New-Item -ItemType Directory -Path $Target -Force | Out-Null
    }
}

# =========================
# Registry Update (Load Hive if needed)
# =========================

$HiveLoaded = Test-Path "Registry::HKEY_USERS\$SID"

if (-not $HiveLoaded) {
    $NtUser = "$UserProfile\NTUSER.DAT"
    if (Test-Path $NtUser) {
        reg load "HKU\$SID" "$NtUser" | Out-Null
        $HiveLoaded = $true
        $TempLoaded = $true
    }
}

if (-not $HiveLoaded) {
    Write-Host "moving impossible"
    exit
}

$RegPath = "Registry::HKEY_USERS\$SID\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"

foreach ($Folder in $Folders.Keys) {
    $Target = Join-Path $TargetBase $Folder
    Set-ItemProperty -Path $RegPath -Name $Folders[$Folder] -Value $Target
}

if ($TempLoaded) {
    reg unload "HKU\$SID" | Out-Null
}

Write-Host "`nFolders relocated to $($BestDrive.DeviceID)"
Write-Host "Registry updated for $($User.Name)"
Write-Host "User must log off and log back in."

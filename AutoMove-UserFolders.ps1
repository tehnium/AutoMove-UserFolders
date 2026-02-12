# Verificare Administrator
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "Run as Administrator."
    exit
}

$FoldersToMove = @("Desktop","Documents","Downloads","Pictures","Music","Videos")

# Enumerare utilizatori reali
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
foreach ($Folder in $FoldersToMove) {
    $Path = Join-Path $UserProfile $Folder
    if (Test-Path $Path) {
        $Size = (Get-ChildItem $Path -Recurse -ErrorAction SilentlyContinue |
                Measure-Object Length -Sum).Sum
        if ($Size) { $TotalSize += $Size }
    }
}

# Drive-uri interne (Fixed), fără C:
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

# Obține SID user pentru registry
$UserSID = (Get-LocalUser -Name $UserName).SID.Value
$RegPath = "Registry::HKEY_USERS\$UserSID\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"

# GUID Known Folders
$FolderGUIDs = @{
    "Desktop"    = "{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}"
    "Documents"  = "{FDD39AD0-238F-46AF-ADB4-6C85480369C7}"
    "Downloads"  = "{374DE290-123F-4565-9164-39C4925E467B}"
    "Pictures"   = "{33E28130-4E1E-4676-835A-98395C3BC3BB}"
    "Music"      = "{4BD8D571-6D19-48D3-BE97-422220080E43}"
    "Videos"     = "{18989B1D-99B5-455B-841C-AB7C74E4DDFC}"
}

foreach ($Folder in $FoldersToMove) {

    $Source = Join-Path $UserProfile $Folder
    $Target = Join-Path $TargetBase $Folder

    if (!(Test-Path $Target)) {
        New-Item -ItemType Directory -Path $Target -Force | Out-Null
    }

    if (Test-Path $Source) {
        Move-Item "$Source\*" $Target -Force -ErrorAction SilentlyContinue
    }

    Set-ItemProperty -Path $RegPath -Name $FolderGUIDs[$Folder] -Value $Target
}

Write-Host "`nFolders moved to $($BestDrive.DeviceID)"
Write-Host "User should log off and log back in."


Clear-Host

Write-Host ""
Write-Host "AutoMove User Folders" -ForegroundColor Cyan
Write-Host ""

# SYSTEM folders to ignore
$excluded = @(
"Public",
"Default",
"Default User",
"All Users",
"defaultuser0"
)

# detect users
$users = Get-ChildItem "C:\Users" -Directory | Where-Object {
    $excluded -notcontains $_.Name
}

if ($users.Count -eq 0) {
    Write-Host "No valid user profiles found." -ForegroundColor Red
    exit
}

Write-Host "Select user to move:"
Write-Host ""

for ($i = 0; $i -lt $users.Count; $i++) {
    Write-Host "$($i+1). $($users[$i].Name)"
}

Write-Host ""
$selection = Read-Host "Enter number"

if (-not ($selection -match '^\d+$')) {
    Write-Host "Invalid selection" -ForegroundColor Red
    exit
}

$index = [int]$selection - 1

if ($index -lt 0 -or $index -ge $users.Count) {
    Write-Host "Invalid selection" -ForegroundColor Red
    exit
}

$user = $users[$index].Name
$userPath = "C:\Users\$user"
$targetRoot = "D:\Users\$user"

Write-Host ""
Write-Host "Selected user: $user" -ForegroundColor Green
Write-Host ""

# create base folder
New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null

# folders to move
$folders = @(
"Desktop",
"Documents",
"Downloads",
"Pictures",
"Music",
"Videos"
)

foreach ($folder in $folders) {

    $source = Join-Path $userPath $folder
    $target = Join-Path $targetRoot $folder

    if (-not (Test-Path $source)) {
        continue
    }

    Write-Host "Processing $folder..." -ForegroundColor Yellow

    New-Item -ItemType Directory -Force -Path $target | Out-Null

    # robocopy move (enterprise safe method)
    robocopy $source $target /MOVE /E /COPYALL /R:1 /W:1 /XJ /NFL /NDL /NP | Out-Null

    # remove source if empty
    if (Test-Path $source) {
        Remove-Item $source -Recurse -Force -ErrorAction SilentlyContinue
    }

    # create junction
    New-Item -ItemType Junction -Path $source -Target $target | Out-Null

}

Write-Host ""
Write-Host "Folders successfully moved." -ForegroundColor Green
Write-Host ""
Write-Host "New location:"
Write-Host $targetRoot
Write-Host ""

# AutoMove-UserFolders.ps1
# Fixed user detection

Clear-Host
Write-Host "Select user to move:" -ForegroundColor Cyan
Write-Host ""

# detect user folders
$excluded = @(
"Public",
"Default",
"Default User",
"All Users",
"defaultuser0"
)

$users = Get-ChildItem "C:\Users" -Directory | Where-Object {
    $excluded -notcontains $_.Name
}

if ($users.Count -eq 0) {
    Write-Host "No valid user profiles found." -ForegroundColor Red
    exit
}

# show menu
for ($i = 0; $i -lt $users.Count; $i++) {
    Write-Host "$($i+1). $($users[$i].Name)"
}

Write-Host ""
$selection = Read-Host "Enter number"

if (![int]::TryParse($selection, [ref]$null)) {
    Write-Host "Invalid selection"
    exit
}

$index = [int]$selection - 1

if ($index -lt 0 -or $index -ge $users.Count) {
    Write-Host "Invalid selection"
    exit
}

$user = $users[$index].Name
$userPath = "C:\Users\$user"

Write-Host ""
Write-Host "Selected user: $user" -ForegroundColor Green
Write-Host ""

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
    $target = "D:\Users\$user\$folder"

    if (Test-Path $source) {

        Write-Host "Moving $folder..."

        New-Item -ItemType Directory -Force -Path $target | Out-Null

        Move-Item $source $target -Force

        New-Item -ItemType Junction -Path $source -Target $target | Out-Null
    }

}

Write-Host ""
Write-Host "Done." -ForegroundColor Green

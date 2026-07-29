<#
.SYNOPSIS
    Symlinks this repo's pi\ folder to $HOME\.pi (Windows).
.NOTES
    Creating a symlink on Windows requires either:
      - Developer Mode enabled (Settings > Update & Security > For developers), or
      - Running this script as Administrator.
#>

$ErrorActionPreference = "Stop"

$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Src = Join-Path $RepoDir "pi"
$Dest = Join-Path $HOME ".pi"

if (-not (Test-Path $Src)) {
    Write-Error "Source folder not found: $Src"
    exit 1
}

if (Test-Path $Dest) {
    $item = Get-Item $Dest -Force
    if ($item.LinkType -eq "SymbolicLink") {
        $target = $item.Target
        if ($target -eq $Src) {
            Write-Host "$Dest already links to $Src. Nothing to do."
            exit 0
        }
        Write-Host "Removing existing symlink $Dest -> $target"
        Remove-Item $Dest -Force
    } else {
        Write-Error "$Dest already exists and is not a symlink. Back it up or remove it, then re-run this script."
        exit 1
    }
}

try {
    New-Item -ItemType SymbolicLink -Path $Dest -Target $Src | Out-Null
    Write-Host "Linked $Dest -> $Src"
} catch {
    Write-Error "Failed to create symlink. Enable Developer Mode or re-run this script as Administrator.`n$_"
    exit 1
}

$authPath = Join-Path $Src "agent\auth.json"
if (-not (Test-Path $authPath)) {
    Write-Host ""
    Write-Host "Note: $authPath does not exist yet (it's gitignored)."
    Write-Host "Run 'pi' and use /login for built-in providers, and/or set the"
    Write-Host "YUNWU_API_KEY environment variable for the yunwu provider in models.json."
}

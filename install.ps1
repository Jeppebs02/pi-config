<#
.SYNOPSIS
    Symlinks this repo's pi\ folder to $HOME\.pi (Windows) and excludes the
    repo from Windows Defender so the security-skill docs aren't quarantined.
.NOTES
    Run this script as Administrator. Administrator is required to:
      - add the Windows Defender exclusion (Add-MpPreference), and
      - create the symlink (unless Developer Mode is enabled).
    Without Administrator the Defender step is skipped and the hack-skills /
    ctf-skills payload docs will keep getting deleted by real-time protection.
#>

$ErrorActionPreference = "Stop"

$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Src = Join-Path $RepoDir "pi"
$Dest = Join-Path $HOME ".pi"

# Are we elevated?
$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Warning "Not running as Administrator - run me as admin."
    Write-Warning "The Windows Defender exclusion will be skipped, so the security-skill"
    Write-Warning "docs may be quarantined. Re-run this script from an elevated PowerShell:"
    Write-Warning "  Right-click PowerShell > Run as administrator, then re-run install.ps1"
    Write-Host ""
}

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

# Exclude the repo from Windows Defender. The hack-skills / ctf-skills docs
# contain reverse-shell and web-shell payload examples that real-time
# protection flags as malware (Backdoor:*) and deletes on sight.
if ($IsAdmin) {
    try {
        $existing = (Get-MpPreference).ExclusionPath
        if ($existing -contains $RepoDir) {
            Write-Host "Defender exclusion already present for $RepoDir."
        } else {
            Add-MpPreference -ExclusionPath $RepoDir
            Write-Host "Added Windows Defender exclusion for $RepoDir."
        }
    } catch {
        Write-Warning "Could not add Windows Defender exclusion (is Defender present/enabled?).`n$_"
        Write-Warning "Add it manually from an elevated shell:"
        Write-Warning "  Add-MpPreference -ExclusionPath `"$RepoDir`""
    }
} else {
    Write-Warning "Skipped Windows Defender exclusion (not Administrator)."
    Write-Warning "Add it manually from an elevated shell:"
    Write-Warning "  Add-MpPreference -ExclusionPath `"$RepoDir`""
}

$authPath = Join-Path $Src "agent\auth.json"
if (-not (Test-Path $authPath)) {
    Write-Host ""
    Write-Host "Note: $authPath does not exist yet (it's gitignored)."
    Write-Host "Run 'pi' and use /login for built-in providers, and/or set the"
    Write-Host "YUNWU_API_KEY environment variable for the yunwu provider in models.json."
}

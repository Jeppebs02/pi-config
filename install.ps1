<#
.SYNOPSIS
    Symlinks this repo's pi\ folder to $HOME\.pi (Windows), excludes the
    repo from Windows Defender so the security-skill docs aren't quarantined,
    and registers the toilet-pi supervisor as a Windows Scheduled Task.
.PARAMETER Uninstall
    Remove the toilet-pi supervisor Scheduled Task and exit. Does not touch
    the ~/.pi symlink, the Defender exclusion, or toilet-pi.json.
.NOTES
    Run this script as Administrator. Administrator is required to:
      - add the Windows Defender exclusion (Add-MpPreference), and
      - create the symlink (unless Developer Mode is enabled).
    Without Administrator the Defender step is skipped and the hack-skills /
    ctf-skills payload docs will keep getting deleted by real-time protection.
    The toilet-pi Scheduled Task does not require Administrator.
#>

param(
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$ToiletPiTaskName = "ToiletPiSupervisor"

if ($Uninstall) {
    $existingTask = Get-ScheduledTask -TaskName $ToiletPiTaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Unregister-ScheduledTask -TaskName $ToiletPiTaskName -Confirm:$false
        Write-Host "Removed scheduled task '$ToiletPiTaskName'."
    } else {
        Write-Host "Scheduled task '$ToiletPiTaskName' not found. Nothing to do."
    }
    exit 0
}

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

$SkipSymlink = $false
if (Test-Path $Dest) {
    $item = Get-Item $Dest -Force
    if ($item.LinkType -eq "SymbolicLink") {
        $target = $item.Target
        if ($target -eq $Src) {
            Write-Host "$Dest already links to $Src. Nothing to do."
            $SkipSymlink = $true
        } else {
            Write-Host "Removing existing symlink $Dest -> $target"
            Remove-Item $Dest -Force
        }
    } else {
        Write-Error "$Dest already exists and is not a symlink. Back it up or remove it, then re-run this script."
        exit 1
    }
}

if (-not $SkipSymlink) {
    try {
        New-Item -ItemType SymbolicLink -Path $Dest -Target $Src | Out-Null
        Write-Host "Linked $Dest -> $Src"
    } catch {
        Write-Error "Failed to create symlink. Enable Developer Mode or re-run this script as Administrator.`n$_"
        exit 1
    }
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

# toilet-pi supervisor (Windows Scheduled Task) -----------------------------
# toilet-pi (https://github.com/mrexodia/toilet-pi) is loaded as a pi package
# via pi/agent/settings.json's "packages" list; pi itself clones/updates the
# checkout on startup. This step just wires the supervisor process (the thing
# that makes this machine controllable from the toilet-pi web UI) into
# Windows Task Scheduler so it survives logoff, reboot, sleep/wake, and
# crashes. See docs/toilet-pi.md.
$ToiletPiDir = Join-Path $Dest "agent\git\github.com\mrexodia\toilet-pi"

Write-Host ""
if (-not (Test-Path (Join-Path $ToiletPiDir "package.json"))) {
    Write-Warning "toilet-pi checkout not found at $ToiletPiDir yet."
    Write-Warning "Start 'pi' once so it installs the package from settings.json (or run"
    Write-Warning "'pi install https://github.com/mrexodia/toilet-pi' yourself), then re-run"
    Write-Warning "install.ps1 to register the supervisor scheduled task. See docs/toilet-pi.md."
} else {
    try {
        $logonTrigger = New-ScheduledTaskTrigger -AtLogOn

        # "At workstation unlock" has no dedicated New-ScheduledTaskTrigger
        # switch; build it from the underlying CIM class directly.
        # StateChange 8 = TASK_SESSION_UNLOCK.
        $unlockTriggerClass = Get-CimClass -ClassName MSFT_TaskSessionStateChangeTrigger `
            -Namespace Root/Microsoft/Windows/TaskScheduler
        $unlockTrigger = New-CimInstance -CimClass $unlockTriggerClass -ClientOnly
        $unlockTrigger.StateChange = 8
        $unlockTrigger.Enabled = $true

        $action = New-ScheduledTaskAction -Execute "$env:ComSpec" `
            -Argument "/d /c npm run supervisor" `
            -WorkingDirectory $ToiletPiDir

        $settings = New-ScheduledTaskSettingsSet `
            -RestartCount 999 `
            -RestartInterval (New-TimeSpan -Minutes 1) `
            -ExecutionTimeLimit ([TimeSpan]::Zero) `
            -MultipleInstances IgnoreNew `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -StartWhenAvailable `
            -DontStopOnIdleEnd

        $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" `
            -LogonType Interactive -RunLevel Limited

        Register-ScheduledTask -TaskName $ToiletPiTaskName `
            -Action $action `
            -Trigger @($logonTrigger, $unlockTrigger) `
            -Settings $settings `
            -Principal $principal `
            -Force -ErrorAction Stop | Out-Null

        Write-Host "Registered scheduled task '$ToiletPiTaskName' (runs 'npm run supervisor' from $ToiletPiDir)."
        Write-Host "Triggers: at logon and at workstation unlock. Restarts on failure (999 retries, 1 min apart;"
        Write-Host "the counter resets on the next logon/unlock trigger)."
        Write-Host "Start it now with: Start-ScheduledTask -TaskName $ToiletPiTaskName"
    } catch {
        Write-Warning "Failed to register scheduled task '$ToiletPiTaskName'.`n$_"
    }

    $toiletPiConfigPath = Join-Path $Dest "agent\toilet-pi.json"
    if (-not (Test-Path $toiletPiConfigPath)) {
        Write-Host ""
        Write-Host "Note: $toiletPiConfigPath does not exist yet (it's gitignored)."
        Write-Host "Run 'pi' and use '/toilet-pi setup <machine-url>' to connect this machine."
        Write-Host "See docs/toilet-pi.md."
    }
}

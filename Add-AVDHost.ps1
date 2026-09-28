<#
.SYNOPSIS
    Adds an AVD Session Host to an existing AVD Host Pool.
 
.DESCRIPTION
    This script adds an AVD Session Host to an existing AVD Host Pool by:
    - Configuring Azure AD Join registry settings when required
    - Downloading the AVD Agent
    - Downloading the AVD Boot Loader
    - Installing the AVD Boot Loader
    - Installing the AVD Agent
    - Verifying the AVD Agent installation
    - Logging all actions and MSI installation results
 
.NOTES
    File Name  : Add-AVDHost.ps1
    Author     : InSpark
    Version    : v2.0.0
 
.EXAMPLE
    .\Add-AVDHost.ps1 -avdRegistrationKey <yourRegistrationKey>
 
.DISCLAIMER
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
    INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
    PARTICULAR PURPOSE AND NONINFRINGEMENT.
#>
 
param(
    [Parameter(Mandatory = $true)]
    [string] $avdRegistrationKey,
 
    [string] $LogDir = "$env:windir\system32\logfiles",
 
    [string] $isAzureADJoined = "false",
 
    [string] $isIntuneManaged = "false"
)
 
# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
 
$RootFolder          = "C:\AVDInstall"
$AgentInstaller      = Join-Path $RootFolder "Microsoft.RDInfra.RDAgent.msi"
$BootLoaderInstaller = Join-Path $RootFolder "Microsoft.RDInfra.RDAgentBootLoader.msi"
 
$AgentUrl            = "https://go.microsoft.com/fwlink/?linkid=2310011"
$BootLoaderUrl       = "https://go.microsoft.com/fwlink/?linkid=2311028"
 
$LogFile             = Join-Path $LogDir "WVD.addAVDHost.log"
$AgentMsiLog         = Join-Path $RootFolder "RDAgent-install.log"
$BootLoaderMsiLog    = Join-Path $RootFolder "BootLoader-install.log"
 
# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
 
function LogWriter {
    param(
        [string] $Message
    )
 
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
 
    $LogMessage = "[$Timestamp] $Message"
 
    Write-Host $LogMessage
 
    try {
        if (-not (Test-Path $LogDir)) {
            New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
        }
 
        Add-Content -Path $LogFile -Value $LogMessage
    }
    catch {
        Write-Host "WARNING: Could not write to log file $LogFile. Error: $($_.Exception.Message)"
    }
}
 
# ---------------------------------------------------------------------------
# Error handling
# ---------------------------------------------------------------------------
 
$ErrorActionPreference = "Stop"
 
try {
 
    LogWriter "============================================================"
    LogWriter "Starting AVD Session Host installation"
    LogWriter "Script version: 2.0.0"
    LogWriter "Computer Name : $env:COMPUTERNAME"
    LogWriter "PowerShell    : $($PSVersionTable.PSVersion)"
    LogWriter "Root folder   : $RootFolder"
    LogWriter "Log file      : $LogFile"
    LogWriter "============================================================"
 
    # -----------------------------------------------------------------------
    # Create folder structure
    # -----------------------------------------------------------------------
 
    LogWriter "Checking installation directory..."
 
    if (-not (Test-Path -Path $RootFolder)) {
        LogWriter "Creating installation directory: $RootFolder"
 
        New-Item `
            -Path $RootFolder `
            -ItemType Directory `
            -Force | Out-Null
 
        LogWriter "Installation directory created successfully."
    }
    else {
        LogWriter "Installation directory already exists."
    }
 
    # -----------------------------------------------------------------------
    # Azure AD Join registry configuration
    # -----------------------------------------------------------------------
 
    if ($isAzureADJoined -eq "true") {
 
        LogWriter "Azure AD Joined configuration enabled."
 
        $registryPath = "HKLM:\SOFTWARE\Microsoft\RDInfraAgent\AzureADJoin"
 
        if (-not (Test-Path -Path $registryPath)) {
 
            LogWriter "Creating registry path: $registryPath"
 
            New-Item `
                -Path $registryPath `
                -Force | Out-Null
        }
 
        LogWriter "Setting registry value JoinAzureAD = 1"
 
        New-ItemProperty `
            -Path $registryPath `
            -Name JoinAzureAD `
            -PropertyType DWord `
            -Value 1 `
            -Force | Out-Null
 
        LogWriter "JoinAzureAD registry value configured successfully."
 
        if ($isIntuneManaged -eq "true") {
 
            LogWriter "Intune managed configuration enabled."
 
            LogWriter "Setting MDMEnrollmentId"
 
            New-ItemProperty `
                -Path $registryPath `
                -Name MDMEnrollmentId `
                -PropertyType String `
                -Value "0000000a-0000-0000-c000-000000000000" `
                -Force | Out-Null
 
            LogWriter "MDMEnrollmentId configured successfully."
        }
    }
    else {
        LogWriter "Azure AD Joined configuration disabled."
    }
 
    # -----------------------------------------------------------------------
    # Download files
    # -----------------------------------------------------------------------
 
    LogWriter "============================================================"
    LogWriter "Downloading AVD installation files"
    LogWriter "============================================================"
 
    $files = @(
        @{
            Name = "AVD Agent"
            Url  = $AgentUrl
            Path = $AgentInstaller
        },
        @{
            Name = "AVD Boot Loader"
            Url  = $BootLoaderUrl
            Path = $BootLoaderInstaller
        }
    )
 
    foreach ($File in $files) {
 
        LogWriter "Downloading $($File.Name)"
        LogWriter "URL : $($File.Url)"
        LogWriter "Path: $($File.Path)"
 
        try {
 
            $WebClient = New-Object System.Net.WebClient
 
            $WebClient.DownloadFile(
                $File.Url,
                $File.Path
            )
 
            $WebClient.Dispose()
 
            if (-not (Test-Path $File.Path)) {
                throw "Downloaded file does not exist after download."
            }
 
            $FileInfo = Get-Item $File.Path
 
            LogWriter "$($File.Name) downloaded successfully."
            LogWriter "File size: $($FileInfo.Length) bytes"
            LogWriter "Last write time: $($FileInfo.LastWriteTime)"
 
        }
        catch {
 
            LogWriter "ERROR: Failed to download $($File.Name)"
            LogWriter "ERROR: $($_.Exception.Message)"
 
            throw
        }
    }
 
    # -----------------------------------------------------------------------
    # Verify downloaded files
    # -----------------------------------------------------------------------
 
    LogWriter "Verifying downloaded MSI files..."
 
    foreach ($Installer in @($AgentInstaller, $BootLoaderInstaller)) {
 
        if (-not (Test-Path $Installer)) {
            throw "Required installer not found: $Installer"
        }
 
        $InstallerInfo = Get-Item $Installer
 
        if ($InstallerInfo.Length -eq 0) {
            throw "Installer exists but has a size of 0 bytes: $Installer"
        }
 
        LogWriter "Verified installer: $Installer"
        LogWriter "Size: $($InstallerInfo.Length) bytes"
    }
 
    # -----------------------------------------------------------------------
    # Install Boot Loader
    # -----------------------------------------------------------------------
 
    LogWriter "============================================================"
    LogWriter "Installing AVD Boot Loader"
    LogWriter "============================================================"
 
    LogWriter "Installer: $BootLoaderInstaller"
    LogWriter "MSI log  : $BootLoaderMsiLog"
 
    $BootLoaderArguments = @(
        "/i"
        "`"$BootLoaderInstaller`""
        "/qn"
        "/L*v"
        "`"$BootLoaderMsiLog`""
    )
 
    LogWriter "Starting msiexec.exe for Boot Loader..."
 
    $BootLoaderProcess = Start-Process `
        -FilePath "msiexec.exe" `
        -ArgumentList ($BootLoaderArguments -join " ") `
        -Wait `
        -PassThru
 
    LogWriter "Boot Loader MSI process completed."
    LogWriter "Boot Loader MSI ExitCode: $($BootLoaderProcess.ExitCode)"
 
    if ($BootLoaderProcess.ExitCode -ne 0) {
 
        LogWriter "ERROR: Boot Loader installation failed."
        LogWriter "See MSI log: $BootLoaderMsiLog"
 
        throw "Boot Loader installation failed with exit code $($BootLoaderProcess.ExitCode)"
    }
 
    LogWriter "Boot Loader installation completed successfully."
 
    # -----------------------------------------------------------------------
    # Install AVD Agent
    # -----------------------------------------------------------------------
 
    LogWriter "============================================================"
    LogWriter "Installing AVD Agent"
    LogWriter "============================================================"
 
    LogWriter "Installer: $AgentInstaller"
    LogWriter "MSI log  : $AgentMsiLog"
 
    # Do NOT log the actual registration token.
    LogWriter "Registration token supplied: YES"
 
    $AgentArguments = @(
        "/i"
        "`"$AgentInstaller`""
        "/qn"
        "RegistrationToken=`"$avdRegistrationKey`""
        "/L*v"
        "`"$AgentMsiLog`""
    )
 
    LogWriter "Starting msiexec.exe for AVD Agent..."
 
    $AgentProcess = Start-Process `
        -FilePath "msiexec.exe" `
        -ArgumentList ($AgentArguments -join " ") `
        -Wait `
        -PassThru
 
    LogWriter "AVD Agent MSI process completed."
    LogWriter "AVD Agent MSI ExitCode: $($AgentProcess.ExitCode)"
 
    if ($AgentProcess.ExitCode -ne 0) {
 
        LogWriter "ERROR: AVD Agent installation failed."
        LogWriter "See MSI log: $AgentMsiLog"
 
        throw "AVD Agent installation failed with exit code $($AgentProcess.ExitCode)"
    }
 
    LogWriter "AVD Agent MSI reported successful installation."
 
    # -----------------------------------------------------------------------
    # Verify RDAgent installation
    # -----------------------------------------------------------------------
 
    LogWriter "============================================================"
    LogWriter "Verifying AVD Agent installation"
    LogWriter "============================================================"
 
    $AgentDirectories = Get-ChildItem `
        "C:\Program Files\Microsoft RDInfra\" `
        -Directory `
        -Filter "RDAgent_*" `
        -ErrorAction SilentlyContinue
 
    if (-not $AgentDirectories) {
 
        LogWriter "ERROR: No RDAgent_* directory found."
 
        throw "AVD Agent MSI reported success but RDAgent directory was not found."
    }
 
    foreach ($AgentDirectory in $AgentDirectories) {
        LogWriter "Found RDAgent installation: $($AgentDirectory.FullName)"
    }
 
    $RDAgentDll = Get-ChildItem `
        "C:\Program Files\Microsoft RDInfra\" `
        -Recurse `
        -Filter "RDAgent.dll" `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1
 
    if (-not $RDAgentDll) {
 
        LogWriter "ERROR: RDAgent.dll was not found."
 
        throw "RDAgent.dll was not found after successful MSI installation."
    }
 
    LogWriter "RDAgent.dll found: $($RDAgentDll.FullName)"
 
    # -----------------------------------------------------------------------
    # Verify Boot Loader service
    # -----------------------------------------------------------------------
 
    LogWriter "Checking RDAgentBootLoader service..."
 
    $BootLoaderService = Get-Service `
        -Name "RDAgentBootLoader" `
        -ErrorAction SilentlyContinue
 
    if ($null -eq $BootLoaderService) {
 
        LogWriter "ERROR: RDAgentBootLoader service not found."
 
        throw "RDAgentBootLoader service was not found."
    }
 
    LogWriter "RDAgentBootLoader service found."
    LogWriter "Status    : $($BootLoaderService.Status)"
    LogWriter "StartType : $($BootLoaderService.StartType)"
 
    # -----------------------------------------------------------------------
    # Final result
    # -----------------------------------------------------------------------
 
    LogWriter "============================================================"
    LogWriter "AVD Session Host installation completed successfully"
    LogWriter "Computer Name : $env:COMPUTERNAME"
    LogWriter "RDAgent      : $($RDAgentDll.FullName)"
    LogWriter "BootLoader   : $($BootLoaderService.Status)"
    LogWriter "============================================================"
 
    exit 0
}
catch {
 
    LogWriter "============================================================"
    LogWriter "ERROR: AVD Session Host installation FAILED"
    LogWriter "Error: $($_.Exception.Message)"
    LogWriter "============================================================"
 
    exit 1
}

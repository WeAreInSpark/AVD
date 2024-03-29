<#
.SYNOPSIS
  The script can be used to start or stop Azure VMs, for example when they need to update using Update Management with Automation Account. 
.DESCRIPTION
The script does the following:
* Starting the Azure VM when status is not "running"

Required Powershell modules:
	'Az.Compute'
	'Az.Resources'
	'Az.Automation'

.PARAMETER SubscriptionId
    Subscription ID of where the Session Hosts are hosted
.PARAMETER SkipTag
    The name of the tag, which will exclude the VM from scaling. The default value is SkipAutoShutdown
.PARAMETER TimeDifference
    The time diference with UTC (e.g. +2:00)                    
.NOTES
  Version:        1.0
  Author:         Siebren Mossel
  Creation Date:  08/03/2023
  Purpose/Change: Initial script development
#>

param(
    [Parameter(mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(mandatory = $true)]
    [string]$Action,
    [ValidateSet("Start", "Stop")]
	
    [Parameter(mandatory = $false)]
    [string]$ResourceGroupName,

    [Parameter(mandatory = $false)]
    [string]$TagName,

    [Parameter(mandatory = $false)]
    [string]$SkipTag = "SkipStart",
    
    [Parameter(mandatory = $false)]
    [string]$TimeDifference = "+2:00"

)

[array]$RequiredModules = @(
    'Az.Compute'
    'Az.Resources'
    'Az.Automation'
)


[string[]]$TimeDiffHrsMin = "$($TimeDifference):0".Split(':')
#Functions

function Write-Log {
    # Note: this is required to support param such as ErrorAction
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [switch]$Err,

        [switch]$Warn
    )

    [string]$MessageTimeStamp = (Get-LocalDateTime).ToString('yyyy-MM-dd HH:mm:ss')
    $Message = "[$($MyInvocation.ScriptLineNumber)] $Message"
    [string]$WriteMessage = "$MessageTimeStamp $Message"

    if ($Err) {
        Write-Error $WriteMessage
        $Message = "ERROR: $Message"
    }
    elseif ($Warn) {
        Write-Warning $WriteMessage
        $Message = "WARN: $Message"
    }
    else {
        Write-Output $WriteMessage
    }

}

# Function to return local time converted from UTC
function Get-LocalDateTime {
    return (Get-Date).ToUniversalTime().AddHours($TimeDiffHrsMin[0]).AddMinutes($TimeDiffHrsMin[1])
}

Authenticating

try {


    Write-log "Logging in to Azure..."
    $connecting = Connect-AzAccount -identity 

}
catch {
    Write-Error -Message $_.Exception
    Write-log "Unable to sign in, terminating script.."
    throw $_.Exception

}

#starting script
Write-Log 'Starting script for starting/stopping Azure VMs'


Write-Log 'Checking if required modules are installed in the Automation Account'
# Checking if required modules are present 
foreach ($ModuleName in $RequiredModules) {
    if (Get-Module -ListAvailable -Name $ModuleName) {
        Write-Log "$($ModuleName) is present"
    } 
    else {
        Write-Log "$($ModuleName) is not present. Make sure to import the required modules in the Automation Account. Check the desription"
        #throw
    }
}

#Getting Azure VMs
if ($ResourceGroupName) {
    Write-Log 'Getting all Azure VMs based on ResourceGroupName'
    $AzureVMs = Get-AzVM -ResourceGroupName $ResourceGroupName
    if (!$AzureVMs) {
        Write-Log "There are no Azure Vms in the ResourceGroup $ResourceGroupName."
        Write-Log 'End'
        return
    }
}
elseif ($TagName) {
    Write-Log 'Getting all Azure VMs based on Tag'
    $AzureVMs = Get-AzVM | Where-Object { $_.Tags[$TagName] }
    if (!$AzureVMs) {
        Write-Log "There are no Azure Vms with tagName $TagName."
        Write-Log 'End'
        return
    }
}

#Evaluate eacht session hosts
foreach ($vm in $AzureVMs) {
    $RGName = $vm.ResourceGroupName
    $vmName = $vm.Name
    #Gathering information about the running state
    $VMStatus = (Get-AzVM -ResourceGroupName $RGName -Name $vmName -Status).Statuses[1].Code
    Write-Log $VMStatus
    #Gathering information about tags
    $VMSkip = (Get-AzVm -ResourceGroupName $RGName -Name $vmName).Tags.Keys

    # VM is Deallocated   
    if ($VMStatus -eq 'PowerState/deallocated') {
        if ($Action -eq 'Start') {
            Write-Log "$vmName is in a deallocated state, starting VM"
            $StartVM = Start-AzVM -Name $vmName -ResourceGroupName $RGName
            Write-Log "Starting $vmName ended with status: $($StartVM.Status)"
        }
        if ($Action -eq 'Stop') {
            Write-Log "$vmName is already stopped"2
            continue
        }
    }
    # If VM has skiptag we can skip
    if ($VMSkip -contains $SkipTag) {
        Write-Log "VM $vmName contains the skip tag and will be ignored"
        continue
    }
    # If VM is stopped, deallocate VM
    if ($VMStatus -eq 'PowerState/stopped') {
        if ($Action -eq 'Start') {
            Write-Log "$vmName is stopped, starting VM"
            $StartVM = Start-AzVM -Name $vmName -ResourceGroupName $RGName
            Write-Log "Starting $vmName ended with status: $($StartVM.Status)"
        }
        if ($Action -eq 'Stop') {
            Write-Log "$vmName is stopped, deallocationg VM"
            $StopVM = Stop-AzVM -Name $vmName -ResourceGroupName $RGName
            Write-Log "Starting $vmName ended with status: $($StopVM.Status)"
        }
    }

    #for running vms
    if ($VMStatus -eq 'PowerState/running') {
        if ($Action -eq 'Start') {
            Write-Log "$vmName is already running"
            continue
        }
        if ($Action -eq 'Stop') {
            Write-Log "$vmName is running, deallocationg VM"
            $StopVM = Stop-AzVM -Name $vmName -ResourceGroupName $RGName
            Write-Log "Starting $vmName ended with status: $($StopVM.Status)"
        }
    }  
}
Write-Log 'All VMs are processed'
Write-Log 'Disconnecting AZ Session'

#disconnect
$DisconnectInfo = Disconnect-AzAccount

Write-Log 'End'

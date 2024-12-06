[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]
    $SubscriptionId,

    [Parameter()]
    [string]
    $ResourceGroupName = ''
)

# Import the required modules
Import-Module Az.Compute
Import-Module Az.Accounts

# Authenticate to Azure
try {
    "Logging in to Azure..."
    Connect-AzAccount -Identity
} catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}


# Define the resource group and the list of VMs
if ([string]::IsNullOrEmpty($ResourceGroupName)) {
    Get-AzVM | Where-Object {$_.tags.EnablePrivateNetworkGC -eq "TRUE"}
} else {
    Get-AzVM -ResourceGroupName $ResourceGroupName | Where-Object {$_.tags.EnablePrivateNetworkGC -eq "TRUE"} 
}

# Function to get the last logon time of a VM
function Get-LastLogonTime {
    param (
        [string]$vmName
    )
    # Get the diagnostics logs or performance metrics to determine the last logon time
    # For simplicity, this example uses a placeholder value
    # Replace this with the actual logic to get the last logon time
    $lastLogonTime = (Get-Date).AddHours(-($RANDOM % 24)) # Placeholder logic
    return $lastLogonTime
}

# Define the idle time threshold (8 hours)
$idleTimeThreshold = 8

foreach ($vmName in $vmNames) {
    try {
        $vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Status
        $lastLogonTime = Get-LastLogonTime -vmName $vmName

if ($vm.Statuses[1].Code -eq "PowerState/running") {
            $currentTime = Get-Date
            $idleTime = ($currentTime - $lastLogonTime).TotalHours

if ($idleTime -gt $idleTimeThreshold) {
                Write-Output "VM $vmName has been idle for $idleTime hours. Shutting down..."
                Stop-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Force
            } else {
                Write-Output "VM $vmName has been idle for $idleTime hours. No action required."
            }
        } else {
            Write-Output "VM $vmName is not running. No action required."
        }
    } catch {
        Write-Error "An error occurred while processing VM $($vmName): $_"
    }
}

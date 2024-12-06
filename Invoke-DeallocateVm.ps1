# Import the required modules
Import-Module Az.Compute
Import-Module Az.Accounts

# Authenticate to Azure
# This script assumes you have set up a Run As account in your Azure Automation account
$Connection = Get-AutomationConnection -Name "AzureRunAsConnection"
Connect-AzAccount -ServicePrincipal -TenantId $Connection.TenantId -ApplicationId $Connection.ApplicationId -CertificateThumbprint $Connection.CertificateThumbprint

# Define the resource group and the list of VMs
$resourceGroupName = "YourResourceGroupName"
$vmNames = @("VM1", "VM2", "VM3", ...) # Add all your VM names here

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
        Write-Error "An error occurred while processing VM $vmName: $_"
    }
}

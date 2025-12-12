<#
.SYNOPSIS
    Create an Azure On-Demand Capacity Reservation with retry, backoff, and error logging.

.REQUIREMENTS
    Install-Module Az -Scope CurrentUser
    Import-Module Az.Accounts, Az.Compute

.PARAMETERS
    -SubscriptionId:    Target subscription
    -ResourceGroup:     Resource group to create or reuse
    -Location:          Azure region, e.g., eastus, westus3
    -Zone:              Availability zone as string: "1" | "2" | "3" (optional for regional CRG)
    -CrgName:           Capacity Reservation Group name
    -ReservationName:   Capacity Reservation name
    -SkuFamily:         VM family, e.g., "Dsv5", "Esv5". Use -VmSize to override
    -VmSize:            Exact VM size, e.g., "Standard_D2s_v5". If omitted, the script picks a small size in the family
    -Capacity:          Number of instances to reserve
    -Tags:              Hashtable of tags, e.g., @{env="prod";owner="joe"}
    -MaxAttempts:       Upper bound on retries (default 15)
    -BaseDelaySec:      Initial backoff seconds (default 5)
    -MaxDelaySec:       Maximum backoff seconds (default 300)
    -LogPath:           Error log file path (default "$env:TEMP\odcr-create-errors.log")
#>

param(
    [Parameter(Mandatory=$true)]  [string] $SubscriptionId,
    [Parameter(Mandatory=$true)]  [string] $ResourceGroup,
    [Parameter(Mandatory=$true)]  [string] $Location,
    [Parameter(Mandatory=$false)] [ValidateSet("1","2","3")] [string] $Zone,
    [Parameter(Mandatory=$true)]  [string] $CrgName,
    [Parameter(Mandatory=$true)]  [string] $ReservationName,
    [Parameter(Mandatory=$false)] [string] $SkuFamily,
    [Parameter(Mandatory=$false)] [string] $VmSize,
    [Parameter(Mandatory=$true)]  [int]    $Capacity,
    [Parameter(Mandatory=$false)] [hashtable] $Tags = @{},
    [Parameter(Mandatory=$false)] [int] $MaxAttempts = 15,
    [Parameter(Mandatory=$false)] [int] $BaseDelaySec = 5,
    [Parameter(Mandatory=$false)] [int] $MaxDelaySec = 300,
    [Parameter(Mandatory=$false)] [string] $LogPath = "$env:TEMP\odcr-create-errors.log"
)

# -------- Helpers --------

function Write-Log {
    param([string]$Message)
    $ts = (Get-Date).ToString("s")
    $line = "[$ts] $Message"
    Write-Host $line
    Add-Content -Path $LogPath -Value $line
}

function Ensure-Modules {
    $modules = @("Az.Accounts","Az.Compute")
    foreach ($m in $modules) {
        if (-not (Get-Module -ListAvailable -Name $m)) {
            Write-Log "Installing missing module: $m"
            Install-Module Az -Scope CurrentUser -Force
        }
    }
    Import-Module Az.Accounts -ErrorAction Stop
    Import-Module Az.Compute  -ErrorAction Stop
}

function Get-CapacityReservationSupportedSizes {
    param([string]$Region)
    $skus = Get-AzComputeResourceSku -Location $Region -ResourceType "virtualMachines" `
        | Where-Object { $_.Restrictions.Count -eq 0 -and $_.Locations -contains $Region } `
        | Where-Object {
            $_.Capabilities -and ($_.Capabilities | Where-Object { $_.Name -eq "CapacityReservationSupported" -and $_.Value -eq "True" })
        }
    return $skus
}

function Resolve-VmSize {
    param([string]$Region,[string]$Family,[string]$ExplicitSize)
    if ($ExplicitSize) { return $ExplicitSize }
    if (-not $Family) { throw "You must supply -VmSize or -SkuFamily." }

    $skus = Get-CapacityReservationSupportedSizes -Region $Region
    if (-not $skus) { throw "No CR-supported VM sizes returned for region $Region." }

    $familyMatch = $skus | Where-Object { $_.Family -like "*$Family*" -or $_.Name -like "Standard_${Family}*" }
    if (-not $familyMatch) {
        $avail = ($skus | Select-Object -ExpandProperty Family -Unique | Sort-Object) -join ", "
        throw "No CR-supported sizes found for family '$Family' in $Region. Available families: $avail"
    }

    $preferred = $familyMatch | Where-Object { $_.Name -match 'Standard_.*2.*' } | Select-Object -ExpandProperty Name -First 1
    if ($preferred) { return $preferred }
    return ($familyMatch | Select-Object -ExpandProperty Name | Sort-Object | Select-Object -First 1)
}

function Ensure-ResourceGroup {
    param([string]$Rg,[string]$Region)
    $rg = Get-AzResourceGroup -Name $Rg -ErrorAction SilentlyContinue
    if (-not $rg) {
        Write-Log "Creating resource group $Rg in $Region"
        New-AzResourceGroup -Name $Rg -Location $Region | Out-Null
    }
}

function Ensure-CapacityReservationGroup {
    param([string]$Rg,[string]$Region,[string]$Name,[string]$Zone,[hashtable]$Tags)
    $existing = Get-AzCapacityReservationGroup -ResourceGroupName $Rg -Name $Name -ErrorAction SilentlyContinue
    if ($existing) { return $existing }

    Write-Log "Creating Capacity Reservation Group '$Name' in $Region" + ($(if($Zone){" zone $Zone"}else{""}))
    if ($Zone) {
        return New-AzCapacityReservationGroup -ResourceGroupName $Rg -Location $Region -Name $Name -Zone $Zone -Tag $Tags
    } else {
        return New-AzCapacityReservationGroup -ResourceGroupName $Rg -Location $Region -Name $Name -Tag $Tags
    }
}

function New-ODCR-WithRetry {
    param([string]$Rg,[string]$Region,[string]$Crg,[string]$ResName,[string]$Size,[int]$Qty,[string]$Zone,[int]$MaxAttempts,[int]$BaseDelaySec,[int]$MaxDelaySec)
    $attempt = 0
    while ($true) {
        $attempt++
        try {
            Write-Log "Attempt $attempt: creating ODCR '$ResName' size '$Size' capacity $Qty in group '$Crg' $Region" + ($(if($Zone){" zone $Zone"}else{""}))
            $cr = if ($Zone) {
                New-AzCapacityReservation -ResourceGroupName $Rg -ReservationGroupName $Crg -Name $ResName `
                    -Location $Region -Sku $Size -CapacityToReserve $Qty -Zone $Zone
            } else {
                New-AzCapacityReservation -ResourceGroupName $Rg -ReservationGroupName $Crg -Name $ResName `
                    -Location $Region -Sku $Size -CapacityToReserve $Qty
            }
            if ($cr -and $cr.ProvisioningState -in @("Succeeded","Created","Updating")) {
                Write-Log "Success. ProvisioningState: $($cr.ProvisioningState)."
                return $cr
            } else { throw "Reservation returned unexpected state '$($cr.ProvisioningState)'." }
        }
        catch {
            $msg = $_.Exception.Message
            Write-Log "Error on attempt $attempt: $msg"
            if ($attempt -ge $MaxAttempts) { Write-Log "Max attempts reached. Giving up."; return $null }

            $delay = [Math]::Min($MaxDelaySec, $BaseDelaySec * [Math]::Pow(2, $attempt - 1))
            $delay = Get-Random -Minimum ([int]($delay * 0.5)) -Maximum ([int]$delay + 1)
            Write-Log "Backing off for $delay seconds before retry."
            Start-Sleep -Seconds $delay
        }
    }
}

# -------- Main --------
Ensure-Modules
Set-AzContext -Subscription $SubscriptionId | Out-Null
Ensure-ResourceGroup -Rg $ResourceGroup -Region $Location
$resolvedSize = Resolve-VmSize -Region $Location -Family $SkuFamily -ExplicitSize $VmSize
Write-Log "Resolved VM size: $resolvedSize"
$crg = Ensure-CapacityReservationGroup -Rg $ResourceGroup -Region $Location -Name $CrgName -Zone $Zone -Tags $Tags
$result = New-ODCR-WithRetry -Rg $ResourceGroup -Region $Location -Crg $CrgName -ResName $ReservationName `
    -Size $resolvedSize -Qty $Capacity -Zone $Zone -MaxAttempts $MaxAttempts -BaseDelaySec $BaseDelaySec -MaxDelaySec $MaxDelaySec
$result | ConvertTo-Json -Depth 5

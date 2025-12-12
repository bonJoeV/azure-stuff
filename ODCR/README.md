# Azure On-Demand Capacity Reservation Automation (ODCR Creator)

**Author:** Joe Vandermark, Microsoft  
**Purpose:** Automate creation of On-Demand Capacity Reservations (ODCR) with retries, backoff, and error logging to ensure reliability when Azure capacity is limited or API calls are throttled.

---

## Overview

This PowerShell script automates the creation of an **Azure On-Demand Capacity Reservation (ODCR)** in a specific **region**, **availability zone**, and **SKU family**.

When Azure capacity is constrained, reservations can intermittently fail. This script retries the request with **exponential backoff and jitter**, logs all errors, and continues attempting until successful or until it reaches a defined retry limit.

It is designed for use in both **interactive** and **automated** environments, such as **Azure Automation Accounts**, **GitHub Actions**, or **scheduled jobs**.

---

## Features

- Creates a Capacity Reservation Group if it does not exist  
- Supports zonal or regional reservations  
- Validates available VM sizes that support ODCR in the target region  
- Retries on transient or throttling errors using exponential backoff with jitter  
- Logs all errors and retry events to a timestamped log file  
- Stops automatically after the defined maximum attempts  
- Built with production resilience and automation in mind  

---

## Prerequisites

### Azure PowerShell Modules

```powershell
Install-Module Az -Scope CurrentUser
Import-Module Az.Accounts, Az.Compute
```

### Authentication

```powershell
Connect-AzAccount
```

### Subscription Access

Ensure your account has permission to create capacity reservations and groups in the target subscription and resource group.

---

## Parameters

| Parameter | Required | Description |
|---|---|---|
| `-SubscriptionId` | Yes | Target Azure subscription ID |
| `-ResourceGroup` | Yes | Name of the resource group for the reservation |
| `-Location` | Yes | Azure region, e.g., `eastus` |
| `-Zone` | No | Availability zone `1`, `2`, or `3` |
| `-CrgName` | Yes | Capacity Reservation Group name |
| `-ReservationName` | Yes | Capacity Reservation name |
| `-SkuFamily` | Conditional | VM family, e.g., `Dsv5` (required if `VmSize` not provided) |
| `-VmSize` | Conditional | Exact VM size, e.g., `Standard_D2s_v5` |
| `-Capacity` | Yes | Number of VM instances to reserve |
| `-Tags` | No | Hashtable of tags, e.g., `@{env="prod";owner="joe"}` |
| `-MaxAttempts` | No | Maximum number of retry attempts. Default 60 |
| `-BaseDelaySec` | No | Initial backoff in seconds. Default 5 |
| `-MaxDelaySec` | No | Maximum backoff in seconds. Default 300 |
| `-LogPath` | No | Error log path. Default `.\odcr-create-errors.log` |

---

## Example Usage

```powershell
.\Create-ODCR.ps1 `
  -SubscriptionId "00000000-0000-0000-0000-000000000000" `
  -ResourceGroup "RG-Capacity-Reservations" `
  -Location "eastus" `
  -Zone "1" `
  -CrgName "CRG-EastUS-Zone1" `
  -ReservationName "ODCR-D2sV5-EastUS-Zone1" `
  -SkuFamily "Dsv5" `
  -Capacity 10 `
  -Tags @{env="prod";owner="joe"} `
  -MaxAttempts 50
```

The script will:

- Confirm that the resource group and capacity reservation group exist  
- Resolve a VM size that supports ODCR in the region when a family is provided  
- Retry creation until successful, with backoff and jitter between attempts  
- Log all errors and API responses to a local log file  

---

## Logging

All attempts, errors, and backoff intervals are recorded in the log file defined by `-LogPath`.

Example:

```
[2025-10-10T09:13:22] Attempt 3: creating ODCR 'ODCR-D2sV5-EastUS-Zone1' size 'Standard_D2s_v5' capacity 10
[2025-10-10T09:13:23] Error on attempt 3. Status: 409. Message: Capacity temporarily unavailable.
[2025-10-10T09:13:23] Backing off for 54 seconds before retry.
```

---

## Error Handling and Retry Logic

The script automatically retries for:

- HTTP 408, 409, 429, 500, 502, 503, 504  
- Throttling with `Retry-After` headers  
- Transient compute messages such as `OperationNotAllowed`, `SkuNotAvailable`, `Throttling`, `QuotaExceeded`, and similar capacity related text

It stops retrying when:

- The reservation is successfully created, or  
- The maximum number of attempts is reached, or  
- A non-retryable error is detected  

---

## Notes

- Capacity reservations can be regional or zonal based on the `-Zone` parameter.  
- Only VM sizes that support ODCR in the region can be used. The script detects these when you pass a family.  
- Use tags and policy to track and govern reservations across environments.  

---

## References

- https://learn.microsoft.com/azure/virtual-machines/capacity-reservation-overview  
- https://learn.microsoft.com/powershell/module/az.compute/new-azcapacityreservationgroup  
- https://learn.microsoft.com/powershell/module/az.compute/new-azcapacityreservation  
- https://learn.microsoft.com/powershell/module/az.compute/get-azcomputeresourcesku  

---

## License

This script is released under the MIT License.  
© 2025 Joe Vandermark, Microsoft.

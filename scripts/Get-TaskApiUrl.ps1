<#
.SYNOPSIS
    Resolves the active Task API base URL.

.DESCRIPTION
    Returns the value of the TASK_API_URL environment variable if set;
    otherwise defaults to the local mock API at http://localhost:8080.

    Set TASK_API_URL to point at the deployed Azure Container App endpoint
    (or any other remote URL) to switch the entire demo to the real API:

        $env:TASK_API_URL = "https://<your-app>.azurecontainerapps.io"

    When the variable is not set, all scripts fall back to the local mock
    server started by Start-MockApi.ps1.

.OUTPUTS
    [string] The resolved API URL with no trailing slash.

.EXAMPLE
    $apiUrl = & .\scripts\Get-TaskApiUrl.ps1
    Invoke-RestMethod "$apiUrl/health"
#>
[CmdletBinding()]
param()

$url = ($env:TASK_API_URL ?? "").Trim().TrimEnd("/")

if ($url) {
    Write-Host "API URL (from TASK_API_URL): $url" -ForegroundColor Cyan
} else {
    $url = "http://localhost:8080"
    Write-Host "TASK_API_URL not set – using local mock: $url" -ForegroundColor Yellow
    Write-Host "  Set TASK_API_URL to use a deployed endpoint:" -ForegroundColor Yellow
    Write-Host "    `$env:TASK_API_URL = 'https://<your-app>.azurecontainerapps.io'" -ForegroundColor Yellow
}

$url

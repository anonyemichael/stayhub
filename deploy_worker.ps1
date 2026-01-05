
# Deploy Cloudflare Worker Script
$apiToken = "-2CSJ6r1tYXmMiHgo-cte8v_VJ2wl_Vw2k5IWFnV"
$headers = @{ "Authorization" = "Bearer $apiToken"; "Content-Type" = "application/javascript" }

Write-Host "Getting Account ID..."
$accResp = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/accounts" -Method Get -Headers @{ "Authorization" = "Bearer $apiToken"; "Content-Type" = "application/json" }
$accountId = $accResp.result[0].id
Write-Host "Account ID: $accountId" -ForegroundColor Green

$workerName = "stayhub-otp-sender"
$scriptContent = Get-Content "worker.js" -Raw

Write-Host "Uploading Worker Script: $workerName..."
$deployUrl = "https://api.cloudflare.com/client/v4/accounts/$accountId/workers/scripts/$workerName"

try {
    # Upload script (using PUT with javascript content type)
    $response = Invoke-RestMethod -Uri $deployUrl -Method Put -Headers $headers -Body $scriptContent
    if ($response.success) {
        Write-Host "Worker Deployed Successfully!" -ForegroundColor Green
        
        # Deploy to subdomain (enable it)
        $subdomainUrl = "https://api.cloudflare.com/client/v4/accounts/$accountId/workers/scripts/$workerName/subdomain"
        $subResp = Invoke-RestMethod -Uri $subdomainUrl -Method Post -Headers @{ "Authorization" = "Bearer $apiToken"; "Content-Type" = "application/json" } -Body '{ "enabled": true }'
        
        if ($subResp.success) {
            Write-Host "Worker published to accessible subdomain!" -ForegroundColor Green
            Write-Host "URL should be: https://$workerName.stayhub.workers.dev" -ForegroundColor Cyan
             
            # Get user subdomain to be sure
            $meUrl = "https://api.cloudflare.com/client/v4/accounts/$accountId/workers/subdomain"
            $meResp = Invoke-RestMethod -Uri $meUrl -Method Get -Headers @{ "Authorization" = "Bearer $apiToken"; "Content-Type" = "application/json" }
            $sub = $meResp.result.subdomain
            Write-Host "Final URL: https://$workerName.$sub.workers.dev" -ForegroundColor Green
            ("https://$workerName.$sub.workers.dev") | Out-File "worker_url.txt"
        }
    }
    else {
        Write-Error "Deployment Failed: $($response.errors[0].message)"
    }
}
catch {
    Write-Error "Deploy Exception: $_"
    # Print more detail
    $_.Exception.Response.GetResponseStream() | % { $reader = New-Object System.IO.StreamReader($_); $reader.ReadToEnd() }
}

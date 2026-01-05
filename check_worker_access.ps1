
$apiToken = Get-Content "cloudflare_token.txt" -Raw
$apiToken = $apiToken.Trim()
$headers = @{ "Authorization" = "Bearer $apiToken"; "Content-Type" = "application/json" }

Write-Host "Checking Account ID..."
$response = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/accounts" -Method Get -Headers $headers
if ($response.success) {
    $accountId = $response.result[0].id
    Write-Host "Account ID: $accountId" -ForegroundColor Green
    
    # Check if we can list workers (test permission)
    Write-Host "Checking Workers permission..."
    try {
        $workerResp = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/accounts/$accountId/workers/scripts" -Method Get -Headers $headers
        if ($workerResp.success) {
            Write-Host "Workers Access: GRANTED" -ForegroundColor Green
            $accountId | Out-File "cloudflare_account_id.txt"
        }
        else {
            Write-Host "Workers Access: DENIED (API Error)" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Workers Access: DENIED ($($_.Exception.Message))" -ForegroundColor Red
    }
}
else {
    Write-Error "Failed to get Account ID."
}

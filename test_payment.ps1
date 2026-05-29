try {
    $body = '{"email":"test@test.com","amount":100,"reference":"test_ref_debug_001","currency":"GHS"}'
    $r = Invoke-WebRequest -Uri 'https://us-central1-device-streaming-d7021871.cloudfunctions.net/initializePayment' -Method POST -ContentType 'application/json' -Body $body -TimeoutSec 30
    Write-Host "STATUS:" $r.StatusCode
    Write-Host "BODY:" $r.Content
} catch {
    Write-Host "ERROR:" $_.Exception.Message
    $resp = $_.Exception.Response
    if ($resp -ne $null) {
        $stream = $resp.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $text = $reader.ReadToEnd()
        Write-Host "RESPONSE BODY:" $text
        Write-Host "HTTP STATUS:" ([int]$resp.StatusCode)
    }
}

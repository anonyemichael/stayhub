$ErrorActionPreference = "Stop"

Write-Host "--- Starting Deployment with Landing Page ---" -ForegroundColor Cyan

# 1. Clean and Build Flutter App for /app/ subpath
Write-Host "Building Flutter Web App (Chrome-Grade Performance)..."
flutter clean
flutter build web --release --base-href "/app/"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter build failed."
    exit 1
}

# 2. restructure build/web
# Current state: build/web contains the Flutter App
# Target state: 
#   build/web/app/ -> Contains Flutter App
#   build/web/ -> Contains Landing Page

Write-Host "Restructuring directories..."
$buildDir = "build/web"
$appDir = "build/web/app"

# Create the /app subdirectory
New-Item -ItemType Directory -Force -Path $appDir | Out-Null

# Move all flutter items into /app
# We exclude 'app' folder itself from the move to avoid recursion error
Get-ChildItem -Path $buildDir | Where-Object { $_.Name -ne "app" } | Move-Item -Destination $appDir

# 3. Copy Landing Page files to root
Write-Host "Copying Landing Page..."
Copy-Item -Path "landing_page\*" -Destination $buildDir -Recurse -Force

Write-Host "Build directory prepared successfully."

# 4. Deploy
Write-Host "Deploying to Firebase..."
cmd.exe /c npx firebase-tools deploy --only hosting
Write-Host "--- Deployment Complete ---" -ForegroundColor Green
Write-Host "Landing Page: https://stayhubgh.com"
Write-Host "Web App:      https://stayhubgh.com/app"

# Robust Deploy Script for StayHub
# Ensures correct structure for Landing Page (root) and Flutter App (/app/)

$ErrorActionPreference = "Stop"

# 1. Build Flutter App
echo "--- Step 1: Building Flutter Web App ---"
flutter build web --release --base-href "/app/"
if ($LASTEXITCODE -ne 0) { 
    echo "Flutter build failed!"
    exit $LASTEXITCODE 
}

# 2. Prepare Final Structure
echo "--- Step 2: Preparing Deployment Structure ---"

$targetDir = "hosting_deploy"
$landingPage = "landing_page"
$flutterBuild = "build/web"

# Ensure target app directory exists
if (!(Test-Path "$targetDir/app")) {
    New-Item -ItemType Directory -Path "$targetDir/app" -Force
}

# Copy Landing Page files to root of hosting_deploy
echo "Syncing Landing Page to $targetDir..."
Copy-Item "$landingPage/*" $targetDir -Recurse -Force

# Copy Flutter build to /app/ subdirectory of hosting_deploy
echo "Syncing Flutter build to $targetDir/app/..."
# Remove old app files first to avoid clutter
Remove-Item "$targetDir/app/*" -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item "$flutterBuild/*" "$targetDir/app/" -Recurse -Force

# Inject cache-busting version directly into the deployed index.html
$timestamp = (Get-Date -UFormat "%s").ToString()
$indexFile = "$targetDir/app/index.html"
if (Test-Path $indexFile) {
    (Get-Content $indexFile) -replace 'const currentAppVersion = ".*?";', "const currentAppVersion = `"$timestamp`";" | Set-Content $indexFile
}

# 3. Deploy to Firebase
echo "--- Step 3: Deploying to Firebase ---"
firebase deploy

echo "--- DEPLOYMENT COMPLETE ---"
echo "Landing Page: https://stayhubgh.com"
echo "Web App:      https://stayhubgh.com/app"

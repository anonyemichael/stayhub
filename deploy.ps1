# Robust Deploy Script for StayHub
# Ensures correct structure for Landing Page (root) and Flutter App (/app/)

# 1. Build Flutter App
echo "--- Step 1: Building Flutter Web App ---"
flutter build web --release --base-href "/app/"
if ($LASTEXITCODE -ne 0) { 
    echo "Flutter build failed!"
    exit $LASTEXITCODE 
}

# 2. Prepare Final Structure
echo "--- Step 2: Preparing Deployment Structure ---"

# We use build/web as the base for Firebase Hosting
# Move build/web to a temporary location first
$tempWeb = "build/temp_flutter_web"
$finalWeb = "build/web"
$landingPage = "landing_page"

if (Test-Path $tempWeb) { Remove-Item $tempWeb -Recurse -Force }

# Rename build/web (which contains Flutter build) to temp
Rename-Item $finalWeb "temp_flutter_web"

# Create a fresh build/web root
New-Item -ItemType Directory -Path $finalWeb -Force
New-Item -ItemType Directory -Path "$finalWeb/app" -Force

# Copy Landing Page files to root
echo "Copying Landing Page..."
Copy-Item "$landingPage/*" $finalWeb -Recurse -Force

# Copy Flutter build to /app/
echo "Moving Flutter build to /app/..."
Copy-Item "$tempWeb/*" "$finalWeb/app/" -Recurse -Force

# Cleanup temp
Remove-Item $tempWeb -Recurse -Force

# 3. Deploy to Firebase
echo "--- Step 3: Deploying to Firebase ---"
firebase.cmd deploy --only hosting

echo "--- DEPLOYMENT COMPLETE ---"

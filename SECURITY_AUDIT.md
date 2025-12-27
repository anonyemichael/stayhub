# Security Audit Report

## 1. Critical: Exposed Paystack Secret Key
**File:** `lib/services/payment_service.dart`
**Issue:** The Paystack **Secret Key** (`sk_test_...`) is hardcoded in the application code.
**Risk:** This key is visible to anyone who decompiles the app. Malicious actors could use this key to:
- Refund transactions.
- Verify fake transactions.
- Access transaction history.
**Recommendation:** 
- **Immediate:** Rotate (change) this key in your Paystack Dashboard immediately.
- **Fix:** Never use the Secret Key in the mobile app. The mobile app should only use the **Public Key**. Transaction verification should happen on a secure backend server (or Firebase Cloud Functions) using the Secret Key.

## 2. Hardcoded Admin Access
**File:** `lib/features/profile/settings_page.dart`
**Issue:** Admin privileges are granted based on a hardcoded email comparison:
```dart
if (user != null && user.email == "anonyemichael6@gmail.com") { ... }
```
**Risk:** If email verification is not strictly enforced **before** login, an attacker could potentially sign up with this email (if they catch the system at a time when the account doesn't exist or is deleted) and gain admin access.
**Recommendation:** 
- Use Firebase Custom Claims or a dedicated `admins` collection in Firestore to manage roles.
- Ensure `user.emailVerified` is checked before granting privileges.

## 3. Firestore Security Rules (Verification Required)
**Issue:** The application writes directly to sensitive collections like `users` and `hostels` from the client side.
**Risk:** Without proper Firestore Security Rules, any authenticated user could potentially:
- Overwrite other users' profiles (confusing `updateUserProfile` calls).
- Change booking statuses to "PAID" without paying.
**Recommendation:** Ensure your `firestore.rules` look something like this:
```
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    // Only Agents/Admins can write to hostels (requires Role check)
    match /hostels/{hostelId} {
      allow read: if true;
      allow write: if request.auth != null && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['agent', 'admin'];
    }
  }
}
```

## 4. Cloudinary Unsigned Uploads
**File:** `lib/services/cloudinary_service.dart`
**Issue:** Uses an upload preset `stayhub_preset` without backend signature.
**Risk:** Users might upload malicious content or exhaust your storage quota.
**Recommendation:** Configure the Upload Preset in Cloudinary Console to:
- Restrict file types (images/videos only).
- Limit file size.
- Enable moderation features if possible.

## 5. Android Manifest Settings
**File:** `android/app/src/main/AndroidManifest.xml`
**Issue:** `android:usesCleartextTraffic="true"` is enabled.
**Risk:** Allows unencrypted HTTP traffic, which can be intercepted.
**Recommendation:** Set to `false` for production builds unless you specifically need to communicate with non-HTTPS servers.
**Note:** Verify your Google Maps API Key (`AIza...`) in the Google Cloud Console. Ensure it is restricted to your Android Package Name (`com.example.stayhub` or equivalent) and SHA-1 fingerprint to prevent quota theft.

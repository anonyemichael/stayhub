class ApiConfig {
  // ✅ Switch to Firebase Functions (Serverless) for speed & scale
  static const String baseUrl = "https://us-central1-device-streaming-d7021871.cloudfunctions.net"; 
  // static const String baseUrl = "https://stayhub-vof1.onrender.com"; (Old Render) 
  
  // Endpoints
  static const String sendPasswordReset = "$baseUrl/sendPasswordResetLink";
  static const String initializePayment = "$baseUrl/initializePayment";
  static const String verifyPayment = "$baseUrl/verifyPayment";
  static const String getBanks = "$baseUrl/getBanks";
  static const String createSubAccount = "$baseUrl/createSubAccount";
  static const String sendOtp = "$baseUrl/sendOtp";
  static const String ping = "$baseUrl/ping";
}

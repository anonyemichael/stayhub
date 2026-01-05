import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:stayhub/core/api_config.dart';

class ResendService {
  // Use our centralized Render Backend
  static Future<bool> sendOtp(String toEmail, String otpCode) async {
    try {
      final url = Uri.parse(ApiConfig.sendOtp);
      debugPrint("Sending OTP via Backend: $url");

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': toEmail,
          'otp': otpCode,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('OTP sent successfully to $toEmail');
        return true;
      } else {
        debugPrint('Backend OTP Error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('OTP Exception: $e');
      return false;
    }
  }
}

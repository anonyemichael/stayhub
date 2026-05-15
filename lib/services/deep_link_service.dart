import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:stayhub/auth/new_password_page.dart';
import 'package:stayhub/features/bookings/payment_callback_page.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  void init(GlobalKey<NavigatorState> navigatorKey) {
    try {
      _initDeepLinks(navigatorKey);
    } catch (e) {
      debugPrint('DeepLinkService: Initialization failed: $e');
    }
  }

  Future<void> _initDeepLinks(GlobalKey<NavigatorState> navigatorKey) async {
    // 1. Handle Cold Start (Initial Link)
    // Note: Splash Screen usually handles this via getInitialLink, 
    // but we can also double check or let Splash handle it.
    // However, for clean architecture, we can listen to the stream which *updates* on hot start.
    
    // 2. Handle Hot Start (Stream)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('DeepLinkService: Received $uri');
      _handleDeepLink(uri, navigatorKey);
    }, onError: (err) {
      debugPrint('DeepLinkService: Error $err');
    });
  }

  void _handleDeepLink(Uri uri, GlobalKey<NavigatorState> navigatorKey) {
    try {
    if (uri.path.contains('reset-password') || uri.queryParameters.containsKey('oobCode')) {
      final code = uri.queryParameters['oobCode'];
      final email = uri.queryParameters['email']; // Optional
      
      if (code != null) {
        debugPrint('DeepLinkService: Navigating to NewPasswordPage');
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => NewPasswordPage(code: code, email: email),
          ),
        );
      }
    } else if (uri.path.contains('payment-callback') || 
               uri.toString().contains('success') ||
               uri.queryParameters.containsKey('trxref') ||
               uri.queryParameters.containsKey('reference')) {
      
      final reference = uri.queryParameters['reference'] ?? uri.queryParameters['trxref'];
      final bookingId = uri.queryParameters['bookingId'];
      final userId = uri.queryParameters['userId'];
      final amountStr = uri.queryParameters['amount'];
      final double? amount = amountStr != null ? double.tryParse(amountStr) : null;

      debugPrint('DeepLinkService: Navigating to PaymentCallbackPage with ref: $reference');
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => PaymentCallbackPage(
            reference: reference,
            bookingId: bookingId,
            userId: userId,
            amount: amount,
          ),
        ),
      );
    }
    } catch (e) {
      debugPrint('DeepLinkService: Error handling link $uri: $e');
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}

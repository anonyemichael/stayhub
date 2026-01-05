import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:stayhub/auth/new_password_page.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  void init(GlobalKey<NavigatorState> navigatorKey) {
    _initDeepLinks(navigatorKey);
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
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}

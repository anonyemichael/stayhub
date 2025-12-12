// test/mock_firebase.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// This is a standard way to mock Firebase services in tests.
typedef Callback = void Function(MethodCall call);

void setupFirebaseAuthMocks([Callback? customHandlers]) {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock the Firebase Core platform channel
  const MethodChannel channel = MethodChannel('plugins.flutter.io/firebase_core');

  channel.setMockMethodCallHandler((MethodCall methodCall) async {
    if (methodCall.method == 'Firebase#initializeCore') {
      return [
        {
          'name': '[DEFAULT]',
          'options': {
            'apiKey': '123',
            'appId': '1:123:android:123',
            'messagingSenderId': '123',
            'projectId': 'test-project',
          },
          'pluginConstants': {},
        }
      ];
    } else if (methodCall.method == 'Firebase#initializeApp') {
      return {
        'name': methodCall.arguments['appName'],
        'options': methodCall.arguments['options'],
        'pluginConstants': {},
      };
    }

    if (customHandlers != null) {
      customHandlers(methodCall);
    }

    return null;
  });
}

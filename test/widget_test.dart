import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:stayhub/main.dart';
import 'package:stayhub/core/splash_screen.dart';
import 'package:stayhub/auth/auth_page.dart';

import 'mock_firebase.dart';

void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('SplashScreen navigates to AuthPage after 5 seconds', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Verify that the SplashScreen is shown
    expect(find.byType(SplashScreen), findsOneWidget);

    // Fast-forward time by 5 seconds
    await tester.pump(const Duration(seconds: 5));

    // Re-render the widget tree
    await tester.pumpAndSettle();

    // Verify that the AuthPage is now shown
    expect(find.byType(AuthPage), findsOneWidget);
  });
}

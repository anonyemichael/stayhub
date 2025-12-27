import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:stayhub/core/splash_screen.dart';
import 'package:stayhub/firebase_options.dart';
import 'package:stayhub/providers/locale_provider.dart';
import 'package:stayhub/providers/theme_provider.dart';
import 'package:stayhub/services/notification_service.dart'; // Added import
import 'package:stayhub/services/payment_service.dart'; // Import PaymentService
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint("Global Error: ${details.exception}");
  };

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await dotenv.load(fileName: ".env");
     PaymentService().initialize(); // Initialize Paystack
  } catch (e) {
    debugPrint("Firebase/Env Initialization Error: $e");
    // Continue running, as some features might work offline
  }

  await NotificationService().init(); // Initialize NotificationService
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, themeProvider, localeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'StayHub',
            themeMode: themeProvider.themeMode,
            locale: localeProvider.locale,
            supportedLocales: L10n.all,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              brightness: Brightness.light,
              primaryColor: const Color(0xFF2E2AB7),
              scaffoldBackgroundColor: const Color(0xFFF0F2F5),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFFF0F2F5),
                foregroundColor: Colors.black87,
                elevation: 0,
              ),
              textTheme: GoogleFonts.poppinsTextTheme(ThemeData(brightness: Brightness.light).textTheme),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2E2AB7),
                brightness: Brightness.light,
              ),
              cardTheme: const CardThemeData(color: Colors.white),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              primaryColor: const Color(0xFF2E2AB7),
              scaffoldBackgroundColor: const Color(0xFF121212),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              textTheme: GoogleFonts.poppinsTextTheme(ThemeData(brightness: Brightness.dark).textTheme),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2E2AB7),
                brightness: Brightness.dark,
                surface: const Color(0xFF1c1c1e),
              ),
              cardTheme: const CardThemeData(color: Color(0xFF1c1c1e)),
            ),
            home: const SplashScreen(), // Always start with the SplashScreen
          );
        },
      ),
    );
  }
}

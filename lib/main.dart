import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:stayhub/core/splash_screen.dart';
import 'package:stayhub/firebase_options.dart';
import 'package:stayhub/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase Initialization Error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const AppContent(),
    );
  }
}

class AppContent extends StatelessWidget {
  const AppContent({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StayHub',
      
      // Theme Configuration
      themeMode: themeProvider.themeMode,
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
        cardTheme: const CardThemeData(color: const Color(0xFF1c1c1e)),
      ),

      home: const SplashScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:stayhub/core/auth_gate.dart';
import 'package:stayhub/firebase_options.dart';
import 'package:stayhub/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Variable to track initialization status
  String? initializationError;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    initializationError = e.toString();
    debugPrint("FATAL ERROR: Failed to initialize Firebase: $e");
  }

  // If initialization failed, run the ErrorApp
  if (initializationError != null) {
    runApp(ErrorApp(error: initializationError));
  } else {
    // Otherwise, run the main app
    runApp(const MyApp());
  }
}

/// A simple app to display fatal initialization errors.
class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.red.shade50,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 16),
                const Text(
                  "Initialization Failed",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 12),
                Text(
                  "Firebase could not be initialized.",
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    error,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'StayHub',
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
              cardTheme: const CardThemeData(
                color: Colors.white,
              ),
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
              cardTheme: const CardThemeData(
                color: Color(0xFF1c1c1e),
              ),
            ),
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

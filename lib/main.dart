import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:stayhub/core/splash_screen.dart';
import 'package:stayhub/firebase_options.dart';
import 'package:stayhub/providers/locale_provider.dart';
import 'package:stayhub/providers/theme_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stayhub/services/notification_service.dart';
import 'package:stayhub/services/payment_service.dart';
import 'package:stayhub/services/deep_link_service.dart';
import 'package:stayhub/services/connectivity_service.dart';
import 'package:stayhub/core/offline_banner.dart';
import 'package:audioplayers/audioplayers.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
    
    // Explicitly Enable Offline Persistence
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    PaymentService().initialize();
    ConnectivityService().initialize(); // Start monitoring network
  } catch (e) {
    debugPrint("Firebase/Env Initialization Error: $e");
  }

  // CONFIGURE AUDIO CONTEXT FOR SIMULTANEOUS PLAYBACK
  AudioPlayer.global.setAudioContext(AudioContext(
    android: AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none, 
    ),
  ));

  NotificationService().initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  
  @override
  void initState() {
    super.initState();
    DeepLinkService().init(navigatorKey);
  }

  @override
  void dispose() {
    DeepLinkService().dispose();
    super.dispose();
  }

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
            navigatorKey: navigatorKey,
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
            home: const SplashScreen(),
            builder: (context, child) {
              return Stack(
                children: [
                  child!,
                  const OfflineBanner(),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

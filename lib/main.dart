import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:stayhub/core/splash_screen.dart';
import 'package:stayhub/firebase_options.dart';
import 'package:stayhub/providers/locale_provider.dart';
import 'package:stayhub/providers/theme_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stayhub/services/notification_service.dart';
import 'package:stayhub/services/deep_link_service.dart';
import 'package:stayhub/services/connectivity_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui' show PointerDeviceKind;
import 'package:stayhub/features/bookings/payment_callback_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized for background processing
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Lock to portrait for stability (TikTok-style clips work best portrait)
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // System UI styling
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint("Global Flutter Error: ${details.exception}\n${details.stack}");
    };

    // Initialize Firebase (Required before runApp for some plugins)
    try {
      debugPrint("Main: Initializing Firebase...");
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("Main: Firebase initialized.");
    } catch (e) {
      debugPrint("Firebase Initialization Error: $e");
    }

    // Run the app as soon as core Firebase is ready
    runApp(const MyApp());
    debugPrint("Main: runApp called.");

    // Defer remaining initialization to avoid blocking the first frame
    Future.microtask(() async {
      try {
        // Register background messaging handler
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
        debugPrint("Main: Background Messaging Handler registered.");
        
        if (kIsWeb) {
          FirebaseFirestore.instance.settings = const Settings(
            persistenceEnabled: false, 
            cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
            webExperimentalForceLongPolling: true,
          );
        } else {
          FirebaseFirestore.instance.settings = const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
          );
        }
        debugPrint("Main: Firestore settings configured.");

        // Initialize services
        ConnectivityService().initialize();
        
        NotificationService().initialize().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint("NotificationService initialization timed out");
          },
        ).catchError((e) {
          debugPrint("NotificationService init error: $e");
        });

        // Audio Context
        if (!kIsWeb) {
          try {
            dynamic audioContext = AudioContext(
              android: const AudioContextAndroid(
                audioFocus: AndroidAudioFocus.none,
              ),
            );
            AudioPlayer.global.setAudioContext(audioContext);
            debugPrint("Main: Audio Context configured.");
          } catch (e) {
            debugPrint("Audio Context Error: $e");
          }
        }
      } catch (e) {
        debugPrint("Deferred Initialization Error: $e");
      }
    });
  }, (error, stack) {
    debugPrint("Unhandled Zone Error: $error\n$stack");
  });
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
            routes: {
              '/payment-callback': (context) => const PaymentCallbackPage(),
            },
            themeMode: themeProvider.themeMode,
            locale: localeProvider.locale,
            supportedLocales: L10n.all,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              primaryColor: const Color(0xFF2E2AB7),
              fontFamily: GoogleFonts.inter().fontFamily,
              textTheme: GoogleFonts.interTextTheme(),
              scaffoldBackgroundColor: const Color(0xFFF0F2F5),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFFF0F2F5),
                foregroundColor: Colors.black87,
                elevation: 0,
              ),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2E2AB7),
                brightness: Brightness.light,
              ),
              cardTheme: const CardThemeData(color: Colors.white),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              primaryColor: const Color(0xFF2E2AB7),
              fontFamily: GoogleFonts.inter().fontFamily,
              textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
              scaffoldBackgroundColor: const Color(0xFF121212),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2E2AB7),
                brightness: Brightness.dark,
                surface: const Color(0xFF1c1c1e),
              ),
              cardTheme: const CardThemeData(color: Color(0xFF1c1c1e)),
            ),
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.mouse,
                PointerDeviceKind.touch,
                PointerDeviceKind.stylus,
                PointerDeviceKind.unknown,
              },
              physics: const BouncingScrollPhysics(),
            ),
            home: const SplashScreen(),
            builder: (context, child) {
              return child!;
            },
          );
        },
      ),
    );
  }
}

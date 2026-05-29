import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_helper_stub.dart'
    if (dart.library.js) 'notification_helper_web.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  
  // --- WEB VAPID KEY ---
  // IMPORTANT: Replace this with your actual Public VAPID Key from 
  // Firebase Console -> Project Settings -> Cloud Messaging -> Web Configuration
  static const String _vapidKey = String.fromEnvironment('VAPID_KEY', defaultValue: "BKed5fDYOVTHmr8LUVqXqitNn188BLwocBBGcYJIi1dmsz6VNxQeqeume_uJAUny9Vz2nYkeNlyTqcf1FyqWSyE");

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Local Notifications Helper
  final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();

  // Firestore Listener for simulated push
  StreamSubscription<QuerySnapshot>? _notifSubscription;
  StreamSubscription<User?>? _authSubscription;

  Future<void> initialize() async {
    // 0. Initialize Local Notifications (Skip detailed config on web as it's limited)
    if (!kIsWeb) {
      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _localNotif.initialize(initializationSettings);
    }

    // 1. Request Permission
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
      
      // 2. Get Token (Initial)
      try {
        String? token;
        if (kIsWeb) {
          // Only use VAPID key if it's not the placeholder
          final isPlaceholder = _vapidKey.startsWith("BFG5") || _vapidKey.isEmpty;
          
          if (isPlaceholder) {
            debugPrint('FCM: Web VAPID key is placeholder. FCM will not work until a real key is provided.');
          }

          // Retry logic for Web Service Worker activation
          for (int i = 0; i < 3; i++) {
            try {
              if (isPlaceholder) {
                token = await _fcm.getToken();
              } else {
                token = await _fcm.getToken(vapidKey: _vapidKey);
              }
              if (token != null) break;
            } catch (err) {
              if (i == 2) {
                debugPrint('FCM: Final attempt to get token failed: $err');
                break; 
              }
              debugPrint('FCM: Service Worker may not be active yet, retrying in 3s... (Attempt ${i + 1}/3)');
              await Future.delayed(const Duration(seconds: 3));
            }
          }
        } else {
          token = await _fcm.getToken();
        }
        
        if (token != null) {
          debugPrint('FCM Token: $token');
          await saveToken(token);
        }
      } catch (e) {
        debugPrint('Error getting FCM token: $e');
      }

      // 3. Listen for token refresh
      _fcm.onTokenRefresh.listen(saveToken);
      
      // 4. Handle Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint("FCM: Received foreground message");
        if (message.notification != null) {
          if (kIsWeb) {
            // On web, we can't use local_notifications. showNotification will handle the fallback.
            showNotification(
              title: message.notification!.title ?? "StayHub",
              body: message.notification!.body ?? "",
            );
          } else {
            showNotification(
              title: message.notification!.title ?? "StayHub",
              body: message.notification!.body ?? "",
            );
          }
        }
      });

      // 4.1 Handle Background/Terminated state message click
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint("FCM: App opened from notification");
        // Navigation logic could go here if needed
      });

      // 5. Reactive Listener: Start/Stop based on Auth state
      _authSubscription = _auth.authStateChanges().listen((user) {
        if (user != null) {
          listenToFirestoreNotifications(user.uid);
          // Also refresh token on login
          _fcm.getToken().then((token) {
            if (token != null) saveToken(token);
          }).catchError((e) {
            debugPrint("FCM: Background token fetch failed: $e");
            return null;
          });
        } else {
          _notifSubscription?.cancel();
        }
      });
    } else {
      debugPrint('User declined or has not accepted permission');
    }
  }

  void listenToFirestoreNotifications(String uid) {
    _notifSubscription?.cancel();
    
    // Only listen for notifications added AFTER this moment to avoid spamming old ones on login
    final startTime = Timestamp.now();

    _notifSubscription = _db.collection('users').doc(uid).collection('notifications')
        .where('timestamp', isGreaterThan: startTime)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final isRead = data['isRead'] ?? false;
          
          if (!isRead) {
            showNotification(
              title: data['title'] ?? "New Update",
              body: data['body'] ?? "You have a new message.",
            );
          }
        }
      }
    });
  }

  void dispose() {
    _notifSubscription?.cancel();
    _authSubscription?.cancel();
  }

  Future<void> showNotification({required String title, required String body}) async {
    if (kIsWeb) {
      // Use browser's native Notification API
      debugPrint("Showing Web Notification: $title - $body");
      
      // Import html library conditionally or use a JS interop helper
      // For now, we'll use a basic JS call if available, otherwise fallback to snackbar
      try {
        _showWebNotification(title, body);
      } catch (e) {
        debugPrint("Web Notification failed: $e");
      }
    } else {
      const androidDetails = AndroidNotificationDetails(
        'stayhub_urgent', 
        'Urgent Alerts', 
        channelDescription: 'Used for booking approvals and payments',
        importance: Importance.max, 
        priority: Priority.high,
        ticker: 'ticker',
        showWhen: true,
        enableVibration: true,
        playSound: true,
        fullScreenIntent: true, // Makes it more likely to show heads-up
        category: AndroidNotificationCategory.message,
      );
      
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true, 
          presentSound: true, 
          presentBadge: true,
        ),
      );
      
      await _localNotif.show(
        DateTime.now().millisecond, 
        title, 
        body, 
        details
      );
    }
  }

  Future<void> saveToken(String token) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _db.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final agentDoc = await _db.collection('agents').doc(user.uid).get();
      if (agentDoc.exists) {
        await _db.collection('agents').doc(user.uid).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }

  Stream<int> getUnreadNotificationCount(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // JS Interop / Native Notification Helper for Web
  void _showWebNotification(String title, String body) {
    if (kIsWeb) {
      showWebNotification(title, body);
    }
  }
}

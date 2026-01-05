import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Local Notifications Helper
  final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // 0. Initialize Local Notifications
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotif.initialize(initializationSettings);

    // 1. Request Permission
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
      
      // 2. Get Token
      try {
        String? token = await _fcm.getToken();
        if (token != null) {
          await saveToken(token);
        }
      } catch (e) {
        debugPrint('Error getting FCM token: $e');
      }

      // 3. Listen for token refresh
      _fcm.onTokenRefresh.listen(saveToken);
      
      // 4. Handle Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint("Received a foreground message: ${message.notification?.title}");
        if (message.notification != null) {
          showNotification(
            title: message.notification!.title ?? "StayHub",
            body: message.notification!.body ?? "",
          );
        }
      });
    } else {
      debugPrint('User declined or has not accepted permission');
    }
  }

  Future<void> showNotification({required String title, required String body}) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails('stayhub_main', 'Main Notifications', importance: Importance.max, priority: Priority.high),
      iOS: DarwinNotificationDetails(),
    );
    await _localNotif.show(DateTime.now().millisecond, title, body, details);
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
}

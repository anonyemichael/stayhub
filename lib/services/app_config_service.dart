import 'package:cloud_firestore/cloud_firestore.dart';

class AppConfigService {
  final CollectionReference _configCollection = FirebaseFirestore.instance.collection('app_settings');

  // Singleton
  static final AppConfigService _instance = AppConfigService._internal();
  factory AppConfigService() => _instance;
  AppConfigService._internal();

  // Stream of config data
  Stream<DocumentSnapshot> getConfigStream() {
    return _configCollection.doc('general').snapshots();
  }

  // Fetch once
  Future<Map<String, dynamic>> getConfig() async {
    final doc = await _configCollection.doc('general').get();
    return doc.data() as Map<String, dynamic>? ?? {};
  }

  // Update Config (Admin only)
  Future<void> updateConfig(Map<String, dynamic> data) async {
    await _configCollection.doc('general').set(data, SetOptions(merge: true));
  }
}

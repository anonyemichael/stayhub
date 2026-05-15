import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocalCacheService {
  static const String KEY_FEATURED_HOSTELS = 'cached_featured_hostels';
  static const String KEY_CATEGORIES = 'cached_categories';
  static const String KEY_USER_PROFILE = 'cached_user_profile';
  static const String KEY_TRENDING_HOSTELS = 'cached_trending_hostels';

  static Future<void> save(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    if (data == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, jsonEncode(data, toEncodable: (Object? value) {
        if (value is Timestamp) {
          return value.toDate().toIso8601String();
        }
        return value;
      }));
    }
  }

  static Future<dynamic> load(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(key);
    if (jsonString == null) return null;
    try {
      return jsonDecode(jsonString);
    } catch (e) {
      return null;
    }
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

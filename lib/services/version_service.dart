import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:stayhub/core/html_stub.dart' if (dart.library.html) 'dart:html' as html;

class VersionService {
  static final VersionService _instance = VersionService._internal();
  factory VersionService() => _instance;
  VersionService._internal();

  // This should match the version in pubspec.yaml
  // We'll automate this comparison by checking a version.json on the server
  Future<void> checkForUpdates(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = packageInfo.buildNumber;

      if (!kIsWeb) return; 

      // Fetch version.json from the root of your web deployment
      final baseUrl = Uri.base.path.contains('/app') ? '${Uri.base.origin}/app' : Uri.base.origin;
      final response = await http.get(Uri.parse('$baseUrl/version.json')).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['version'];
        final latestBuild = data['build_number'];

        if (_isNewer(currentVersion, currentBuildNumber, latestVersion, latestBuild)) {
          _showUpdateBanner(context);
        }
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
    }
  }

  bool _isNewer(String currentV, String currentB, String latestV, String latestB) {
    // Basic comparison logic
    if (latestV != currentV) return true;
    
    int curB = int.tryParse(currentB) ?? 0;
    int latB = int.tryParse(latestB) ?? 0;
    return latB > curB;
  }

  void _showUpdateBanner(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          "🚀 A new version of StayHub is available!",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        duration: const Duration(days: 1), // Stay until dismissed
        action: SnackBarAction(
          label: "UPDATE NOW",
          textColor: Colors.cyanAccent,
          onPressed: () {
          if (kIsWeb) {
            // Just reload, don't clear localStorage as it conflicts with index.html bootstrap
            html.window.location.reload();
          } else {
            // Redirect to store or refresh
            html.window.location.reload();
          }
        },
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}

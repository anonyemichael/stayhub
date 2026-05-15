import 'package:flutter/foundation.dart';

class ImageUtils {
  /// Converts a URL to a CORS-safe URL for Web, or ensures HTTPS for native.
  static String getSecureUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    
    String secureUrl = url;
    if (url.startsWith('http://')) {
      secureUrl = url.replaceFirst('http://', 'https://');
    }

    if (kIsWeb) {
      // Use images.weserv.nl as a CORS proxy for the web.
      // This is essential to prevent "Broken Image" icons due to CORS headers.
      // We pass the full URL and let the proxy handle it.
      final encodedUrl = Uri.encodeComponent(secureUrl);
      
      // If it's a small icon/logo, we don't want fit=cover
      final isLogo = secureUrl.contains('logo') || 
                     secureUrl.contains('badge') || 
                     secureUrl.contains('icon') ||
                     secureUrl.contains('edu.gh') ||
                     secureUrl.contains('Artboard') ||
                     secureUrl.contains('uenr');

      if (isLogo) {
        return "https://images.weserv.nl/?url=$encodedUrl&w=200&fit=contain";
      }
      
      return "https://images.weserv.nl/?url=$encodedUrl&w=1200&fit=cover";
    }

    return secureUrl;
  }
}

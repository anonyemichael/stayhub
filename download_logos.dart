import 'dart:io';

void main() async {
  final Map<String, String> logos = {
    'knust.png': 'https://www.freelogovectors.net/wp-content/uploads/2022/03/knust_logo_freelogovectors.net_.png',
    'ug.png': 'https://upload.wikimedia.org/wikipedia/commons/6/64/University_of_Ghana.png',
    'uenr.png': 'https://uenr.edu.gh/wp-content/uploads/2022/08/UENR-LOGO-spline-Converted-1.png',
  };

  final client = HttpClient();

  for (final entry in logos.entries) {
    try {
      final req = await client.getUrl(Uri.parse(entry.value));
      final res = await req.close();
      if (res.statusCode == 200) {
        // Save to assets/logo (singular) to match pubspec.yaml
        final file = File('assets/logo/${entry.key}');
        await file.create(recursive: true);
        await res.pipe(file.openWrite());
        print('Downloaded: ${entry.key}');
      } else {
        print('Failed ${entry.key}: Status ${res.statusCode}');
      }
    } catch (e) {
      print('Error ${entry.key}: $e');
    }
  }
}

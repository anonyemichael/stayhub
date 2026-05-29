import 'package:stayhub/core/image_utils.dart';

class SchoolUtils {
  /// The absolute source of truth for school logos.
  /// This map contains official, high-resolution logos for all supported schools.
  static final Map<String, String> _officialLogos = {
    'KNUST': 'https://www.freelogovectors.net/wp-content/uploads/2022/03/knust_logo_freelogovectors.net_.png',
    'KWAME NKRUMAH UNIVERSITY OF SCIENCE AND TECHNOLOGY': 'https://www.freelogovectors.net/wp-content/uploads/2022/03/knust_logo_freelogovectors.net_.png',
    
    'UNIVERSITY OF GHANA': 'https://upload.wikimedia.org/wikipedia/commons/6/64/University_of_Ghana.png',
    'UG': 'https://upload.wikimedia.org/wikipedia/commons/6/64/University_of_Ghana.png',
    'LEGON': 'https://upload.wikimedia.org/wikipedia/commons/6/64/University_of_Ghana.png',
    
    'UENR': 'https://uenr.edu.gh/wp-content/uploads/2022/08/UENR-LOGO-spline-Converted-1.png',
    'UNIVERSITY OF ENERGY AND NATURAL RESOURCES': 'https://uenr.edu.gh/wp-content/uploads/2022/08/UENR-LOGO-spline-Converted-1.png',
    
    'CUG': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSKhcD7Wig1Ulyj7Zdt-SUZjsVgSbywpKvqTQ&s',
    'CATHOLIC UNIVERSITY OF GHANA': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSKhcD7Wig1Ulyj7Zdt-SUZjsVgSbywpKvqTQ&s',
    
    'UDS': 'https://weadapt.org/wp-content/uploads/2023/05/university_of_development_studies-ghana_logo.jpg',
    'UNIVERSITY FOR DEVELOPMENT STUDIES': 'https://weadapt.org/wp-content/uploads/2023/05/university_of_development_studies-ghana_logo.jpg',
    
    'UCC': 'https://ucc.edu.gh/themes/custom/adepts/images/ucc-logo.png',
    'UNIVERSITY OF CAPE COAST': 'https://ucc.edu.gh/themes/custom/adepts/images/ucc-logo.png',
    
    'UPSA': 'https://upsa.edu.gh/wp-content/uploads/2020/12/UPSA-Logo-New.png',
    'UNIVERSITY OF PROFESSIONAL STUDIES': 'https://upsa.edu.gh/wp-content/uploads/2020/12/UPSA-Logo-New.png',
    
    'GCTU': 'https://gctu.edu.gh/wp-content/uploads/2021/04/GCTU-LOGO.png',
    'GHANA COMMUNICATION TECHNOLOGY UNIVERSITY': 'https://gctu.edu.gh/wp-content/uploads/2021/04/GCTU-LOGO.png',
  };

  /// Local asset mappings for offline/fast loading.
  static final Map<String, String> _assetLogos = {
    'KNUST': 'assets/logo/knust.png',
    'UG': 'assets/logo/ug.png',
    'UENR': 'assets/logo/uenr.png',
  };

  /// Centrally managed school logo retrieval logic.
  /// Priority: 1. Passed URL, 2. Official Network URL, 3. Local Asset.
  static String? getSchoolLogo(String schoolName, Map<String, String> fetchedLogos) {
    final name = schoolName.toUpperCase().trim();
    
    // 1. Check if a specific URL was passed from Firestore (dynamic override)
    String? logo = fetchedLogos[name];

    // 2. Check the Official Hardcoded Map (Source of Truth)
    if (logo == null || logo.isEmpty) {
      logo = _officialLogos[name];
      
      // Fuzzy match for official logos
      if (logo == null) {
        for (var entry in _officialLogos.entries) {
          if (name.contains(entry.key) || entry.key.contains(name)) {
            logo = entry.value;
            break;
          }
        }
      }
    }

    // 3. Fallback to Local Assets if no network URL found
    if (logo == null || logo.isEmpty) {
      logo = _assetLogos[name];
      if (logo == null) {
        for (var entry in _assetLogos.entries) {
          if (name.contains(entry.key) || entry.key.contains(name)) {
            logo = entry.value;
            break;
          }
        }
      }
    }

    if (logo != null && logo.isNotEmpty) {
      return ImageUtils.getSecureUrl(logo);
    }

    return null;
  }
}

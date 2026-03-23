import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../lib/firebase_options.dart';

// SCRIPT TO SEED SCHOOLS INTO FIRESTORE CONFIG
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final db = FirebaseFirestore.instance;
  
  final schools = [
    {'name': 'UENR', 'lat': 7.3456, 'lng': -2.3451},
    {'name': 'CUG', 'lat': 7.3300, 'lng': -2.3280},
    {'name': 'KNUST', 'lat': 6.6745, 'lng': -1.5716},
    {'name': 'UDS', 'lat': 9.4034, 'lng': -0.8424},
    {'name': 'UCC', 'lat': 5.1036, 'lng': -1.2825},
    {'name': 'LEGON', 'lat': 5.6508, 'lng': -0.1870},
  ];

  print("🚀 Seeding dynamic school configuration...");
  
  try {
    await db.collection('config').doc('app_config').set({
      'available_schools': schools.map((s) => s['name']).toList(),
      'school_coordinates': {
        for (var s in schools) s['name'] as String: {
          'lat': s['lat'],
          'lng': s['lng']
        }
      }
    }, SetOptions(merge: true));
    
    print("✅ Seeded ${schools.length} schools successfully!");
  } catch (e) {
    print("❌ Error seeding schools: $e");
  }
}

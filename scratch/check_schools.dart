import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../lib/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final snapshot = await FirebaseFirestore.instance.collection('schools').get();
  print('--- SCHOOLS IN DATABASE ---');
  for (var doc in snapshot.docs) {
    final data = doc.data();
    print('ID: ${doc.id}');
    print('Name: ${data['name']}');
    print('Logo URL: ${data['logo_url']}');
    print('---');
  }
}

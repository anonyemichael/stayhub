import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final snapshot = await FirebaseFirestore.instance.collection('chats').limit(1).get();
  if (snapshot.docs.isNotEmpty) {
    print("Chat Document Data: ${snapshot.docs.first.data()}");
  } else {
    print("No chats found.");
  }
}

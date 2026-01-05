import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService {
  // Singleton pattern
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();

  Stream<bool> get connectionStatus => _connectionStatusController.stream;

  void initialize() {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
       _checkStatus(results);
    });
    // Initial check
    _connectivity.checkConnectivity().then((results) => _checkStatus(results));
  }

  void _checkStatus(List<ConnectivityResult> results) {
      // Check if ANY result in the list is NOT none
      bool isConnected = results.any((result) => result != ConnectivityResult.none);
      _connectionStatusController.add(isConnected);
      debugPrint("Connectivity Status Changed: ${isConnected ? 'Online' : 'Offline'}");
  }

  void dispose() {
    _connectionStatusController.close();
  }
}

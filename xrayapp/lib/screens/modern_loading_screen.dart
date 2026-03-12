import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart'; // <--- 1. Import the translator

class ModernLoadingScreen extends StatefulWidget {
  const ModernLoadingScreen({super.key});

  @override
  State<ModernLoadingScreen> createState() => _ModernLoadingScreenState();
}

class _ModernLoadingScreenState extends State<ModernLoadingScreen> {
  // ---> 2. USE KEYS INSTEAD OF HARDCODED TEXT <---
  final List<String> _loadingKeys = [
    "ui_loading_step_1",
  ];

  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Cycle the text every 2.2 seconds
    _timer = Timer.periodic(const Duration(milliseconds: 0), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _loadingKeys.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Clean up the timer when the screen is dismissed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // The Animation
          Lottie.asset(
            'assets/scanner2.json',
            width: 220,
            height: 220,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 32),
          // The Dynamic Text
          Text(
            _loadingKeys[_currentIndex].tr(), // <--- 3. TRANSLATE AT BUILD TIME
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

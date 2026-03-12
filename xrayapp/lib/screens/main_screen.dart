import 'package:flutter/material.dart';
import 'analyze_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Forces the clean, flat look
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset(
          'assets/logo.png',
          height: 64,
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        // Optional: Adds that classic X/IG hairline border under the top app bar too!
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.shade200, height: 1.0),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          AnalyzeScreen(),
          HistoryScreen(),
          SettingsScreen(),
        ],
      ),

      // ---> THE INSTAGRAM / X STYLE NAV BAR <---
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Colors.grey.shade200, // Crisp, subtle top line
              width: 1.0,
            ),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 55, // Compact, standard social media height
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Pass the Outline Icon, the Solid Icon, and the Index
                _buildNavItem(Icons.analytics_outlined, Icons.analytics, 0),
                _buildNavItem(Icons.history_outlined, Icons.history, 1),
                _buildNavItem(Icons.settings_outlined, Icons.settings, 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- ULTRA MINIMALIST ICON BUILDER ---
  Widget _buildNavItem(IconData outlineIcon, IconData solidIcon, int index) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Icon(
            isSelected ? solidIcon : outlineIcon, // Swaps to filled on tap
            // Uses your brand purple for active, standard dark grey for inactive
            color: isSelected ? Color.fromARGB(255, 0, 0, 0) : Colors.black54,
            size: 25.5, // Larger icons to compensate for having no text labels
          ),
        ),
      ),
    );
  }
}

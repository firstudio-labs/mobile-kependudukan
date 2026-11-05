import 'package:flutter/material.dart';
import 'package:ladimas/core/theme/app_theme.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavigationBarItem> items;
  final bool showLabels;

  const AppBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.showLabels = false,
  }) : super(key: key);

  static BottomNavigationBarItem item({
    required IconData icon,
    String label = '',
    double iconSize = 24,
  }) {
    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Icon(
          icon,
          size: iconSize,
          color: const Color(0xFF94A3B8),
        ),
      ),
      activeIcon: Container(
        margin: const EdgeInsets.symmetric(vertical: 2.0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: AppTheme.primaryColor,
        ),
      ),
      label: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: BottomNavigationBar(
            elevation: 0,
            backgroundColor: Colors.white,
            currentIndex: currentIndex,
            type: BottomNavigationBarType.fixed,
            showSelectedLabels: showLabels,
            showUnselectedLabels: showLabels,
            selectedItemColor: AppTheme.primaryColor,
            unselectedItemColor: const Color(0xFF94A3B8),
            selectedFontSize: showLabels ? 12 : 0,
            unselectedFontSize: showLabels ? 12 : 0,
            items: items,
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

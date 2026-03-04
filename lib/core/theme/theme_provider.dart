import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the user's chosen primary theme color, persisted via SharedPreferences.
class ThemeColorNotifier extends Notifier<Color> {
  static const _key = 'theme_primary_color';

  @override
  Color build() {
    _loadSaved();
    return const Color(0xFFF97316); // default orange
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_key);
    if (saved != null) {
      state = Color(saved);
    }
  }

  Future<void> setColor(Color color) async {
    state = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, color.value);
  }
}

final themeColorProvider = NotifierProvider<ThemeColorNotifier, Color>(
  ThemeColorNotifier.new,
);

/// Available theme accent colors
const List<Color> themeColorOptions = [
  Color(0xFF6C63FF), // Purple (default)
  Color(0xFF3B82F6), // Blue
  Color(0xFF14B8A6), // Teal
  Color(0xFF4ADE80), // Green
  Color(0xFFF97316), // Orange
  Color(0xFFEF4444), // Red
  Color(0xFFEC4899), // Pink
  Color(0xFFFBBF24), // Yellow
  Color(0xFF8B5CF6), // Violet
  Color(0xFF00E5FF), // Cyan
];

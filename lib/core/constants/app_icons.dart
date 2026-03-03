import 'package:flutter/material.dart';

/// Maps of icon data for habit icon picker
class AppIcons {
  static const Map<String, IconData> habitIcons = {
    'fitness': Icons.fitness_center,
    'water': Icons.water_drop,
    'book': Icons.menu_book,
    'code': Icons.code,
    'meditation': Icons.self_improvement,
    'run': Icons.directions_run,
    'sleep': Icons.bedtime,
    'food': Icons.restaurant,
    'music': Icons.music_note,
    'study': Icons.school,
    'walk': Icons.directions_walk,
    'bike': Icons.directions_bike,
    'swim': Icons.pool,
    'heart': Icons.favorite,
    'star': Icons.star,
    'coffee': Icons.coffee,
    'smoke': Icons.smoke_free,
    'phone': Icons.phone_android,
    'money': Icons.savings,
    'brush': Icons.brush,
    'camera': Icons.camera_alt,
    'pill': Icons.medication,
    'language': Icons.language,
    'clean': Icons.cleaning_services,
    'plant': Icons.eco,
    'write': Icons.edit_note,
    'pray': Icons.mosque,
    'yoga': Icons.spa,
    'game': Icons.sports_esports,
    'no_alcohol': Icons.no_drinks,
  };

  static IconData getIcon(String name) {
    return habitIcons[name] ?? Icons.check_circle;
  }

  static String getDefaultIconName() => 'star';
}

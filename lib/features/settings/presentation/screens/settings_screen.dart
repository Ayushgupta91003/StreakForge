import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streak_forge/core/theme/app_theme.dart';
import 'package:streak_forge/core/theme/theme_provider.dart';
import 'package:streak_forge/features/habits/presentation/providers/habit_providers.dart';
import 'package:streak_forge/features/reminders/presentation/screens/manage_all_reminders_screen.dart';
import 'package:streak_forge/services/backup_service.dart';
import 'package:streak_forge/services/notification_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentColor = ref.watch(themeColorProvider);

    return Scaffold(
      body: CustomScrollView(
      slivers: [
        const SliverAppBar(
          floating: true,
          title: Text(
            'Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Appearance ───
                const _SectionHeader(title: 'APPEARANCE'),
                const SizedBox(height: 8),
                _ThemeColorPicker(
                  currentColor: currentColor,
                  onColorSelected: (color) {
                    ref.read(themeColorProvider.notifier).setColor(color);
                  },
                ),
                const SizedBox(height: 20),

                // ─── Reminders ───
                const _SectionHeader(title: 'REMINDERS'),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.notifications_active_rounded,
                  iconColor: AppColors.accent,
                  title: 'Manage Reminders',
                  subtitle: 'View and control all habit reminders',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageAllRemindersScreen(),
                      ),
                    );
                  },
                ),
                _SettingsTile(
                  icon: Icons.notifications_none_rounded,
                  iconColor: AppColors.warning,
                  title: 'Test Notification',
                  subtitle: 'Send a test notification now',
                  onTap: () async {
                    await NotificationService().showTestNotification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Test notification sent!')),
                      );
                    }
                  },
                ),
                _NotificationSoundTile(),
                const SizedBox(height: 20),

                // ─── Data ───
                const _SectionHeader(title: 'DATA'),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.file_download_rounded,
                  iconColor: AppColors.info,
                  title: 'Export as CSV',
                  subtitle: 'Share your habit data as spreadsheet',
                  onTap: () => _exportCsv(context, ref),
                ),
                _SettingsTile(
                  icon: Icons.backup_rounded,
                  iconColor: AppColors.success,
                  title: 'Backup Data',
                  subtitle: 'Create a full JSON backup',
                  onTap: () => _backupData(context, ref),
                ),
                _SettingsTile(
                  icon: Icons.restore_rounded,
                  iconColor: AppColors.warning,
                  title: 'Restore Data',
                  subtitle: 'Restore from a JSON backup file',
                  onTap: () => _restoreData(context, ref),
                ),
                const SizedBox(height: 20),

                // ─── About ───
                const _SectionHeader(title: 'ABOUT'),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: currentColor,
                  title: 'StreakForge',
                  subtitle: 'Version 1.0.0',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.code_rounded,
                  iconColor: AppColors.accent,
                  title: 'Source Code',
                  subtitle: 'github.com/Ayushgupta91003/StreakForge',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.favorite_rounded,
                  iconColor: AppColors.error,
                  title: 'Made with ❤️',
                  subtitle: 'Built with Flutter & Isar',
                  onTap: () {},
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    try {
      final isar = ref.read(isarProvider).value;
      if (isar == null) return;
      final backup = BackupService(isar);
      await backup.shareCsv();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _backupData(BuildContext context, WidgetRef ref) async {
    try {
      final isar = ref.read(isarProvider).value;
      if (isar == null) return;
      final backup = BackupService(isar);
      await backup.shareBackup();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    }
  }

  Future<void> _restoreData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore from Backup?'),
        content: const Text(
          'This will add data from the backup file. Existing data will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();

      final isar = ref.read(isarProvider).value;
      if (isar == null) return;

      final backup = BackupService(isar);
      final count = await backup.restoreFromJson(jsonString);

      ref.invalidate(habitListProvider);
      ref.invalidate(todayRecordsProvider);
      ref.invalidate(categoryListProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restored $count records successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    }
  }
}

// ─── Theme Color Picker ──────────────────────────────────────────────────────

class _ThemeColorPicker extends StatelessWidget {
  final Color currentColor;
  final ValueChanged<Color> onColorSelected;

  const _ThemeColorPicker({
    required this.currentColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.surfaceVariant.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: currentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.palette_rounded,
                  color: currentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Accent Color',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Tap to change the primary color',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: themeColorOptions.map((color) {
              final isSelected = color.value == currentColor.value;
              return GestureDetector(
                onTap: () => onColorSelected(color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2.5)
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: color.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 1)
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
        letterSpacing: 1.5,
      ),
    );
  }
}

// ─── Settings Tile ───────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.surfaceVariant.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textTertiary,
          size: 20,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),
    );
  }
}

// ─── Notification Sound Picker ───────────────────────────────────────────────

class _NotificationSoundTile extends StatefulWidget {
  @override
  State<_NotificationSoundTile> createState() => _NotificationSoundTileState();
}

class _NotificationSoundTileState extends State<_NotificationSoundTile> {
  String _currentSound = 'default';

  static const Map<String, String> _soundOptions = {
    'default': 'Default',
    'silent': 'Silent',
  };

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentSound = prefs.getString('notification_sound') ?? 'default';
    });
  }

  Future<void> _savePreference(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notification_sound', value);
    NotificationService().setSoundPreference(value);
    setState(() => _currentSound = value);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.surfaceVariant.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: ListTile(
        onTap: () => _showSoundPicker(context),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.info.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.volume_up_rounded,
              color: AppColors.info, size: 20),
        ),
        title: const Text(
          'Notification Sound',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          _soundOptions[_currentSound] ?? 'Default',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textTertiary,
          size: 20,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),
    ),
    );
  }

  void _showSoundPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Notification Sound',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ..._soundOptions.entries.map((entry) {
              final isSelected = entry.key == _currentSound;
              return ListTile(
                leading: Icon(
                  entry.key == 'silent'
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : AppColors.textTertiary,
                ),
                title: Text(
                  entry.value,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : AppColors.textPrimary,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle_rounded,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  _savePreference(entry.key);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}


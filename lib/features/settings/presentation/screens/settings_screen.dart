import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:streak_forge/core/theme/app_theme.dart';
import 'package:streak_forge/features/habits/presentation/providers/habit_providers.dart';
import 'package:streak_forge/services/backup_service.dart';
import 'package:streak_forge/services/notification_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: const Text(
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
                // ─── Data Section ───
                _SectionHeader(title: 'Data'),
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

                const SizedBox(height: 24),

                // ─── Notifications Section ───
                _SectionHeader(title: 'Notifications'),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.notifications_off_rounded,
                  iconColor: AppColors.error,
                  title: 'Cancel All Reminders',
                  subtitle: 'Remove all scheduled notifications',
                  onTap: () => _cancelAllReminders(context),
                ),

                const SizedBox(height: 24),

                // ─── About Section ───
                _SectionHeader(title: 'About'),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: AppColors.primary,
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

      // Refresh all data
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

  Future<void> _cancelAllReminders(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel All Reminders?'),
        content: const Text(
          'This will cancel all scheduled notification reminders.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove All',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await NotificationService().cancelAll();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All reminders cancelled'),
        ),
      );
    }
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
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
        letterSpacing: 1.2,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),
    );
  }
}

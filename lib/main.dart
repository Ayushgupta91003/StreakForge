import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streak_forge/core/theme/app_theme.dart';
import 'package:streak_forge/core/theme/theme_provider.dart';
import 'package:streak_forge/features/habits/presentation/providers/habit_providers.dart';
import 'package:streak_forge/features/habits/presentation/screens/home_screen.dart';
import 'package:streak_forge/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Lock portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize notifications
  await NotificationService().initialize();

  runApp(const ProviderScope(child: StreakForgeApp()));
}

class StreakForgeApp extends ConsumerWidget {
  const StreakForgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbAsync = ref.watch(isarProvider);
    final primaryColor = ref.watch(themeColorProvider);

    return MaterialApp(
      title: 'StreakForge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(primaryColor: primaryColor),
      home: dbAsync.when(
        loading: () => _SplashScreen(primaryColor: primaryColor),
        error: (e, _) => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_rounded,
                    color: AppColors.error, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Failed to initialize database',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        data: (_) => const HomeScreen(),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  final Color primaryColor;

  const _SplashScreen({required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo with animated glow
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.5 + value * 0.5,
                  child: Opacity(
                    opacity: value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryColor,
                            HSLColor.fromColor(primaryColor)
                                .withLightness(0.35)
                                .toColor(),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3 * value),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_fire_department_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: const Text(
                'StreakForge',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Forge your daily streaks',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(primaryColor),
              ), 
            ),
          ],
        ),
      ),
    );
  }
}

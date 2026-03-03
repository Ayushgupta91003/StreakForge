import 'package:flutter/material.dart';
import 'package:streak_forge/core/theme/app_theme.dart';

/// Animated fire streak badge that pulses when the streak is active
class StreakBadge extends StatefulWidget {
  final int streak;
  final Color color;
  final double size;

  const StreakBadge({
    super.key,
    required this.streak,
    this.color = AppColors.warning,
    this.size = 48,
  });

  @override
  State<StreakBadge> createState() => _StreakBadgeState();
}

class _StreakBadgeState extends State<StreakBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.2, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.streak > 0) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(StreakBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.streak > 0 && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (widget.streak == 0 && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.streak == 0) {
      return _buildStatic();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(_glowAnimation.value),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: _buildContent(),
          ),
        );
      },
    );
  }

  Widget _buildStatic() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.local_fire_department_rounded,
          color: widget.streak > 0 ? widget.color : AppColors.textTertiary,
          size: widget.size * 0.7,
        ),
        Positioned(
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.streak > 0
                    ? widget.color
                    : AppColors.textTertiary,
                width: 1.5,
              ),
            ),
            child: Text(
              '${widget.streak}',
              style: TextStyle(
                fontSize: widget.size * 0.22,
                fontWeight: FontWeight.w800,
                color: widget.streak > 0
                    ? widget.color
                    : AppColors.textTertiary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Celebration overlay that shows when completing a habit
class CompletionCelebration extends StatefulWidget {
  final Color color;
  final VoidCallback onComplete;

  const CompletionCelebration({
    super.key,
    required this.color,
    required this.onComplete,
  });

  @override
  State<CompletionCelebration> createState() => _CompletionCelebrationState();
}

class _CompletionCelebrationState extends State<CompletionCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: (1 - _controller.value).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 1 + _controller.value * 2,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withOpacity(0.3),
              ),
              child: Icon(
                Icons.check_rounded,
                color: widget.color,
                size: 28,
              ),
            ),
          ),
        );
      },
    );
  }
}

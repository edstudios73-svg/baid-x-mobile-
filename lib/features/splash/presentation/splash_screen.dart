import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';

/// Becomes true after the opening moment, so routing can leave the splash.
final splashReleasedProvider = NotifierProvider<SplashRelease, bool>(SplashRelease.new);

class SplashRelease extends Notifier<bool> {
  @override
  bool build() => false;

  void release() {
    if (!state) state = true;
  }
}

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  static const _hold = Duration(milliseconds: 4600);

  late final AnimationController _motion;
  Timer? _releaseTimer;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this, duration: const Duration(milliseconds: 4800))..forward();
    _releaseTimer = Timer(_hold, () {
      if (mounted) ref.read(splashReleasedProvider.notifier).release();
    });
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(
      parent: _motion,
      curve: const Interval(0.10, 0.27, curve: Curves.easeOut),
    );
    final settle = Tween<double>(begin: 0.94, end: 1).animate(
      CurvedAnimation(parent: _motion, curve: const Interval(0.10, 0.28, curve: Curves.easeOutCubic)),
    );
    final breathe = Tween<double>(begin: 1, end: 1.025).animate(
      CurvedAnimation(parent: _motion, curve: const Interval(0.32, 0.72, curve: Curves.easeInOut)),
    );
    final leave = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _motion, curve: const Interval(0.82, 1, curve: Curves.easeIn)),
    );

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Center(
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, child) {
            final scale = settle.value * breathe.value;
            final opacity = (fade.value * leave.value).clamp(0.0, 1.0);
            return Opacity(
              opacity: opacity.clamp(0, 1),
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: Image.asset(
            'assets/images/logo/baid_x_logo.png',
            width: 200,
            height: 112,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/app_lock.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart';
import 'lock_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  late final Animation<double> _logoScale = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
  );
  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
  );
  late final Animation<double> _textFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
  );
  late final Animation<double> _glow = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _controller.addStatusListener((status) async {
      if (status == AnimationStatus.completed && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (!mounted) {
          return;
        }
        Navigator.of(context).pushReplacement(
          PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (routeContext, __, ___) => AppLock.isEnabled
                ? LockScreen(
                    onUnlocked: () => Navigator.of(routeContext).pushReplacement(
                      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
                    ),
                  )
                : const HomeScreen(),
            transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.1,
                colors: [
                  Color.lerp(AppColors.bg, AppColors.accent.withValues(alpha: 0.18), _glow.value) ?? AppColors.bg,
                  AppColors.bg,
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.6, end: 1).animate(_logoScale),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface.withValues(alpha: 0.6),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.35 * _glow.value),
                              blurRadius: 40,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const LogoMark(size: 84),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _textFade,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(_textFade),
                      child: Column(
                        children: [
                          Text(
                            'ShellBox',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'splash.tagline'.tr(),
                            style: TextStyle(color: AppColors.textDim, fontSize: 13, letterSpacing: 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

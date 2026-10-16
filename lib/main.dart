import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'nav.dart';
import 'screens/lock_screen.dart';
import 'screens/splash_screen.dart';
import 'services/activity_log.dart';
import 'services/app_lock.dart';
import 'services/auth_service.dart';
import 'services/store.dart';
import 'services/theme_controller.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStore.instance.load();
  await ActivityLog.instance.load();
  ThemeController.instance.loadMode(ThemeController.modeFromString(AppStore.instance.themeMode));
  AppColors.active = ThemeController.instance.resolvePalette(PlatformDispatcher.instance.platformBrightness);
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await AuthService.instance.init();
  } catch (_) {}
  runApp(const ShellBoxApp());
}

class ShellBoxApp extends StatefulWidget {
  const ShellBoxApp({super.key});

  @override
  State<ShellBoxApp> createState() => _ShellBoxAppState();
}

class _ShellBoxAppState extends State<ShellBoxApp> with WidgetsBindingObserver {
  bool _wentBackground = false;
  bool _lockShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _wentBackground = true;
    } else if (state == AppLifecycleState.resumed && _wentBackground) {
      _wentBackground = false;
      _maybeLock();
    }
  }

  Future<void> _maybeLock() async {
    if (!AppLock.isEnabled || _lockShowing) {
      return;
    }
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    _lockShowing = true;
    await navigator.push(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (_, __, ___) => const LockScreen(),
      ),
    );
    _lockShowing = false;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'ShellBox',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: messengerKey,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeController.instance.mode,
          themeAnimationDuration: Duration.zero,
          builder: (context, child) {
            final dark = ThemeController.instance.resolveIsDark(MediaQuery.platformBrightnessOf(context));
            AppColors.active = dark ? darkPalette : lightPalette;
            SystemChrome.setSystemUIOverlayStyle(
              SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
                statusBarBrightness: dark ? Brightness.dark : Brightness.light,
                systemNavigationBarColor: AppColors.surface,
                systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
              ),
            );
            return child!;
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}

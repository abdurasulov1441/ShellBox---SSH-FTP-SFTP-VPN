import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nav.dart';
import 'screens/home_screen.dart';
import 'services/store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await AppStore.instance.load();
  runApp(const KonsolApp());
}

class KonsolApp extends StatelessWidget {
  const KonsolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Konsol',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
    );
  }
}

import 'package:flutter/material.dart';

import 'models.dart';
import 'screens/files_screen.dart';
import 'screens/terminal_screen.dart';
import 'services/sessions.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

class TerminalRoute {
  static bool visible = false;
}

void showSnack(String message, {bool error = false}) {
  final messenger = messengerKey.currentState;
  if (messenger == null) {
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: error ? AppColors.red : AppColors.green,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        duration: Duration(milliseconds: error ? 4000 : 2200),
      ),
    );
}

Future<void> showTerminal() async {
  final navigator = navigatorKey.currentState;
  if (navigator == null || TerminalRoute.visible) {
    return;
  }
  await navigator.push(MaterialPageRoute<void>(builder: (_) => const TerminalScreen()));
}

Future<void> openTerminal(Host host) async {
  SessionManager.instance.open(host);
  await showTerminal();
}

Future<void> openFiles(Host host) async {
  final navigator = navigatorKey.currentState;
  if (navigator == null) {
    return;
  }
  await navigator.push(MaterialPageRoute<void>(builder: (_) => FilesScreen(host: host)));
}

Future<void> openHost(Host host) async {
  switch (host.protocol) {
    case Protocol.ssh:
      await openTerminal(host);
    case Protocol.ftp:
    case Protocol.ftps:
      await openFiles(host);
  }
}

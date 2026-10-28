import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../nav.dart';
import '../services/sessions.dart';
import '../services/theme_controller.dart';
import '../theme.dart';
import '../widgets/app_nav_bar.dart';
import '../widgets/common.dart';
import 'host_editor.dart';
import 'hosts_screen.dart';
import 'keys_screen.dart';
import 'settings_screen.dart';
import 'snippets_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [
                HostsScreen(),
                KeysScreen(),
                SnippetsScreen(),
                SettingsScreen(),
              ],
            ),
          ),
          ListenableBuilder(
            listenable: SessionManager.instance,
            builder: (context, _) {
              final sessions = SessionManager.instance.sessions;
              if (sessions.isEmpty) {
                return const SizedBox.shrink();
              }
              final connected = sessions.where((s) => s.isConnected).length;
              return _ActiveSessionsBar(total: sessions.length, connected: connected);
            },
          ),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        currentIndex: _tab,
        onTap: (index) => setState(() => _tab = index),
        centerLabel: 'hosts.add'.tr(),
        onCenterTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const HostEditorScreen()),
        ),
        items: [
          NavItem(icon: HugeIcons.strokeRoundedServerStack01, label: 'nav.hosts'.tr()),
          NavItem(icon: HugeIcons.strokeRoundedKey01, label: 'nav.keys'.tr()),
          NavItem(icon: HugeIcons.strokeRoundedFlash, label: 'nav.snippets'.tr()),
          NavItem(icon: HugeIcons.strokeRoundedSettings02, label: 'nav.settings'.tr()),
        ],
      ),
    );
  }
}

class _ActiveSessionsBar extends StatelessWidget {
  const _ActiveSessionsBar({required this.total, required this.connected});

  final int total;
  final int connected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Material(
        color: AppColors.surfaceHigh,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.green.withValues(alpha: 0.45)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: showTerminal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                StatusDot(color: connected > 0 ? AppColors.green : AppColors.textDim, size: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'home.active_sessions'.tr(namedArgs: {'count': '$total'}),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (connected != total)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      'home.online'.tr(namedArgs: {'count': '$connected'}),
                      style: TextStyle(color: AppColors.textDim, fontSize: 12.5),
                    ),
                  ),
                Icon(HugeIcons.strokeRoundedCommandLine, color: AppColors.accent, size: 20),
                const SizedBox(width: 4),
                Icon(HugeIcons.strokeRoundedArrowRight01, color: AppColors.textDim),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

// import '../services/auth_service.dart'; // Google sign-in temporarily disabled
import '../nav.dart';
import '../services/app_lock.dart';
import '../services/secure_window.dart';
import '../services/sessions.dart';
import '../services/store.dart';
import '../services/theme_controller.dart';
import '../services/vpn.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import 'logs_screen.dart';
import 'pin_setup_screen.dart';
import 'terminal_settings_screen.dart';
import 'tools_screen.dart';
import 'vpn_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _toggleLock(BuildContext context, bool value) async {
    if (value) {
      final pin = await _createPin(context);
      if (pin != null) {
        await AppStore.instance.setLock(enabled: true, pin: pin);
        showSnack('settings.lock_enabled'.tr());
      }
    } else {
      final ok = await confirmAction(
        title: 'settings.lock_off_title'.tr(),
        message: 'settings.lock_off_msg'.tr(),
        confirmLabel: 'settings.turn_off'.tr(),
      );
      if (ok) {
        await AppStore.instance.setLock(enabled: false);
        showSnack('settings.lock_disabled'.tr());
      }
    }
  }

  Future<void> _toggleBiometric(BuildContext context, bool value) async {
    if (value) {
      final available = await AppLock.biometricAvailable();
      if (!available) {
        showSnack('settings.biometric_unavailable'.tr(), error: true);
        return;
      }
      await AppStore.instance.setLock(enabled: true, biometric: true);
    } else {
      await AppStore.instance.setLock(enabled: true, biometric: false);
    }
  }

  // Google sign-in temporarily disabled — kept for later use.
  // Future<void> _signIn(BuildContext context) async {
  //   final ok = await AuthService.instance.signInWithGoogle();
  //   if (!ok) {
  //     final err = AuthService.instance.error;
  //     if (err != null) {
  //       showSnack(err, error: true);
  //     }
  //   }
  // }
  //
  // Future<void> _signOut(BuildContext context) async {
  //   final ok = await confirmAction(
  //     title: 'settings.signout_title'.tr(),
  //     message: 'settings.signout_msg'.tr(),
  //     confirmLabel: 'settings.signout'.tr(),
  //   );
  //   if (ok) {
  //     await AuthService.instance.signOut();
  //   }
  // }

  Future<void> _changePin(BuildContext context) async {
    final pin = await _createPin(context);
    if (pin != null) {
      await AppStore.instance.setLock(enabled: true, pin: pin);
      showSnack('settings.pin_changed'.tr());
    }
  }

  Future<String?> _createPin(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const PinSetupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('nav.settings'.tr())),
      body: ListenableBuilder(
        listenable: Listenable.merge([AppStore.instance, SessionManager.instance]),
        builder: (context, _) {
          final store = AppStore.instance;
          final known = store.knownHosts.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
          return ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              // ─── Google account section temporarily disabled (kept for later) ───
              // SectionHeader('settings.account'.tr(), padding: const EdgeInsets.fromLTRB(20, 8, 20, 8)),
              // (account card using AuthService — restore when Google sign-in is re-enabled)

              SectionHeader('settings.appearance'.tr(), padding: const EdgeInsets.fromLTRB(20, 8, 20, 8)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListenableBuilder(
                  listenable: ThemeController.instance,
                  builder: (context, _) {
                    final mode = ThemeController.instance.mode;
                    return Row(
                      children: [
                        _ThemeOption(
                          label: 'settings.theme_system'.tr(),
                          icon: HugeIcons.strokeRoundedComputerPhoneSync,
                          selected: mode == ThemeMode.system,
                          onTap: () => ThemeController.instance.setMode(ThemeMode.system),
                        ),
                        const SizedBox(width: 10),
                        _ThemeOption(
                          label: 'settings.theme_light'.tr(),
                          icon: HugeIcons.strokeRoundedSun03,
                          selected: mode == ThemeMode.light,
                          onTap: () => ThemeController.instance.setMode(ThemeMode.light),
                        ),
                        const SizedBox(width: 10),
                        _ThemeOption(
                          label: 'settings.theme_dark'.tr(),
                          icon: HugeIcons.strokeRoundedMoon02,
                          selected: mode == ThemeMode.dark,
                          onTap: () => ThemeController.instance.setMode(ThemeMode.dark),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SectionHeader('settings.language'.tr(), padding: const EdgeInsets.fromLTRB(20, 8, 20, 8)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _LangOption(
                      code: 'RU',
                      name: 'Русский',
                      selected: context.locale.languageCode == 'ru',
                      onTap: () => context.setLocale(const Locale('ru')),
                    ),
                    const SizedBox(width: 10),
                    _LangOption(
                      code: 'UZ',
                      name: 'O\'zbek',
                      selected: context.locale.languageCode == 'uz',
                      onTap: () => context.setLocale(const Locale('uz')),
                    ),
                    const SizedBox(width: 10),
                    _LangOption(
                      code: 'EN',
                      name: 'English',
                      selected: context.locale.languageCode == 'en',
                      onTap: () => context.setLocale(const Locale('en')),
                    ),
                  ],
                ),
              ),
              SectionHeader('settings.network'.tr(), padding: const EdgeInsets.fromLTRB(20, 8, 20, 8)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListenableBuilder(
                  listenable: VpnController.instance,
                  builder: (context, _) {
                    final controller = VpnController.instance;
                    final connected = controller.isConnected;
                    final count = store.vpnProfiles.length;
                    return _SettingsTile(
                      icon: HugeIcons.strokeRoundedShieldKey,
                      iconColor: connected ? AppColors.green : AppColors.accent,
                      title: 'VPN · WireGuard',
                      subtitle: connected
                          ? 'settings.vpn_connected'.tr()
                          : (count == 0
                              ? 'settings.vpn_import_hint'.tr()
                              : 'settings.vpn_profiles'.tr(namedArgs: {'count': '$count'})),
                      subtitleColor: connected ? AppColors.green : null,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const VpnScreen()),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _SettingsTile(
                  icon: HugeIcons.strokeRoundedWrench01,
                  iconColor: const Color(0xFFA371F7),
                  title: 'tools.title'.tr(),
                  subtitle: 'settings.tools_subtitle'.tr(),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const ToolsScreen()),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _SettingsTile(
                  icon: HugeIcons.strokeRoundedCommandLine,
                  iconColor: const Color(0xFF2DD4BF),
                  title: 'nav.terminal'.tr(),
                  subtitle: 'settings.terminal_subtitle'.tr(),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const TerminalSettingsScreen()),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _SettingsTile(
                  icon: HugeIcons.strokeRoundedTask01,
                  iconColor: AppColors.yellow,
                  title: 'tools.logs'.tr(),
                  subtitle: 'tools.logs_sub'.tr(),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const LogsScreen()),
                  ),
                ),
              ),
              SectionHeader('settings.known_hosts'.tr(namedArgs: {'count': '${known.length}'})),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: known.isEmpty
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'settings.known_hosts_empty'.tr(),
                            style: TextStyle(color: AppColors.textDim),
                          ),
                        ),
                      )
                    : Card(
                        child: Column(
                          children: [
                            for (var i = 0; i < known.length; i++) ...[
                              if (i > 0) const Divider(indent: 16, endIndent: 16),
                              ListTile(
                                leading: Icon(HugeIcons.strokeRoundedSecurityCheck, color: AppColors.green),
                                title: Text(known[i].key, style: AppFonts.monoStyle(size: 13.5)),
                                subtitle: Text(
                                  known[i].value,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.monoStyle(size: 11, color: AppColors.textDim),
                                ),
                                trailing: IconButton(
                                  tooltip: 'settings.forget'.tr(),
                                  icon: Icon(HugeIcons.strokeRoundedDelete02, color: AppColors.red),
                                  onPressed: () async {
                                    final endpoint = known[i].key;
                                    final ok = await confirmAction(
                                      title: 'settings.forget_key_title'.tr(),
                                      message: 'settings.forget_key_msg'.tr(namedArgs: {'endpoint': endpoint}),
                                      confirmLabel: 'settings.forget'.tr(),
                                    );
                                    if (ok) {
                                      await store.forgetHostKey(endpoint);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
              SectionHeader('settings.security'.tr()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Column(
                    children: [
                      AppSwitchTile(
                        leading: const GradientIcon(
                          icon: HugeIcons.strokeRoundedSquareLock02,
                          color: Color(0xFF3FB950),
                          size: 38,
                        ),
                        title: 'settings.app_lock'.tr(),
                        subtitle: Text(store.lockEnabled ? 'settings.pin_set'.tr() : 'settings.protect_with_pin'.tr()),
                        value: store.lockEnabled,
                        onChanged: (value) => _toggleLock(context, value),
                      ),
                      if (store.lockEnabled) ...[
                        const Divider(indent: 16, endIndent: 16),
                        AppSwitchTile(
                          leading: const GradientIcon(
                            icon: HugeIcons.strokeRoundedFingerPrint,
                            color: Color(0xFF4F8CFF),
                            size: 38,
                          ),
                          title: 'settings.biometric_login'.tr(),
                          subtitle: Text('settings.biometric_sub'.tr()),
                          value: store.biometricEnabled,
                          onChanged: (value) => _toggleBiometric(context, value),
                        ),
                        const Divider(indent: 16, endIndent: 16),
                        ListTile(
                          leading: const SizedBox(width: 38),
                          title: Text('settings.change_pin'.tr()),
                          trailing: const Icon(HugeIcons.strokeRoundedArrowRight01),
                          onTap: () => _changePin(context),
                        ),
                      ],
                      const Divider(indent: 16, endIndent: 16),
                      AppSwitchTile(
                        leading: const GradientIcon(
                          icon: HugeIcons.strokeRoundedViewOffSlash,
                          color: Color(0xFFD29922),
                          size: 38,
                        ),
                        title: 'settings.secure_screen'.tr(),
                        subtitle: Text('settings.secure_screen_sub'.tr()),
                        value: store.secureScreen,
                        onChanged: (value) async {
                          await store.setSecureScreen(value);
                          await SecureWindow.apply(value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SectionHeader('settings.about'.tr()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const LogoMark(size: 48),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ShellBox',
                                    style:
                                        Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  Text('settings.app_version'.tr(), style: TextStyle(color: AppColors.textDim)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _Counter(
                                label: 'nav.hosts'.tr(), value: store.hosts.length, icon: HugeIcons.strokeRoundedDatabase),
                            _Counter(label: 'nav.keys'.tr(), value: store.keys.length, icon: HugeIcons.strokeRoundedKey01),
                            _Counter(
                                label: 'nav.snippets'.tr(),
                                value: store.snippets.length,
                                icon: HugeIcons.strokeRoundedFlash),
                            _Counter(
                              label: 'settings.sessions'.tr(),
                              value: SessionManager.instance.sessions.length,
                              icon: HugeIcons.strokeRoundedCommandLine,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'settings.security_note'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textDim, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.subtitleColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Pressable(
        scale: 0.985,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              GradientIcon(icon: icon, color: iconColor, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: subtitleColor ?? AppColors.textDim, fontSize: 12.5)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(HugeIcons.strokeRoundedArrowRight01, color: AppColors.textDim, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.value, required this.icon});

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(height: 6),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Text(label, style: TextStyle(color: AppColors.textDim, fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Pressable(
        scale: 0.95,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent.withValues(alpha: 0.16) : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.accent : AppColors.border, width: selected ? 1.6 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: selected ? AppColors.accent : AppColors.textDim),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.text : AppColors.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  const _LangOption({required this.code, required this.name, required this.selected, required this.onTap});

  final String code;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Pressable(
        scale: 0.95,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent.withValues(alpha: 0.16) : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.accent : AppColors.border, width: selected ? 1.6 : 1),
          ),
          child: Column(
            children: [
              Text(
                code,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.accent : AppColors.textDim,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.text : AppColors.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

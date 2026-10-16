import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../nav.dart';
import '../services/app_lock.dart';
import '../services/auth_service.dart';
import '../services/sessions.dart';
import '../services/store.dart';
import '../services/theme_controller.dart';
import '../services/vpn.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import 'tools_screen.dart';
import 'vpn_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _toggleLock(BuildContext context, bool value) async {
    if (value) {
      final pin = await _createPin(context);
      if (pin != null) {
        await AppStore.instance.setLock(enabled: true, pin: pin);
        showSnack('Блокировка включена');
      }
    } else {
      final ok = await confirmAction(
        title: 'Выключить блокировку?',
        message: 'PIN-код и вход по биометрии будут удалены.',
        confirmLabel: 'Выключить',
      );
      if (ok) {
        await AppStore.instance.setLock(enabled: false);
        showSnack('Блокировка выключена');
      }
    }
  }

  Future<void> _toggleBiometric(BuildContext context, bool value) async {
    if (value) {
      final available = await AppLock.biometricAvailable();
      if (!available) {
        showSnack('Биометрия недоступна на этом устройстве', error: true);
        return;
      }
      await AppStore.instance.setLock(enabled: true, biometric: true);
    } else {
      await AppStore.instance.setLock(enabled: true, biometric: false);
    }
  }

  Future<void> _signIn(BuildContext context) async {
    final ok = await AuthService.instance.signInWithGoogle();
    if (!ok) {
      final err = AuthService.instance.error;
      if (err != null) {
        showSnack(err, error: true);
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await confirmAction(
      title: 'Выйти из аккаунта?',
      message: 'Вы сможете войти снова в любой момент.',
      confirmLabel: 'Выйти',
    );
    if (ok) {
      await AuthService.instance.signOut();
    }
  }

  Future<void> _changePin(BuildContext context) async {
    final pin = await _createPin(context);
    if (pin != null) {
      await AppStore.instance.setLock(enabled: true, pin: pin);
      showSnack('PIN-код изменён');
    }
  }

  Future<String?> _createPin(BuildContext context) async {
    final first = await _promptPin(context, 'Создайте PIN-код');
    if (first == null || !context.mounted) {
      return null;
    }
    final second = await _promptPin(context, 'Повторите PIN-код');
    if (second == null) {
      return null;
    }
    if (first != second) {
      showSnack('PIN-коды не совпадают', error: true);
      return null;
    }
    return first;
  }

  Future<String?> _promptPin(BuildContext context, String title) {
    return showDialog<String>(context: context, builder: (_) => _PinDialog(title: title));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListenableBuilder(
        listenable: Listenable.merge([AppStore.instance, SessionManager.instance]),
        builder: (context, _) {
          final store = AppStore.instance;
          final scheme = TerminalScheme.byId(store.terminalTheme);
          final known = store.knownHosts.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
          return ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              const SectionHeader('Аккаунт', padding: EdgeInsets.fromLTRB(20, 8, 20, 8)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListenableBuilder(
                  listenable: AuthService.instance,
                  builder: (context, _) {
                    final auth = AuthService.instance;
                    if (auth.signedIn) {
                      return Card(
                        child: ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          leading: _Avatar(name: auth.displayName, photoUrl: auth.photoUrl),
                          title: Text(auth.displayName,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(auth.email,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textDim)),
                          trailing: IconButton(
                            tooltip: 'Выйти',
                            icon: Icon(HugeIcons.strokeRoundedLogout03, color: AppColors.red),
                            onPressed: () => _signOut(context),
                          ),
                        ),
                      );
                    }
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const GradientIcon(
                                  icon: HugeIcons.strokeRoundedUserCircle,
                                  color: Color(0xFF2F6FEB),
                                  size: 40,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Вход не выполнен', style: TextStyle(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text('Войдите, чтобы видеть свой профиль',
                                          style: TextStyle(color: AppColors.textDim, fontSize: 12.5)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 48,
                              child: FilledButton.icon(
                                onPressed: auth.busy ? null : () => _signIn(context),
                                icon: auth.busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(HugeIcons.strokeRoundedGoogle, size: 20),
                                label: Text(auth.busy ? 'Вход…' : 'Войти через Google'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SectionHeader('Оформление', padding: EdgeInsets.fromLTRB(20, 8, 20, 8)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListenableBuilder(
                  listenable: ThemeController.instance,
                  builder: (context, _) {
                    final mode = ThemeController.instance.mode;
                    return Row(
                      children: [
                        _ThemeOption(
                          label: 'Система',
                          icon: HugeIcons.strokeRoundedComputerPhoneSync,
                          selected: mode == ThemeMode.system,
                          onTap: () => ThemeController.instance.setMode(ThemeMode.system),
                        ),
                        const SizedBox(width: 10),
                        _ThemeOption(
                          label: 'Светлая',
                          icon: HugeIcons.strokeRoundedSun03,
                          selected: mode == ThemeMode.light,
                          onTap: () => ThemeController.instance.setMode(ThemeMode.light),
                        ),
                        const SizedBox(width: 10),
                        _ThemeOption(
                          label: 'Тёмная',
                          icon: HugeIcons.strokeRoundedMoon02,
                          selected: mode == ThemeMode.dark,
                          onTap: () => ThemeController.instance.setMode(ThemeMode.dark),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SectionHeader('Сеть', padding: EdgeInsets.fromLTRB(20, 8, 20, 8)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListenableBuilder(
                  listenable: VpnController.instance,
                  builder: (context, _) {
                    final controller = VpnController.instance;
                    final connected = controller.isConnected;
                    final count = store.vpnProfiles.length;
                    return Card(
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        leading: GradientIcon(
                          icon: connected ? Icons.vpn_lock_rounded : Icons.vpn_key_rounded,
                          color: connected ? AppColors.green : AppColors.accent,
                          size: 40,
                        ),
                        title: const Text('VPN · WireGuard'),
                        subtitle: Text(
                          connected ? 'Подключено' : (count == 0 ? 'Импортируйте .conf один раз' : 'Профилей: $count'),
                          style: TextStyle(color: connected ? AppColors.green : AppColors.textDim),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const VpnScreen()),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Card(
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    leading: const GradientIcon(
                      icon: HugeIcons.strokeRoundedWrench01,
                      color: Color(0xFFA371F7),
                      size: 40,
                    ),
                    title: const Text('Инструменты'),
                    subtitle: Text(
                      'IP-калькулятор, порты, терминал, логи',
                      style: TextStyle(color: AppColors.textDim),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const ToolsScreen()),
                    ),
                  ),
                ),
              ),
              const SectionHeader('Терминал'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.format_size_rounded, color: AppColors.textDim, size: 20),
                            const SizedBox(width: 10),
                            const Expanded(child: Text('Размер шрифта', style: TextStyle(fontWeight: FontWeight.w600))),
                            Text('${store.fontSize.round()} pt',
                                style: AppFonts.monoStyle(size: 13, color: AppColors.accent)),
                          ],
                        ),
                        Slider(
                          value: store.fontSize,
                          min: 8,
                          max: 28,
                          divisions: 20,
                          onChanged: (value) => store.setFontSize(value),
                        ),
                        _PromptPreview(scheme: scheme, fontSize: store.fontSize, fontId: store.terminalFont),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
              const SectionHeader('Цветовая схема'),
              SizedBox(
                height: 128,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: TerminalScheme.all.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = TerminalScheme.all[index];
                    return _SchemeCard(
                      scheme: item,
                      selected: item.id == scheme.id,
                      onTap: () => store.setTerminalTheme(item.id),
                    );
                  },
                ),
              ),
              const SectionHeader('Шрифт терминала'),
              SizedBox(
                height: 86,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: MonoFonts.all.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final font = MonoFonts.all[index];
                    return _FontCard(
                      font: font,
                      selected: font.id == store.terminalFont,
                      onTap: () => store.setTerminalFont(font.id),
                    );
                  },
                ),
              ),
              SectionHeader('Известные хосты (${known.length})'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: known.isEmpty
                    ? Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Отпечатки ключей серверов появятся здесь после первого подключения.',
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
                                leading: Icon(Icons.verified_user_outlined, color: AppColors.green),
                                title: Text(known[i].key, style: AppFonts.monoStyle(size: 13.5)),
                                subtitle: Text(
                                  known[i].value,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.monoStyle(size: 11, color: AppColors.textDim),
                                ),
                                trailing: IconButton(
                                  tooltip: 'Забыть',
                                  icon: Icon(Icons.delete_outline_rounded, color: AppColors.red),
                                  onPressed: () async {
                                    final endpoint = known[i].key;
                                    final ok = await confirmAction(
                                      title: 'Забыть ключ?',
                                      message:
                                          'При следующем подключении к $endpoint отпечаток ключа нужно будет подтвердить заново.',
                                      confirmLabel: 'Забыть',
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
              const SectionHeader('Безопасность'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        secondary: const GradientIcon(
                          icon: HugeIcons.strokeRoundedSquareLock02,
                          color: Color(0xFF3FB950),
                          size: 38,
                        ),
                        title: const Text('Блокировка приложения'),
                        subtitle: Text(
                          store.lockEnabled ? 'PIN-код установлен' : 'Защитить вход PIN-кодом',
                          style: TextStyle(color: AppColors.textDim),
                        ),
                        value: store.lockEnabled,
                        onChanged: (value) => _toggleLock(context, value),
                      ),
                      if (store.lockEnabled) ...[
                        const Divider(indent: 16, endIndent: 16),
                        SwitchListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          secondary: const GradientIcon(
                            icon: HugeIcons.strokeRoundedFingerPrint,
                            color: Color(0xFF4F8CFF),
                            size: 38,
                          ),
                          title: const Text('Вход по биометрии'),
                          subtitle: Text('Отпечаток или лицо', style: TextStyle(color: AppColors.textDim)),
                          value: store.biometricEnabled,
                          onChanged: (value) => _toggleBiometric(context, value),
                        ),
                        ListTile(
                          leading: const SizedBox(width: 38),
                          title: const Text('Изменить PIN-код'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _changePin(context),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SectionHeader('О приложении'),
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
                                  Text('SSH-клиент · версия 1.0.0', style: TextStyle(color: AppColors.textDim)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _Counter(label: 'Хосты', value: store.hosts.length, icon: Icons.dns_rounded),
                            _Counter(label: 'Ключи', value: store.keys.length, icon: Icons.key_rounded),
                            _Counter(label: 'Сниппеты', value: store.snippets.length, icon: Icons.bolt_rounded),
                            _Counter(
                              label: 'Сессии',
                              value: SessionManager.instance.sessions.length,
                              icon: Icons.terminal_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Пароли и приватные ключи хранятся только в защищённом хранилище устройства.',
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

class _PromptPreview extends StatelessWidget {
  const _PromptPreview({required this.scheme, required this.fontSize, required this.fontId});

  final TerminalScheme scheme;
  final double fontSize;
  final String fontId;

  @override
  Widget build(BuildContext context) {
    final theme = scheme.theme;
    TextStyle style(Color color, {FontWeight weight = FontWeight.w400}) =>
        MonoFonts.style(fontId, size: fontSize, color: color, weight: weight);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'root@server', style: style(theme.green, weight: FontWeight.w700)),
            TextSpan(text: ':', style: style(theme.foreground)),
            TextSpan(text: '~', style: style(theme.blue, weight: FontWeight.w700)),
            TextSpan(text: r'$ ', style: style(theme.foreground)),
            TextSpan(text: 'uptime\n', style: style(theme.foreground)),
            TextSpan(text: ' 12:04:51 up 42 days, load average: ', style: style(theme.foreground)),
            TextSpan(text: '0.12', style: style(theme.yellow)),
          ],
        ),
      ),
    );
  }
}

class _FontCard extends StatelessWidget {
  const _FontCard({required this.font, required this.selected, required this.onTap});

  final MonoFont font;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.96,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.accent : AppColors.border, width: selected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    font.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                if (selected) Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 16),
              ],
            ),
            Text(
              'sudo rm -rf',
              style: MonoFonts.style(font.id, size: 15).copyWith(color: AppColors.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchemeCard extends StatelessWidget {
  const _SchemeCard({required this.scheme, required this.selected, required this.onTap});

  final TerminalScheme scheme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = scheme.theme;
    final colors = [theme.red, theme.green, theme.yellow, theme.blue, theme.magenta, theme.cyan];
    return Pressable(
      scale: 0.96,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.accent : AppColors.border, width: selected ? 2 : 1),
          boxShadow: selected ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 14)] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    scheme.name,
                    style: TextStyle(color: theme.foreground, fontWeight: FontWeight.w700),
                  ),
                ),
                if (selected) Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'user', style: AppFonts.monoStyle(size: 11, color: theme.green)),
                  TextSpan(text: ':', style: AppFonts.monoStyle(size: 11, color: theme.foreground)),
                  TextSpan(text: '~', style: AppFonts.monoStyle(size: 11, color: theme.blue)),
                  TextSpan(text: r'$ ls', style: AppFonts.monoStyle(size: 11, color: theme.foreground)),
                ],
              ),
            ),
            const Spacer(),
            Row(
              children: [
                for (final color in colors)
                  Expanded(
                    child: Container(
                      height: 10,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
              ],
            ),
          ],
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    final placeholder = Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Color(0xFF2F6FEB), Color(0xFF8B5CF6)]),
      ),
      child: Text(letter, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
    );
    final url = photoUrl;
    if (url == null || url.isEmpty) {
      return placeholder;
    }
    return ClipOval(
      child: Image.network(
        url,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => placeholder,
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

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.title});

  final String title;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  String _pin = '';

  void _add(String d) {
    if (_pin.length >= 4) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _pin += d);
    if (_pin.length == 4) {
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (mounted) {
          Navigator.of(context).pop(_pin);
        }
      });
    }
  }

  void _back() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget key(String d) => _DialogKey(label: d, onTap: () => _add(d));
    return AlertDialog(
      title: Text(widget.title, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 4; i++)
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length ? AppColors.accent : Colors.transparent,
                    border: Border.all(color: i < _pin.length ? AppColors.accent : AppColors.border, width: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final d in row) key(d)]),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 56),
              key('0'),
              _DialogKey(icon: Icons.backspace_outlined, onTap: _back),
            ],
          ),
        ],
      ),
    );
  }
}

class _DialogKey extends StatelessWidget {
  const _DialogKey({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: AppColors.surfaceHigh,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 22, color: AppColors.text)
                  : Text(label ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }
}

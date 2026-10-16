import 'package:flutter/material.dart';

import '../services/sessions.dart';
import '../services/store.dart';
import '../services/vpn.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import 'vpn_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
                            const Icon(Icons.format_size_rounded, color: AppColors.textDim, size: 20),
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
                    ? const Card(
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
                                leading: const Icon(Icons.verified_user_outlined, color: AppColors.green),
                                title: Text(known[i].key, style: AppFonts.monoStyle(size: 13.5)),
                                subtitle: Text(
                                  known[i].value,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.monoStyle(size: 11, color: AppColors.textDim),
                                ),
                                trailing: IconButton(
                                  tooltip: 'Забыть',
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
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
                                    'Konsol',
                                    style:
                                        Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const Text('SSH-клиент · версия 1.0.0', style: TextStyle(color: AppColors.textDim)),
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
                        const Text(
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
    return GestureDetector(
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
                if (selected) const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 16),
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
    return GestureDetector(
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
                if (selected) const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 18),
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
          Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 11.5)),
        ],
      ),
    );
  }
}

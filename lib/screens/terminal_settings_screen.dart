import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';

class TerminalSettingsScreen extends StatelessWidget {
  const TerminalSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('nav.terminal'.tr())),
      body: ListenableBuilder(
        listenable: AppStore.instance,
        builder: (context, _) {
          final store = AppStore.instance;
          final scheme = TerminalScheme.byId(store.terminalTheme);
          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 40),
            children: [
              SectionHeader('settings.font_size'.tr()),
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
                            Icon(HugeIcons.strokeRoundedTextFont, color: AppColors.textDim, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text('settings.font_size'.tr(),
                                    style: const TextStyle(fontWeight: FontWeight.w600))),
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
              SectionHeader('settings.color_scheme'.tr()),
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
              SectionHeader('settings.terminal_font'.tr()),
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
                if (selected) Icon(HugeIcons.strokeRoundedCheckmarkCircle02, color: AppColors.accent, size: 16),
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
                if (selected) Icon(HugeIcons.strokeRoundedCheckmarkCircle02, color: AppColors.accent, size: 18),
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

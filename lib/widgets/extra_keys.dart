import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../data/command_intel.dart';
import '../services/sessions.dart';
import '../services/store.dart';
import '../theme.dart';
import 'common.dart';

Future<void> pasteInto(TerminalSession session) async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final text = data?.text;
  if (text == null || text.isEmpty) {
    return;
  }
  session.paste(text);
}

Future<void> showSnippetSheet(BuildContext context, TerminalSession session) async {
  final snippets = AppStore.instance.snippets;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetTitle('Сниппеты', subtitle: 'Выполнить в ${session.host.title}'),
              if (snippets.isEmpty)
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Сниппетов пока нет. Добавьте их на вкладке «Сниппеты».',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textDim),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: snippets.length,
                    itemBuilder: (_, index) {
                      final snippet = snippets[index];
                      return ListTile(
                        leading: Icon(Icons.bolt_rounded, color: AppColors.yellow),
                        title: Text(snippet.name.isEmpty ? snippet.command : snippet.name),
                        subtitle: Text(
                          snippet.command,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.monoStyle(size: 12, color: AppColors.textDim),
                        ),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          session.run(snippet.command);
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

class SuggestionBar extends StatelessWidget {
  const SuggestionBar({super.key, required this.session});

  final TerminalSession session;

  IconData _icon(SuggestionKind kind) {
    switch (kind) {
      case SuggestionKind.history:
        return Icons.history_rounded;
      case SuggestionKind.snippet:
        return Icons.bolt_rounded;
      case SuggestionKind.command:
        return Icons.terminal_rounded;
      case SuggestionKind.next:
        return Icons.chevron_right_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: session.line,
      builder: (context, line, _) {
        final suggestions = CommandIntel.suggest(
          line: line,
          history: AppStore.instance.commandHistory,
          snippetCommands: AppStore.instance.snippets.map((s) => s.command).toList(),
        );
        if (suggestions.isEmpty) {
          return const SizedBox.shrink();
        }
        return Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.bg,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            itemCount: suggestions.length,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              final highlight = suggestion.kind == SuggestionKind.history;
              return Material(
                color: highlight ? AppColors.accent.withValues(alpha: 0.16) : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    session.applyCompletion(suggestion.insert);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Icon(
                          _icon(suggestion.kind),
                          size: 14,
                          color: highlight ? AppColors.accent : AppColors.textDim,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          suggestion.label,
                          style: AppFonts.monoStyle(size: 12.5, color: AppColors.text, weight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class ExtraKeysBar extends StatefulWidget {
  const ExtraKeysBar({super.key, required this.session, required this.focusNode});

  final TerminalSession session;
  final FocusNode focusNode;

  @override
  State<ExtraKeysBar> createState() => _ExtraKeysBarState();
}

class _ExtraKeysBarState extends State<ExtraKeysBar> {
  bool _fn = false;

  static const _functionKeys = <(String, TerminalKey)>[
    ('F1', TerminalKey.f1),
    ('F2', TerminalKey.f2),
    ('F3', TerminalKey.f3),
    ('F4', TerminalKey.f4),
    ('F5', TerminalKey.f5),
    ('F6', TerminalKey.f6),
    ('F7', TerminalKey.f7),
    ('F8', TerminalKey.f8),
    ('F9', TerminalKey.f9),
    ('F10', TerminalKey.f10),
    ('F11', TerminalKey.f11),
    ('F12', TerminalKey.f12),
  ];

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        return Container(
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            children: [
              _KeyButton(
                icon: Icons.keyboard_hide_rounded,
                onTap: () {
                  if (widget.focusNode.hasFocus) {
                    widget.focusNode.unfocus();
                  } else {
                    widget.focusNode.requestFocus();
                  }
                },
              ),
              _KeyButton(label: 'Fn', active: _fn, onTap: () => setState(() => _fn = !_fn)),
              if (_fn) ..._buildFnKeys(session) else ..._buildNormalKeys(session),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildFnKeys(TerminalSession session) {
    return [
      _KeyButton(label: 'ESC', onTap: () => session.key(TerminalKey.escape)),
      for (final entry in _functionKeys) _KeyButton(label: entry.$1, onTap: () => session.key(entry.$2)),
    ];
  }

  List<Widget> _buildNormalKeys(TerminalSession session) {
    return [
      _KeyButton(label: 'ESC', onTap: () => session.key(TerminalKey.escape)),
      _KeyButton(label: 'TAB', onTap: () => session.key(TerminalKey.tab)),
      _KeyButton(label: 'CTRL', active: session.ctrl, onTap: session.toggleCtrl),
      _KeyButton(label: 'ALT', active: session.alt, onTap: session.toggleAlt),
      _RepeatKey(icon: Icons.arrow_upward_rounded, onKey: () => session.key(TerminalKey.arrowUp)),
      _RepeatKey(icon: Icons.arrow_downward_rounded, onKey: () => session.key(TerminalKey.arrowDown)),
      _RepeatKey(icon: Icons.arrow_back_rounded, onKey: () => session.key(TerminalKey.arrowLeft)),
      _RepeatKey(icon: Icons.arrow_forward_rounded, onKey: () => session.key(TerminalKey.arrowRight)),
      for (final symbol in const ['/', '-', '|', '~', ':', '*', '>', '&', '\$', '.'])
        _KeyButton(label: symbol, onTap: () => session.input(symbol)),
      _KeyButton(label: 'HOME', onTap: () => session.key(TerminalKey.home)),
      _KeyButton(label: 'END', onTap: () => session.key(TerminalKey.end)),
      _KeyButton(label: 'PGUP', onTap: () => session.key(TerminalKey.pageUp)),
      _KeyButton(label: 'PGDN', onTap: () => session.key(TerminalKey.pageDown)),
      _KeyButton(label: '^C', onTap: () => session.sendRaw('\x03')),
      _KeyButton(label: '^D', onTap: () => session.sendRaw('\x04')),
      _KeyButton(label: '^Z', onTap: () => session.sendRaw('\x1a')),
      _KeyButton(label: '^L', onTap: () => session.sendRaw('\x0c')),
      _KeyButton(icon: Icons.content_paste_rounded, onTap: () => pasteInto(session)),
      _KeyButton(icon: Icons.bolt_rounded, onTap: () => showSnippetSheet(context, session)),
    ];
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({this.label, this.icon, required this.onTap, this.active = false});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: active ? AppColors.accent : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: _KeyFace(label: label, icon: icon, active: active),
        ),
      ),
    );
  }
}

class _KeyFace extends StatelessWidget {
  const _KeyFace({this.label, this.icon, this.active = false});

  final String? label;
  final IconData? icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : AppColors.text;
    return Container(
      constraints: const BoxConstraints(minWidth: 40),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? AppColors.accent : AppColors.border),
      ),
      child: icon != null
          ? Icon(icon, size: 18, color: color)
          : Text(label ?? '', style: AppFonts.monoStyle(size: 13, color: color, weight: FontWeight.w600)),
    );
  }
}

class _RepeatKey extends StatefulWidget {
  const _RepeatKey({required this.icon, required this.onKey});

  final IconData icon;
  final VoidCallback onKey;

  @override
  State<_RepeatKey> createState() => _RepeatKeyState();
}

class _RepeatKeyState extends State<_RepeatKey> {
  Timer? _delay;
  Timer? _repeat;
  bool _pressed = false;

  void _start() {
    _stop();
    HapticFeedback.selectionClick();
    widget.onKey();
    setState(() => _pressed = true);
    _delay = Timer(const Duration(milliseconds: 350), () {
      _repeat = Timer.periodic(const Duration(milliseconds: 60), (_) => widget.onKey());
    });
  }

  void _stop() {
    _delay?.cancel();
    _repeat?.cancel();
    _delay = null;
    _repeat = null;
    if (_pressed && mounted) {
      setState(() => _pressed = false);
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _repeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _start(),
        onTapUp: (_) => _stop(),
        onTapCancel: _stop,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          decoration: BoxDecoration(
            color: _pressed ? AppColors.border : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: _KeyFace(icon: widget.icon),
        ),
      ),
    );
  }
}

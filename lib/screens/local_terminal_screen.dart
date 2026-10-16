import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../services/activity_log.dart';
import '../services/store.dart';
import '../theme.dart';

class LocalTerminalScreen extends StatefulWidget {
  const LocalTerminalScreen({super.key});

  @override
  State<LocalTerminalScreen> createState() => _LocalTerminalScreenState();
}

class _LocalTerminalScreenState extends State<LocalTerminalScreen> {
  final Terminal _terminal = Terminal(maxLines: 5000);
  final TerminalController _controller = TerminalController();
  final FocusNode _focus = FocusNode();

  Process? _process;
  StreamSubscription<String>? _stdout;
  StreamSubscription<String>? _stderr;
  String _line = '';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _terminal.onOutput = _onInput;
    _start();
  }

  Future<void> _start() async {
    _terminal.write('\x1b[90mЛокальный терминал устройства\x1b[0m\r\n');
    const shells = ['/system/bin/sh', '/bin/sh', 'sh'];
    for (final shell in shells) {
      try {
        final process = await Process.start(shell, const [], environment: {'TERM': 'dumb', 'PS1': r'$ '});
        _process = process;
        _ready = true;
        _stdout = const Utf8Decoder(allowMalformed: true).bind(process.stdout).listen(_terminal.write);
        _stderr = const Utf8Decoder(allowMalformed: true).bind(process.stderr).listen(_terminal.write);
        process.exitCode.then((code) {
          if (mounted) {
            _terminal.write('\r\n\x1b[90mСеанс завершён (код $code)\x1b[0m\r\n');
            setState(() => _ready = false);
          }
        });
        ActivityLog.instance.info('Терминал', 'Открыт локальный терминал ($shell)');
        _send('uname -a 2>/dev/null; id 2>/dev/null\n');
        return;
      } catch (_) {}
    }
    _terminal.write('\r\n\x1b[31mНе удалось запустить локальную оболочку на этом устройстве\x1b[0m\r\n');
  }

  void _send(String data) {
    final process = _process;
    if (process == null || !_ready) {
      return;
    }
    try {
      process.stdin.add(utf8.encode(data));
    } catch (_) {}
  }

  void _onInput(String data) {
    for (final rune in data.runes) {
      if (rune == 0x0d || rune == 0x0a) {
        _terminal.write('\r\n');
        _send('$_line\n');
        _line = '';
      } else if (rune == 0x7f || rune == 0x08) {
        if (_line.isNotEmpty) {
          _line = _line.substring(0, _line.length - 1);
          _terminal.write('\b \b');
        }
      } else if (rune == 0x03) {
        _terminal.write('^C\r\n');
        _send('\x03');
        _line = '';
      } else if (rune >= 0x20) {
        final char = String.fromCharCode(rune);
        _line += char;
        _terminal.write(char);
      }
    }
  }

  void _key(String seq, {bool clearLine = false}) {
    if (clearLine) {
      _line = '';
    }
    _send(seq);
  }

  @override
  void dispose() {
    _stdout?.cancel();
    _stderr?.cancel();
    try {
      _process?.kill();
    } catch (_) {}
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = TerminalScheme.byId(AppStore.instance.terminalTheme);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Локальный терминал'),
        actions: [
          IconButton(
            tooltip: 'Очистить',
            icon: const Icon(Icons.cleaning_services_rounded),
            onPressed: () => _send('clear\n'),
          ),
        ],
      ),
      backgroundColor: scheme.theme.background,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: TerminalView(
                _terminal,
                controller: _controller,
                focusNode: _focus,
                theme: scheme.theme,
                textStyle: TerminalStyle(fontSize: AppStore.instance.fontSize, fontFamily: AppFonts.mono),
                padding: const EdgeInsets.all(8),
                autofocus: true,
                keyboardType: TextInputType.visiblePassword,
                deleteDetection: true,
              ),
            ),
            Container(
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                children: [
                  _ToolKey(
                      icon: Icons.keyboard_hide_rounded,
                      onTap: () => _focus.hasFocus ? _focus.unfocus() : _focus.requestFocus()),
                  _ToolKey(label: 'TAB', onTap: () => _send('\t')),
                  _ToolKey(label: '^C', onTap: () => _key('\x03', clearLine: true)),
                  _ToolKey(label: '^D', onTap: () => _send('\x04')),
                  for (final cmd in const ['ls', 'pwd', 'id', 'ps', 'getprop', 'ping -c 4 1.1.1.1'])
                    _ToolKey(label: cmd, onTap: () => _runCommand(cmd)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _runCommand(String cmd) {
    _terminal.write('$cmd\r\n');
    _send('$cmd\n');
    _line = '';
  }
}

class _ToolKey extends StatelessWidget {
  const _ToolKey({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            constraints: const BoxConstraints(minWidth: 40),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: icon != null
                ? Icon(icon, size: 18, color: AppColors.text)
                : Text(label ?? '', style: AppFonts.monoStyle(size: 12.5, weight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}

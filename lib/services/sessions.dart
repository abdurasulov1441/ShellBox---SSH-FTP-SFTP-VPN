import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';

import '../data/command_intel.dart';
import '../models.dart';
import '../widgets/dialogs.dart';
import 'connector.dart';
import 'store.dart';

enum SessionState { connecting, connected, closed, failed }

class TerminalSession extends ChangeNotifier {
  TerminalSession(this.host) : id = AppStore.newId() {
    terminal = Terminal(maxLines: 10000);
    terminal.onOutput = input;
    terminal.onResize = _handleResize;
  }

  final Host host;
  final String id;
  late final Terminal terminal;
  final TerminalController controller = TerminalController();

  SessionState state = SessionState.connecting;
  String? error;
  bool ctrl = false;
  bool alt = false;

  final ValueNotifier<String> line = ValueNotifier<String>('');
  String _line = '';

  SSHClient? _client;
  SSHSession? _shell;
  StreamSubscription<String>? _stdout;
  StreamSubscription<String>? _stderr;
  int _generation = 0;
  bool _disposed = false;

  bool get isConnected => state == SessionState.connected;

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> start() async {
    _teardown();
    _line = '';
    line.value = '';
    final gen = ++_generation;
    state = SessionState.connecting;
    error = null;
    ctrl = false;
    alt = false;
    _notify();
    terminal.write('\x1b[90m${'files.connecting'.tr(namedArgs: {'host': host.subtitle})}\x1b[0m\r\n');
    try {
      final client = await SshConnector.connect(
        host,
        onHostKey: confirmHostKey,
        onPassword: askPassword,
      );
      if (gen != _generation || _disposed) {
        client.close();
        return;
      }
      _client = client;
      final width = terminal.viewWidth > 0 ? terminal.viewWidth : 80;
      final height = terminal.viewHeight > 0 ? terminal.viewHeight : 24;
      final shell = await client.shell(
        pty: SSHPtyConfig(type: 'xterm-256color', width: width, height: height),
      );
      if (gen != _generation || _disposed) {
        shell.close();
        client.close();
        return;
      }
      _shell = shell;
      _stdout = const Utf8Decoder(allowMalformed: true).bind(shell.stdout).listen((data) {
        if (gen == _generation) {
          terminal.write(data);
        }
      });
      _stderr = const Utf8Decoder(allowMalformed: true).bind(shell.stderr).listen((data) {
        if (gen == _generation) {
          terminal.write(data);
        }
      });
      shell.done.then((_) => _onClosed(gen), onError: (Object e) => _onClosed(gen, e));
      client.done.then((_) => _onClosed(gen), onError: (Object e) => _onClosed(gen, e));
      state = SessionState.connected;
      _notify();
      if (terminal.viewWidth != width || terminal.viewHeight != height) {
        _handleResize(terminal.viewWidth, terminal.viewHeight, 0, 0);
      }
      unawaited(AppStore.instance.touchHost(host.id));
      final startup = host.startupCommand.trim();
      if (startup.isNotEmpty) {
        run(startup);
      }
    } catch (e) {
      if (gen != _generation || _disposed) {
        return;
      }
      _teardown();
      state = SessionState.failed;
      error = describeSshError(e);
      terminal.write('\r\n\x1b[31m$error\x1b[0m\r\n');
      _notify();
    }
  }

  void _onClosed(int gen, [Object? cause]) {
    if (gen != _generation || _disposed) {
      return;
    }
    if (state == SessionState.closed || state == SessionState.failed) {
      return;
    }
    _teardown();
    if (cause != null) {
      state = SessionState.failed;
      error = describeSshError(cause);
      terminal.write('\r\n\x1b[31m$error\x1b[0m\r\n');
    } else {
      state = SessionState.closed;
      error = null;
      terminal.write('\r\n\x1b[90m${'terminal.connection_closed'.tr()}\x1b[0m\r\n');
    }
    _notify();
  }

  void _teardown() {
    _stdout?.cancel();
    _stderr?.cancel();
    _stdout = null;
    _stderr = null;
    final shell = _shell;
    _shell = null;
    if (shell != null) {
      try {
        shell.close();
      } catch (_) {}
    }
    final client = _client;
    _client = null;
    if (client != null) {
      try {
        client.close();
      } catch (_) {}
    }
  }

  void _handleResize(int width, int height, int pixelWidth, int pixelHeight) {
    final shell = _shell;
    if (shell == null || width <= 0 || height <= 0) {
      return;
    }
    try {
      shell.resizeTerminal(width, height, pixelWidth, pixelHeight);
    } catch (_) {}
  }

  void _send(String data) {
    final shell = _shell;
    if (shell == null || state != SessionState.connected) {
      return;
    }
    try {
      shell.write(Uint8List.fromList(utf8.encode(data)));
    } on StateError catch (e) {
      // dartssh2 throws StateError when stdin of a closed channel is written;
      // report the dead connection instead of swallowing keystrokes.
      _onClosed(_generation, e);
    } on Exception catch (e) {
      _onClosed(_generation, e);
    }
  }

  void input(String data) {
    var out = data;
    if (ctrl || alt) {
      if (ctrl && out.length == 1) {
        final code = out.codeUnitAt(0);
        if (code >= 0x61 && code <= 0x7A) {
          out = String.fromCharCode(code - 0x60);
        } else if (code >= 0x40 && code <= 0x5F) {
          out = String.fromCharCode(code - 0x40);
        } else if (code == 0x20) {
          out = '\x00';
        }
      }
      if (alt) {
        out = '\x1b$out';
      }
      ctrl = false;
      alt = false;
      _notify();
    }
    _track(out);
    _send(out);
  }

  void _track(String out) {
    if (out.isEmpty || out.codeUnitAt(0) == 0x1b) {
      return;
    }
    var buf = _line;
    for (final rune in out.runes) {
      if (rune == 0x0d || rune == 0x0a) {
        _commit(buf);
        buf = '';
      } else if (rune == 0x7f || rune == 0x08) {
        if (buf.isNotEmpty) {
          buf = buf.substring(0, buf.length - 1);
        }
      } else if (rune == 0x03 || rune == 0x15) {
        buf = '';
      } else if (rune == 0x17) {
        buf = _dropLastWord(buf);
      } else if (rune >= 0x20) {
        buf += String.fromCharCode(rune);
      }
    }
    if (buf != _line) {
      _line = buf;
      line.value = buf;
    }
  }

  void _commit(String raw) {
    final cmd = raw.trim();
    if (cmd.isEmpty || cmd.length > 200) {
      return;
    }
    if (cmd.contains(' ') || CommandIntel.commands.contains(cmd)) {
      AppStore.instance.addCommandHistory(cmd);
    }
  }

  String _dropLastWord(String value) {
    var trimmed = value;
    while (trimmed.endsWith(' ')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    final index = trimmed.lastIndexOf(' ');
    return index < 0 ? '' : trimmed.substring(0, index + 1);
  }

  void applyCompletion(String insert) {
    if (insert.isEmpty || state != SessionState.connected) {
      return;
    }
    _send(insert);
    _line += insert;
    line.value = _line;
  }

  void key(TerminalKey key) {
    final useCtrl = ctrl;
    final useAlt = alt;
    if (ctrl || alt) {
      ctrl = false;
      alt = false;
      _notify();
    }
    terminal.keyInput(key, ctrl: useCtrl, alt: useAlt);
  }

  void sendRaw(String data) => _send(data);

  void toggleCtrl() {
    ctrl = !ctrl;
    _notify();
  }

  void toggleAlt() {
    alt = !alt;
    _notify();
  }

  void run(String command) {
    final trimmed = command.trim();
    if (trimmed.isNotEmpty) {
      AppStore.instance.addCommandHistory(trimmed);
    }
    _line = '';
    line.value = '';
    _send('$command\r');
  }

  void paste(String text) {
    final normalized = text.replaceAll('\r\n', '\r').replaceAll('\n', '\r');
    if (ctrl || alt) {
      ctrl = false;
      alt = false;
      _notify();
    }
    terminal.paste(normalized);
  }

  String selectedText() {
    final selection = controller.selection;
    if (selection == null) {
      return '';
    }
    return terminal.buffer.getText(selection);
  }

  void disconnect() {
    _generation++;
    _teardown();
    if (state != SessionState.failed) {
      state = SessionState.closed;
    }
    _notify();
  }

  @override
  void dispose() {
    _generation++;
    _teardown();
    _disposed = true;
    line.dispose();
    controller.dispose();
    super.dispose();
  }
}

class SessionManager extends ChangeNotifier {
  SessionManager._();

  static final SessionManager instance = SessionManager._();

  final List<TerminalSession> _sessions = [];
  int _active = 0;

  List<TerminalSession> get sessions => List.unmodifiable(_sessions);

  int get active {
    if (_sessions.isEmpty) {
      return 0;
    }
    if (_active < 0) {
      return 0;
    }
    if (_active >= _sessions.length) {
      return _sessions.length - 1;
    }
    return _active;
  }

  TerminalSession? get current => _sessions.isEmpty ? null : _sessions[active];

  TerminalSession? get connectedCurrent {
    final session = current;
    if (session != null && session.isConnected) {
      return session;
    }
    for (final s in _sessions) {
      if (s.isConnected) {
        return s;
      }
    }
    return null;
  }

  TerminalSession open(Host host) {
    final session = TerminalSession(host);
    session.addListener(notifyListeners);
    _sessions.add(session);
    _active = _sessions.length - 1;
    notifyListeners();
    unawaited(session.start());
    return session;
  }

  void select(int index) {
    if (index < 0 || index >= _sessions.length) {
      return;
    }
    _active = index;
    notifyListeners();
  }

  void selectSession(TerminalSession session) {
    final index = _sessions.indexOf(session);
    if (index >= 0) {
      select(index);
    }
  }

  void close(TerminalSession session) {
    final index = _sessions.indexOf(session);
    if (index < 0) {
      return;
    }
    session.removeListener(notifyListeners);
    _sessions.removeAt(index);
    if (_active > index || _active >= _sessions.length) {
      _active = _active - 1;
    }
    if (_active < 0) {
      _active = 0;
    }
    session.dispose();
    notifyListeners();
  }

  void closeAll() {
    for (final session in _sessions) {
      session.removeListener(notifyListeners);
      session.dispose();
    }
    _sessions.clear();
    _active = 0;
    notifyListeners();
  }
}

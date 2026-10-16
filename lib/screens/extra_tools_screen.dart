import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../nav.dart';
import '../theme.dart';
import '../widgets/common.dart';

enum _EncMode { base64, url, jwt }

class EncoderScreen extends StatefulWidget {
  const EncoderScreen({super.key});

  @override
  State<EncoderScreen> createState() => _EncoderScreenState();
}

class _EncoderScreenState extends State<EncoderScreen> {
  final TextEditingController _input = TextEditingController();
  _EncMode _mode = _EncMode.base64;
  bool _decode = false;
  String _output = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _input.addListener(_run);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _run() {
    final text = _input.text;
    String out = '';
    String? err;
    if (text.isEmpty) {
      setState(() {
        _output = '';
        _error = null;
      });
      return;
    }
    try {
      switch (_mode) {
        case _EncMode.base64:
          out = _decode ? utf8.decode(base64.decode(base64.normalize(text.trim()))) : base64.encode(utf8.encode(text));
        case _EncMode.url:
          out = _decode ? Uri.decodeComponent(text.trim()) : Uri.encodeComponent(text);
        case _EncMode.jwt:
          out = _decodeJwt(text.trim());
      }
    } catch (_) {
      err = 'Не удалось обработать ввод';
    }
    setState(() {
      _output = out;
      _error = err;
    });
  }

  String _decodeJwt(String token) {
    final parts = token.split('.');
    if (parts.length < 2) {
      throw const FormatException('bad jwt');
    }
    final header = utf8.decode(base64.decode(base64.normalize(parts[0])));
    final payload = utf8.decode(base64.decode(base64.normalize(parts[1])));
    final encoder = const JsonEncoder.withIndent('  ');
    final h = encoder.convert(jsonDecode(header));
    final p = encoder.convert(jsonDecode(payload));
    return 'HEADER\n$h\n\nPAYLOAD\n$p';
  }

  void _setMode(_EncMode mode) {
    setState(() => _mode = mode);
    _run();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Кодировщик')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<_EncMode>(
            segments: const [
              ButtonSegment(value: _EncMode.base64, label: Text('Base64')),
              ButtonSegment(value: _EncMode.url, label: Text('URL')),
              ButtonSegment(value: _EncMode.jwt, label: Text('JWT')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => _setMode(s.first),
          ),
          const SizedBox(height: 14),
          if (_mode != _EncMode.jwt)
            Row(
              children: [
                Expanded(child: _ModeChip(label: 'Кодировать', active: !_decode, onTap: () => _setDecode(false))),
                const SizedBox(width: 10),
                Expanded(child: _ModeChip(label: 'Декодировать', active: _decode, onTap: () => _setDecode(true))),
              ],
            ),
          if (_mode != _EncMode.jwt) const SizedBox(height: 14),
          TextField(
            controller: _input,
            autocorrect: false,
            maxLines: 5,
            style: AppFonts.monoStyle(size: 14),
            decoration: InputDecoration(
              labelText: _mode == _EncMode.jwt ? 'JWT-токен' : 'Входной текст',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          _OutputCard(text: _output, error: _error),
        ],
      ),
    );
  }

  void _setDecode(bool value) {
    setState(() => _decode = value);
    _run();
  }
}

class HashScreen extends StatefulWidget {
  const HashScreen({super.key});

  @override
  State<HashScreen> createState() => _HashScreenState();
}

class _HashScreenState extends State<HashScreen> {
  final TextEditingController _input = TextEditingController();
  Map<String, String> _hashes = const {};

  @override
  void initState() {
    super.initState();
    _input.addListener(_run);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _run() {
    final text = _input.text;
    if (text.isEmpty) {
      setState(() => _hashes = const {});
      return;
    }
    final bytes = utf8.encode(text);
    setState(() {
      _hashes = {
        'MD5': md5.convert(bytes).toString(),
        'SHA-1': sha1.convert(bytes).toString(),
        'SHA-256': sha256.convert(bytes).toString(),
        'SHA-512': sha512.convert(bytes).toString(),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Хеши')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _input,
            autocorrect: false,
            maxLines: 4,
            style: AppFonts.monoStyle(size: 14),
            decoration: const InputDecoration(labelText: 'Текст для хеширования', alignLabelWithHint: true),
          ),
          const SizedBox(height: 16),
          if (_hashes.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(child: Text('Введите текст выше', style: TextStyle(color: AppColors.textDim))),
            )
          else
            for (final e in _hashes.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HashCard(algo: e.key, value: e.value),
              ),
        ],
      ),
    );
  }
}

class NetProbeScreen extends StatefulWidget {
  const NetProbeScreen({super.key});

  @override
  State<NetProbeScreen> createState() => _NetProbeScreenState();
}

class _NetProbeScreenState extends State<NetProbeScreen> {
  final TextEditingController _host = TextEditingController(text: 'example.com');
  final TextEditingController _port = TextEditingController(text: '443');
  bool _busy = false;
  List<String> _addresses = const [];
  String? _dnsError;
  String? _tcpResult;
  bool _tcpOpen = false;

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final host = _host.text.trim();
    if (host.isEmpty || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _dnsError = null;
      _addresses = const [];
      _tcpResult = null;
    });
    try {
      final result = await InternetAddress.lookup(host).timeout(const Duration(seconds: 6));
      setState(() => _addresses = result.map((a) => a.address).toList());
    } catch (_) {
      setState(() => _dnsError = 'Не удалось разрешить имя');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _checkPort() async {
    final host = _host.text.trim();
    final port = int.tryParse(_port.text.trim());
    if (host.isEmpty || port == null || port < 1 || port > 65535 || _busy) {
      setState(() => _tcpResult = 'Укажите хост и порт (1–65535)');
      return;
    }
    setState(() {
      _busy = true;
      _tcpResult = null;
    });
    final watch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      watch.stop();
      socket.destroy();
      setState(() {
        _tcpOpen = true;
        _tcpResult = 'Порт $port открыт · ${watch.elapsedMilliseconds} мс';
      });
    } catch (_) {
      watch.stop();
      setState(() {
        _tcpOpen = false;
        _tcpResult = 'Порт $port закрыт или недоступен';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DNS и порты')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _host,
            autocorrect: false,
            keyboardType: TextInputType.url,
            style: AppFonts.monoStyle(size: 15),
            decoration: const InputDecoration(labelText: 'Хост или домен', prefixIcon: Icon(Icons.dns_rounded)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _lookup,
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text('DNS lookup'),
                ),
              ),
            ],
          ),
          if (_dnsError != null) ...[
            const SizedBox(height: 12),
            Text(_dnsError!, style: TextStyle(color: AppColors.red)),
          ],
          if (_addresses.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _addresses.length; i++)
                    InkWell(
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: _addresses[i]));
                        showSnack('Скопировано: ${_addresses[i]}');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: i == _addresses.length - 1 ? null : Border(bottom: BorderSide(color: AppColors.border)),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(_addresses[i], style: AppFonts.monoStyle(size: 14))),
                            Icon(Icons.copy_rounded, size: 15, color: AppColors.textDim),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          const SectionHeader('Проверка порта (TCP)', padding: EdgeInsets.only(bottom: 10)),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _port,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppFonts.monoStyle(size: 15),
                  decoration: const InputDecoration(labelText: 'Порт'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _checkPort,
                    icon: _busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.network_check_rounded, size: 18),
                    label: const Text('Проверить'),
                  ),
                ),
              ),
            ],
          ),
          if (_tcpResult != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (_tcpOpen ? AppColors.green : AppColors.red).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(_tcpOpen ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: _tcpOpen ? AppColors.green : AppColors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_tcpResult!,
                        style: TextStyle(color: _tcpOpen ? AppColors.green : AppColors.red, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.97,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.accent.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? AppColors.accent : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? AppColors.accent : AppColors.textDim,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}

class _OutputCard extends StatelessWidget {
  const _OutputCard({required this.text, this.error});

  final String text;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(error!, style: TextStyle(color: AppColors.red)),
      );
    }
    if (text.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 30),
        child: Center(child: Text('Результат появится здесь', style: TextStyle(color: AppColors.textDim))),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(text, style: AppFonts.monoStyle(size: 14)),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                showSnack('Скопировано');
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Копировать'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HashCard extends StatelessWidget {
  const _HashCard({required this.algo, required this.value});

  final String algo;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: value));
        showSnack('$algo скопирован');
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(algo, style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 13)),
                const Spacer(),
                Icon(Icons.copy_rounded, size: 14, color: AppColors.textDim),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(value, style: AppFonts.monoStyle(size: 13)),
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../nav.dart';
import '../services/keygen.dart';
import '../services/sessions.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

class KeysScreen extends StatelessWidget {
  const KeysScreen({super.key, this.standalone = false});

  final bool standalone;

  Future<void> _showAddMenu(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetTitle('Новый ключ'),
            ListTile(
              leading: const GradientIcon(icon: Icons.auto_awesome_rounded, size: 38),
              title: const Text('Сгенерировать Ed25519'),
              subtitle: Text('Быстрый и надёжный современный ключ', style: TextStyle(color: AppColors.textDim)),
              onTap: () => Navigator.of(sheetContext).pop('generate'),
            ),
            ListTile(
              leading: GradientIcon(icon: Icons.file_download_rounded, color: AppColors.green, size: 38),
              title: const Text('Импортировать'),
              subtitle: Text('OpenSSH, RSA или EC в формате PEM', style: TextStyle(color: AppColors.textDim)),
              onTap: () => Navigator.of(sheetContext).pop('import'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) {
      return;
    }
    if (choice == 'generate') {
      await _generate(context);
    } else {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const KeyImportScreen()));
    }
  }

  Future<void> _generate(BuildContext context) async {
    final name = await promptText(
      title: 'Новый ключ Ed25519',
      label: 'Название',
      initial: 'Ключ ${AppStore.instance.keys.length + 1}',
      confirmLabel: 'Создать',
    );
    if (name == null || !context.mounted) {
      return;
    }
    try {
      final comment = 'shellbox-${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')}';
      final generated = await KeyGen.ed25519(comment);
      final key = SshKey(
        id: AppStore.newId(),
        name: name,
        type: generated.type,
        publicKey: generated.publicLine,
        createdAt: DateTime.now(),
      );
      await AppStore.instance.saveKey(key, privatePem: generated.privatePem);
      if (!context.mounted) {
        return;
      }
      await showPublicKeySheet(context, key);
    } catch (e) {
      showSnack('Не удалось создать ключ: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ключи')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'keys-fab',
        onPressed: () => _showAddMenu(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: ListenableBuilder(
        listenable: AppStore.instance,
        builder: (context, _) {
          final keys = AppStore.instance.keys;
          if (keys.isEmpty) {
            return EmptyState(
              icon: Icons.key_rounded,
              title: 'Нет SSH-ключей',
              message:
                  'Вход по ключу безопаснее и удобнее пароля. Сгенерируйте новый ключ или импортируйте существующий.',
              actionLabel: 'Добавить ключ',
              onAction: () => _showAddMenu(context),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            itemCount: keys.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _KeyTile(sshKey: keys[index]),
          );
        },
      ),
    );
  }
}

class _KeyTile extends StatelessWidget {
  const _KeyTile({required this.sshKey});

  final SshKey sshKey;

  Future<void> _onMenu(BuildContext context, String action) async {
    switch (action) {
      case 'public':
        await showPublicKeySheet(context, sshKey);
      case 'private':
        final ok = await confirmAction(
          title: 'Скопировать приватный ключ?',
          message:
              'Приватный ключ даёт полный доступ ко всем серверам, где он установлен. Не отправляйте его никому и не храните в открытом виде.',
          confirmLabel: 'Скопировать',
        );
        if (!ok) {
          return;
        }
        final pem = await AppStore.instance.readPrivateKey(sshKey.id);
        if (pem == null) {
          showSnack('Приватный ключ не найден', error: true);
          return;
        }
        await Clipboard.setData(ClipboardData(text: pem));
        showSnack('Приватный ключ скопирован');
      case 'rename':
        final name = await promptText(title: 'Переименовать ключ', label: 'Название', initial: sshKey.name);
        if (name == null) {
          return;
        }
        await AppStore.instance.saveKey(sshKey.copyWith(name: name));
      case 'delete':
        final used = AppStore.instance.hostsUsingKey(sshKey.id);
        final ok = await confirmAction(
          title: 'Удалить ключ «${sshKey.name}»?',
          message: used > 0
              ? 'Ключ используется в хостах: $used. Они будут переключены на вход по паролю. Действие нельзя отменить.'
              : 'Приватный ключ будет удалён с устройства. Действие нельзя отменить.',
        );
        if (!ok) {
          return;
        }
        await AppStore.instance.deleteKey(sshKey.id);
        showSnack('Ключ удалён');
    }
  }

  @override
  Widget build(BuildContext context) {
    final used = AppStore.instance.hostsUsingKey(sshKey.id);
    final date = sshKey.createdAt;
    final created = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showPublicKeySheet(context, sshKey),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Row(
            children: [
              GradientIcon(icon: Icons.key_rounded, color: AppColors.yellow, size: 42),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sshKey.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(sshKey.type, style: AppFonts.monoStyle(size: 12, color: AppColors.textDim)),
                    const SizedBox(height: 2),
                    Text(
                      used > 0 ? 'Создан $created · хостов: $used' : 'Создан $created',
                      style: TextStyle(color: AppColors.textDim, fontSize: 12),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: AppColors.textDim),
                onSelected: (value) => _onMenu(context, value),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'public',
                    child: ListTile(leading: Icon(Icons.public_rounded), title: Text('Публичный ключ')),
                  ),
                  PopupMenuItem(
                    value: 'private',
                    child: ListTile(leading: Icon(Icons.lock_rounded), title: Text('Копировать приватный')),
                  ),
                  PopupMenuItem(
                    value: 'rename',
                    child: ListTile(leading: Icon(Icons.edit_rounded), title: Text('Переименовать')),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline_rounded, color: AppColors.red),
                      title: Text('Удалить', style: TextStyle(color: AppColors.red)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showPublicKeySheet(BuildContext context, SshKey key) async {
  final installCommand = 'echo "${key.publicKey}" >> ~/.ssh/authorized_keys';
  final fullInstall =
      'mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo "${key.publicKey}" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys';
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final session = SessionManager.instance.connectedCurrent;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetTitle(key.name, subtitle: 'Публичный ключ · ${key.type}'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MonoBox(key.publicKey),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: key.publicKey));
                        showSnack('Публичный ключ скопирован');
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Копировать'),
                    ),
                    const SizedBox(height: 20),
                    const FieldLabel('Добавьте ключ на сервер командой'),
                    MonoBox(installCommand),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: installCommand));
                        showSnack('Команда скопирована');
                      },
                      icon: const Icon(Icons.terminal_rounded),
                      label: const Text('Копировать команду'),
                    ),
                    if (session != null) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          session.run(fullInstall);
                          Navigator.of(sheetContext).pop();
                          showSnack('Ключ добавлен на ${session.host.title}');
                        },
                        icon: Icon(Icons.bolt_rounded, color: AppColors.yellow),
                        label: Text('Установить на ${session.host.title}'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class KeyImportScreen extends StatefulWidget {
  const KeyImportScreen({super.key});

  @override
  State<KeyImportScreen> createState() => _KeyImportScreenState();
}

class _KeyImportScreenState extends State<KeyImportScreen> {
  final _name = TextEditingController();
  final _pem = TextEditingController();
  final _passphrase = TextEditingController();
  bool _encrypted = false;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pem.addListener(_onPemChanged);
  }

  @override
  void dispose() {
    _pem.removeListener(_onPemChanged);
    _name.dispose();
    _pem.dispose();
    _passphrase.dispose();
    super.dispose();
  }

  void _onPemChanged() {
    final encrypted = KeyGen.isEncrypted(_pem.text.trim());
    if (encrypted != _encrypted || _error != null) {
      setState(() {
        _encrypted = encrypted;
        _error = null;
      });
    }
  }

  Future<void> _fromFile() async {
    try {
      final files = await FilePicker.pickFiles(dialogTitle: 'Выберите приватный ключ');
      if (!mounted || files.isEmpty) {
        return;
      }
      final file = files.first;
      final bytes = await file.readAsBytes();
      if (!mounted) {
        return;
      }
      if (bytes.length > 64 * 1024) {
        setState(() => _error = 'Файл слишком большой для SSH-ключа');
        return;
      }
      _pem.text = utf8.decode(bytes, allowMalformed: true);
      if (_name.text.trim().isEmpty) {
        _name.text = file.name;
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = 'Не удалось прочитать файл: $e');
    }
  }

  Future<void> _fromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) {
      return;
    }
    final text = data?.text ?? '';
    if (text.trim().isEmpty) {
      setState(() => _error = 'Буфер обмена пуст');
      return;
    }
    _pem.text = text;
  }

  Future<void> _save() async {
    final pem = _pem.text.trim();
    final name = _name.text.trim().isEmpty ? 'Импортированный ключ' : _name.text.trim();
    if (pem.isEmpty) {
      setState(() => _error = 'Вставьте приватный ключ');
      return;
    }
    if (!pem.contains('PRIVATE KEY')) {
      setState(() => _error = 'Это не приватный ключ в формате PEM');
      return;
    }
    final passphrase = _encrypted ? _passphrase.text : null;
    if (_encrypted && (passphrase == null || passphrase.isEmpty)) {
      setState(() => _error = 'Ключ зашифрован — введите парольную фразу');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final info = await compute(_inspectKey, [pem, passphrase ?? '', name]);
      final key = SshKey(
        id: AppStore.newId(),
        name: name,
        type: info.type,
        publicKey: info.publicLine,
        createdAt: DateTime.now(),
      );
      await AppStore.instance.saveKey(key, privatePem: '$pem\n', passphrase: passphrase);
      if (!mounted) {
        return;
      }
      showSnack('Ключ импортирован');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) {
        return;
      }
      final text = e.toString();
      setState(() {
        _busy = false;
        _error = _encrypted && (text.contains('passphrase') || text.contains('Decrypt') || text.contains('decrypt'))
            ? 'Неверная парольная фраза'
            : 'Не удалось прочитать ключ: $text';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Импорт ключа'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Сохранить'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Название', prefixIcon: Icon(Icons.label_outline_rounded)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _fromFile,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Из файла'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _fromClipboard,
                  icon: const Icon(Icons.content_paste_rounded),
                  label: const Text('Из буфера'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pem,
            minLines: 8,
            maxLines: 14,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.multiline,
            style: AppFonts.monoStyle(size: 11.5),
            decoration: const InputDecoration(
              hintText: '-----BEGIN OPENSSH PRIVATE KEY-----\n…\n-----END OPENSSH PRIVATE KEY-----',
              alignLabelWithHint: true,
            ),
          ),
          if (_encrypted) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _passphrase,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Парольная фраза',
                helperText: 'Ключ зашифрован',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded, color: AppColors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: TextStyle(color: AppColors.red))),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Приватный ключ хранится только в защищённом хранилище устройства и никуда не передаётся.',
            style: TextStyle(color: AppColors.textDim, fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}

KeyInfo _inspectKey(List<String> args) {
  final passphrase = args[1].isEmpty ? null : args[1];
  return KeyGen.inspect(args[0], passphrase, args[2]);
}

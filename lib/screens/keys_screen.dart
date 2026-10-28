import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
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
            SheetTitle('keys.new_key'.tr()),
            ListTile(
              leading: const GradientIcon(icon: HugeIcons.strokeRoundedSparkles, size: 38),
              title: Text('keys.generate_ed25519'.tr()),
              subtitle: Text('keys.generate_sub'.tr(), style: TextStyle(color: AppColors.textDim)),
              onTap: () => Navigator.of(sheetContext).pop('generate'),
            ),
            ListTile(
              leading: GradientIcon(icon: HugeIcons.strokeRoundedDownload04, color: AppColors.green, size: 38),
              title: Text('keys.import'.tr()),
              subtitle: Text('keys.import_sub'.tr(), style: TextStyle(color: AppColors.textDim)),
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
      title: 'keys.new_ed25519'.tr(),
      label: 'keys.name'.tr(),
      initial: 'keys.key_n'.tr(namedArgs: {'n': '${AppStore.instance.keys.length + 1}'}),
      confirmLabel: 'keys.create'.tr(),
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
      showSnack('keys.create_failed'.tr(namedArgs: {'error': '$e'}), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('nav.keys'.tr())),
      floatingActionButton: FloatingActionButton(
        heroTag: 'keys-fab',
        onPressed: () => _showAddMenu(context),
        child: const Icon(HugeIcons.strokeRoundedAdd01),
      ),
      body: ListenableBuilder(
        listenable: AppStore.instance,
        builder: (context, _) {
          final keys = AppStore.instance.keys;
          if (keys.isEmpty) {
            return EmptyState(
              icon: HugeIcons.strokeRoundedKey01,
              title: 'keys.empty_title'.tr(),
              message: 'keys.empty_msg'.tr(),
              actionLabel: 'keys.add'.tr(),
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
          title: 'keys.copy_private_title'.tr(),
          message: 'keys.copy_private_msg'.tr(),
          confirmLabel: 'keys.copy'.tr(),
        );
        if (!ok) {
          return;
        }
        final pem = await AppStore.instance.readPrivateKey(sshKey.id);
        if (pem == null) {
          showSnack('keys.private_not_found'.tr(), error: true);
          return;
        }
        await Clipboard.setData(ClipboardData(text: pem));
        showSnack('keys.private_copied'.tr());
      case 'rename':
        final name = await promptText(title: 'keys.rename'.tr(), label: 'keys.name'.tr(), initial: sshKey.name);
        if (name == null) {
          return;
        }
        await AppStore.instance.saveKey(sshKey.copyWith(name: name));
      case 'delete':
        final used = AppStore.instance.hostsUsingKey(sshKey.id);
        final ok = await confirmAction(
          title: 'keys.delete_title'.tr(namedArgs: {'name': sshKey.name}),
          message: used > 0
              ? 'keys.delete_used_msg'.tr(namedArgs: {'count': '$used'})
              : 'keys.delete_msg'.tr(),
        );
        if (!ok) {
          return;
        }
        await AppStore.instance.deleteKey(sshKey.id);
        showSnack('keys.deleted'.tr());
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
              GradientIcon(icon: HugeIcons.strokeRoundedKey01, color: AppColors.yellow, size: 42),
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
                      used > 0
                          ? 'keys.created_used'.tr(namedArgs: {'date': created, 'count': '$used'})
                          : 'keys.created'.tr(namedArgs: {'date': created}),
                      style: TextStyle(color: AppColors.textDim, fontSize: 12),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(HugeIcons.strokeRoundedMoreVerticalCircle01, color: AppColors.textDim),
                onSelected: (value) => _onMenu(context, value),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'public',
                    child: ListTile(leading: const Icon(HugeIcons.strokeRoundedGlobe02), title: Text('keys.public_key'.tr())),
                  ),
                  PopupMenuItem(
                    value: 'private',
                    child: ListTile(leading: const Icon(HugeIcons.strokeRoundedSquareLock02), title: Text('keys.copy_private'.tr())),
                  ),
                  PopupMenuItem(
                    value: 'rename',
                    child: ListTile(leading: const Icon(HugeIcons.strokeRoundedEdit02), title: Text('keys.rename'.tr())),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(HugeIcons.strokeRoundedDelete02, color: AppColors.red),
                      title: Text('common.delete'.tr(), style: TextStyle(color: AppColors.red)),
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
              SheetTitle(key.name, subtitle: 'keys.public_key_sub'.tr(namedArgs: {'type': key.type})),
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
                        showSnack('keys.public_copied'.tr());
                      },
                      icon: const Icon(HugeIcons.strokeRoundedCopy01),
                      label: Text('keys.copy'.tr()),
                    ),
                    const SizedBox(height: 20),
                    FieldLabel('keys.add_to_server'.tr()),
                    MonoBox(installCommand),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: installCommand));
                        showSnack('keys.command_copied'.tr());
                      },
                      icon: const Icon(HugeIcons.strokeRoundedCommandLine),
                      label: Text('keys.copy_command'.tr()),
                    ),
                    if (session != null) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          session.run(fullInstall);
                          Navigator.of(sheetContext).pop();
                          showSnack('keys.installed_on'.tr(namedArgs: {'host': session.host.title}));
                        },
                        icon: Icon(HugeIcons.strokeRoundedFlash, color: AppColors.yellow),
                        label: Text('keys.install_on'.tr(namedArgs: {'host': session.host.title})),
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
      final files = await FilePicker.pickFiles(dialogTitle: 'keys.pick_private'.tr());
      if (!mounted || files.isEmpty) {
        return;
      }
      final file = files.first;
      final bytes = await file.readAsBytes();
      if (!mounted) {
        return;
      }
      if (bytes.length > 64 * 1024) {
        setState(() => _error = 'keys.file_too_big'.tr());
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
      setState(() => _error = 'keys.file_read_failed'.tr(namedArgs: {'error': '$e'}));
    }
  }

  Future<void> _fromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) {
      return;
    }
    final text = data?.text ?? '';
    if (text.trim().isEmpty) {
      setState(() => _error = 'keys.clipboard_empty'.tr());
      return;
    }
    _pem.text = text;
  }

  Future<void> _save() async {
    final pem = _pem.text.trim();
    final name = _name.text.trim().isEmpty ? 'keys.imported_key'.tr() : _name.text.trim();
    if (pem.isEmpty) {
      setState(() => _error = 'keys.paste_private'.tr());
      return;
    }
    if (!pem.contains('PRIVATE KEY')) {
      setState(() => _error = 'keys.not_pem'.tr());
      return;
    }
    final passphrase = _encrypted ? _passphrase.text : null;
    if (_encrypted && (passphrase == null || passphrase.isEmpty)) {
      setState(() => _error = 'keys.need_passphrase'.tr());
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
      showSnack('keys.imported'.tr());
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) {
        return;
      }
      final text = e.toString();
      setState(() {
        _busy = false;
        _error = _encrypted && (text.contains('passphrase') || text.contains('Decrypt') || text.contains('decrypt'))
            ? 'keys.wrong_passphrase'.tr()
            : 'keys.key_read_failed'.tr(namedArgs: {'error': text});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('keys.import_title'.tr()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('common.save'.tr()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: 'keys.name'.tr(), prefixIcon: const Icon(HugeIcons.strokeRoundedTag01)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _fromFile,
                  icon: const Icon(HugeIcons.strokeRoundedFolderOpen),
                  label: Text('keys.from_file'.tr()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _fromClipboard,
                  icon: const Icon(HugeIcons.strokeRoundedClipboard),
                  label: Text('keys.from_clipboard'.tr()),
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
                labelText: 'keys.passphrase'.tr(),
                helperText: 'keys.encrypted'.tr(),
                prefixIcon: const Icon(HugeIcons.strokeRoundedSquareLock01),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'common.show_password'.tr() : 'common.hide_password'.tr(),
                  icon: Icon(_obscure ? HugeIcons.strokeRoundedView : HugeIcons.strokeRoundedViewOffSlash),
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
                Icon(HugeIcons.strokeRoundedAlert02, color: AppColors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: TextStyle(color: AppColors.red))),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'keys.security_note'.tr(),
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

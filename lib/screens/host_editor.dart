import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../nav.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'keys_screen.dart';

class HostEditorScreen extends StatefulWidget {
  const HostEditorScreen({super.key, this.host});

  final Host? host;

  @override
  State<HostEditorScreen> createState() => _HostEditorScreenState();
}

class _HostEditorScreenState extends State<HostEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _group;
  late final TextEditingController _address;
  late final TextEditingController _port;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _startup;

  late final String _id;
  late Protocol _protocol;
  late int _color;
  late AuthType _auth;
  String? _keyId;
  late bool _legacy;
  bool _hasSavedPassword = false;
  bool _removePassword = false;
  bool _obscure = true;
  bool _saving = false;

  bool get _isExisting => AppStore.instance.hostById(_id) != null;

  @override
  void initState() {
    super.initState();
    final host = widget.host;
    _id = host?.id ?? AppStore.newId();
    _label = TextEditingController(text: host?.label ?? '');
    _group = TextEditingController(text: host?.group ?? '');
    _address = TextEditingController(text: host?.address ?? '');
    _port = TextEditingController(text: '${host?.port ?? 22}');
    _username = TextEditingController(text: host?.username ?? 'root');
    _password = TextEditingController();
    _startup = TextEditingController(text: host?.startupCommand ?? '');
    _protocol = host?.protocol ?? Protocol.ssh;
    _color = host?.color ?? AppColors.hostColors.first;
    _auth = host?.auth ?? AuthType.password;
    _keyId = AppStore.instance.keyById(host?.keyId)?.id;
    _legacy = host?.legacy ?? false;
    _loadPasswordState();
  }

  Future<void> _loadPasswordState() async {
    final saved = await AppStore.instance.hasPassword(_id);
    if (!mounted) {
      return;
    }
    setState(() => _hasSavedPassword = saved);
  }

  @override
  void dispose() {
    _label.dispose();
    _group.dispose();
    _address.dispose();
    _port.dispose();
    _username.dispose();
    _password.dispose();
    _startup.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_protocol.isSsh && _auth == AuthType.key && _keyId == null) {
      showSnack('editor.pick_key_or_password'.tr(), error: true);
      return;
    }
    setState(() => _saving = true);
    final previous = AppStore.instance.hostById(_id);
    final host = Host(
      id: _id,
      protocol: _protocol,
      label: _label.text.trim(),
      group: _group.text.trim(),
      address: _address.text.trim(),
      port: int.parse(_port.text.trim()),
      username: _username.text.trim(),
      auth: _protocol.isSsh ? _auth : AuthType.password,
      keyId: _protocol.isSsh && _auth == AuthType.key ? _keyId : null,
      startupCommand: _startup.text.trim(),
      color: _color,
      legacy: _legacy,
      lastUsed: previous?.lastUsed ?? widget.host?.lastUsed,
    );
    String? password;
    if (_password.text.isNotEmpty) {
      password = _password.text;
    } else if (_removePassword) {
      password = '';
    }
    await AppStore.instance.saveHost(host, password: password);
    if (!mounted) {
      return;
    }
    showSnack(previous == null ? 'editor.host_added'.tr() : 'editor.changes_saved'.tr());
    Navigator.of(context).pop(host);
  }

  Future<void> _openKeys() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const KeysScreen(standalone: true)));
    if (!mounted) {
      return;
    }
    final keys = AppStore.instance.keys;
    setState(() {
      if (_keyId == null && keys.isNotEmpty) {
        _keyId = keys.last.id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isExisting ? 'editor.edit_host'.tr() : 'editor.new_host'.tr()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: _saving ? null : _save,
              child: Text('common.save'.tr()),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: AppStore.instance,
        builder: (context, _) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _buildColorPicker(),
              const SizedBox(height: 20),
              FieldLabel('editor.protocol'.tr()),
              _buildProtocolPicker(),
              const SizedBox(height: 20),
              FieldLabel('editor.general'.tr()),
              TextFormField(
                controller: _label,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'keys.name'.tr(),
                  hintText: 'editor.name_hint'.tr(),
                  prefixIcon: const Icon(HugeIcons.strokeRoundedTag01),
                ),
              ),
              const SizedBox(height: 12),
              _buildGroupField(),
              const SizedBox(height: 20),
              FieldLabel('editor.connection'.tr()),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _address,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      style: AppFonts.monoStyle(size: 14),
                      decoration: InputDecoration(
                        labelText: 'editor.address'.tr(),
                        hintText: '192.168.1.10',
                        prefixIcon: const Icon(HugeIcons.strokeRoundedGlobe02),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return 'editor.address_required'.tr();
                        }
                        if (text.contains(' ') || text.contains('@')) {
                          return 'editor.address_invalid'.tr();
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 104,
                    child: TextFormField(
                      controller: _port,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                      style: AppFonts.monoStyle(size: 14),
                      decoration: InputDecoration(labelText: 'editor.port'.tr()),
                      validator: (value) {
                        final port = int.tryParse(value?.trim() ?? '');
                        if (port == null || port < 1 || port > 65535) {
                          return '1–65535';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _username,
                autocorrect: false,
                style: AppFonts.monoStyle(size: 14),
                decoration: InputDecoration(
                  labelText: 'editor.user'.tr(),
                  hintText: _protocol.isFtp ? 'editor.anon_hint'.tr() : null,
                  prefixIcon: const Icon(HugeIcons.strokeRoundedUser),
                ),
                validator: (value) => !_protocol.isFtp && (value?.trim() ?? '').isEmpty ? 'editor.user_required'.tr() : null,
              ),
              const SizedBox(height: 20),
              if (_protocol.isSsh) FieldLabel('editor.auth_method'.tr()),
              if (_protocol.isSsh)
                SegmentedButton<AuthType>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: AuthType.password,
                      label: Text('password.title'.tr()),
                      icon: const Icon(HugeIcons.strokeRoundedLockPassword),
                    ),
                    ButtonSegment(
                      value: AuthType.key,
                      label: Text('editor.ssh_key'.tr()),
                      icon: const Icon(HugeIcons.strokeRoundedKey01),
                    ),
                  ],
                  selected: {_auth},
                  onSelectionChanged: (value) => setState(() => _auth = value.first),
                ),
              if (_protocol.isSsh) const SizedBox(height: 12),
              if (_protocol.isSsh && _auth == AuthType.key) _buildKeySelector(),
              if (_protocol.isSsh && _auth == AuthType.key) const SizedBox(height: 12),
              if (!_protocol.isSsh) FieldLabel('password.title'.tr()),
              _buildPasswordField(),
              if (_protocol.isSsh) ...[
                const SizedBox(height: 20),
                FieldLabel('editor.advanced'.tr()),
                TextFormField(
                  controller: _startup,
                  autocorrect: false,
                  style: AppFonts.monoStyle(size: 14),
                  decoration: InputDecoration(
                    labelText: 'editor.startup_command'.tr(),
                    hintText: 'cd /var/www && ls',
                    prefixIcon: const Icon(HugeIcons.strokeRoundedPlay),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: AppSwitchTile(
                    value: _legacy,
                    onChanged: (value) => setState(() => _legacy = value),
                    title: 'editor.legacy_algos'.tr(),
                    subtitle: Text('editor.legacy_algos_desc'.tr()),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    return Row(
      children: [
        GradientIcon(icon: protocolIcon(_protocol), color: Color(_color), size: 52),
        const SizedBox(width: 16),
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final value in AppColors.hostColors)
                Pressable(
                  scale: 0.88,
                  onTap: () => setState(() => _color = value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Color(value),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == value ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: _color == value
                          ? [BoxShadow(color: Color(value).withValues(alpha: 0.6), blurRadius: 10)]
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _setProtocol(Protocol protocol) {
    final currentPort = int.tryParse(_port.text.trim());
    setState(() {
      if (currentPort == null || currentPort == _protocol.defaultPort || (_protocol.isFtp && currentPort == 990)) {
        _port.text = '${protocol.defaultPort}';
      }
      if (_protocol.isFtp && protocol.isFtp == false && _username.text.trim().isEmpty) {
        _username.text = 'root';
      }
      _protocol = protocol;
    });
  }

  Widget _buildProtocolPicker() {
    final base = _protocol.isFtp ? Protocol.ftp : _protocol;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<Protocol>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: Protocol.ssh, label: Text('SSH'), icon: Icon(HugeIcons.strokeRoundedCommandLine)),
            ButtonSegment(value: Protocol.ftp, label: Text('FTP'), icon: Icon(HugeIcons.strokeRoundedFolder02)),
          ],
          selected: {base},
          onSelectionChanged: (value) => _setProtocol(value.first),
        ),
        if (_protocol.isSsh)
          Padding(
            padding: EdgeInsets.only(top: 8, left: 4),
            child: Text(
              'editor.ssh_note'.tr(),
              style: TextStyle(color: AppColors.textDim, fontSize: 12.5),
            ),
          ),
        if (_protocol.isFtp)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Card(
              child: AppSwitchTile(
                value: _protocol == Protocol.ftps,
                onChanged: (value) => setState(() => _protocol = value ? Protocol.ftps : Protocol.ftp),
                title: 'editor.tls_title'.tr(),
                subtitle: Text('editor.tls_desc'.tr()),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGroupField() {
    final groups = AppStore.instance.groups;
    return TextFormField(
      controller: _group,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: 'editor.group'.tr(),
        hintText: 'hosts.no_group'.tr(),
        prefixIcon: const Icon(HugeIcons.strokeRoundedFolder01),
        suffixIcon: groups.isEmpty
            ? null
            : PopupMenuButton<String>(
                tooltip: 'editor.existing_groups'.tr(),
                icon: const Icon(HugeIcons.strokeRoundedArrowDown01),
                onSelected: (value) => setState(() => _group.text = value),
                itemBuilder: (_) => [
                  for (final group in groups) PopupMenuItem(value: group, child: Text(group)),
                ],
              ),
      ),
    );
  }

  Widget _buildKeySelector() {
    final keys = AppStore.instance.keys;
    if (keys.isEmpty) {
      return Card(
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: GradientIcon(icon: HugeIcons.strokeRoundedKey01, color: AppColors.yellow, size: 36),
          title: Text('editor.no_keys_yet'.tr()),
          subtitle: Text('editor.no_keys_sub'.tr(), style: TextStyle(color: AppColors.textDim)),
          trailing: const Icon(HugeIcons.strokeRoundedArrowRight01),
          onTap: _openKeys,
        ),
      );
    }
    final selected = keys.any((k) => k.id == _keyId) ? _keyId : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('keys-${keys.length}-$selected'),
      initialValue: selected,
      isExpanded: true,
      dropdownColor: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(12),
      decoration: InputDecoration(labelText: 'editor.ssh_key'.tr(), prefixIcon: const Icon(HugeIcons.strokeRoundedKey01)),
      items: [
        for (final key in keys)
          DropdownMenuItem(
            value: key.id,
            child: Text('${key.name}  ·  ${key.type}', overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) => setState(() => _keyId = value),
      validator: (value) => value == null ? 'editor.pick_key'.tr() : null,
    );
  }

  Widget _buildPasswordField() {
    final hint = _removePassword
        ? 'editor.pw_will_remove'.tr()
        : (_hasSavedPassword
            ? 'editor.pw_saved_hint'.tr()
            : 'editor.pw_ask_hint'.tr());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _password,
          obscureText: _obscure,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) {
            if (_removePassword) {
              setState(() => _removePassword = false);
            }
          },
          decoration: InputDecoration(
            labelText: _protocol.isSsh && _auth == AuthType.key ? 'editor.pw_fallback'.tr() : 'password.title'.tr(),
            hintText: hint,
            helperText: _hasSavedPassword && !_removePassword ? 'editor.saved'.tr() : null,
            prefixIcon: const Icon(HugeIcons.strokeRoundedSquareLock01),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? HugeIcons.strokeRoundedView : HugeIcons.strokeRoundedViewOffSlash),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        if (_hasSavedPassword && !_removePassword)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.red),
              onPressed: () => setState(() {
                _removePassword = true;
                _password.clear();
              }),
              icon: const Icon(HugeIcons.strokeRoundedDelete02, size: 18),
              label: Text('editor.remove_saved_pw'.tr()),
            ),
          ),
      ],
    );
  }
}

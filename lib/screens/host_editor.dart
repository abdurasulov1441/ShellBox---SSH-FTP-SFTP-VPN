import 'package:flutter/material.dart';
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
      showSnack('Выберите SSH-ключ или переключитесь на вход по паролю', error: true);
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
    showSnack(previous == null ? 'Хост добавлен' : 'Изменения сохранены');
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
        title: Text(_isExisting ? 'Изменить хост' : 'Новый хост'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: _saving ? null : _save,
              child: const Text('Сохранить'),
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
              const FieldLabel('Протокол'),
              _buildProtocolPicker(),
              const SizedBox(height: 20),
              const FieldLabel('Основное'),
              TextFormField(
                controller: _label,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  hintText: 'Например, Рабочий сервер',
                  prefixIcon: Icon(Icons.label_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              _buildGroupField(),
              const SizedBox(height: 20),
              const FieldLabel('Подключение'),
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
                      decoration: const InputDecoration(
                        labelText: 'Адрес',
                        hintText: '192.168.1.10',
                        prefixIcon: Icon(Icons.public_rounded),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return 'Укажите адрес';
                        }
                        if (text.contains(' ') || text.contains('@')) {
                          return 'Неверный адрес';
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
                      decoration: const InputDecoration(labelText: 'Порт'),
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
                  labelText: 'Пользователь',
                  hintText: _protocol.isFtp ? 'Пусто — анонимный вход' : null,
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
                validator: (value) => !_protocol.isFtp && (value?.trim() ?? '').isEmpty ? 'Укажите пользователя' : null,
              ),
              const SizedBox(height: 20),
              if (_protocol.isSsh) const FieldLabel('Способ входа'),
              if (_protocol.isSsh)
                SegmentedButton<AuthType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: AuthType.password,
                      label: Text('Пароль'),
                      icon: Icon(Icons.password_rounded),
                    ),
                    ButtonSegment(
                      value: AuthType.key,
                      label: Text('SSH-ключ'),
                      icon: Icon(Icons.key_rounded),
                    ),
                  ],
                  selected: {_auth},
                  onSelectionChanged: (value) => setState(() => _auth = value.first),
                ),
              if (_protocol.isSsh) const SizedBox(height: 12),
              if (_protocol.isSsh && _auth == AuthType.key) _buildKeySelector(),
              if (_protocol.isSsh && _auth == AuthType.key) const SizedBox(height: 12),
              if (!_protocol.isSsh) const FieldLabel('Пароль'),
              _buildPasswordField(),
              if (_protocol.isSsh) ...[
                const SizedBox(height: 20),
                const FieldLabel('Дополнительно'),
                TextFormField(
                  controller: _startup,
                  autocorrect: false,
                  style: AppFonts.monoStyle(size: 14),
                  decoration: const InputDecoration(
                    labelText: 'Команда при входе',
                    hintText: 'cd /var/www && ls',
                    prefixIcon: Icon(Icons.play_arrow_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: SwitchListTile(
                    value: _legacy,
                    onChanged: (value) => setState(() => _legacy = value),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    title: const Text('Старые алгоритмы'),
                    subtitle: const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Разрешить ssh-rsa (SHA-1), CBC-шифры и DH-sha1. Нужно для старых коммутаторов, роутеров и NAS. Менее безопасно.',
                        style: TextStyle(color: AppColors.textDim, fontSize: 12.5, height: 1.35),
                      ),
                    ),
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
                GestureDetector(
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
            ButtonSegment(value: Protocol.ssh, label: Text('SSH'), icon: Icon(Icons.terminal_rounded)),
            ButtonSegment(value: Protocol.ftp, label: Text('FTP'), icon: Icon(Icons.folder_copy_outlined)),
          ],
          selected: {base},
          onSelectionChanged: (value) => _setProtocol(value.first),
        ),
        if (_protocol.isSsh)
          const Padding(
            padding: EdgeInsets.only(top: 8, left: 4),
            child: Text(
              'Терминал и файлы по SFTP через одно подключение',
              style: TextStyle(color: AppColors.textDim, fontSize: 12.5),
            ),
          ),
        if (_protocol.isFtp)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Card(
              child: SwitchListTile(
                value: _protocol == Protocol.ftps,
                onChanged: (value) => setState(() => _protocol = value ? Protocol.ftps : Protocol.ftp),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                title: const Text('Шифрование TLS (FTPS)'),
                subtitle: const Text(
                  'Явный TLS через AUTH TLS (FTPES). Без него пароль передаётся открытым текстом.',
                  style: TextStyle(color: AppColors.textDim, fontSize: 12.5),
                ),
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
        labelText: 'Группа',
        hintText: 'Без группы',
        prefixIcon: const Icon(Icons.folder_outlined),
        suffixIcon: groups.isEmpty
            ? null
            : PopupMenuButton<String>(
                tooltip: 'Существующие группы',
                icon: const Icon(Icons.arrow_drop_down_rounded),
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
          leading: const GradientIcon(icon: Icons.key_rounded, color: AppColors.yellow, size: 36),
          title: const Text('Ключей пока нет'),
          subtitle: const Text('Сгенерируйте или импортируйте ключ', style: TextStyle(color: AppColors.textDim)),
          trailing: const Icon(Icons.chevron_right_rounded),
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
      decoration: const InputDecoration(labelText: 'SSH-ключ', prefixIcon: Icon(Icons.key_rounded)),
      items: [
        for (final key in keys)
          DropdownMenuItem(
            value: key.id,
            child: Text('${key.name}  ·  ${key.type}', overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) => setState(() => _keyId = value),
      validator: (value) => value == null ? 'Выберите ключ' : null,
    );
  }

  Widget _buildPasswordField() {
    final hint = _removePassword
        ? 'Сохранённый пароль будет удалён'
        : (_hasSavedPassword
            ? 'Пароль сохранён — оставьте пустым, чтобы не менять'
            : 'Не сохранять — спрашивать при входе');
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
            labelText: _protocol.isSsh && _auth == AuthType.key ? 'Пароль (запасной)' : 'Пароль',
            hintText: hint,
            helperText: _hasSavedPassword && !_removePassword ? 'сохранён' : null,
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
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
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Удалить сохранённый пароль'),
            ),
          ),
      ],
    );
  }
}

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../nav.dart';
import '../services/store.dart';
import '../services/vpn.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

class VpnScreen extends StatefulWidget {
  const VpnScreen({super.key});

  @override
  State<VpnScreen> createState() => _VpnScreenState();
}

class _VpnScreenState extends State<VpnScreen> {
  @override
  void initState() {
    super.initState();
    VpnController.instance.ensureReady();
  }

  Future<void> _import(BuildContext context) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetTitle('Импорт профиля', subtitle: 'Файл конфигурации WireGuard (.conf)'),
            ListTile(
              leading: const GradientIcon(icon: Icons.folder_open_rounded, size: 38),
              title: const Text('Из файла'),
              subtitle: Text('Выберите .conf-файл', style: TextStyle(color: AppColors.textDim)),
              onTap: () => Navigator.of(sheetContext).pop('file'),
            ),
            ListTile(
              leading: GradientIcon(icon: Icons.content_paste_rounded, color: AppColors.green, size: 38),
              title: const Text('Из буфера обмена'),
              subtitle: Text('Вставить текст конфигурации', style: TextStyle(color: AppColors.textDim)),
              onTap: () => Navigator.of(sheetContext).pop('clipboard'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!context.mounted || source == null) {
      return;
    }
    String config;
    String suggestedName;
    if (source == 'file') {
      try {
        final files = await FilePicker.pickFiles(dialogTitle: 'Выберите конфигурацию WireGuard');
        if (files.isEmpty) {
          return;
        }
        final file = files.first;
        final bytes = await file.readAsBytes();
        if (bytes.length > 64 * 1024) {
          showSnack('Файл слишком большой для конфигурации', error: true);
          return;
        }
        config = utf8.decode(bytes, allowMalformed: true);
        suggestedName = file.name.replaceAll(RegExp(r'\.conf$', caseSensitive: false), '');
      } catch (e) {
        showSnack('Не удалось прочитать файл: $e', error: true);
        return;
      }
    } else {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      config = data?.text ?? '';
      suggestedName = 'VPN ${AppStore.instance.vpnProfiles.length + 1}';
      if (config.trim().isEmpty) {
        showSnack('Буфер обмена пуст', error: true);
        return;
      }
    }
    final parsed = VpnProfile.parseConfig(config);
    if (parsed == null) {
      showSnack('Это не похоже на конфигурацию WireGuard', error: true);
      return;
    }
    if (!context.mounted) {
      return;
    }
    final name = await promptText(
      title: 'Название профиля',
      label: 'Название',
      initial: suggestedName.isEmpty ? 'VPN' : suggestedName,
      confirmLabel: 'Сохранить',
    );
    if (name == null) {
      return;
    }
    final profile = VpnProfile(
      id: AppStore.newId(),
      name: name,
      endpoint: parsed.endpoint,
      address: parsed.address,
      dns: parsed.dns,
      createdAt: DateTime.now(),
    );
    await AppStore.instance.saveVpnProfile(profile, config: config);
    showSnack('Профиль добавлен');
  }

  Future<void> _menu(BuildContext context, VpnProfile profile) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetTitle(profile.name, subtitle: profile.endpoint),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Переименовать'),
              onTap: () => Navigator.of(sheetContext).pop('rename'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: AppColors.red),
              title: Text('Удалить', style: TextStyle(color: AppColors.red)),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) {
      return;
    }
    if (action == 'rename') {
      final name = await promptText(title: 'Переименовать', label: 'Название', initial: profile.name);
      if (name != null) {
        await AppStore.instance.saveVpnProfile(profile.copyWith(name: name));
      }
    } else if (action == 'delete') {
      final controller = VpnController.instance;
      if (controller.activeId == profile.id && controller.isConnected) {
        await controller.disconnect();
      }
      final ok = await confirmAction(
        title: 'Удалить профиль «${profile.name}»?',
        message: 'Конфигурация будет удалена с устройства.',
      );
      if (ok) {
        await AppStore.instance.deleteVpnProfile(profile.id);
        showSnack('Профиль удалён');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VPN · WireGuard')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'vpn-fab',
        onPressed: () => _import(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Профиль'),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([AppStore.instance, VpnController.instance]),
        builder: (context, _) {
          final profiles = AppStore.instance.vpnProfiles;
          final controller = VpnController.instance;
          if (profiles.isEmpty) {
            return EmptyState(
              icon: Icons.vpn_key_rounded,
              title: 'Нет VPN-профилей',
              message:
                  'Импортируйте файл WireGuard (.conf) один раз, и включайте VPN прямо здесь — туннель работает для всего устройства.',
              actionLabel: 'Импортировать профиль',
              onAction: () => _import(context),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              _StatusCard(controller: controller),
              const SizedBox(height: 8),
              for (final profile in profiles)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _ProfileCard(
                    profile: profile,
                    controller: controller,
                    onToggle: () => controller.toggle(profile),
                    onMenu: () => _menu(context, profile),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Конфигурации с приватным ключом хранятся только в защищённом хранилище устройства. VPN работает системно — весь трафик, включая SSH и FTP, идёт через туннель, пока он включён.',
                style: TextStyle(color: AppColors.textDim, fontSize: 12.5, height: 1.4),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.controller});

  final VpnController controller;

  @override
  Widget build(BuildContext context) {
    final connected = controller.isConnected;
    final busy = controller.isBusy;
    final color = connected ? AppColors.green : (busy ? AppColors.yellow : AppColors.textDim);
    final active = controller.activeId == null ? null : AppStore.instance.vpnProfileById(controller.activeId!);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.16), AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          GradientIcon(
            icon: connected ? Icons.vpn_lock_rounded : Icons.vpn_key_off_rounded,
            color: color == AppColors.textDim ? AppColors.accent : color,
            size: 48,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vpnStageLabel(controller.stage),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  active != null ? active.name : 'VPN выключен',
                  style: TextStyle(color: AppColors.textDim, fontSize: 13),
                ),
                if (controller.error != null) ...[
                  const SizedBox(height: 4),
                  Text(controller.error!, style: TextStyle(color: AppColors.red, fontSize: 12)),
                ],
              ],
            ),
          ),
          if (connected || busy)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.red,
                side: BorderSide(color: AppColors.red.withValues(alpha: 0.5)),
              ),
              onPressed: controller.disconnect,
              child: const Text('Откл.'),
            ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.controller,
    required this.onToggle,
    required this.onMenu,
  });

  final VpnProfile profile;
  final VpnController controller;
  final VoidCallback onToggle;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final isActive = controller.activeId == profile.id;
    final connected = isActive && controller.isConnected;
    final busy = isActive && controller.isBusy;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          children: [
            GradientIcon(
              icon: Icons.shield_rounded,
              color: connected ? AppColors.green : AppColors.accent,
              size: 42,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(
                    profile.endpoint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.monoStyle(size: 12, color: AppColors.textDim),
                  ),
                  if (profile.address.isNotEmpty)
                    Text(
                      profile.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.monoStyle(size: 11, color: AppColors.textDim),
                    ),
                ],
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
              )
            else
              Switch(value: connected, onChanged: (_) => onToggle()),
            IconButton(
              icon: Icon(Icons.more_vert_rounded, color: AppColors.textDim),
              onPressed: onMenu,
            ),
          ],
        ),
      ),
    );
  }
}

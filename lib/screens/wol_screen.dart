import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../models.dart';
import '../nav.dart';
import '../services/activity_log.dart';
import '../services/store.dart';
import '../services/wake_on_lan.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

class WolScreen extends StatelessWidget {
  const WolScreen({super.key});

  Future<void> _wake(WolDevice device) async {
    final ok = await WakeOnLan.send(device.mac, broadcast: device.broadcast, port: device.port);
    if (ok) {
      ActivityLog.instance.success('WOL', 'wol.log_sent'.tr(namedArgs: {'mac': device.mac}));
      showSnack('wol.sent'.tr(namedArgs: {'name': device.name}));
    } else {
      showSnack('wol.failed'.tr(), error: true);
    }
  }

  Future<void> _edit(BuildContext context, [WolDevice? device]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WolSheet(device: device),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wake-on-LAN')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'wol-fab',
        onPressed: () => _edit(context),
        child: const Icon(HugeIcons.strokeRoundedAdd01),
      ),
      body: ListenableBuilder(
        listenable: AppStore.instance,
        builder: (context, _) {
          final devices = AppStore.instance.wolDevices;
          if (devices.isEmpty) {
            return EmptyState(
              icon: HugeIcons.strokeRoundedComputerArrowUp,
              title: 'wol.empty_title'.tr(),
              message: 'wol.empty_msg'.tr(),
              actionLabel: 'wol.add'.tr(),
              onAction: () => _edit(context),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            itemCount: devices.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final device = devices[index];
              return Card(
                child: Pressable(
                  scale: 0.98,
                  onTap: () => _wake(device),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                    child: Row(
                      children: [
                        GradientIcon(icon: HugeIcons.strokeRoundedComputerArrowUp, color: AppColors.green, size: 42),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(device.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                              const SizedBox(height: 3),
                              Text('${device.mac}  ·  ${device.broadcast}:${device.port}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.monoStyle(size: 12, color: AppColors.textDim)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'wol.send'.tr(),
                          icon: Icon(HugeIcons.strokeRoundedEnergy, color: AppColors.yellow),
                          onPressed: () => _wake(device),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(HugeIcons.strokeRoundedMoreVerticalCircle01, color: AppColors.textDim),
                          onSelected: (value) async {
                            if (value == 'edit') {
                              await _edit(context, device);
                            } else if (value == 'delete') {
                              final ok = await confirmAction(
                                title: 'wol.delete_title'.tr(),
                                message: 'wol.delete_msg'.tr(namedArgs: {'name': device.name}),
                              );
                              if (ok) {
                                await AppStore.instance.deleteWolDevice(device.id);
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(leading: const Icon(HugeIcons.strokeRoundedEdit02), title: Text('hosts.edit'.tr())),
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
            },
          );
        },
      ),
    );
  }
}

class _WolSheet extends StatefulWidget {
  const _WolSheet({this.device});

  final WolDevice? device;

  @override
  State<_WolSheet> createState() => _WolSheetState();
}

class _WolSheetState extends State<_WolSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.device?.name ?? '');
  late final TextEditingController _mac = TextEditingController(text: widget.device?.mac ?? '');
  late final TextEditingController _broadcast =
      TextEditingController(text: widget.device?.broadcast ?? '255.255.255.255');
  late final TextEditingController _port = TextEditingController(text: '${widget.device?.port ?? 9}');
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _mac.dispose();
    _broadcast.dispose();
    _port.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final mac = _mac.text.trim();
    if (WakeOnLan.parseMac(mac) == null) {
      setState(() => _error = 'wol.bad_mac'.tr());
      return;
    }
    final name = _name.text.trim().isEmpty ? mac : _name.text.trim();
    final port = int.tryParse(_port.text.trim()) ?? 9;
    final broadcast = _broadcast.text.trim().isEmpty ? '255.255.255.255' : _broadcast.text.trim();
    final device = WolDevice(
      id: widget.device?.id ?? AppStore.newId(),
      name: name,
      mac: mac,
      broadcast: broadcast,
      port: port,
    );
    await AppStore.instance.saveWolDevice(device);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.device != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetTitle(editing ? 'wol.edit_title'.tr() : 'wol.new_title'.tr()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'keys.name'.tr(),
                        prefixIcon: const Icon(HugeIcons.strokeRoundedComputer),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _mac,
                      autocorrect: false,
                      style: AppFonts.monoStyle(size: 15),
                      onChanged: (_) {
                        if (_error != null) {
                          setState(() => _error = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'wol.mac'.tr(),
                        hintText: 'AA:BB:CC:DD:EE:FF',
                        errorText: _error,
                        prefixIcon: const Icon(HugeIcons.strokeRoundedRouter01),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _broadcast,
                            autocorrect: false,
                            keyboardType: TextInputType.url,
                            style: AppFonts.monoStyle(size: 15),
                            decoration: InputDecoration(labelText: 'wol.broadcast'.tr()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _port,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: AppFonts.monoStyle(size: 15),
                            decoration: InputDecoration(labelText: 'wol.port'.tr()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(HugeIcons.strokeRoundedTick02, size: 18),
                      label: Text('common.save'.tr()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

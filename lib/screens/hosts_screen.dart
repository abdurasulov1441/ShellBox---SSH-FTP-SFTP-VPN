import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../models.dart';
import '../nav.dart';
import '../services/store.dart';
import '../services/vpn.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import 'host_editor.dart';
import 'vpn_screen.dart';

final _quickPattern = RegExp(
  r'^(?:(ssh|sftp|ftp|ftps)://)?([^@\s/]+)@([^:\s@/]+)(?::(\d{1,5}))?/?$',
  caseSensitive: false,
);

class HostsScreen extends StatefulWidget {
  const HostsScreen({super.key});

  @override
  State<HostsScreen> createState() => _HostsScreenState();
}

class _HostsScreenState extends State<HostsScreen> {
  final _search = TextEditingController();
  String _query = '';
  Protocol? _filter;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearch);
  }

  @override
  void dispose() {
    _search.removeListener(_onSearch);
    _search.dispose();
    super.dispose();
  }

  void _onSearch() {
    final value = _search.text.trim();
    if (value != _query) {
      setState(() => _query = value);
    }
  }

  Future<void> _addHost([Host? template]) async {
    final saved = await Navigator.of(context).push<Host>(
      MaterialPageRoute(builder: (_) => HostEditorScreen(host: template)),
    );
    if (!mounted) {
      return;
    }
    if (saved != null && template != null) {
      _search.clear();
      FocusScope.of(context).unfocus();
    }
  }

  Host? _quickHost() {
    final match = _quickPattern.firstMatch(_query);
    if (match == null) {
      return null;
    }
    final scheme = (match.group(1) ?? 'ssh').toLowerCase();
    final protocol = scheme == 'sftp' ? Protocol.ssh : Protocol.parse(scheme);
    final portText = match.group(4);
    final port = portText == null ? protocol.defaultPort : int.tryParse(portText);
    if (port == null || port < 1 || port > 65535) {
      return null;
    }
    return Host(
      id: AppStore.newId(),
      protocol: protocol,
      address: match.group(3)!,
      port: port,
      username: match.group(2)!,
    );
  }

  bool _matches(Host host, String query) {
    final q = query.toLowerCase();
    return host.title.toLowerCase().contains(q) ||
        host.address.toLowerCase().contains(q) ||
        host.username.toLowerCase().contains(q) ||
        host.group.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: AppStore.instance,
        builder: (context, _) {
          final store = AppStore.instance;
          final all = store.hosts;
          final filter = _filter;
          final filtered = all
              .where((h) => _query.isEmpty || _matches(h, _query))
              .where((h) => filter == null || (filter.isFtp ? h.protocol.isFtp : h.protocol == filter))
              .toList();
          final protocolsUsed = <Protocol>{for (final h in all) h.protocol.isFtp ? Protocol.ftp : h.protocol};
          final quick = _quickHost();
          final recent = _query.isEmpty ? store.recentHosts : <Host>[];
          final grouped = <String, List<Host>>{};
          for (final host in filtered) {
            grouped.putIfAbsent(host.group.trim(), () => []).add(host);
          }
          final groupNames = grouped.keys.where((g) => g.isNotEmpty).toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          if (grouped.containsKey('')) {
            groupNames.add('');
          }
          for (final list in grouped.values) {
            list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
          }

          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 104,
                backgroundColor: AppColors.bg,
                surfaceTintColor: Colors.transparent,
                actions: const [_VpnAction()],
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 14),
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LogoMark(size: 26),
                      const SizedBox(width: 10),
                      Text(
                        'nav.hosts'.tr(),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TextField(
                    controller: _search,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'hosts.search_hint'.tr(),
                      prefixIcon: const Icon(HugeIcons.strokeRoundedSearch01),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'common.clear'.tr(),
                              icon: const Icon(HugeIcons.strokeRoundedCancel01),
                              onPressed: _search.clear,
                            ),
                    ),
                  ),
                ),
              ),
              if (protocolsUsed.length > 1 || filter != null)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                      children: [
                        _FilterChip(
                            label: 'hosts.all'.tr(), selected: filter == null, onTap: () => setState(() => _filter = null)),
                        for (final protocol in const [Protocol.ssh, Protocol.ftp])
                          if (protocolsUsed.contains(protocol) || filter == protocol)
                            _FilterChip(
                              label: protocol.title,
                              icon: protocolIcon(protocol),
                              selected: filter == protocol,
                              onTap: () => setState(() => _filter = filter == protocol ? null : protocol),
                            ),
                      ],
                    ),
                  ),
                ),
              if (quick != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: _QuickConnectCard(
                      host: quick,
                      onConnect: () {
                        FocusScope.of(context).unfocus();
                        openHost(quick);
                      },
                      onSave: () => _addHost(quick),
                    ),
                  ),
                ),
              if (recent.isNotEmpty) ...[
                SliverToBoxAdapter(child: SectionHeader('hosts.recent'.tr())),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: recent.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 10),
                      itemBuilder: (context, index) => _RecentCard(host: recent[index]),
                    ),
                  ),
                ),
              ],
              if (all.isEmpty && quick == null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: HugeIcons.strokeRoundedDatabase,
                    title: 'hosts.empty_title'.tr(),
                    message: 'hosts.empty_msg'.tr(),
                    actionLabel: 'hosts.add'.tr(),
                    onAction: _addHost,
                  ),
                )
              else if (filtered.isEmpty && quick == null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text('hosts.nothing_found'.tr(), style: TextStyle(color: AppColors.textDim)),
                  ),
                )
              else
                for (final group in groupNames) ...[
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      group.isEmpty ? (groupNames.length > 1 ? 'hosts.no_group'.tr() : 'hosts.all_hosts'.tr()) : group,
                      trailing: Text(
                        '${grouped[group]!.length}',
                        style: TextStyle(color: AppColors.textDim, fontSize: 12),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.separated(
                      itemCount: grouped[group]!.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _HostTile(host: grouped[group]![index]),
                    ),
                  ),
                ],
              const SliverToBoxAdapter(child: SizedBox(height: 140)),
            ],
          );
        },
      ),
    );
  }
}

class _QuickConnectCard extends StatelessWidget {
  const _QuickConnectCard({required this.host, required this.onConnect, required this.onSave});

  final Host host;
  final VoidCallback onConnect;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [AppColors.accent.withValues(alpha: 0.18), AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GradientIcon(icon: protocolIcon(host.protocol), size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('hosts.quick_connect'.tr(namedArgs: {'proto': host.protocol.title}),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(host.subtitle, style: AppFonts.monoStyle(size: 13, color: AppColors.textDim)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onConnect,
                  icon: Icon(protocolIcon(host.protocol)),
                  label: Text('hosts.connect'.tr()),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onSave,
                icon: const Icon(HugeIcons.strokeRoundedBookmarkAdd01),
                label: Text('common.save'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.host});

  final Host host;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => openHost(host),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HostAvatar(host: host, size: 30),
                    const Spacer(),
                    ProtocolBadge(protocol: host.protocol),
                  ],
                ),
                const Spacer(),
                Text(
                  host.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                Text(
                  host.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.monoStyle(size: 11, color: AppColors.textDim),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HostTile extends StatelessWidget {
  const _HostTile({required this.host});

  final Host host;

  Future<void> _onMenu(BuildContext context, String action) async {
    switch (action) {
      case 'terminal':
        await openTerminal(host);
      case 'files':
        await openFiles(host);
      case 'edit':
        await Navigator.of(context).push<Host>(MaterialPageRoute(builder: (_) => HostEditorScreen(host: host)));
      case 'duplicate':
        await AppStore.instance.duplicateHost(host);
        showSnack('hosts.duplicated'.tr());
      case 'delete':
        final ok = await confirmAction(
          title: 'hosts.delete_title'.tr(namedArgs: {'title': host.title}),
          message: 'hosts.delete_msg'.tr(),
        );
        if (!ok) {
          return;
        }
        await AppStore.instance.deleteHost(host.id);
        showSnack('hosts.deleted'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = host.auth == AuthType.key ? AppStore.instance.keyById(host.keyId) : null;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => openHost(host),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 2, 10),
          child: Row(
            children: [
              HostAvatar(host: host),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        ProtocolBadge(protocol: host.protocol),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            host.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.monoStyle(size: 12, color: AppColors.textDim),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (host.protocol.isSsh)
                IconButton(
                  tooltip: 'hosts.files_sftp'.tr(),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(HugeIcons.strokeRoundedFolderOpen, size: 20, color: AppColors.accent),
                  onPressed: () => openFiles(host),
                ),
              if (host.protocol.isSsh)
                Tooltip(
                  message: host.auth == AuthType.key
                      ? 'hosts.ssh_key_tip'.tr(namedArgs: {'name': key?.name ?? 'hosts.not_selected'.tr()})
                      : 'password.title'.tr(),
                  child: Icon(
                    host.auth == AuthType.key ? HugeIcons.strokeRoundedKey01 : HugeIcons.strokeRoundedLockPassword,
                    size: 18,
                    color: host.auth == AuthType.key ? AppColors.yellow : AppColors.textDim,
                  ),
                ),
              if (host.legacy)
                Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Tooltip(
                    message: 'hosts.legacy_algos'.tr(),
                    child: Icon(HugeIcons.strokeRoundedClock01, size: 18, color: AppColors.textDim),
                  ),
                ),
              PopupMenuButton<String>(
                icon: Icon(HugeIcons.strokeRoundedMoreVerticalCircle01, color: AppColors.textDim),
                onSelected: (value) => _onMenu(context, value),
                itemBuilder: (_) => [
                  if (host.protocol.isSsh) ...[
                    PopupMenuItem(
                      value: 'terminal',
                      child: ListTile(leading: const Icon(HugeIcons.strokeRoundedCommandLine), title: Text('nav.terminal'.tr())),
                    ),
                    PopupMenuItem(
                      value: 'files',
                      child: ListTile(leading: const Icon(HugeIcons.strokeRoundedFolder02), title: Text('hosts.files_sftp'.tr())),
                    ),
                  ],
                  if (host.protocol.isFtp)
                    PopupMenuItem(
                      value: 'files',
                      child: ListTile(
                        leading: const Icon(HugeIcons.strokeRoundedFolder02),
                        title: Text('hosts.files_proto'.tr(namedArgs: {'proto': host.protocol.title})),
                      ),
                    ),
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(leading: const Icon(HugeIcons.strokeRoundedEdit02), title: Text('hosts.edit'.tr())),
                  ),
                  PopupMenuItem(
                    value: 'duplicate',
                    child: ListTile(leading: const Icon(HugeIcons.strokeRoundedCopy01), title: Text('hosts.duplicate'.tr())),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppColors.accent.withValues(alpha: 0.2) : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: selected ? AppColors.accent : AppColors.textDim),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.text : AppColors.textDim,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VpnAction extends StatelessWidget {
  const _VpnAction();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VpnController.instance,
      builder: (context, _) {
        final controller = VpnController.instance;
        final connected = controller.isConnected;
        final busy = controller.isBusy;
        return IconButton(
          tooltip: 'VPN',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const VpnScreen()),
          ),
          icon: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                connected ? HugeIcons.strokeRoundedShieldKey : HugeIcons.strokeRoundedShieldKey,
                color: connected ? AppColors.green : (busy ? AppColors.yellow : AppColors.textDim),
              ),
              if (connected)
                Positioned(
                  right: 2,
                  top: 4,
                  child: StatusDot(color: AppColors.green, size: 7),
                ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../data/ip_tools.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'extra_tools_screen.dart';
import 'local_terminal_screen.dart';
import 'wol_screen.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = <_Tool>[
      _Tool('tools.ipcalc'.tr(), 'tools.ipcalc_sub'.tr(), HugeIcons.strokeRoundedSecuredNetwork, AppColors.accent,
          () => const IpCalculatorScreen()),
      _Tool('tools.ports'.tr(), 'tools.ports_sub'.tr(), HugeIcons.strokeRoundedElearningExchange, AppColors.green,
          () => const PortReferenceScreen()),
      _Tool('tools.dns'.tr(), 'tools.dns_sub'.tr(), HugeIcons.strokeRoundedGlobe02, const Color(0xFF2DD4BF),
          () => const NetProbeScreen()),
      _Tool('tools.encoder'.tr(), 'tools.encoder_sub'.tr(), HugeIcons.strokeRoundedSourceCode, AppColors.accent,
          () => const EncoderScreen()),
      _Tool('tools.hashes'.tr(), 'tools.hashes_sub'.tr(), HugeIcons.strokeRoundedFingerAccess, const Color(0xFFF778BA),
          () => const HashScreen()),
      _Tool('wol.title'.tr(), 'wol.subtitle'.tr(), HugeIcons.strokeRoundedComputerArrowUp, const Color(0xFF3FB950),
          () => const WolScreen()),
      _Tool('tools.local_term'.tr(), 'tools.local_term_sub'.tr(), HugeIcons.strokeRoundedCommandLine,
          const Color(0xFFA371F7), () => const LocalTerminalScreen()),
    ];
    return Scaffold(
      appBar: AppBar(title: Text('tools.title'.tr())),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
        children: [
          for (final tool in tools)
            Pressable(
              scale: 0.96,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => tool.builder())),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GradientIcon(icon: tool.icon, color: tool.color, size: 46),
                    const Spacer(),
                    Text(tool.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(tool.subtitle, style: TextStyle(color: AppColors.textDim, fontSize: 12), maxLines: 2),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tool {
  const _Tool(this.title, this.subtitle, this.icon, this.color, this.builder);

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget Function() builder;
}

class IpCalculatorScreen extends StatefulWidget {
  const IpCalculatorScreen({super.key});

  @override
  State<IpCalculatorScreen> createState() => _IpCalculatorScreenState();
}

class _IpCalculatorScreenState extends State<IpCalculatorScreen> {
  final TextEditingController _controller = TextEditingController(text: '192.168.1.10/24');
  SubnetInfo? _info;

  @override
  void initState() {
    super.initState();
    _recalc();
    _controller.addListener(_recalc);
  }

  void _recalc() => setState(() => _info = IpTools.parse(_controller.text));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return Scaffold(
      appBar: AppBar(title: Text('tools.ipcalc'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            autocorrect: false,
            style: AppFonts.monoStyle(size: 16),
            decoration: InputDecoration(
              labelText: 'tools.ip_cidr'.tr(),
              hintText: '10.0.0.5/24',
              prefixIcon: const Icon(HugeIcons.strokeRoundedInternet),
            ),
          ),
          const SizedBox(height: 16),
          if (info == null)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text('tools.ip_hint'.tr(), style: TextStyle(color: AppColors.textDim)),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _row('tools.net'.tr(), '${info.network}/${info.prefix}'),
                  _row('tools.mask'.tr(), info.netmask),
                  _row('Wildcard', info.wildcard),
                  _row('Broadcast', info.broadcast),
                  _row('tools.first_host'.tr(), info.firstHost),
                  _row('tools.last_host'.tr(), info.lastHost),
                  _row('tools.total_addr'.tr(), '${info.totalAddresses}'),
                  _row('tools.usable_hosts'.tr(), '${info.usableHosts}'),
                  _row('tools.class'.tr(), info.ipClass),
                  _row('tools.type'.tr(), info.isPrivate ? 'tools.private'.tr() : 'tools.public'.tr(), last: true),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool last = false}) {
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: value));
        showSnack('common.copied_value'.tr(namedArgs: {'value': value}));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(color: AppColors.textDim, fontSize: 13.5))),
            Text(value, style: AppFonts.monoStyle(size: 14, weight: FontWeight.w600)),
            const SizedBox(width: 8),
            Icon(HugeIcons.strokeRoundedCopy01, size: 15, color: AppColors.textDim),
          ],
        ),
      ),
    );
  }
}

class PortReferenceScreen extends StatefulWidget {
  const PortReferenceScreen({super.key});

  @override
  State<PortReferenceScreen> createState() => _PortReferenceScreenState();
}

class _PortReferenceScreenState extends State<PortReferenceScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final ports = q.isEmpty
        ? PortReference.ports
        : PortReference.ports
            .where((p) =>
                '${p.port}'.contains(q) ||
                p.service.toLowerCase().contains(q) ||
                p.description.toLowerCase().contains(q) ||
                p.proto.toLowerCase().contains(q))
            .toList();
    return Scaffold(
      appBar: AppBar(title: Text('tools.ports'.tr())),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              autocorrect: false,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'tools.ports_search'.tr(),
                prefixIcon: const Icon(HugeIcons.strokeRoundedSearch01),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: ports.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final p = ports[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: '${p.port}'));
                    showSnack('tools.port_copied'.tr(namedArgs: {'port': '${p.port}'}));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 62,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${p.port}',
                              style: AppFonts.monoStyle(size: 15, color: AppColors.accent, weight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(p.service, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                                  const SizedBox(width: 8),
                                  Text(p.proto, style: AppFonts.monoStyle(size: 11, color: AppColors.textDim)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(p.description, style: TextStyle(color: AppColors.textDim, fontSize: 12.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

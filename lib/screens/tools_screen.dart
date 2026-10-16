import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../data/ip_tools.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'extra_tools_screen.dart';
import 'local_terminal_screen.dart';
import 'logs_screen.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = <_Tool>[
      _Tool('IP-калькулятор', 'Подсеть, маска, диапазон', HugeIcons.strokeRoundedSecuredNetwork, AppColors.accent,
          () => const IpCalculatorScreen()),
      _Tool('Справочник портов', 'Частые порты и службы', HugeIcons.strokeRoundedElearningExchange, AppColors.green,
          () => const PortReferenceScreen()),
      _Tool('DNS и порты', 'Lookup и проверка TCP', HugeIcons.strokeRoundedGlobe02, const Color(0xFF2DD4BF),
          () => const NetProbeScreen()),
      _Tool('Кодировщик', 'Base64, URL, JWT', HugeIcons.strokeRoundedSourceCode, AppColors.accent,
          () => const EncoderScreen()),
      _Tool('Хеши', 'MD5, SHA-1/256/512', HugeIcons.strokeRoundedFingerAccess, const Color(0xFFF778BA),
          () => const HashScreen()),
      _Tool('Локальный терминал', 'Оболочка этого устройства', HugeIcons.strokeRoundedCommandLine,
          const Color(0xFFA371F7), () => const LocalTerminalScreen()),
      _Tool('Логи активности', 'Что делает приложение', HugeIcons.strokeRoundedTask01, AppColors.yellow,
          () => const LogsScreen()),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Инструменты')),
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
      appBar: AppBar(title: const Text('IP-калькулятор')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            autocorrect: false,
            style: AppFonts.monoStyle(size: 16),
            decoration: const InputDecoration(
              labelText: 'IP-адрес / CIDR',
              hintText: '10.0.0.5/24',
              prefixIcon: Icon(Icons.lan_rounded),
            ),
          ),
          const SizedBox(height: 16),
          if (info == null)
            Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: Text('Введите IP с маской, например 192.168.0.1/24', style: TextStyle(color: AppColors.textDim)),
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
                  _row('Сеть', '${info.network}/${info.prefix}'),
                  _row('Маска', info.netmask),
                  _row('Wildcard', info.wildcard),
                  _row('Broadcast', info.broadcast),
                  _row('Первый хост', info.firstHost),
                  _row('Последний хост', info.lastHost),
                  _row('Всего адресов', '${info.totalAddresses}'),
                  _row('Хостов доступно', '${info.usableHosts}'),
                  _row('Класс', info.ipClass),
                  _row('Тип', info.isPrivate ? 'Приватный' : 'Публичный', last: true),
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
        showSnack('Скопировано: $value');
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
            Icon(Icons.copy_rounded, size: 15, color: AppColors.textDim),
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
      appBar: AppBar(title: const Text('Справочник портов')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              autocorrect: false,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Поиск: порт, служба (ssh, 443, mysql)',
                prefixIcon: Icon(Icons.search_rounded),
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
                    showSnack('Скопирован порт ${p.port}');
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

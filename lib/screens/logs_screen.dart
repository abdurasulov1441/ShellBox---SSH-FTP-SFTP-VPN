import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../nav.dart';
import '../services/activity_log.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  Color _color(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return AppColors.textDim;
      case LogLevel.success:
        return AppColors.green;
      case LogLevel.warning:
        return AppColors.yellow;
      case LogLevel.error:
        return AppColors.red;
    }
  }

  String _time(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Логи активности'),
        actions: [
          IconButton(
            tooltip: 'Копировать всё',
            icon: const Icon(Icons.copy_all_rounded),
            onPressed: () async {
              final text = ActivityLog.instance.exportText();
              if (text.trim().isEmpty) {
                showSnack('Логи пусты');
                return;
              }
              await Clipboard.setData(ClipboardData(text: text));
              showSnack('Логи скопированы');
            },
          ),
          IconButton(
            tooltip: 'Очистить',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final ok = await confirmAction(
                title: 'Очистить логи?',
                message: 'Все записи журнала будут удалены.',
                confirmLabel: 'Очистить',
              );
              if (ok) {
                await ActivityLog.instance.clear();
              }
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: ActivityLog.instance,
        builder: (context, _) {
          final entries = ActivityLog.instance.entries;
          if (entries.isEmpty) {
            return const EmptyState(
              icon: Icons.article_rounded,
              title: 'Журнал пуст',
              message: 'Здесь появятся события приложения: подключения, VPN, ошибки и действия.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: entries.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final e = entries[index];
              final color = _color(e.level);
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        width: 4,
                        height: 38,
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(e.tag, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
                              const Spacer(),
                              Text(_time(e.time), style: AppFonts.monoStyle(size: 11, color: AppColors.textDim)),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(e.message, style: const TextStyle(fontSize: 13, height: 1.3)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

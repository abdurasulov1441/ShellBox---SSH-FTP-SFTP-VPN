import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
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
        title: Text('tools.logs'.tr()),
        actions: [
          IconButton(
            tooltip: 'logs.copy_all'.tr(),
            icon: const Icon(HugeIcons.strokeRoundedCopy01),
            onPressed: () async {
              final text = ActivityLog.instance.exportText();
              if (text.trim().isEmpty) {
                showSnack('logs.empty_snack'.tr());
                return;
              }
              await Clipboard.setData(ClipboardData(text: text));
              showSnack('logs.copied'.tr());
            },
          ),
          IconButton(
            tooltip: 'logs.clear'.tr(),
            icon: const Icon(HugeIcons.strokeRoundedDelete02),
            onPressed: () async {
              final ok = await confirmAction(
                title: 'logs.clear_title'.tr(),
                message: 'logs.clear_msg'.tr(),
                confirmLabel: 'logs.clear'.tr(),
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
            return EmptyState(
              icon: HugeIcons.strokeRoundedTask01,
              title: 'logs.empty_title'.tr(),
              message: 'logs.empty_msg'.tr(),
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

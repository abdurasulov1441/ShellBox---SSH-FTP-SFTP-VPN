import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../data/command_library.dart';
import '../models.dart';
import '../nav.dart';
import '../services/sessions.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/run_sheet.dart';

class CommandLibraryScreen extends StatelessWidget {
  const CommandLibraryScreen({super.key});

  Future<void> _run(BuildContext context, LibraryCommand command) async {
    await showRunSheet(context, command.command);
  }

  Future<void> _save(LibraryCommand command) async {
    await AppStore.instance.saveSnippet(
      Snippet(id: AppStore.newId(), name: command.name, command: command.command),
    );
    showSnack('library.added_to_snippets'.tr());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('snippets.library'.tr())),
      body: ListenableBuilder(
        listenable: SessionManager.instance,
        builder: (context, _) {
          final target = SessionManager.instance.connectedCurrent;
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(HugeIcons.strokeRoundedInformationCircle, size: 18, color: AppColors.textDim),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          target != null
                              ? 'library.hint_active'.tr(namedArgs: {'host': target.host.title})
                              : 'library.hint_inactive'.tr(),
                          style: TextStyle(color: AppColors.textDim, fontSize: 12.5, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (final category in CommandLibrary.categories)
                _CategoryTile(category: category, onRun: _run, onSave: _save),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onRun, required this.onSave});

  final LibraryCategory category;
  final Future<void> Function(BuildContext, LibraryCommand) onRun;
  final Future<void> Function(LibraryCommand) onSave;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(category.icon, color: AppColors.accent),
        title: Text(category.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('library.commands_count'.tr(namedArgs: {'count': '${category.commands.length}'}),
            style: TextStyle(color: AppColors.textDim, fontSize: 12)),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        shape: const Border(),
        collapsedShape: const Border(),
        children: [
          for (final command in category.commands)
            ListTile(
              dense: true,
              title: Text(command.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  command.command,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.monoStyle(size: 11.5, color: AppColors.textDim),
                ),
              ),
              trailing: IconButton(
                tooltip: 'library.to_snippets'.tr(),
                icon: Icon(HugeIcons.strokeRoundedBookmarkAdd01, size: 20, color: AppColors.textDim),
                onPressed: () => onSave(command),
              ),
              onTap: () => onRun(context, command),
              onLongPress: () async {
                await Clipboard.setData(ClipboardData(text: command.command));
                showSnack('keys.command_copied'.tr());
              },
            ),
        ],
      ),
    );
  }
}

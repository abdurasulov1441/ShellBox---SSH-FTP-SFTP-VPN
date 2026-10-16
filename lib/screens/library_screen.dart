import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/command_library.dart';
import '../models.dart';
import '../nav.dart';
import '../services/sessions.dart';
import '../services/store.dart';
import '../theme.dart';

class CommandLibraryScreen extends StatelessWidget {
  const CommandLibraryScreen({super.key});

  Future<void> _run(LibraryCommand command) async {
    final session = SessionManager.instance.connectedCurrent;
    if (session == null) {
      await Clipboard.setData(ClipboardData(text: command.command));
      showSnack('Нет активной сессии — команда скопирована');
      return;
    }
    SessionManager.instance.selectSession(session);
    session.run(command.command);
    await showTerminal();
  }

  Future<void> _save(LibraryCommand command) async {
    await AppStore.instance.saveSnippet(
      Snippet(id: AppStore.newId(), name: command.name, command: command.command),
    );
    showSnack('Добавлено в сниппеты');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Библиотека команд')),
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
                      Icon(Icons.info_outline_rounded, size: 18, color: AppColors.textDim),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          target != null
                              ? 'Нажатие запускает команду в «${target.host.title}». Замените TARGET на адрес цели.'
                              : 'Нет активной сессии — нажатие копирует команду. TARGET замените на адрес цели.',
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
  final Future<void> Function(LibraryCommand) onRun;
  final Future<void> Function(LibraryCommand) onSave;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(category.icon, color: AppColors.accent),
        title: Text(category.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${category.commands.length} команд', style: TextStyle(color: AppColors.textDim, fontSize: 12)),
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
                tooltip: 'В сниппеты',
                icon: Icon(Icons.bookmark_add_outlined, size: 20, color: AppColors.textDim),
                onPressed: () => onSave(command),
              ),
              onTap: () => onRun(command),
              onLongPress: () async {
                await Clipboard.setData(ClipboardData(text: command.command));
                showSnack('Команда скопирована');
              },
            ),
        ],
      ),
    );
  }
}

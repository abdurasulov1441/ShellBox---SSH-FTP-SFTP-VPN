import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../nav.dart';
import '../services/sessions.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import 'library_screen.dart';

class SnippetsScreen extends StatelessWidget {
  const SnippetsScreen({super.key});

  Future<void> _edit(BuildContext context, [Snippet? snippet]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SnippetSheet(snippet: snippet),
    );
  }

  Future<void> _run(Snippet snippet) async {
    final manager = SessionManager.instance;
    final session = manager.connectedCurrent;
    if (session == null) {
      await Clipboard.setData(ClipboardData(text: snippet.command));
      showSnack('Нет активной сессии — команда скопирована');
      return;
    }
    manager.selectSession(session);
    session.run(snippet.command);
    await showTerminal();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сниппеты'),
        actions: [
          IconButton(
            tooltip: 'Библиотека команд',
            icon: const Icon(Icons.library_books_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CommandLibraryScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'snippets-fab',
        onPressed: () => _edit(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([AppStore.instance, SessionManager.instance]),
        builder: (context, _) {
          final snippets = AppStore.instance.snippets;
          final target = SessionManager.instance.connectedCurrent;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: target != null ? AppColors.green.withValues(alpha: 0.1) : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: target != null ? AppColors.green.withValues(alpha: 0.4) : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      StatusDot(color: target != null ? AppColors.green : AppColors.textDim),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'Запуск в: ', style: TextStyle(color: AppColors.textDim)),
                              TextSpan(
                                text: target?.host.title ?? 'нет сессии — команда будет скопирована',
                                style: TextStyle(
                                  fontWeight: target != null ? FontWeight.w600 : FontWeight.w400,
                                  color: target != null ? AppColors.text : AppColors.textDim,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: snippets.isEmpty
                    ? EmptyState(
                        icon: Icons.bolt_rounded,
                        title: 'Нет сниппетов',
                        message: 'Сохраняйте частые команды и запускайте их одним касанием.',
                        actionLabel: 'Добавить сниппет',
                        onAction: () => _edit(context),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                        itemCount: snippets.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final snippet = snippets[index];
                          return Card(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _run(snippet),
                              onLongPress: () => _edit(context, snippet),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    const GradientIcon(icon: Icons.bolt_rounded, color: AppColors.yellow, size: 40),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            snippet.name.isEmpty ? 'Без названия' : snippet.name,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            snippet.command,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppFonts.monoStyle(size: 12.5, color: AppColors.textDim),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      target != null ? Icons.play_arrow_rounded : Icons.copy_rounded,
                                      color: target != null ? AppColors.green : AppColors.textDim,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SnippetSheet extends StatefulWidget {
  const _SnippetSheet({this.snippet});

  final Snippet? snippet;

  @override
  State<_SnippetSheet> createState() => _SnippetSheetState();
}

class _SnippetSheetState extends State<_SnippetSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.snippet?.name ?? '');
  late final TextEditingController _command = TextEditingController(text: widget.snippet?.command ?? '');
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _command.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final command = _command.text.trim();
    if (command.isEmpty) {
      setState(() => _error = 'Введите команду');
      return;
    }
    await AppStore.instance.saveSnippet(
      Snippet(id: widget.snippet?.id ?? AppStore.newId(), name: _name.text.trim(), command: command),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final snippet = widget.snippet;
    if (snippet == null) {
      return;
    }
    final ok = await confirmAction(
      title: 'Удалить сниппет?',
      message: '«${snippet.name.isEmpty ? snippet.command : snippet.name}» будет удалён.',
    );
    if (!ok) {
      return;
    }
    await AppStore.instance.deleteSnippet(snippet.id);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.snippet != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                editing ? 'Изменить сниппет' : 'Новый сниппет',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                autofocus: !editing,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Название', prefixIcon: Icon(Icons.label_outline_rounded)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _command,
                minLines: 2,
                maxLines: 6,
                autocorrect: false,
                enableSuggestions: false,
                style: AppFonts.monoStyle(size: 13.5),
                onChanged: (_) {
                  if (_error != null) {
                    setState(() => _error = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Команда',
                  hintText: 'sudo systemctl restart nginx',
                  errorText: _error,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (editing)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.red,
                          side: BorderSide(color: AppColors.red.withValues(alpha: 0.5)),
                        ),
                        onPressed: _delete,
                        child: const Icon(Icons.delete_outline_rounded),
                      ),
                    ),
                  Expanded(
                    child: FilledButton(onPressed: _save, child: const Text('Сохранить')),
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

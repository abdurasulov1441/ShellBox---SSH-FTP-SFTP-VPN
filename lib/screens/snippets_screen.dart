import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../models.dart';
import '../services/sessions.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import '../widgets/run_sheet.dart';
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

  Future<void> _run(BuildContext context, Snippet snippet) async {
    await showRunSheet(context, snippet.command);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('nav.snippets'.tr()),
        actions: [
          IconButton(
            tooltip: 'snippets.library'.tr(),
            icon: const Icon(HugeIcons.strokeRoundedBookOpen01),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CommandLibraryScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'snippets-fab',
        onPressed: () => _edit(context),
        child: const Icon(HugeIcons.strokeRoundedAdd01),
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
                              TextSpan(text: 'snippets.run_at'.tr(), style: TextStyle(color: AppColors.textDim)),
                              TextSpan(
                                text: target?.host.title ?? 'snippets.no_session_hint'.tr(),
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
                        icon: HugeIcons.strokeRoundedFlash,
                        title: 'snippets.empty_title'.tr(),
                        message: 'snippets.empty_msg'.tr(),
                        actionLabel: 'snippets.add'.tr(),
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
                              onTap: () => _run(context, snippet),
                              onLongPress: () => _edit(context, snippet),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    GradientIcon(icon: HugeIcons.strokeRoundedFlash, color: AppColors.yellow, size: 40),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            snippet.name.isEmpty ? 'snippets.untitled'.tr() : snippet.name,
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
                                      target != null ? HugeIcons.strokeRoundedPlay : HugeIcons.strokeRoundedCopy01,
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
      setState(() => _error = 'snippets.enter_command'.tr());
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
      title: 'snippets.delete_title'.tr(),
      message: 'snippets.delete_msg'.tr(namedArgs: {'name': snippet.name.isEmpty ? snippet.command : snippet.name}),
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
                editing ? 'snippets.edit_title'.tr() : 'snippets.new_title'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                autofocus: !editing,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: 'keys.name'.tr(), prefixIcon: const Icon(HugeIcons.strokeRoundedTag01)),
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
                  labelText: 'snippets.command'.tr(),
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
                        child: const Icon(HugeIcons.strokeRoundedDelete02),
                      ),
                    ),
                  Expanded(
                    child: FilledButton(onPressed: _save, child: Text('common.save'.tr())),
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

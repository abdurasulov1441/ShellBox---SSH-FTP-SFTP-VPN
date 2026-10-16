import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../models.dart';
import '../nav.dart';
import '../services/sessions.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/extra_keys.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final FocusNode _focus = FocusNode();
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    TerminalRoute.visible = true;
  }

  @override
  void dispose() {
    TerminalRoute.visible = false;
    _focus.dispose();
    super.dispose();
  }

  Color _statusColor(SessionState state) {
    switch (state) {
      case SessionState.connected:
        return AppColors.green;
      case SessionState.connecting:
        return AppColors.yellow;
      case SessionState.failed:
        return AppColors.red;
      case SessionState.closed:
        return AppColors.textDim;
    }
  }

  Future<void> _newTab() async {
    final hosts = AppStore.instance.hosts.where((h) => h.protocol.isSsh).toList();
    final host = await showModalBottomSheet<Host>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetTitle('Новая вкладка', subtitle: 'Выберите хост для подключения'),
              if (hosts.isEmpty)
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Сохранённых хостов нет',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textDim),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: hosts.length,
                    itemBuilder: (_, index) {
                      final item = hosts[index];
                      return ListTile(
                        leading: HostAvatar(host: item, size: 38),
                        title: Text(item.title),
                        subtitle: Text(item.subtitle, style: AppFonts.monoStyle(size: 12, color: AppColors.textDim)),
                        onTap: () => Navigator.of(sheetContext).pop(item),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (host == null || !mounted) {
      return;
    }
    SessionManager.instance.open(host);
  }

  Future<void> _onMenu(String action, TerminalSession session) async {
    final store = AppStore.instance;
    switch (action) {
      case 'paste':
        await pasteInto(session);
      case 'copy':
        final text = session.selectedText();
        if (text.trim().isEmpty) {
          showSnack('Сначала выделите текст в терминале', error: true);
          return;
        }
        await Clipboard.setData(ClipboardData(text: text));
        session.controller.clearSelection();
        showSnack('Скопировано');
      case 'snippets':
        if (!mounted) {
          return;
        }
        await showSnippetSheet(context, session);
      case 'sftp':
        await openFiles(session.host);
      case 'bigger':
        await store.setFontSize(store.fontSize + 1);
      case 'smaller':
        await store.setFontSize(store.fontSize - 1);
      case 'reconnect':
        await session.start();
      case 'close':
        SessionManager.instance.close(session);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([SessionManager.instance, AppStore.instance]),
      builder: (context, _) {
        final manager = SessionManager.instance;
        final session = manager.current;
        if (session == null) {
          if (!_closing) {
            _closing = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            });
          }
          return const Scaffold(body: SizedBox.shrink());
        }
        final store = AppStore.instance;
        final scheme = TerminalScheme.byId(store.terminalTheme);
        return Scaffold(
          backgroundColor: scheme.theme.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            titleSpacing: 0,
            title: _buildTabs(manager),
            actions: [
              IconButton(tooltip: 'Новая вкладка', icon: const Icon(Icons.add_rounded), onPressed: _newTab),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) => _onMenu(value, session),
                itemBuilder: (_) => [
                  _menuItem('paste', Icons.content_paste_rounded, 'Вставить'),
                  _menuItem('copy', Icons.copy_rounded, 'Копировать выделенное'),
                  _menuItem('snippets', Icons.bolt_rounded, 'Сниппеты'),
                  _menuItem('sftp', Icons.folder_copy_outlined, 'SFTP'),
                  const PopupMenuDivider(),
                  _menuItem('bigger', Icons.text_increase_rounded, 'Шрифт крупнее'),
                  _menuItem('smaller', Icons.text_decrease_rounded, 'Шрифт мельче'),
                  const PopupMenuDivider(),
                  _menuItem('reconnect', Icons.refresh_rounded, 'Переподключить'),
                  _menuItem('close', Icons.close_rounded, 'Закрыть сессию', color: AppColors.red),
                ],
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                if (session.state == SessionState.failed || session.state == SessionState.closed) _buildBanner(session),
                Expanded(
                  child: TerminalView(
                    session.terminal,
                    key: ValueKey(session.id),
                    controller: session.controller,
                    focusNode: _focus,
                    theme: scheme.theme,
                    textStyle:
                        TerminalStyle(fontSize: store.fontSize, fontFamily: MonoFonts.family(store.terminalFont)),
                    padding: const EdgeInsets.all(6),
                    autofocus: true,
                    keyboardType: TextInputType.visiblePassword,
                    deleteDetection: true,
                  ),
                ),
                SuggestionBar(session: session),
                ExtraKeysBar(session: session, focusNode: _focus),
              ],
            ),
          ),
        );
      },
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label, {Color? color}) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? AppColors.textDim),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Widget _buildTabs(SessionManager manager) {
    final sessions = manager.sessions;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: sessions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final item = sessions[index];
          final selected = index == manager.active;
          return Center(
            child: Material(
              color: selected ? AppColors.surfaceHigh : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: selected ? AppColors.accent.withValues(alpha: 0.6) : AppColors.border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => manager.select(index),
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusDot(color: _statusColor(item.state)),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 130),
                        child: Text(
                          item.host.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                            color: selected ? AppColors.text : AppColors.textDim,
                          ),
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => manager.close(item),
                        child: Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.close_rounded, size: 16, color: AppColors.textDim),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBanner(TerminalSession session) {
    final failed = session.state == SessionState.failed;
    final color = failed ? AppColors.red : AppColors.textDim;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          Icon(failed ? Icons.error_outline_rounded : Icons.link_off_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              failed ? (session.error ?? 'Ошибка подключения') : 'Соединение закрыто',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: failed ? AppColors.red : AppColors.text, fontSize: 13),
            ),
          ),
          TextButton.icon(
            onPressed: session.start,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Переподключить'),
          ),
        ],
      ),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../nav.dart';
import '../services/sessions.dart';
import '../theme.dart';
import 'common.dart';

Future<void> showRunSheet(BuildContext context, String command) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RunSheet(command: command),
  );
}

class _RunSheet extends StatefulWidget {
  const _RunSheet({required this.command});

  final String command;

  @override
  State<_RunSheet> createState() => _RunSheetState();
}

class _RunSheetState extends State<_RunSheet> {
  late final TextEditingController _controller = TextEditingController(text: widget.command);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final cmd = _controller.text.trim();
    if (cmd.isEmpty) {
      return;
    }
    Navigator.of(context).pop();
    final manager = SessionManager.instance;
    final session = manager.connectedCurrent;
    if (session == null) {
      await Clipboard.setData(ClipboardData(text: cmd));
      showSnack('snippets.no_session_copied'.tr());
      return;
    }
    manager.selectSession(session);
    session.run(cmd);
    await showTerminal();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _controller.text));
    if (mounted) {
      Navigator.of(context).pop();
    }
    showSnack('common.copied'.tr());
  }

  @override
  Widget build(BuildContext context) {
    final target = SessionManager.instance.connectedCurrent;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetTitle(
                'run.title'.tr(),
                subtitle: target != null
                    ? 'snippets.run_in'.tr(namedArgs: {'host': target.host.title})
                    : 'snippets.no_session_hint'.tr(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      minLines: 2,
                      maxLines: 8,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: AppFonts.monoStyle(size: 14),
                      decoration: InputDecoration(
                        labelText: 'snippets.command'.tr(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _copy,
                            icon: const Icon(HugeIcons.strokeRoundedCopy01, size: 18),
                            label: Text('keys.copy'.tr()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _run,
                            icon: const Icon(HugeIcons.strokeRoundedPlay, size: 18),
                            label: Text('run.run'.tr()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

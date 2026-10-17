import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../models.dart';
import '../nav.dart';
import '../services/connector.dart';
import '../theme.dart';
import 'common.dart';

Future<bool> confirmHostKey(HostKeyCheck check) async {
  final context = navigatorKey.currentContext;
  if (context == null) {
    return false;
  }
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _HostKeyDialog(check: check),
  );
  return result ?? false;
}

Future<PasswordReply?> askPassword(Host host) async {
  final context = navigatorKey.currentContext;
  if (context == null) {
    return null;
  }
  return showDialog<PasswordReply>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PasswordDialog(host: host),
  );
}

Future<String?> promptText({
  required String title,
  String label = '',
  String initial = '',
  String hint = '',
  String? confirmLabel,
  bool mono = false,
}) async {
  final context = navigatorKey.currentContext;
  if (context == null) {
    return null;
  }
  return showDialog<String>(
    context: context,
    builder: (_) => _PromptDialog(
      title: title,
      label: label,
      initial: initial,
      hint: hint,
      confirmLabel: confirmLabel ?? 'common.save'.tr(),
      mono: mono,
    ),
  );
}

Future<bool> confirmAction({
  required String title,
  required String message,
  String? confirmLabel,
  bool destructive = true,
}) async {
  final context = navigatorKey.currentContext;
  if (context == null) {
    return false;
  }
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message, style: TextStyle(color: AppColors.textDim, height: 1.4)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text('common.cancel'.tr(), style: TextStyle(color: AppColors.textDim)),
        ),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.red) : null,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel ?? 'common.delete'.tr()),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _HostKeyDialog extends StatelessWidget {
  const _HostKeyDialog({required this.check});

  final HostKeyCheck check;

  @override
  Widget build(BuildContext context) {
    final changed = check.changed;
    final color = changed ? AppColors.red : AppColors.accent;
    final textTheme = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        icon: Center(
          child: GradientIcon(
            icon: changed ? HugeIcons.strokeRoundedSecurityBlock : HugeIcons.strokeRoundedSecurityCheck,
            color: color,
            size: 52,
          ),
        ),
        title: Text(changed ? 'hostkey.changed_title'.tr() : 'hostkey.new_title'.tr(), textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                changed
                    ? 'hostkey.changed_body'.tr(namedArgs: {'host': check.host.endpoint})
                    : 'hostkey.new_body'.tr(namedArgs: {'host': check.host.endpoint}),
                style: textTheme.bodyMedium?.copyWith(
                  color: changed ? AppColors.red : AppColors.textDim,
                  height: 1.4,
                ),
              ),
              if (changed) ...[
                const SizedBox(height: 16),
                FieldLabel('hostkey.saved_was'.tr()),
                MonoBox(check.previous ?? ''),
              ],
              const SizedBox(height: 16),
              FieldLabel(changed ? 'hostkey.new_key'.tr() : 'hostkey.key_type'.tr(namedArgs: {'type': check.type})),
              MonoBox(changed ? check.value : check.fingerprint),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('common.cancel'.tr(), style: TextStyle(color: AppColors.textDim)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(changed ? 'hostkey.trust_anyway'.tr() : 'hostkey.trust'.tr()),
          ),
        ],
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.host});

  final Host host;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _remember = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(PasswordReply(_controller.text, remember: _remember));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('password.title'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.host.subtitle, style: AppFonts.monoStyle(size: 13, color: AppColors.textDim)),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'password.hint'.tr(),
              prefixIcon: const Icon(HugeIcons.strokeRoundedSquareLock01),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? HugeIcons.strokeRoundedView : HugeIcons.strokeRoundedViewOffSlash),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _remember,
            onChanged: (value) => setState(() => _remember = value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: Text('password.remember'.tr()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr(), style: TextStyle(color: AppColors.textDim)),
        ),
        FilledButton(onPressed: _submit, child: Text('password.login'.tr())),
      ],
    );
  }
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.hint,
    required this.confirmLabel,
    required this.mono,
  });

  final String title;
  final String label;
  final String initial;
  final String hint;
  final String confirmLabel;
  final bool mono;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void initState() {
    super.initState();
    _controller.selection = TextSelection(baseOffset: 0, extentOffset: widget.initial.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        autocorrect: false,
        style: widget.mono ? AppFonts.monoStyle(size: 14) : null,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: widget.label.isEmpty ? null : widget.label,
          hintText: widget.hint.isEmpty ? null : widget.hint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr(), style: TextStyle(color: AppColors.textDim)),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme.dart';

const double kPadButtonSize = 72;

class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length, required this.filled, this.error = false, this.count = 4});

  final int length;
  final int filled;
  final bool error;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 15,
            height: 15,
            margin: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? (error ? AppColors.red : AppColors.accent) : Colors.transparent,
              border: Border.all(
                color: error ? AppColors.red : (i < filled ? AppColors.accent : AppColors.textDim.withValues(alpha: 0.5)),
                width: 2,
              ),
              boxShadow: i < filled && !error
                  ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.5), blurRadius: 10)]
                  : null,
            ),
          ),
      ],
    );
  }
}

class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
    this.onCenters,
  });

  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;

  /// Reports the centre of every real key (global coordinates) after layout,
  /// so a backdrop can wire circuit traces to them.
  final void Function(List<Offset>)? onCenters;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  final List<GlobalKey> _keys = List.generate(12, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  void didUpdateWidget(PinPad old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  void _report() {
    final cb = widget.onCenters;
    if (cb == null || !mounted) {
      return;
    }
    final centers = <Offset>[];
    for (final key in _keys) {
      final ctx = key.currentContext;
      if (ctx == null) {
        continue;
      }
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        continue;
      }
      centers.add(box.localToGlobal(box.size.center(Offset.zero)));
    }
    if (centers.isNotEmpty) {
      cb(centers);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget digit(String d, int i) => _PadButton(key: _keys[i], label: d, onTap: () => widget.onDigit(d));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 44),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [digit('1', 0), digit('2', 1), digit('3', 2)],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [digit('4', 3), digit('5', 4), digit('6', 5)],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [digit('7', 6), digit('8', 7), digit('9', 8)],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              widget.onBiometric == null
                  ? const SizedBox(width: kPadButtonSize, height: kPadButtonSize)
                  : _PadButton(key: _keys[9], icon: HugeIcons.strokeRoundedFingerPrint, onTap: widget.onBiometric!),
              digit('0', 10),
              _PadButton(key: _keys[11], icon: HugeIcons.strokeRoundedDelete02, onTap: widget.onBackspace),
            ],
          ),
        ],
      ),
    );
  }
}

class _PadButton extends StatefulWidget {
  const _PadButton({super.key, this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  State<_PadButton> createState() => _PadButtonState();
}

class _PadButtonState extends State<_PadButton> {
  bool _down = false;

  void _set(bool v) => setState(() => _down = v);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.9 : 1,
        duration: const Duration(milliseconds: 90),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: kPadButtonSize,
          height: kPadButtonSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _down ? AppColors.accent.withValues(alpha: 0.18) : AppColors.surface.withValues(alpha: 0.65),
            border: Border.all(
              color: _down ? AppColors.accent : AppColors.border,
              width: _down ? 1.6 : 1,
            ),
          ),
          child: widget.icon != null
              ? Icon(widget.icon, size: 25, color: AppColors.text)
              : Text(widget.label ?? '',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

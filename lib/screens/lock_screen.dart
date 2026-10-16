import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../services/app_lock.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, this.onUnlocked});

  final VoidCallback? onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _error = false;
  bool _checking = false;

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    if (AppLock.biometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    final ok = await AppLock.authenticateBiometric();
    if (ok && mounted) {
      _unlock();
    }
  }

  void _unlock() {
    HapticFeedback.mediumImpact();
    if (widget.onUnlocked != null) {
      widget.onUnlocked!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _add(String digit) async {
    if (_checking || _pin.length >= 4) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _error = false;
      _pin += digit;
    });
    if (_pin.length == 4) {
      setState(() => _checking = true);
      final ok = await AppLock.verifyPin(_pin);
      if (!mounted) {
        return;
      }
      if (ok) {
        _unlock();
      } else {
        HapticFeedback.heavyImpact();
        _shake.forward(from: 0);
        setState(() {
          _error = true;
          _pin = '';
          _checking = false;
        });
      }
    }
  }

  void _backspace() {
    if (_pin.isEmpty) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _error = false;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              const LogoMark(size: 64),
              const SizedBox(height: 18),
              const Text('ShellBox', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                _error ? 'Неверный PIN' : 'Введите PIN-код',
                style: TextStyle(color: _error ? AppColors.red : AppColors.textDim, fontSize: 14),
              ),
              const SizedBox(height: 28),
              AnimatedBuilder(
                animation: _shake,
                builder: (context, child) {
                  final dx = (_shake.value == 0 || _shake.value == 1)
                      ? 0.0
                      : 12 * (1 - _shake.value) * (((_shake.value * 6).round() % 2 == 0) ? 1 : -1);
                  return Transform.translate(offset: Offset(dx, 0), child: child);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 4; i++)
                      Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _pin.length ? AppColors.accent : Colors.transparent,
                          border: Border.all(
                            color: _error ? AppColors.red : (i < _pin.length ? AppColors.accent : AppColors.border),
                            width: 2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              _Pad(
                  onDigit: _add, onBackspace: _backspace, onBiometric: AppLock.biometricEnabled ? _tryBiometric : null),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pad extends StatelessWidget {
  const _Pad({required this.onDigit, required this.onBackspace, this.onBiometric});

  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;

  @override
  Widget build(BuildContext context) {
    Widget digit(String d) => _PadButton(label: d, onTap: () => onDigit(d));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [digit('1'), digit('2'), digit('3')]),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [digit('4'), digit('5'), digit('6')]),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [digit('7'), digit('8'), digit('9')]),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              onBiometric == null
                  ? const SizedBox(width: 70, height: 70)
                  : _PadButton(icon: HugeIcons.strokeRoundedFingerPrint, onTap: onBiometric!),
              digit('0'),
              _PadButton(icon: HugeIcons.strokeRoundedDelete02, onTap: onBackspace),
            ],
          ),
        ],
      ),
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 70,
          height: 70,
          child: Center(
            child: icon != null
                ? Icon(icon, size: 26, color: AppColors.text)
                : Text(label ?? '', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}

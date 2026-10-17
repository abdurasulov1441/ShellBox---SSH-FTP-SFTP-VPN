import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_lock.dart';
import '../theme.dart';
import '../widgets/circuit_background.dart';
import '../widgets/common.dart';
import '../widgets/pin_pad.dart';

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

  final GlobalKey _circuitKey = GlobalKey();
  List<Offset> _targets = const [];

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  void _onCenters(List<Offset> global) {
    final box = _circuitKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !mounted) {
      return;
    }
    final local = [for (final g in global) box.globalToLocal(g)];
    if (local.length == _targets.length) {
      var same = true;
      for (var i = 0; i < local.length; i++) {
        if ((local[i] - _targets[i]).distanceSquared > 1) {
          same = false;
          break;
        }
      }
      if (same) {
        return;
      }
    }
    setState(() => _targets = local);
  }

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
        body: Stack(
          children: [
            Positioned.fill(child: CircuitBackground(key: _circuitKey, color: AppColors.green, targets: _targets)),
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  const LogoMark(size: 64),
                  const SizedBox(height: 18),
                  const Text('ShellBox', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    _error ? 'lock.wrong_pin'.tr() : 'lock.enter_pin'.tr(),
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
                    child: PinDots(length: 4, filled: _pin.length, error: _error),
                  ),
                  const Spacer(flex: 2),
                  PinPad(
                    onDigit: _add,
                    onBackspace: _backspace,
                    onBiometric: AppLock.biometricEnabled ? _tryBiometric : null,
                    onCenters: _onCenters,
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

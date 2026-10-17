import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../widgets/circuit_background.dart';
import '../widgets/common.dart';
import '../widgets/pin_pad.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _first;
  bool _error = false;

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
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  bool get _confirming => _first != null;

  void _add(String digit) {
    if (_pin.length >= 4) {
      return;
    }
    setState(() {
      _error = false;
      _pin += digit;
    });
    if (_pin.length == 4) {
      _submit();
    }
  }

  Future<void> _submit() async {
    if (!_confirming) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) {
        return;
      }
      setState(() {
        _first = _pin;
        _pin = '';
      });
      return;
    }
    if (_pin == _first) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(_pin);
    } else {
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
      setState(() {
        _error = true;
        _pin = '';
        _first = null;
      });
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
    final title = _confirming ? 'settings.repeat_pin'.tr() : 'settings.create_pin'.tr();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: Colors.transparent),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(child: CircuitBackground(key: _circuitKey, color: AppColors.green, targets: _targets)),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                const LogoMark(size: 56),
                const SizedBox(height: 20),
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  _error ? 'settings.pin_mismatch'.tr() : 'lock.enter_pin'.tr(),
                  style: TextStyle(color: _error ? AppColors.red : AppColors.textDim, fontSize: 13.5),
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
                PinPad(onDigit: _add, onBackspace: _backspace, onCenters: _onCenters),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

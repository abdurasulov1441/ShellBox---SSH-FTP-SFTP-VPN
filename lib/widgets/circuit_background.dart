import 'dart:math';

import 'package:flutter/material.dart';

class CircuitBackground extends StatefulWidget {
  const CircuitBackground({
    super.key,
    required this.color,
    this.targets = const [],
    this.buttonRadius = 36,
    this.seed = 7,
  });

  final Color color;

  /// Key centres (local pixels) the traces should wire up to.
  final List<Offset> targets;
  final double buttonRadius;
  final int seed;

  @override
  State<CircuitBackground> createState() => _CircuitBackgroundState();
}

class _CircuitBackgroundState extends State<CircuitBackground> with TickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );

  List<_Spec> _specs = const [];
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _pulse.stop();
      _pulse.value = 0.5;
      _draw.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(CircuitBackground old) {
    super.didUpdateWidget(old);
    if (old.targets.length != widget.targets.length ||
        !_sameTargets(old.targets, widget.targets)) {
      _rebuild();
    }
  }

  bool _sameTargets(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).distanceSquared > 1) {
        return false;
      }
    }
    return true;
  }

  void _rebuild() {
    if (widget.targets.isEmpty) {
      _specs = const [];
      return;
    }
    final rnd = Random(widget.seed);
    final specs = <_Spec>[];
    for (var i = 0; i < widget.targets.length; i++) {
      specs.add(_Spec(
        target: widget.targets[i],
        edge: rnd.nextInt(4),
        startFrac: 0.08 + rnd.nextDouble() * 0.84,
        bendFrac: 0.35 + rnd.nextDouble() * 0.4,
        lengthFactor: 0.6 + rnd.nextDouble() * 0.4,
        phase: rnd.nextDouble(),
      ));
    }
    _specs = specs;
    if (_reduceMotion) {
      _draw.value = 1;
    } else {
      _draw.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Decorative only; isolated so the 60 fps pulse does not repaint the PIN pad.
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([_draw, _pulse]),
          builder: (context, _) {
            return CustomPaint(
              painter: _CircuitPainter(
                specs: _specs,
                color: widget.color,
                radius: widget.buttonRadius,
                progress: Curves.easeOutCubic.transform(_draw.value),
                pulse: _pulse.value,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _Spec {
  _Spec({
    required this.target,
    required this.edge,
    required this.startFrac,
    required this.bendFrac,
    required this.lengthFactor,
    required this.phase,
  });

  final Offset target;
  final int edge;
  final double startFrac;
  final double bendFrac;
  final double lengthFactor;
  final double phase;
}

class _CircuitPainter extends CustomPainter {
  _CircuitPainter({
    required this.specs,
    required this.color,
    required this.radius,
    required this.progress,
    required this.pulse,
  });

  final List<_Spec> specs;
  final Color color;
  final double radius;
  final double progress;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    for (final spec in specs) {
      final t = spec.target;
      final gap = radius + 3;
      Offset start;
      Offset bendA;
      Offset bendB;
      Offset landing;
      final vertical = spec.edge == 0 || spec.edge == 2;
      if (vertical) {
        final sx = spec.startFrac * size.width;
        final sy = spec.edge == 0 ? 0.0 : size.height;
        start = Offset(sx, sy);
        final midY = sy + (t.dy - sy) * spec.bendFrac;
        bendA = Offset(sx, midY);
        bendB = Offset(t.dx, midY);
        final sign = (t.dy - midY) >= 0 ? 1.0 : -1.0;
        landing = Offset(t.dx, t.dy - sign * gap);
      } else {
        final sy = spec.startFrac * size.height;
        final sx = spec.edge == 1 ? size.width : 0.0;
        start = Offset(sx, sy);
        final midX = sx + (t.dx - sx) * spec.bendFrac;
        bendA = Offset(midX, sy);
        bendB = Offset(midX, t.dy);
        final sign = (t.dx - midX) >= 0 ? 1.0 : -1.0;
        landing = Offset(t.dx - sign * gap, t.dy);
      }

      final pts = [start, bendA, bendB, landing];
      final segLengths = <double>[];
      var total = 0.0;
      for (var i = 0; i < pts.length - 1; i++) {
        final l = (pts[i + 1] - pts[i]).distance;
        segLengths.add(l);
        total += l;
      }
      if (total <= 0) {
        continue;
      }
      final reveal = (progress / spec.lengthFactor).clamp(0.0, 1.0);
      final drawLen = total * reveal;

      final path = Path()..moveTo(start.dx, start.dy);
      var acc = 0.0;
      Offset endPoint = start;
      for (var i = 0; i < pts.length - 1; i++) {
        final segLen = segLengths[i];
        if (acc + segLen <= drawLen) {
          path.lineTo(pts[i + 1].dx, pts[i + 1].dy);
          endPoint = pts[i + 1];
        } else {
          final remain = drawLen - acc;
          final f = segLen == 0 ? 0.0 : remain / segLen;
          final p = Offset.lerp(pts[i], pts[i + 1], f)!;
          path.lineTo(p.dx, p.dy);
          endPoint = p;
          break;
        }
        acc += segLen;
      }

      final shimmer = 0.45 + 0.55 * (0.5 + 0.5 * sin((pulse + spec.phase) * 2 * pi));

      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.10 * shimmer * reveal)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawPath(path, glowPaint);

      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: (0.20 + 0.32 * shimmer) * reveal);
      canvas.drawPath(path, linePaint);

      // Contact pad on the moving tip of the trace.
      final padPaint = Paint()..color = color.withValues(alpha: (0.55 + 0.35 * shimmer) * (0.4 + 0.6 * reveal));
      final padRect = Rect.fromCenter(center: endPoint, width: 5.5, height: 5.5);
      canvas.drawRRect(RRect.fromRectAndRadius(padRect, const Radius.circular(1.5)), padPaint);

      // When the trace has reached the key, light up a contact ring around it.
      if (reveal >= 1.0) {
        final ringGlow = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = color.withValues(alpha: 0.10 + 0.22 * shimmer)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(t, radius + 2, ringGlow);

        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = color.withValues(alpha: 0.22 + 0.3 * shimmer);
        canvas.drawCircle(t, radius + 2, ring);

        // Small node where the trace meets the ring.
        final node = Paint()..color = color.withValues(alpha: 0.7 + 0.3 * shimmer);
        canvas.drawCircle(landing, 2.6, node);
      }
    }
  }

  @override
  bool shouldRepaint(_CircuitPainter old) =>
      old.progress != progress || old.pulse != pulse || old.color != color || old.specs != specs;
}

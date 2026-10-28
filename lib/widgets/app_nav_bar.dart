import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme.dart';

class NavItem {
  const NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.onCenterTap,
    required this.centerLabel,
    this.centerIcon = HugeIcons.strokeRoundedPlusSign,
  });

  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCenterTap;
  final String centerLabel;
  final IconData centerIcon;

  @override
  Widget build(BuildContext context) {
    final half = items.length ~/ 2;
    final left = items.sublist(0, half);
    final right = items.sublist(half);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 10)),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < left.length; i++)
                Expanded(child: _NavButton(item: left[i], active: currentIndex == i, onTap: () => onTap(i))),
              Semantics(
                button: true,
                label: centerLabel,
                excludeSemantics: true,
                onTap: onCenterTap,
                child: _CenterButton(icon: centerIcon, onTap: onCenterTap),
              ),
              for (var i = 0; i < right.length; i++)
                Expanded(
                  child: _NavButton(
                    item: right[i],
                    active: currentIndex == half + i,
                    onTap: () => onTap(half + i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.active, required this.onTap});

  final NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.textDim;
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      excludeSemantics: true,
      onTap: onTap,
      child: _buildTarget(color),
    );
  }

  Widget _buildTarget(Color color) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: active ? 1.12 : 1.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: Icon(item.icon, size: 23, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: color),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 3,
            width: active ? 18 : 0,
            decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2)),
          ),
        ],
      ),
    );
  }
}

class _CenterButton extends StatefulWidget {
  const _CenterButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_CenterButton> createState() => _CenterButtonState();
}

class _CenterButtonState extends State<_CenterButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(AppColors.accent);
    final light = hsl.withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0)).toColor();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      child: SizedBox(
        width: 70,
        child: Center(
          child: Transform.translate(
            offset: const Offset(0, -16),
            child: AnimatedScale(
              scale: _down ? 0.9 : 1.0,
              duration: const Duration(milliseconds: 110),
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [light, AppColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                  border: Border.all(color: AppColors.bg, width: 3),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 26),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

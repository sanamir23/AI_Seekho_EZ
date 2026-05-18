import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/ez_colors.dart';

enum EzButtonVariant { primary, yellow, ghost, soft }

class EzPillButton extends StatefulWidget {
  final String label;
  final Widget? child;
  final EzButtonVariant variant;
  final VoidCallback? onTap;
  final bool fullWidth;
  final double? fontSize;
  final EdgeInsets? padding;

  const EzPillButton({
    super.key,
    this.label = '',
    this.child,
    this.variant = EzButtonVariant.primary,
    this.onTap,
    this.fullWidth = false,
    this.fontSize,
    this.padding,
  });

  @override
  State<EzPillButton> createState() => _EzPillButtonState();
}

class _EzPillButtonState extends State<EzPillButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _bg {
    switch (widget.variant) {
      case EzButtonVariant.primary:
        return EzColors.ink;
      case EzButtonVariant.yellow:
        return EzColors.yellow;
      case EzButtonVariant.ghost:
      case EzButtonVariant.soft:
        return EzColors.white;
    }
  }

  Color get _fg {
    switch (widget.variant) {
      case EzButtonVariant.primary:
        return EzColors.white;
      case EzButtonVariant.yellow:
        return EzColors.ink;
      case EzButtonVariant.ghost:
      case EzButtonVariant.soft:
        return EzColors.ink;
    }
  }

  Border? get _border {
    switch (widget.variant) {
      case EzButtonVariant.ghost:
      case EzButtonVariant.soft:
        return Border.all(color: EzColors.border, width: 1);
      default:
        return null;
    }
  }

  List<BoxShadow> get _shadow {
    switch (widget.variant) {
      case EzButtonVariant.primary:
        return [
          BoxShadow(
            color: EzColors.ink.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ];
      case EzButtonVariant.yellow:
        return [
          BoxShadow(
            color: EzColors.yellow.withOpacity(0.40),
            blurRadius: 18,
            offset: const Offset(0, 6),
          )
        ];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: widget.fullWidth ? double.infinity : null,
          padding: widget.padding ??
              const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(999),
            border: _border,
            boxShadow: _shadow,
          ),
          child: widget.child ??
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: widget.fontSize ?? 15,
                  fontWeight: FontWeight.w700,
                  color: _fg,
                  letterSpacing: -0.2,
                ),
              ),
        ),
      ),
    );
  }
}

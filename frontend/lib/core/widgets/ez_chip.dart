import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/ez_colors.dart';

class EzChip extends StatelessWidget {
  final String label;
  final IconData? iconData;
  final Widget? iconWidget;
  final bool active;
  final VoidCallback? onTap;

  const EzChip({
    super.key,
    required this.label,
    this.iconData,
    this.iconWidget,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? EzColors.ink : EzColors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? EzColors.ink : EzColors.border,
            width: 1,
          ),
          boxShadow: active
              ? []
              : [
                  BoxShadow(
                    color: EzColors.shadowColor.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconWidget != null) ...[
              iconWidget!,
              const SizedBox(width: 6),
            ] else if (iconData != null) ...[
              Icon(
                iconData,
                size: 14,
                color: active ? EzColors.yellow : EzColors.ink,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? EzColors.white : EzColors.ink,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

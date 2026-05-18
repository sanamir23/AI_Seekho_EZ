import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/ez_colors.dart';

class EzBottomNav extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int>? onTap;

  const EzBottomNav({
    super.key,
    required this.activeIndex,
    this.onTap,
  });

  static const _items = [
    _NavItem(Icons.home_rounded, 'Home'),
    _NavItem(Icons.calendar_today_rounded, 'Bookings'),
    _NavItem(Icons.chat_bubble_rounded, 'Chat'),
    _NavItem(Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: EzColors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: EzColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: EzColors.ink.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
            BoxShadow(
              color: EzColors.ink.withOpacity(0.06),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: List.generate(_items.length, (i) {
            final on = i == activeIndex;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap?.call(i),
                child: AnimatedOpacity(
                  opacity: on ? 1.0 : 0.45,
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _items[i].icon,
                        size: 22,
                        color: EzColors.ink,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _items[i].label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                          color: EzColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: on ? 14 : 0,
                        height: 2,
                        decoration: BoxDecoration(
                          color: EzColors.yellowDeep,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

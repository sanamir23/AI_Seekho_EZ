import 'package:flutter/material.dart';
import '../theme/ez_colors.dart';

class WaveBars extends StatefulWidget {
  final Color color;
  final double height;
  const WaveBars(
      {super.key, this.color = EzColors.yellow, this.height = 18});

  @override
  State<WaveBars> createState() => _WaveBarsState();
}

class _WaveBarsState extends State<WaveBars> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(5, (i) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      );
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) ctrl.repeat(reverse: true);
      });
      return ctrl;
    });

    _anims = _controllers
        .map((c) =>
            Tween(begin: 0.3, end: 1.0).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut),
            ))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(5, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: AnimatedBuilder(
              animation: _anims[i],
              builder: (_, __) {
                return Container(
                  width: 3,
                  height: widget.height * _anims[i].value,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}

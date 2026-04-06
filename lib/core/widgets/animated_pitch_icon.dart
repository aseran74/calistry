import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Icono de un paso con movimiento suave (flotación + ligera escala), desfasado por [index].
class AnimatedPitchIcon extends StatefulWidget {
  const AnimatedPitchIcon({
    super.key,
    required this.icon,
    required this.index,
    required this.color,
    this.size = 22,
    this.containerPadding = 8,
  });

  final IconData icon;
  final int index;
  final Color color;
  final double size;
  final double containerPadding;

  @override
  State<AnimatedPitchIcon> createState() => _AnimatedPitchIconState();
}

class _AnimatedPitchIconState extends State<AnimatedPitchIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2600),
      vsync: this,
    );
    Future<void>.delayed(Duration(milliseconds: widget.index * 130), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * math.pi * 2;
        final dy = 2.8 * math.sin(t);
        final scale = 1.0 + 0.07 * math.sin(t + widget.index * 0.45);
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(widget.containerPadding),
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.color.withValues(alpha: 0.28),
          ),
        ),
        child: Icon(
          widget.icon,
          size: widget.size,
          color: widget.color,
        ),
      ),
    );
  }
}

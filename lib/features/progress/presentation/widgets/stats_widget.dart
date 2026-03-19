import 'package:flutter/material.dart';

/// Widget reutilizable: número grande + label + icono, con animación de contador al aparecer.
class StatsWidget extends StatefulWidget {
  const StatsWidget({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.valueStyle,
  });

  final int value;
  final String label;
  final IconData? icon;
  final TextStyle? valueStyle;

  @override
  State<StatsWidget> createState() => _StatsWidgetState();
}

class _StatsWidgetState extends State<StatsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(StatsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = widget.valueStyle ??
        theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
        );

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final displayValue = (widget.value * _animation.value).round();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null)
              Icon(widget.icon, size: 28, color: theme.colorScheme.primary),
            if (widget.icon != null) const SizedBox(height: 4),
            Text(
              '$displayValue',
              style: valueStyle,
            ),
            const SizedBox(height: 2),
            Text(
              widget.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }
}

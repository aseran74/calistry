import 'package:flutter/material.dart';
import 'package:calistenia_app/core/constants/app_pitch_steps.dart';

/// Bloque «Tu calistenia en 5 pasos» (home, login, etc.).
class AppPitchStepsPanel extends StatelessWidget {
  const AppPitchStepsPanel({super.key, this.compact = false});

  /// En login u otras pantallas con poco espacio: padding y tipografía más ajustados.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pad = compact
        ? const EdgeInsets.fromLTRB(12, 10, 12, 12)
        : const EdgeInsets.fromLTRB(16, 14, 16, 16);
    final rowGap = compact ? 6.0 : 8.0;
    final titleSize = compact ? 14.0 : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: pad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: compact ? 18 : 20,
                  color: cs.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tu calistenia en 5 pasos',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 10 : 12),
            for (var i = 0; i < kAppPitchSteps.length; i++) ...[
              if (i > 0) SizedBox(height: rowGap),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: compact ? 24 : 26,
                    height: compact ? 24 : 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontSize: compact ? 11 : null,
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      kAppPitchSteps[i],
                      style: (compact
                              ? theme.textTheme.bodySmall
                              : theme.textTheme.bodyMedium)
                          ?.copyWith(
                        height: 1.35,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

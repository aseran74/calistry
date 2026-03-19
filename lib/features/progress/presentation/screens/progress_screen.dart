import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:calistenia_app/features/progress/domain/models/user_progress_entry.dart';
import 'package:calistenia_app/features/progress/presentation/providers/progress_provider.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(userStatsProvider);
    final progressAsync = ref.watch(userProgressListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progreso'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userStatsProvider);
          ref.invalidate(userProgressListProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              statsAsync.when(
                loading: () => const _ProgressHero(
                  totalSesiones: 0,
                  tiempoTotalMin: 0,
                  rachaActual: 0,
                ),
                error: (_, __) => const _ProgressHero(
                  totalSesiones: 0,
                  tiempoTotalMin: 0,
                  rachaActual: 0,
                ),
                data: (stats) {
                  return _ProgressHero(
                    totalSesiones: stats['total_sesiones'] as int? ?? 0,
                    tiempoTotalMin:
                        ((stats['tiempo_total_segundos'] as int? ?? 0) ~/ 60),
                    rachaActual: stats['racha_actual'] as int? ?? 0,
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Actividad',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mapa rápido de constancia durante las últimas semanas.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              progressAsync.when(
                loading: () => const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => _ProgressStatePanel(
                  icon: Icons.error_outline,
                  title: 'No se pudo cargar la actividad',
                  subtitle: '$e',
                ),
                data: (list) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: _ActivityHeatmap(entries: list),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Sesiones por semana (últimas 8)',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Evolución reciente de tu consistencia.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              progressAsync.when(
                loading: () => const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SizedBox(height: 180),
                data: (list) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: SizedBox(
                      height: 180,
                      child: _SessionsLineChart(entries: list),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Historial reciente',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tus últimas sesiones registradas.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              progressAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ProgressStatePanel(
                  icon: Icons.error_outline,
                  title: 'No se pudo cargar el historial',
                  subtitle: '$e',
                ),
                data: (list) => _HistoryList(entries: list),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityHeatmap extends StatelessWidget {
  const _ActivityHeatmap({required this.entries});

  final List<UserProgressEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final days = <DateTime, int>{};
    for (var i = 0; i < 7 * 12; i++) {
      final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      days[d] = 0;
    }
    for (final e in entries) {
      if (e.completedAt == null) continue;
      final d = DateTime(e.completedAt!.year, e.completedAt!.month, e.completedAt!.day);
      if (days.containsKey(d)) days[d] = (days[d]! + 1).clamp(0, 4);
    }
    final sortedDates = days.keys.toList()..sort();
    final maxCount = days.values.isEmpty ? 1 : days.values.reduce((a, b) => a > b ? a : b);
    const columns = 7;
    const rows = 12;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(rows, (row) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(columns, (col) {
            final idx = row * columns + col;
            if (idx >= sortedDates.length) return const SizedBox(width: 12, height: 12);
            final d = sortedDates[idx];
            final count = days[d] ?? 0;
            final intensity = maxCount <= 0 ? 0.0 : count / (maxCount + 1);
            return Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: intensity == 0
                    ? theme.colorScheme.surfaceContainerHighest
                    : theme.colorScheme.primary.withValues(alpha: 0.2 + intensity * 0.8),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      }),
    );
  }
}

class _SessionsLineChart extends StatelessWidget {
  const _SessionsLineChart({required this.entries});

  final List<UserProgressEntry> entries;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekStarts = <DateTime>[];
    for (var i = 0; i < 8; i++) {
      final d = now.subtract(Duration(days: (now.weekday - 1) + i * 7));
      weekStarts.add(DateTime(d.year, d.month, d.day));
    }
    weekStarts.sort();
    final counts = List.filled(8, 0.0);
    for (final e in entries) {
      if (e.completedAt == null) continue;
      for (var i = 0; i < 8; i++) {
        final start = weekStarts[i];
        final end = start.add(const Duration(days: 7));
        if (!e.completedAt!.isBefore(start) && e.completedAt!.isBefore(end)) {
          counts[i]++;
          break;
        }
      }
    }
    final spots = List.generate(8, (i) => FlSpot(i.toDouble(), counts[7 - i]));

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.entries});

  final List<UserProgressEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (entries.isEmpty) {
      return const _ProgressStatePanel(
        icon: Icons.history_toggle_off,
        title: 'Aún no hay historial',
        subtitle: 'Completa tu primera rutina para empezar a ver tu progreso.',
      );
    }
    return Column(
      children: entries.take(20).map((e) {
        final date = e.completedAt != null
            ? '${e.completedAt!.day}/${e.completedAt!.month}/${e.completedAt!.year}'
            : '-';
        final duration = e.durationSeconds != null
            ? '${e.durationSeconds! ~/ 60} min'
            : '-';
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: theme.colorScheme.primary,
              ),
            ),
            title: Text('Rutina · $duration'),
            subtitle: Text(
              '$date${e.notes != null && e.notes!.isNotEmpty ? ' · ${e.notes}' : ''}',
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ProgressHero extends StatelessWidget {
  const _ProgressHero({
    required this.totalSesiones,
    required this.tiempoTotalMin,
    required this.rachaActual,
  });

  final int totalSesiones;
  final int tiempoTotalMin;
  final int rachaActual;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.2),
            theme.colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progreso',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Visualiza tu consistencia, racha y tiempo invertido en entrenar.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ProgressBadge(label: '$totalSesiones sesiones'),
              _ProgressBadge(label: '$tiempoTotalMin min'),
              _ProgressBadge(label: '$rachaActual días de racha'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: theme.textTheme.labelLarge),
    );
  }
}

class _ProgressStatePanel extends StatelessWidget {
  const _ProgressStatePanel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

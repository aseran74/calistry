import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/core/router/student_shell_routes.dart';
import 'package:calistenia_app/features/planning/domain/planning_slot.dart';
import 'package:calistenia_app/features/planning/presentation/providers/planning_provider.dart';
import 'package:calistenia_app/features/progress/presentation/providers/progress_provider.dart';

class PlanningMonthlyView extends ConsumerStatefulWidget {
  const PlanningMonthlyView({super.key, required this.slots});

  final List<PlanningSlot> slots;

  @override
  ConsumerState<PlanningMonthlyView> createState() => _PlanningMonthlyViewState();
}

class _PlanningMonthlyViewState extends ConsumerState<PlanningMonthlyView> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  /// Slots que se repiten por día de la semana.
  List<PlanningSlot> _slotsForDate(DateTime date) {
    final wd = date.weekday;
    return widget.slots.where((s) => s.dayOfWeek == wd).toList()
      ..sort((a, b) => a.hour != b.hour
          ? a.hour.compareTo(b.hour)
          : a.minute.compareTo(b.minute));
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// routineId hechos por fecha (yyyy-MM-dd).
  Map<String, Set<String>> _completedByDate() {
    final progress = ref.watch(userProgressListProvider).valueOrNull ?? [];
    final map = <String, Set<String>>{};
    for (final e in progress) {
      final at = e.completedAt;
      final routineId = e.routineId;
      if (at == null || routineId.isEmpty) continue;
      final key = _dateKey(at);
      map.putIfAbsent(key, () => <String>{}).add(routineId);
    }
    return map;
  }

  Future<void> _markSlotDone(PlanningSlot slot) async {
    try {
      await ref.read(apiClientProvider).saveProgress(
            routineId: slot.routineId,
            durationSeconds: null,
            notes: null,
          );
      ref.invalidate(userProgressListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('«${slot.routineName}» registrada para hoy'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showSlotSheet({
    required DateTime date,
    required PlanningSlot slot,
    required bool isDone,
  }) {
    final today = DateTime.now();
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final notifier = ref.read(planningSlotsProvider.notifier);

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    slot.routineName,
                    style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}/${date.month}/${date.year} · ${slot.timeLabel}'
                    '${isDone ? ' · Hecha' : ''}',
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (isToday)
              ListTile(
                leading: Icon(
                  isDone ? Icons.check_circle : Icons.check_circle_outline,
                  color: isDone
                      ? Theme.of(sheetContext).colorScheme.primary
                      : null,
                ),
                title: Text(isDone ? 'Hecha hoy' : 'Marcar hecha hoy'),
                subtitle: Text(
                  isDone
                      ? 'Ya consta como hecha en el progreso de hoy.'
                      : 'Registra la sesión en tu progreso.',
                ),
                onTap: isDone
                    ? null
                    : () async {
                        Navigator.of(sheetContext).pop();
                        await _markSlotDone(slot);
                      },
              )
            else
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Marcar hecha'),
                subtitle: Text(
                  isDone
                      ? 'Esta rutina ya consta hecha en ese día.'
                      : 'Solo puedes marcar «hecha» en el día de hoy (como en la vista semanal).',
                ),
                enabled: false,
              ),
            ListTile(
              leading: const Icon(Icons.play_arrow_outlined),
              title: const Text('Abrir rutina'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push(StudentShellRoutes.routinePlay(slot.routineId));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Quitar del planning'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                notifier.removeSlot(slot);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${slot.routineName} quitada del planning'),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifier = ref.read(planningSlotsProvider.notifier);
    final completedByDate = _completedByDate();
    final year = _month.year;
    final month = _month.month;
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0);
    final daysInMonth = last.day;
    final firstWeekday = first.weekday;
    const rows = 6;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return RefreshIndicator(
      onRefresh: () => notifier.load(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Toca una rutina para marcarla como hecha (solo el día de hoy) '
              'o abrirla. El ✓ indica que ya consta en el progreso de ese día.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _month = DateTime(year, month - 1);
                    });
                  },
                ),
                Text(
                  _monthLabel(month, year),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _month = DateTime(year, month + 1);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Table(
              border: TableBorder.all(color: theme.colorScheme.outlineVariant),
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  children: ['L', 'M', 'X', 'J', 'V', 'S', 'D']
                      .map(
                        (d) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: Text(
                              d,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                for (int row = 0; row < rows; row++)
                  TableRow(
                    children: List.generate(7, (col) {
                      final day = row * 7 + col + 2 - firstWeekday;
                      if (day < 1 || day > daysInMonth) {
                        return const SizedBox(height: 88);
                      }
                      final date = DateTime(year, month, day);
                      final daySlots = _slotsForDate(date);
                      final doneIds =
                          completedByDate[_dateKey(date)] ?? const <String>{};
                      final isToday = date == todayDate;
                      return _DayCell(
                        day: day,
                        isToday: isToday,
                        slots: daySlots,
                        completedRoutineIds: doneIds,
                        onSlotTap: (slot) => _showSlotSheet(
                          date: date,
                          slot: slot,
                          isDone: doneIds.contains(slot.routineId),
                        ),
                      );
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _monthLabel(int month, int year) {
    const names = [
      '',
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return '${names[month]} $year';
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.slots,
    required this.completedRoutineIds,
    required this.onSlotTap,
  });

  final int day;
  final bool isToday;
  final List<PlanningSlot> slots;
  final Set<String> completedRoutineIds;
  final void Function(PlanningSlot) onSlotTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 88,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isToday
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
            : null,
        border: Border(
          left: BorderSide(color: theme.colorScheme.outlineVariant),
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$day',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: isToday ? theme.colorScheme.primary : null,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: slots.isEmpty
                ? const SizedBox.shrink()
                : ListView.builder(
                    itemCount: slots.length,
                    itemBuilder: (context, i) {
                      final slot = slots[i];
                      final isDone =
                          completedRoutineIds.contains(slot.routineId);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Material(
                          color: isDone
                              ? theme.colorScheme.tertiaryContainer
                                  .withValues(alpha: 0.75)
                              : theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                          child: InkWell(
                            onTap: () => onSlotTap(slot),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 3,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isDone
                                        ? Icons.check_circle
                                        : Icons.fitness_center,
                                    size: 12,
                                    color: isDone
                                        ? theme.colorScheme.tertiary
                                        : theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      isDone
                                          ? '✓ ${slot.routineName}'
                                          : '${slot.timeLabel} ${slot.routineName}',
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        fontWeight:
                                            isDone ? FontWeight.w800 : null,
                                        color: isDone
                                            ? theme.colorScheme.tertiary
                                            : null,
                                        decoration: isDone
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

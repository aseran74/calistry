import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calistenia_app/features/planning/domain/planning_slot.dart';
import 'package:calistenia_app/features/planning/presentation/providers/planning_provider.dart';
import 'package:calistenia_app/features/routines/domain/models/routine.dart';
import 'package:calistenia_app/features/progress/presentation/providers/progress_provider.dart';
import 'package:calistenia_app/features/routines/presentation/providers/routines_provider.dart';

const _startHour = 6;
const _endHour = 23;
const _dayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

class PlanningWeeklyView extends ConsumerWidget {
  const PlanningWeeklyView({super.key, required this.slots});

  final List<PlanningSlot> slots;

  List<PlanningSlot> _slotsAt(List<PlanningSlot> list, int dayOfWeek, int hour, int minute) {
    return list.where((s) =>
        s.dayOfWeek == dayOfWeek && s.hour == hour && s.minute == minute).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(planningSlotsProvider.notifier);
    final routinesAsync = ref.watch(routinesListProvider('mine'));
    final assignedAsync = ref.watch(assignedRoutinesProvider);
    final progressAsync = ref.watch(userProgressListProvider);
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final completedTodayRoutineIds = progressAsync.valueOrNull
            ?.where((e) {
              final at = e.completedAt;
              if (at == null) return false;
              return !at.isBefore(todayStart) && at.isBefore(todayEnd);
            })
            .map((e) => e.routineId)
            .toSet() ??
        {};

    return RefreshIndicator(
      onRefresh: () => notifier.load(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Toca una celda para añadir rutinas. Puedes asignar varias rutinas a la misma hora.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final w = MediaQuery.sizeOf(context).width - 32;
                final cellWidth = ((w - 48) / 7).clamp(40.0, 200.0);
                return Table(
                  columnWidths: {
                    0: const FixedColumnWidth(48),
                    for (int i = 1; i <= 7; i++) i: FixedColumnWidth(cellWidth),
                  },
                  border: TableBorder.all(color: theme.colorScheme.outlineVariant),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                      children: [
                        const SizedBox(height: 40),
                        ...List.generate(7, (i) => Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              _dayLabels[i],
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        )),
                      ],
                    ),
                    for (int hour = _startHour; hour < _endHour; hour++)
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                            child: Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                          for (int day = 1; day <= 7; day++)
                            _WeeklyCell(
                              cellSlots: _slotsAt(slots, day, hour, 0),
                              isTodayColumn: day == today.weekday,
                              completedTodayRoutineIds: completedTodayRoutineIds,
                              onTap: () => _onCellTap(
                                context,
                                ref,
                                day: day,
                                hour: hour,
                                minute: 0,
                                slots: slots,
                                routinesAsync: routinesAsync,
                                assignedAsync: assignedAsync,
                                notifier: notifier,
                              ),
                            ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onCellTap(
    BuildContext context,
    WidgetRef ref, {
    required int day,
    required int hour,
    required int minute,
    required List<PlanningSlot> slots,
    required AsyncValue<List<Routine>> routinesAsync,
    required AsyncValue<List<Map<String, dynamic>>> assignedAsync,
    required PlanningSlotsNotifier notifier,
  }) {
    final cellSlots = _slotsAt(slots, day, hour, minute);
    if (cellSlots.isNotEmpty) {
      _showCellSlotsSheet(
        context,
        ref,
        day: day,
        hour: hour,
        minute: minute,
        cellSlots: cellSlots,
        routinesAsync: routinesAsync,
        assignedAsync: assignedAsync,
        notifier: notifier,
      );
      return;
    }
    _showRoutinePicker(
      context,
      ref,
      day: day,
      hour: hour,
      minute: minute,
      routinesAsync: routinesAsync,
      assignedAsync: assignedAsync,
      notifier: notifier,
    );
  }

  void _showCellSlotsSheet(
    BuildContext context,
    WidgetRef ref, {
    required int day,
    required int hour,
    required int minute,
    required List<PlanningSlot> cellSlots,
    required AsyncValue<List<Routine>> routinesAsync,
    required AsyncValue<List<Map<String, dynamic>>> assignedAsync,
    required PlanningSlotsNotifier notifier,
  }) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${_dayName(day)} ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            ...cellSlots.map((slot) => ListTile(
              leading: const Icon(Icons.fitness_center),
              title: Text(slot.routineName),
              subtitle: const Text('Toca para quitar'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                notifier.removeSlot(slot);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${slot.routineName} quitada del planning')),
                );
              },
            )),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Añadir otra rutina'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showRoutinePicker(
                  context,
                  ref,
                  day: day,
                  hour: hour,
                  minute: minute,
                  routinesAsync: routinesAsync,
                  assignedAsync: assignedAsync,
                  notifier: notifier,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRoutinePicker(
    BuildContext context,
    WidgetRef ref, {
    required int day,
    required int hour,
    required int minute,
    required AsyncValue<List<Routine>> routinesAsync,
    required AsyncValue<List<Map<String, dynamic>>> assignedAsync,
    required PlanningSlotsNotifier notifier,
  }) {
    final List<({String id, String name})> options = [];
    routinesAsync.valueOrNull?.forEach((r) => options.add((id: r.id, name: r.name)));
    assignedAsync.valueOrNull?.forEach((item) {
      final rawRoutine = item['routine'];
      final Map<String, dynamic>? r = rawRoutine is Map<String, dynamic>
          ? rawRoutine
          : (rawRoutine is List && rawRoutine.isNotEmpty)
              ? (rawRoutine.first is Map
                  ? Map<String, dynamic>.from(rawRoutine.first as Map)
                  : null)
              : null;
      if (r == null) return;
      final id = r['id']?.toString() ?? '';
      final name = r['name']?.toString() ?? 'Rutina';
      if (id.isNotEmpty && !options.any((o) => o.id == id)) {
        options.add((id: id, name: name));
      }
    });

    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No tienes rutinas. Crea una en Rutinas o espera una asignada por tu profesor.',
          ),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${_dayName(day)} ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            ...options.map((o) => ListTile(
              leading: const Icon(Icons.fitness_center),
              title: Text(o.name),
              onTap: () {
                Navigator.of(context).pop();
                notifier.addSlot(PlanningSlot(
                  dayOfWeek: day,
                  hour: hour,
                  minute: minute,
                  routineId: o.id,
                  routineName: o.name,
                ));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${o.name} asignada')),
                );
              },
            )),
          ],
        ),
      ),
    );
  }

  static String _dayName(int dayOfWeek) {
    const names = ['', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    return names[dayOfWeek.clamp(1, 7)];
  }
}

class _WeeklyCell extends StatelessWidget {
  const _WeeklyCell({
    required this.cellSlots,
    required this.isTodayColumn,
    required this.completedTodayRoutineIds,
    required this.onTap,
  });

  final List<PlanningSlot> cellSlots;
  final bool isTodayColumn;
  final Set<String> completedTodayRoutineIds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSlots = cellSlots.isNotEmpty;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: hasSlots
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
              : null,
        ),
        child: hasSlots
            ? ListView.builder(
                shrinkWrap: true,
                itemCount: cellSlots.length,
                itemBuilder: (context, i) {
                  final slot = cellSlots[i];
                  final isDone = isTodayColumn &&
                      completedTodayRoutineIds.contains(slot.routineId);
                  return Tooltip(
                    message: isDone
                        ? '${slot.routineName} · Hecha'
                        : '${slot.routineName} · ${slot.timeLabel}',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isDone)
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                        if (isDone) const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            slot.routineName,
                            style: theme.textTheme.labelSmall?.copyWith(
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )
            : const Center(child: Icon(Icons.add, size: 20)),
      ),
    );
  }
}

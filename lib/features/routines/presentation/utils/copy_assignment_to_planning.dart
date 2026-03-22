import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calistenia_app/features/planning/domain/planning_slot.dart';
import 'package:calistenia_app/features/planning/presentation/providers/planning_provider.dart';
import 'package:calistenia_app/features/routines/domain/routine_assignment_schedule.dart';

/// Copia los días y hora indicados por el profesor a los huecos del planning del alumno.
Future<void> copyAssignmentScheduleToMyPlanning({
  required WidgetRef ref,
  required BuildContext context,
  required Map<String, dynamic> assignment,
  required String routineId,
  required String routineName,
}) async {
  final days = RoutineAssignmentSchedule.parseDays(assignment['schedule_days']);
  final h = RoutineAssignmentSchedule.parseHour(assignment);
  final m = RoutineAssignmentSchedule.parseMinute(assignment);

  if (days.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tu profesor no marcó días. Usa el botón + en Planning o elige días a mano.',
        ),
      ),
    );
    return;
  }
  if (h == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No hay hora sugerida. En Planning, botón +, elige rutina y horario.',
        ),
      ),
    );
    return;
  }

  try {
    final slots = days
        .map(
          (d) => PlanningSlot(
            dayOfWeek: d,
            hour: h,
            minute: m,
            routineId: routineId,
            routineName: routineName,
          ),
        )
        .toList();
    await ref.read(planningSlotsProvider.notifier).addSlotsBulk(slots);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Añadida a Planning (${days.length} día${days.length == 1 ? '' : 's'})',
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}

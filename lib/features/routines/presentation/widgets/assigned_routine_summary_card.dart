import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:calistenia_app/core/router/student_shell_routes.dart';
import 'package:calistenia_app/features/routines/domain/models/routine.dart';
import 'package:calistenia_app/features/routines/domain/routine_assignment_schedule.dart';
import 'package:calistenia_app/features/routines/presentation/utils/copy_assignment_to_planning.dart';
import 'package:calistenia_app/features/planning/presentation/widgets/plan_routine_dialog.dart';

/// Tarjeta de una rutina asignada por el profesor (inicio / listas).
class AssignedRoutineSummaryCard extends ConsumerWidget {
  const AssignedRoutineSummaryCard({super.key, required this.item});

  final Map<String, dynamic> item;

  static Routine? parseRoutine(Map<String, dynamic> item) {
    final rawRoutine = item['routine'];
    final Map<String, dynamic>? routineJson =
        rawRoutine is Map<String, dynamic>
            ? rawRoutine
            : (rawRoutine is List && rawRoutine.isNotEmpty)
                ? (rawRoutine.first is Map
                    ? Map<String, dynamic>.from(rawRoutine.first as Map)
                    : null)
                : null;
    if (routineJson == null) return null;
    try {
      return Routine.fromJson(routineJson);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? parseTeacher(Map<String, dynamic> item) {
    final rawTeacher = item['teacher_user'];
    if (rawTeacher is Map<String, dynamic>) return rawTeacher;
    if (rawTeacher is List && rawTeacher.isNotEmpty && rawTeacher.first is Map) {
      return Map<String, dynamic>.from(rawTeacher.first as Map);
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routine = parseRoutine(item);
    if (routine == null) {
      return const SizedBox.shrink();
    }

    final teacher = parseTeacher(item);
    final usernameStr = teacher?['username']?.toString();
    final teacherLabel =
        (usernameStr != null && usernameStr.isNotEmpty)
            ? usernameStr
            : (teacher?['email']?.toString() ?? 'Profesor');

    final schedule = RoutineAssignmentSchedule.formatAssignmentRow(item);
    final canCopyToPlanning =
        RoutineAssignmentSchedule.parseDays(item['schedule_days']).isNotEmpty &&
            RoutineAssignmentSchedule.parseHour(item) != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const CircleAvatar(
                child: Icon(Icons.assignment_turned_in_outlined),
              ),
              title: Text(
                routine.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Asignada por $teacherLabel · ${routine.level}'),
                    const SizedBox(height: 4),
                    Text(
                      schedule,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(
                StudentShellRoutes.routinePlay(routine.id),
                extra: routine,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 12, 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.event_repeat_outlined, size: 18),
                    label: const Text('Horario semanal'),
                    onPressed: () => showPlanRoutineDialog(
                      context,
                      ref,
                      presetRoutineId: routine.id,
                      presetRoutineName: routine.name,
                      lockRoutineSelection: true,
                    ),
                  ),
                  if (canCopyToPlanning)
                    TextButton.icon(
                      icon:
                          const Icon(Icons.copy_all_outlined, size: 18),
                      label: const Text('Copiar horario del profesor'),
                      onPressed: () => copyAssignmentScheduleToMyPlanning(
                        ref: ref,
                        context: context,
                        assignment: item,
                        routineId: routine.id,
                        routineName: routine.name,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

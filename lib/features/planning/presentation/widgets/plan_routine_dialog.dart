import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calistenia_app/features/planning/domain/planning_slot.dart';
import 'package:calistenia_app/features/planning/presentation/providers/planning_provider.dart';
import 'package:calistenia_app/features/planning/presentation/widgets/routine_schedule_picker_section.dart';
import 'package:calistenia_app/features/routines/domain/models/routine.dart';
import 'package:calistenia_app/features/routines/presentation/providers/routines_provider.dart';

/// Diálogo para fijar horario semanal: misma rutina en varios días y hora (bloques en Planning).
///
/// Si pasas [presetRoutineId], esa rutina queda elegida; con [lockRoutineSelection] no se puede cambiar.
Future<void> showPlanRoutineDialog(
  BuildContext context,
  WidgetRef ref, {
  String? presetRoutineId,
  String? presetRoutineName,
  bool lockRoutineSelection = false,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => Consumer(
      builder: (context, ref, _) {
        return _PlanRoutineDialogBody(
          presetRoutineId: presetRoutineId,
          presetRoutineName: presetRoutineName,
          lockRoutineSelection: lockRoutineSelection,
        );
      },
    ),
  );
}

class _PlanRoutineDialogBody extends ConsumerStatefulWidget {
  const _PlanRoutineDialogBody({
    this.presetRoutineId,
    this.presetRoutineName,
    this.lockRoutineSelection = false,
  });

  final String? presetRoutineId;
  final String? presetRoutineName;
  final bool lockRoutineSelection;

  @override
  ConsumerState<_PlanRoutineDialogBody> createState() =>
      _PlanRoutineDialogBodyState();
}

class _PlanRoutineDialogBodyState extends ConsumerState<_PlanRoutineDialogBody> {
  String? _routineId;
  String _routineName = '';
  var _scheduleDays = <int>{};
  TimeOfDay? _scheduleTime = const TimeOfDay(hour: 10, minute: 0);
  var _submitting = false;
  var _defaultsApplied = false;

  @override
  void initState() {
    super.initState();
    final id = widget.presetRoutineId;
    if (id != null && id.isNotEmpty) {
      _routineId = id;
      final n = (widget.presetRoutineName ?? '').trim();
      _routineName = n.isEmpty ? 'Rutina' : n;
      _defaultsApplied = true;
    }
  }

  static List<({String id, String name})> _mineOptions(List<Routine> list) {
    return [
      for (final r in list)
        if (r.id.isNotEmpty) (id: r.id, name: r.name),
    ];
  }

  static List<({String id, String name})> _assignedOptions(
    List<Map<String, dynamic>> items,
  ) {
    final out = <({String id, String name})>[];
    for (final item in items) {
      final rawRoutine = item['routine'];
      final Map<String, dynamic>? r = rawRoutine is Map<String, dynamic>
          ? rawRoutine
          : (rawRoutine is List && rawRoutine.isNotEmpty)
              ? (rawRoutine.first is Map
                  ? Map<String, dynamic>.from(rawRoutine.first as Map)
                  : null)
              : null;
      if (r == null) continue;
      final id = r['id']?.toString() ?? '';
      final name = r['name']?.toString() ?? 'Rutina';
      if (id.isEmpty) continue;
      if (out.any((o) => o.id == id)) continue;
      out.add((id: id, name: name));
    }
    return out;
  }

  Future<void> _submit() async {
    final id = _routineId;
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige una rutina')),
      );
      return;
    }
    if (_scheduleDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marca al menos un día de la semana')),
      );
      return;
    }

    final hour = _scheduleTime?.hour ?? 9;
    final minute = _scheduleTime?.minute ?? 0;

    setState(() => _submitting = true);
    try {
      final days = _scheduleDays.toList()..sort();
      final slots = days
          .map(
            (d) => PlanningSlot(
              dayOfWeek: d,
              hour: hour,
              minute: minute,
              routineId: id,
              routineName: _routineName.isEmpty ? 'Rutina' : _routineName,
            ),
          )
          .toList();

      await ref.read(planningSlotsProvider.notifier).addSlotsBulk(slots);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Añadida a ${days.length} día${days.length == 1 ? '' : 's'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mineAsync = ref.watch(routinesListProvider('mine'));
    final assignedAsync = ref.watch(assignedRoutinesProvider);

    final locked = widget.lockRoutineSelection &&
        widget.presetRoutineId != null &&
        widget.presetRoutineId!.isNotEmpty;

    return AlertDialog(
      title: Text(locked ? 'Tu horario semanal' : 'Horario semanal'),
      content: SizedBox(
        width: 420,
        child: mineAsync.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Error rutinas: $e'),
          data: (mineList) {
            return assignedAsync.when(
              loading: () => const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Error asignadas: $e'),
              data: (assignedList) {
                final mineOpts = _mineOptions(mineList);
                final assignedOpts = _assignedOptions(assignedList);

                if (!_defaultsApplied &&
                    _routineId == null &&
                    (mineOpts.isNotEmpty || assignedOpts.isNotEmpty)) {
                  _defaultsApplied = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() {
                      if (mineOpts.isNotEmpty) {
                        _routineId = mineOpts.first.id;
                        _routineName = mineOpts.first.name;
                      } else {
                        _routineId = assignedOpts.first.id;
                        _routineName = assignedOpts.first.name;
                      }
                    });
                  });
                }

                if (mineOpts.isEmpty && assignedOpts.isEmpty) {
                  return const Text(
                    'No tienes rutinas propias ni asignadas por un profesor. '
                    'Crea una en Rutinas o acepta una invitación.',
                  );
                }

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (locked) ...[
                        Text(
                          'Rutina',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.fitness_center,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(
                            _routineName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text(
                            'Elige los días y la hora; se marcarán los bloques en Planning.',
                          ),
                        ),
                        const SizedBox(height: 8),
                      ] else ...[
                        Text(
                          'Rutina',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        if (mineOpts.isNotEmpty) ...[
                          Text(
                            'Mis rutinas',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          ...mineOpts.map(
                            (o) => RadioListTile<String>(
                              title: Text(o.name),
                              value: o.id,
                              groupValue: _routineId,
                              onChanged: _submitting
                                  ? null
                                  : (v) => setState(() {
                                        _routineId = v;
                                        _routineName = o.name;
                                      }),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (assignedOpts.isNotEmpty) ...[
                          Text(
                            'Asignadas por mi profesor',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.tertiary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          ...assignedOpts.map(
                            (o) => RadioListTile<String>(
                              title: Text(o.name),
                              value: o.id,
                              groupValue: _routineId,
                              onChanged: _submitting
                                  ? null
                                  : (v) => setState(() {
                                        _routineId = v;
                                        _routineName = o.name;
                                      }),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],
                      RoutineSchedulePickerSection(
                        daysTitle: '¿Qué días la harás?',
                        daysHint:
                            'Ejemplo: lunes, martes y viernes a las 10:00 — verás esos bloques rellenos en la cuadrícula.',
                        timeSubtitle:
                            'La cuadrícula semanal usa franjas en punto (:00). Si quitas la hora, se usa las 9:00.',
                        selectedDays: _scheduleDays,
                        onDaysChanged: (d) =>
                            setState(() => _scheduleDays = d),
                        selectedTime: _scheduleTime,
                        onTimeChanged: (t) => setState(() => _scheduleTime = t),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Guardando…' : 'Marcar bloques en Planning'),
        ),
      ],
    );
  }
}

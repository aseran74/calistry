import 'package:flutter/material.dart';
import 'package:calistenia_app/features/routines/domain/routine_assignment_schedule.dart';

/// Días de la semana (1–7) + hora opcional (planning / asignación profesor).
class RoutineSchedulePickerSection extends StatelessWidget {
  const RoutineSchedulePickerSection({
    super.key,
    required this.selectedDays,
    required this.onDaysChanged,
    required this.selectedTime,
    required this.onTimeChanged,
    this.daysTitle,
    this.daysHint,
    this.timeSubtitle,
  });

  final Set<int> selectedDays;
  final ValueChanged<Set<int>> onDaysChanged;
  final TimeOfDay? selectedTime;
  final ValueChanged<TimeOfDay?> onTimeChanged;

  /// Título de la sección de días (p. ej. distinto para alumno vs profesor).
  final String? daysTitle;

  final String? daysHint;

  /// Texto bajo la hora (contexto alumno / profesor).
  final String? timeSubtitle;

  Future<void> _pickTime(BuildContext context) async {
    final initial = selectedTime ?? const TimeOfDay(hour: 10, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) {
        return MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) onTimeChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          daysTitle ?? '¿Qué días?',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          daysHint ??
              'Marca los días en los que quieres entrenar esta rutina.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: RoutineAssignmentSchedule.dayShortEs.entries.map((e) {
            final d = e.key;
            final selected = selectedDays.contains(d);
            return FilterChip(
              label: Text(e.value),
              selected: selected,
              onSelected: (v) {
                final next = {...selectedDays};
                if (v) {
                  next.add(d);
                } else {
                  next.remove(d);
                }
                onDaysChanged(next);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        Text(
          'Hora',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            selectedTime == null
                ? 'Sin hora (solo día en la cuadrícula)'
                : '${selectedTime!.hour.toString().padLeft(2, '0')}:'
                    '${selectedTime!.minute.toString().padLeft(2, '0')}',
          ),
          subtitle: Text(
            timeSubtitle ??
                'En el planning semanal verás la rutina en esa franja horaria.',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectedTime != null)
                IconButton(
                  tooltip: 'Quitar hora',
                  icon: const Icon(Icons.clear),
                  onPressed: () => onTimeChanged(null),
                ),
              IconButton(
                tooltip: 'Elegir hora',
                icon: const Icon(Icons.schedule),
                onPressed: () => _pickTime(context),
              ),
            ],
          ),
          onTap: () => _pickTime(context),
        ),
      ],
    );
  }
}

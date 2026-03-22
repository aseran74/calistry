/// Días y hora que el profesor indica al asignar una rutina (persistente en `routine_assignments`).
class RoutineAssignmentSchedule {
  RoutineAssignmentSchedule._();

  static const dayShortEs = <int, String>{
    1: 'Lun',
    2: 'Mar',
    3: 'Mié',
    4: 'Jue',
    5: 'Vie',
    6: 'Sáb',
    7: 'Dom',
  };

  /// Parsea `schedule_days` desde JSON/API (lista de enteros 1–7).
  static List<int> parseDays(dynamic raw) {
    if (raw == null) return [];
    if (raw is! List) return [];
    final out = <int>[];
    for (final e in raw) {
      final n = e is int ? e : int.tryParse(e.toString());
      if (n != null && n >= 1 && n <= 7) out.add(n);
    }
    out.sort();
    return out;
  }

  static int? parseHour(Map<String, dynamic> row) {
    final v = row['schedule_hour'];
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static int parseMinute(Map<String, dynamic> row) {
    final v = row['schedule_minute'];
    if (v == null) return 0;
    if (v is int) return v.clamp(0, 59);
    return int.tryParse(v.toString())?.clamp(0, 59) ?? 0;
  }

  /// Texto para mostrar al alumno (ej. "Lun, Mié, Vie · 10:00" o "Sin horario fijo").
  static String formatAssignmentRow(Map<String, dynamic> assignment) {
    final days = parseDays(assignment['schedule_days']);
    final h = parseHour(assignment);
    final m = parseMinute(assignment);

    if (days.isEmpty && h == null) {
      return 'Sin horario fijo (cuando puedas)';
    }

    final dayPart = days.isEmpty
        ? 'Cualquier día'
        : days.map((d) => dayShortEs[d] ?? '$d').join(', ');

    if (h == null) {
      return dayPart;
    }

    final time =
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    return '$dayPart · $time';
  }
}

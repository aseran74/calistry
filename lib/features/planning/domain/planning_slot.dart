/// Un hueco del planning: rutina asignada a un día de la semana y una hora.
/// [dayOfWeek] 1 = lunes, 7 = domingo (DateTime.weekday).
/// [id] opcional: id en backend para borrar o sincronizar.
class PlanningSlot {
  const PlanningSlot({
    this.id,
    required this.dayOfWeek,
    required this.hour,
    required this.minute,
    required this.routineId,
    required this.routineName,
  });

  final String? id;
  final int dayOfWeek;
  final int hour;
  final int minute;
  final String routineId;
  final String routineName;

  /// Hora en formato "10:00"
  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'day_of_week': dayOfWeek,
        'hour': hour,
        'minute': minute,
        'routine_id': routineId,
        'routine_name': routineName,
      };

  factory PlanningSlot.fromJson(Map<String, dynamic> json) {
    return PlanningSlot(
      id: json['id'] as String?,
      dayOfWeek: json['day_of_week'] is int
          ? json['day_of_week'] as int
          : int.tryParse(json['day_of_week']?.toString() ?? '1') ?? 1,
      hour: json['hour'] is int
          ? json['hour'] as int
          : int.tryParse(json['hour']?.toString() ?? '0') ?? 0,
      minute: json['minute'] is int
          ? json['minute'] as int
          : int.tryParse(json['minute']?.toString() ?? '0') ?? 0,
      routineId: json['routine_id'] as String? ?? '',
      routineName: json['routine_name'] as String? ?? '',
    );
  }
}

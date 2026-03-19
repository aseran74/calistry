/// Una entrada de historial de progreso (user_progress).
class UserProgressEntry {
  final String id;
  final String routineId;
  final DateTime? completedAt;
  final int? durationSeconds;
  final String? notes;

  const UserProgressEntry({
    required this.id,
    required this.routineId,
    this.completedAt,
    this.durationSeconds,
    this.notes,
  });

  factory UserProgressEntry.fromJson(Map<String, dynamic> json) {
    DateTime? at;
    final completedAtStr = json['completed_at'];
    if (completedAtStr != null) {
      at = DateTime.tryParse(completedAtStr.toString());
    }
    return UserProgressEntry(
      id: json['id'] as String,
      routineId: json['routine_id'] as String,
      completedAt: at,
      durationSeconds: json['duration_seconds'] as int?,
      notes: json['notes'] as String?,
    );
  }
}

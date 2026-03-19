class Routine {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final String level;
  final bool isPublic;
  final String? createdAt;

  const Routine({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.level,
    required this.isPublic,
    this.createdAt,
  });

  factory Routine.fromJson(Map<String, dynamic> json) {
    return Routine(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      level: json['level'] as String? ?? 'principiante',
      isPublic: json['is_public'] as bool? ?? false,
      createdAt: json['created_at'] as String?,
    );
  }
}

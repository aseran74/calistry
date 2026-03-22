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
    final id = json['id']?.toString() ?? '';
    final userId = json['user_id']?.toString() ??
        json['userId']?.toString() ??
        json['owner_user_id']?.toString() ??
        json['ownerUserId']?.toString() ??
        '';
    final name = json['name']?.toString() ?? 'Sin nombre';
    final rawPublic = json['is_public'] ?? json['isPublic'];
    final isPublic = rawPublic == true ||
        rawPublic == 1 ||
        rawPublic?.toString() == 'true';
    final rawDesc = json['description'] ?? json['desc'];
    final String? description = rawDesc == null
        ? null
        : (rawDesc is String ? rawDesc : rawDesc.toString());
    return Routine(
      id: id,
      userId: userId,
      name: name,
      description: description,
      level: json['level']?.toString() ?? 'principiante',
      isPublic: isPublic,
      createdAt: json['created_at']?.toString() ?? json['createdAt']?.toString(),
    );
  }
}

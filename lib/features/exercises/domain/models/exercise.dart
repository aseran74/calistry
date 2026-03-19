class Exercise {
  final String id;
  final String name;
  final String? description;
  final String category;
  final String difficulty;
  final List<String> muscleGroups;
  final String? videoUrl;
  final String? gifUrl;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final bool isActive;
  final String? ownerUserId;
  final String? ownerDisplayName;

  const Exercise({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.difficulty,
    this.muscleGroups = const [],
    this.videoUrl,
    this.gifUrl,
    this.thumbnailUrl,
    this.durationSeconds,
    this.isActive = true,
    this.ownerUserId,
    this.ownerDisplayName,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? 'principiante',
      muscleGroups: (json['muscle_groups'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      videoUrl: json['video_url'] as String?,
      gifUrl: json['gif_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      ownerUserId: json['owner_user_id'] as String?,
      ownerDisplayName: json['owner_display_name'] as String?,
    );
  }

  /// URL para mostrar como imagen (solo GIF o thumbnail; no incluye video).
  String get imageUrl => gifUrl ?? thumbnailUrl ?? '';
}

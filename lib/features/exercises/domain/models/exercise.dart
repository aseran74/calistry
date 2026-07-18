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
  final int? reps;
  final int? sets;
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
    this.reps,
    this.sets,
    this.isActive = true,
    this.ownerUserId,
    this.ownerDisplayName,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    String? asNullableString(dynamic value) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty || text == 'null') return null;
      return text;
    }

    int? asNullableInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    return Exercise(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      description: asNullableString(json['description']),
      category: json['category']?.toString() ?? '',
      difficulty: json['difficulty']?.toString() ?? 'principiante',
      muscleGroups: (json['muscle_groups'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      videoUrl: asNullableString(json['video_url']),
      gifUrl: asNullableString(json['gif_url']),
      thumbnailUrl: asNullableString(json['thumbnail_url']),
      durationSeconds: asNullableInt(json['duration_seconds']),
      reps: asNullableInt(json['reps']),
      sets: asNullableInt(json['sets']),
      isActive: json['is_active'] as bool? ?? true,
      ownerUserId: asNullableString(json['owner_user_id']),
      ownerDisplayName: asNullableString(json['owner_display_name']),
    );
  }

  /// URL para mostrar como imagen (solo GIF o thumbnail; no incluye video).
  String get imageUrl => gifUrl ?? thumbnailUrl ?? '';
}

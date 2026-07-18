import 'package:calistenia_app/core/api/api_client.dart';
import 'package:calistenia_app/core/utils/user_display_name.dart';
import 'package:calistenia_app/features/exercises/domain/models/exercise.dart';

/// Enriquece filas de ejercicios con el nombre del profesor (si aplica).
Future<List<Exercise>> mapExercisesWithOwners(
  ApiClient client,
  List<Map<String, dynamic>> rows,
) async {
  final ownerIds = rows
      .map((row) => row['owner_user_id']?.toString())
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();

  var users = <Map<String, dynamic>>[];
  var teachers = <Map<String, dynamic>>[];
  if (ownerIds.isNotEmpty) {
    try {
      users = await client.getUsersByIds(ownerIds);
    } catch (_) {
      users = [];
    }
    try {
      teachers = await client.getTeacherProfilesByUserIds(ownerIds);
    } catch (_) {
      teachers = [];
    }
  }

  final usersById = {
    for (final user in users) user['id']?.toString() ?? '': user,
  };
  final teachersById = {
    for (final teacher in teachers)
      teacher['user_id']?.toString() ?? '': teacher,
  };

  return rows.map((row) {
    final ownerId = row['owner_user_id']?.toString();
    final teacher = ownerId == null || ownerId.isEmpty
        ? null
        : teachersById[ownerId];
    final owner =
        ownerId == null || ownerId.isEmpty ? null : usersById[ownerId];
    final teacherName = teacher?['display_name']?.toString().trim() ?? '';
    final resolved = teacherName.isNotEmpty
        ? teacherName
        : userDisplayNameFromJson(owner, fallback: '');
    final displayName = resolved.trim().isNotEmpty
        ? resolved.trim()
        : (ownerId != null && ownerId.isNotEmpty ? 'Profesor' : null);

    return Exercise.fromJson({
      ...row,
      'owner_display_name': displayName,
    });
  }).toList();
}

Future<Exercise?> mapExerciseWithOwner(
  ApiClient client,
  Map<String, dynamic>? json,
) async {
  if (json == null) return null;
  final mapped = await mapExercisesWithOwners(client, [json]);
  return mapped.isEmpty ? null : mapped.first;
}

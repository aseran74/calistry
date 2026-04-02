import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:calistenia_app/core/config/api_config.dart';

class ApiClient {
  ApiClient({
    String? accessToken,
    String? userId,
  })  : _accessToken = accessToken,
        _userId = userId,
        _baseUrl = ApiConfig.baseUrl;

  final String _baseUrl;
  final String? _accessToken;
  final String? _userId;

  Map<String, String> get _headers {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (ApiConfig.anonKey.isNotEmpty) {
      map['apikey'] = ApiConfig.anonKey;
    }
    final authToken = _accessToken ?? ApiConfig.anonKey;
    if (authToken.isNotEmpty) {
      map['Authorization'] = 'Bearer $authToken';
    }
    return map;
  }

  Uri _databaseUri(
    String table, {
    Map<String, String>? queryParams,
  }) {
    return Uri.parse('$_baseUrl/api/database/records/$table').replace(
      queryParameters: queryParams,
    );
  }

  Future<List<Map<String, dynamic>>> _databaseGet(
    String table, {
    Map<String, String>? queryParams,
  }) async {
    final response = await http.get(
      _databaseUri(table, queryParams: queryParams),
      headers: _headers,
    );
    return _parseListResponse(response);
  }

  Future<List<Map<String, dynamic>>> _databasePost(
    String table,
    List<Map<String, dynamic>> rows, {
    bool returnRepresentation = true,
    bool mergeDuplicates = false,
  }) async {
    final headers = <String, String>{..._headers};
    final preferValues = <String>[];
    if (mergeDuplicates) preferValues.add('resolution=merge-duplicates');
    if (returnRepresentation) preferValues.add('return=representation');
    if (preferValues.isNotEmpty) {
      headers['Prefer'] = preferValues.join(',');
    }
    final response = await http.post(
      _databaseUri(table),
      headers: headers,
      body: jsonEncode(rows),
    );
    return _parseListResponse(response);
  }

  Future<List<Map<String, dynamic>>> _databasePatch(
    String table,
    Map<String, dynamic> body, {
    Map<String, String>? queryParams,
    bool returnRepresentation = true,
  }) async {
    final headers = <String, String>{..._headers};
    if (returnRepresentation) {
      headers['Prefer'] = 'return=representation';
    }
    final response = await http.patch(
      _databaseUri(table, queryParams: queryParams),
      headers: headers,
      body: jsonEncode(body),
    );
    return _parseListResponse(response);
  }

  Future<List<Map<String, dynamic>>> _databaseDelete(
    String table, {
    Map<String, String>? queryParams,
    bool returnRepresentation = false,
  }) async {
    final headers = <String, String>{..._headers};
    if (returnRepresentation) {
      headers['Prefer'] = 'return=representation';
    }
    final response = await http.delete(
      _databaseUri(table, queryParams: queryParams),
      headers: headers,
    );
    return _parseListResponse(response, allowEmptySuccess: true);
  }

  List<Map<String, dynamic>> _parseListResponse(
    http.Response response, {
    bool allowEmptySuccess = false,
  }) {
    final body = response.body.trim();
    if (response.statusCode >= 400) {
      throw Exception(_extractErrorMessage(response));
    }
    if (body.isEmpty) {
      return allowEmptySuccess ? [] : [];
    }
    if (body.startsWith('<!DOCTYPE html') || body.startsWith('<html')) {
      throw Exception(
        'El backend devolvió HTML en vez de JSON. Revisa la ruta consultada.',
      );
    }
    final decoded = jsonDecode(body);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      // Algunos endpoints/instalaciones devuelven { rows: [...] }.
      final rows = decoded['rows'];
      if (rows is List) {
        return rows
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      // Otros formatos comunes: { result: [...] } o { items: [...] }.
      for (final key in const ['result', 'items', 'records']) {
        final v = decoded[key];
        if (v is List) {
          return v
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
      // Fallback: si hay alguna lista en el primer nivel, úsala.
      for (final entry in decoded.entries) {
        final v = entry.value;
        if (v is List) {
          final mapped = v
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          if (mapped.isNotEmpty || v.isEmpty) return mapped;
        }
      }
    }
    throw Exception('Respuesta no válida del backend.');
  }

  String _extractErrorMessage(http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) {
      return 'Error ${response.statusCode} del backend.';
    }
    if (body.startsWith('<!DOCTYPE html') || body.startsWith('<html')) {
      return 'Ruta no encontrada en Insforge (${response.statusCode}).';
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded['message'] as String? ??
            decoded['error'] as String? ??
            'Error ${response.statusCode} del backend.';
      }
    } catch (_) {
      return body;
    }
    return 'Error ${response.statusCode} del backend.';
  }

  String _requireUserId() {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      throw Exception('No hay usuario autenticado para esta operación.');
    }
    return userId;
  }

  Future<List<Map<String, dynamic>>> getExercises({
    String? category,
    String? difficulty,
    String? muscleGroup,
    String? search,
    String? ownerUserId,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
      'order': 'created_at.desc',
      'is_active': 'eq.true',
    };
    if (category != null && category.isNotEmpty) {
      params['category'] = 'eq.$category';
    }
    if (difficulty != null && difficulty.isNotEmpty) {
      params['difficulty'] = 'eq.$difficulty';
    }
    if (muscleGroup != null && muscleGroup.isNotEmpty) {
      params['muscle_groups'] = 'like.*$muscleGroup*';
    }
    if (search != null && search.isNotEmpty) {
      params['name'] = 'ilike.*$search*';
    }
    if (ownerUserId != null && ownerUserId.isNotEmpty) {
      params['owner_user_id'] = 'eq.$ownerUserId';
    }
    return _databaseGet('exercises', queryParams: params);
  }

  Future<Map<String, dynamic>?> submitExerciseProposal({
    required String name,
    required String category,
    required String difficulty,
    String? description,
    List<String> muscleGroups = const [],
    int? durationSeconds,
    int? reps,
    int? sets,
    String? gifUrl,
    String? videoUrl,
    String? thumbnailUrl,
  }) async {
    final userId = _requireUserId();
    final created = await _databasePost(
      'exercise_submissions',
      [
        {
          'proposed_by_user_id': userId,
          'name': name,
          'description': description,
          'category': category,
          'difficulty': difficulty,
          'muscle_groups': muscleGroups,
          'duration_seconds': durationSeconds,
          'reps': reps,
          'sets': sets,
          'gif_url': gifUrl,
          'video_url': videoUrl,
          'thumbnail_url': thumbnailUrl,
        }
      ],
    );
    if (created.isEmpty) return null;
    return created.first;
  }

  Future<Map<String, dynamic>?> createTeacherExercise({
    required String name,
    required String category,
    required String difficulty,
    String? description,
    List<String> muscleGroups = const [],
    int? durationSeconds,
    int? reps,
    int? sets,
    String? gifUrl,
    String? videoUrl,
    String? thumbnailUrl,
    bool isActive = true,
  }) async {
    final userId = _requireUserId();
    final created = await _databasePost(
      'exercises',
      [
        {
          'owner_user_id': userId,
          'name': name,
          'description': description,
          'category': category,
          'difficulty': difficulty,
          'muscle_groups': muscleGroups,
          'duration_seconds': durationSeconds,
          'reps': reps,
          'sets': sets,
          'gif_url': gifUrl,
          'video_url': videoUrl,
          'thumbnail_url': thumbnailUrl,
          'is_active': isActive,
        }
      ],
    );
    if (created.isEmpty) return null;
    return created.first;
  }

  Future<List<Map<String, dynamic>>> getMyExerciseSubmissions() async {
    final userId = _requireUserId();
    return _databaseGet(
      'exercise_submissions',
      queryParams: {
        'proposed_by_user_id': 'eq.$userId',
        'order': 'created_at.desc',
        'limit': '50',
      },
    );
  }

  Future<Map<String, dynamic>?> getExercise(String id) async {
    final list = await _databaseGet(
      'exercises',
      queryParams: {
        'id': 'eq.$id',
        'limit': '1',
        'is_active': 'eq.true',
      },
    );
    if (list.isEmpty) return null;
    return list.first;
  }

  Future<bool> toggleFavorite(String exerciseId) async {
    final userId = _requireUserId();
    final existing = await _databaseGet(
      'user_favorites',
      queryParams: {
        'user_id': 'eq.$userId',
        'exercise_id': 'eq.$exerciseId',
        'limit': '1',
      },
    );
    if (existing.isNotEmpty) {
      await _databaseDelete(
        'user_favorites',
        queryParams: {
          'user_id': 'eq.$userId',
          'exercise_id': 'eq.$exerciseId',
        },
      );
      return false;
    }

    await _databasePost(
      'user_favorites',
      [
        {
          'user_id': userId,
          'exercise_id': exerciseId,
        }
      ],
      returnRepresentation: false,
    );
    return true;
  }

  Future<List<Map<String, dynamic>>> getFavoriteExercises() async {
    final userId = _requireUserId();
    final favorites = await _databaseGet(
      'user_favorites',
      queryParams: {
        'user_id': 'eq.$userId',
      },
    );
    if (favorites.isEmpty) return [];
    final ids = favorites
        .map((e) => e['exercise_id']?.toString())
        .whereType<String>()
        .toList();
    if (ids.isEmpty) return [];
    return _databaseGet(
      'exercises',
      queryParams: {
        'id': 'in.(${ids.join(',')})',
        'is_active': 'eq.true',
      },
    );
  }

  Future<List<Map<String, dynamic>>> getRoutines({
    String? userId,
    bool? isPublic,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
      'order': 'created_at.desc',
    };
    if (userId != null && userId.isNotEmpty) {
      params['user_id'] = 'eq.$userId';
    }
    if (isPublic != null) {
      params['is_public'] = 'eq.$isPublic';
    }
    return _databaseGet('routines', queryParams: params);
  }

  /// True si la fila de `routines` pertenece al usuario (varias claves según API/Insforge).
  /// IDs en filas de `routine_assignments` (snake_case / camelCase / embed).
  static String? assignmentRoutineId(Map<String, dynamic> a) {
    final v = a['routine_id'] ?? a['routineId'];
    if (v == null) return null;
    if (v is Map) {
      final id = v['id'] ?? v['_id'];
      if (id == null) return null;
      final s = id.toString();
      return s.isEmpty ? null : s;
    }
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  static String? assignmentTeacherUserId(Map<String, dynamic> a) {
    final v = a['teacher_user_id'] ?? a['teacherUserId'];
    if (v == null) return null;
    if (v is Map) {
      final id = v['id'] ?? v['_id'];
      if (id == null) return null;
      final s = id.toString();
      return s.isEmpty ? null : s;
    }
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  static bool routineRowBelongsToUser(Map<String, dynamic> row, String userId) {
    if (userId.isEmpty) return false;
    for (final key in const [
      'user_id',
      'userId',
      'owner_user_id',
      'ownerUserId',
      'profile_id',
      'profileId',
      'author_id',
      'authorId',
      'created_by',
      'createdBy',
    ]) {
      final v = row[key];
      if (v != null && v.toString() == userId) return true;
    }
    return false;
  }

  /// Rutinas creadas por el usuario actual. Combina filtro PostgREST + filtro local
  /// por si `user_id=eq.x` no devuelve filas aunque RLS sí permita leerlas.
  Future<List<Map<String, dynamic>>> getMyRoutines({int limit = 100}) async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) return [];

    final byId = <String, Map<String, dynamic>>{};
    void take(List<Map<String, dynamic>> rows) {
      for (final r in rows) {
        final id = r['id']?.toString();
        if (id != null && id.isNotEmpty) byId[id] = r;
      }
    }

    // 1) Filtro PostgREST clásico
    final byParam = await getRoutines(userId: userId, limit: limit);
    take(byParam);

    // 2) OR por varias columnas de propietario (si existen en el esquema)
    try {
      final orRows = await _databaseGet(
        'routines',
        queryParams: {
          'limit': limit.toString(),
          'offset': '0',
          'order': 'created_at.desc',
          'or': '(user_id.eq.$userId,owner_user_id.eq.$userId,profile_id.eq.$userId,author_id.eq.$userId)',
        },
      );
      take(orRows.where((row) => routineRowBelongsToUser(row, userId)).toList());
    } catch (_) {
      // Columnas distintas o sintaxis no soportada: ignorar
    }

    // 3) Lista amplia con JWT + filtro local (RLS suele limitar filas visibles)
    try {
      final wide = await _databaseGet(
        'routines',
        queryParams: {
          'limit': limit.toString(),
          'offset': '0',
          'order': 'created_at.desc',
        },
      );
      take(wide.where((row) => routineRowBelongsToUser(row, userId)).toList());
    } catch (_) {
      // Sin permiso para listar sin filtro
    }

    final out = byId.values.toList();
    out.sort((a, b) {
      final ta = a['created_at']?.toString() ?? '';
      final tb = b['created_at']?.toString() ?? '';
      return tb.compareTo(ta);
    });
    if (out.length > limit) {
      return out.sublist(0, limit);
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> getPlanningSlots() async {
    final userId = _requireUserId();
    return _databaseGet(
      'planning_slots',
      queryParams: {
        'user_id': 'eq.$userId',
        'order': 'day_of_week.asc,hour.asc,minute.asc',
        'limit': '500',
      },
    );
  }

  Future<Map<String, dynamic>?> addPlanningSlot({
    required int dayOfWeek,
    required int hour,
    required int minute,
    required String routineId,
    required String routineName,
  }) async {
    final userId = _requireUserId();
    final created = await _databasePost(
      'planning_slots',
      [
        {
          'user_id': userId,
          'day_of_week': dayOfWeek,
          'hour': hour,
          'minute': minute,
          'routine_id': routineId,
          'routine_name': routineName,
        },
      ],
    );
    if (created.isEmpty) return null;
    return created.first;
  }

  Future<void> deletePlanningSlot(String slotId) async {
    await _databaseDelete(
      'planning_slots',
      queryParams: {'id': 'eq.$slotId'},
    );
  }

  Future<Map<String, dynamic>?> getMyTeacherApplication() async {
    final userId = _requireUserId();
    final list = await _databaseGet(
      'teacher_applications',
      queryParams: {
        'user_id': 'eq.$userId',
        'limit': '1',
      },
    );
    if (list.isEmpty) return null;
    return list.first;
  }

  Future<Map<String, dynamic>?> submitTeacherApplication({
    required String displayName,
    String? specialty,
    String? bio,
    String? motivation,
  }) async {
    final userId = _requireUserId();
    final existing = await getMyTeacherApplication();
    final payload = {
      'display_name': displayName,
      'specialty': specialty,
      'bio': bio,
      'motivation': motivation,
      'status': 'pending',
      'review_notes': null,
      'reviewed_by_user_id': null,
      'reviewed_at': null,
    };
    if (existing != null) {
      final updated = await _databasePatch(
        'teacher_applications',
        payload,
        queryParams: {'id': 'eq.${existing['id']}'},
      );
      return updated.isEmpty ? null : updated.first;
    }
    final created = await _databasePost(
      'teacher_applications',
      [
        {
          'user_id': userId,
          ...payload,
        }
      ],
    );
    if (created.isEmpty) return null;
    return created.first;
  }

  Future<List<Map<String, dynamic>>> getApprovedTeachers({
    String search = '',
  }) async {
    final params = <String, String>{
      'status': 'eq.approved',
      'order': 'created_at.desc',
      'limit': '100',
    };
    if (search.trim().isNotEmpty) {
      params['or'] =
          '(display_name.ilike.*${search.trim()}*,specialty.ilike.*${search.trim()}*,bio.ilike.*${search.trim()}*)';
    }
    return _databaseGet('teacher_applications', queryParams: params);
  }

  Future<Map<String, dynamic>?> getTeacherProfile(String teacherUserId) async {
    final list = await _databaseGet(
      'teacher_applications',
      queryParams: {
        'user_id': 'eq.$teacherUserId',
        'status': 'eq.approved',
        'limit': '1',
      },
    );
    if (list.isEmpty) return null;
    return list.first;
  }

  /// Actualiza el perfil del profesor (redes sociales). Solo el propio profesor.
  Future<Map<String, dynamic>?> updateTeacherProfile({
    String? instagramUrl,
    String? tiktokUrl,
    String? facebookUrl,
  }) async {
    final userId = _requireUserId();
    final body = <String, dynamic>{};
    if (instagramUrl != null) body['instagram_url'] = instagramUrl.isEmpty ? null : instagramUrl;
    if (tiktokUrl != null) body['tiktok_url'] = tiktokUrl.isEmpty ? null : tiktokUrl;
    if (facebookUrl != null) body['facebook_url'] = facebookUrl.isEmpty ? null : facebookUrl;
    if (body.isEmpty) return getTeacherProfile(userId);
    final updated = await _databasePatch(
      'teacher_applications',
      body,
      queryParams: {'user_id': 'eq.$userId'},
    );
    if (updated.isEmpty) return null;
    return updated.first;
  }

  Future<Map<String, dynamic>?> requestTeacherFollow(
      String teacherUserId) async {
    final userId = _requireUserId();
    final existing = await _databaseGet(
      'teacher_student_links',
      queryParams: {
        'teacher_user_id': 'eq.$teacherUserId',
        'student_user_id': 'eq.$userId',
        'limit': '1',
      },
    );
    if (existing.isNotEmpty) return existing.first;
    final created = await _databasePost(
      'teacher_student_links',
      [
        {
          'teacher_user_id': teacherUserId,
          'student_user_id': userId,
          'requested_by_user_id': userId,
          'status': 'pending',
        }
      ],
    );
    if (created.isEmpty) return null;
    return created.first;
  }

  Future<List<Map<String, dynamic>>> getMyTeacherStudentLinks({
    required bool asTeacher,
    String? status,
  }) async {
    final userId = _requireUserId();
    final params = <String, String>{
      asTeacher ? 'teacher_user_id' : 'student_user_id': 'eq.$userId',
      'order': 'created_at.desc',
      'limit': '100',
    };
    if (status != null && status.isNotEmpty) {
      params['status'] = 'eq.$status';
    }
    return _databaseGet('teacher_student_links', queryParams: params);
  }

  Future<Map<String, dynamic>?> reviewTeacherStudentLink({
    required String linkId,
    required String status,
    String? reviewNotes,
    String? groupName,
  }) async {
    final body = <String, dynamic>{
      'status': status,
      'review_notes': reviewNotes,
      'approved_at': status == 'approved'
          ? DateTime.now().toUtc().toIso8601String()
          : null,
    };
    if (groupName != null) body['group_name'] = groupName.trim().isEmpty ? null : groupName.trim();
    final updated = await _databasePatch(
      'teacher_student_links',
      body,
      queryParams: {'id': 'eq.$linkId'},
    );
    if (updated.isEmpty) return null;
    return updated.first;
  }

  /// Actualiza el nombre del grupo de un enlace profesor-alumno (solo enlaces aprobados).
  Future<Map<String, dynamic>?> updateTeacherStudentLinkGroupName({
    required String linkId,
    String? groupName,
  }) async {
    final updated = await _databasePatch(
      'teacher_student_links',
      {'group_name': groupName?.trim().isEmpty ?? true ? null : groupName!.trim()},
      queryParams: {'id': 'eq.$linkId'},
    );
    if (updated.isEmpty) return null;
    return updated.first;
  }

  Future<List<Map<String, dynamic>>> getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    final ids = userIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return [];
    return _databaseGet(
      'users',
      queryParams: {
        'id': 'in.(${ids.join(',')})',
      },
    );
  }

  Future<Map<String, dynamic>?> getUserById(String userId) async {
    final list = await _databaseGet(
      'users',
      queryParams: {
        'id': 'eq.$userId',
        'limit': '1',
      },
    );
    if (list.isEmpty) return null;
    return list.first;
  }

  Future<List<Map<String, dynamic>>> listConversations() async {
    final userId = _requireUserId();
    final participantRows = await _databaseGet(
      'conversation_participants',
      queryParams: {
        'user_id': 'eq.$userId',
        'order': 'created_at.desc',
        'limit': '100',
      },
    );
    if (participantRows.isEmpty) return [];
    final conversationIds = participantRows
        .map((row) => row['conversation_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    final conversations = await _databaseGet(
      'conversations',
      queryParams: {
        'id': 'in.(${conversationIds.join(',')})',
        'order': 'created_at.desc',
      },
    );
    final allParticipants = await _databaseGet(
      'conversation_participants',
      queryParams: {
        'conversation_id': 'in.(${conversationIds.join(',')})',
      },
    );
    final peerIds = allParticipants
        .where((row) => row['user_id']?.toString() != userId)
        .map((row) => row['user_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    final users = await getUsersByIds(peerIds);
    final userMap = {for (final user in users) user['id'].toString(): user};

    return conversations.map((conversation) {
      final conversationId = conversation['id']?.toString();
      final peerParticipant =
          allParticipants.cast<Map<String, dynamic>?>().firstWhere(
                (row) =>
                    row?['conversation_id']?.toString() == conversationId &&
                    row?['user_id']?.toString() != userId,
                orElse: () => null,
              );
      final peerUserId = peerParticipant?['user_id']?.toString();
      return {
        ...conversation,
        'peer_user': peerUserId == null ? null : userMap[peerUserId],
        'peer_user_id': peerUserId,
      };
    }).toList();
  }

  /// Obtiene la conversación por id. Si no está en la lista (p. ej. faltaban
  /// participantes), la busca por id, asegura participantes y la devuelve.
  Future<Map<String, dynamic>?> getConversationById(
      String conversationId) async {
    final conversations = await listConversations();
    final fromList = conversations.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['id']?.toString() == conversationId,
          orElse: () => null,
        );
    if (fromList != null) return fromList;

    final direct = await _databaseGet(
      'conversations',
      queryParams: {'id': 'eq.$conversationId', 'limit': '1'},
    );
    if (direct.isEmpty) return null;
    final conversation = Map<String, dynamic>.from(direct.first);
    final teacherUserId = conversation['teacher_user_id']?.toString();
    final studentUserId = conversation['student_user_id']?.toString();
    if (teacherUserId != null &&
        teacherUserId.isNotEmpty &&
        studentUserId != null &&
        studentUserId.isNotEmpty) {
      await _ensureConversationParticipants(
        conversationId: conversationId,
        teacherUserId: teacherUserId,
        studentUserId: studentUserId,
      );
    }
    final me = _requireUserId();
    final peerId = me == teacherUserId ? studentUserId : teacherUserId;
    if (peerId != null && peerId.isNotEmpty) {
      final peerUser = await getUserById(peerId);
      if (peerUser != null) conversation['peer_user'] = peerUser;
    }
    return conversation;
  }

  Future<Map<String, dynamic>?> ensureConversation({
    required String teacherUserId,
    required String studentUserId,
  }) async {
    final existing = await _databaseGet(
      'conversations',
      queryParams: {
        'teacher_user_id': 'eq.$teacherUserId',
        'student_user_id': 'eq.$studentUserId',
        'limit': '1',
      },
    );
    final String? conversationId;
    final Map<String, dynamic> conversation;
    if (existing.isNotEmpty) {
      conversation = existing.first;
      conversationId = conversation['id']?.toString();
      if (conversationId != null && conversationId.isNotEmpty) {
        await _ensureConversationParticipants(
          conversationId: conversationId,
          teacherUserId: teacherUserId,
          studentUserId: studentUserId,
        );
      }
      return conversation;
    }

    final created = await _databasePost(
      'conversations',
      [
        {
          'teacher_user_id': teacherUserId,
          'student_user_id': studentUserId,
        }
      ],
    );
    if (created.isEmpty) return null;
    conversation = created.first;
    conversationId = conversation['id']?.toString();
    if (conversationId != null && conversationId.isNotEmpty) {
      await _ensureConversationParticipants(
        conversationId: conversationId,
        teacherUserId: teacherUserId,
        studentUserId: studentUserId,
      );
    }
    return conversation;
  }

  /// Inserta los participantes de la conversación si no existen (permite enviar mensajes).
  Future<void> _ensureConversationParticipants({
    required String conversationId,
    required String teacherUserId,
    required String studentUserId,
  }) async {
    final existing = await _databaseGet(
      'conversation_participants',
      queryParams: {
        'conversation_id': 'eq.$conversationId',
      },
    );
    final existingUserIds = existing
        .map((r) => r['user_id']?.toString())
        .whereType<String>()
        .toSet();
    final toInsert = <Map<String, dynamic>>[];
    if (!existingUserIds.contains(teacherUserId)) {
      toInsert.add({
        'conversation_id': conversationId,
        'user_id': teacherUserId,
        'participant_role': 'teacher',
      });
    }
    if (!existingUserIds.contains(studentUserId)) {
      toInsert.add({
        'conversation_id': conversationId,
        'user_id': studentUserId,
        'participant_role': 'student',
      });
    }
    if (toInsert.isNotEmpty) {
      await _databasePost(
        'conversation_participants',
        toInsert,
        returnRepresentation: false,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(String conversationId) async {
    return _databaseGet(
      'messages',
      queryParams: {
        'conversation_id': 'eq.$conversationId',
        'order': 'created_at.asc',
        'limit': '300',
      },
    );
  }

  // ==========================
  // Grupos de alumnos (teacher)
  // ==========================

  Future<List<Map<String, dynamic>>> getTeacherGroups() async {
    final userId = _requireUserId();
    return _databaseGet(
      'teacher_groups',
      queryParams: {
        'teacher_user_id': 'eq.$userId',
        'order': 'created_at.desc',
        'limit': '200',
      },
    );
  }

  Future<Map<String, dynamic>?> createTeacherGroup({
    required String name,
  }) async {
    final userId = _requireUserId();
    final created = await _databasePost(
      'teacher_groups',
      [
        {
          'teacher_user_id': userId,
          'name': name.trim(),
        }
      ],
    );
    if (created.isEmpty) return null;
    return created.first;
  }

  Future<void> deleteTeacherGroup(String groupId) async {
    await _databaseDelete(
      'teacher_groups',
      queryParams: {'id': 'eq.$groupId'},
    );
  }

  Future<List<Map<String, dynamic>>> getTeacherGroupMembers(String groupId) async {
    return _databaseGet(
      'teacher_group_members',
      queryParams: {
        'group_id': 'eq.$groupId',
        'order': 'created_at.desc',
        'limit': '500',
      },
    );
  }

  Future<Map<String, dynamic>?> addStudentToGroup({
    required String groupId,
    required String studentUserId,
  }) async {
    final created = await _databasePost(
      'teacher_group_members',
      [
        {
          'group_id': groupId,
          'student_user_id': studentUserId,
        }
      ],
      mergeDuplicates: true,
    );
    if (created.isEmpty) return null;
    return created.first;
  }

  Future<void> removeStudentFromGroup({
    required String groupId,
    required String studentUserId,
  }) async {
    await _databaseDelete(
      'teacher_group_members',
      queryParams: {
        'group_id': 'eq.$groupId',
        'student_user_id': 'eq.$studentUserId',
      },
    );
  }

  Future<Map<String, dynamic>?> ensureGroupConversation({
    required String groupId,
  }) async {
    final existing = await _databaseGet(
      'group_conversations',
      queryParams: {'group_id': 'eq.$groupId', 'limit': '1'},
    );
    if (existing.isNotEmpty) return existing.first;
    final created = await _databasePost(
      'group_conversations',
      [
        {'group_id': groupId}
      ],
    );
    if (created.isEmpty) return null;
    return created.first;
  }

  Future<void> ensureGroupConversationParticipants({
    required String groupConversationId,
    required String groupId,
  }) async {
    // Teacher + todos los miembros del grupo
    final me = _requireUserId();
    final members = await getTeacherGroupMembers(groupId);
    final userIds = <String>{me, ...members.map((m) => m['student_user_id']?.toString()).whereType<String>()};
    if (userIds.isEmpty) return;

    final existing = await _databaseGet(
      'group_conversation_participants',
      queryParams: {'group_conversation_id': 'eq.$groupConversationId', 'limit': '1000'},
    );
    final existingIds = existing.map((r) => r['user_id']?.toString()).whereType<String>().toSet();

    final toInsert = userIds
        .where((id) => id.isNotEmpty && !existingIds.contains(id))
        .map((id) => {'group_conversation_id': groupConversationId, 'user_id': id})
        .toList();
    if (toInsert.isEmpty) return;
    await _databasePost(
      'group_conversation_participants',
      toInsert,
      returnRepresentation: false,
      mergeDuplicates: true,
    );
  }

  Future<List<Map<String, dynamic>>> getGroupMessages(String groupConversationId) async {
    return _databaseGet(
      'group_messages',
      queryParams: {
        'group_conversation_id': 'eq.$groupConversationId',
        'order': 'created_at.asc',
        'limit': '500',
      },
    );
  }

  Future<Map<String, dynamic>?> sendGroupMessage({
    required String groupConversationId,
    required String body,
  }) async {
    final userId = _requireUserId();
    final created = await _databasePost(
      'group_messages',
      [
        {
          'group_conversation_id': groupConversationId,
          'sender_user_id': userId,
          'body': body,
        }
      ],
    );
    if (created.isEmpty) return null;
    return created.first;
  }

  Future<void> assignRoutineToGroup({
    required String routineId,
    required String groupId,
    String? notes,
    List<int>? scheduleDays,
    int? scheduleHour,
    int scheduleMinute = 0,
  }) async {
    final userId = _requireUserId();
    final members = await getTeacherGroupMembers(groupId);
    final studentIds = members
        .map((m) => m['student_user_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (studentIds.isEmpty) return;

    final schedule = _routineAssignmentSchedulePayload(
      scheduleDays: scheduleDays,
      scheduleHour: scheduleHour,
      scheduleMinute: scheduleMinute,
    );

    final rows = studentIds
        .map((studentId) => {
              'routine_id': routineId,
              'teacher_user_id': userId,
              'student_user_id': studentId,
              'notes': notes,
              'status': 'active',
              ...schedule,
            })
        .toList();

    await _databasePost(
      'routine_assignments',
      rows,
      returnRepresentation: false,
      mergeDuplicates: true,
    );
  }

  Future<Map<String, dynamic>?> sendMessage({
    required String conversationId,
    required String body,
  }) async {
    final userId = _requireUserId();
    final created = await _databasePost(
      'messages',
      [
        {
          'conversation_id': conversationId,
          'sender_user_id': userId,
          'body': body,
        }
      ],
    );
    if (created.isEmpty) return null;
    return created.first;
  }

  Future<List<Map<String, dynamic>>> getLiveClasses({
    String? teacherUserId,
    String? status,
  }) async {
    final params = <String, String>{
      'order': 'created_at.desc',
      'limit': '100',
    };
    if (teacherUserId != null && teacherUserId.isNotEmpty) {
      params['teacher_user_id'] = 'eq.$teacherUserId';
    }
    if (status != null && status.isNotEmpty) {
      params['status'] = 'eq.$status';
    }
    return _databaseGet('live_classes', queryParams: params);
  }

  Future<Map<String, dynamic>?> getLiveClassById(String liveClassId) async {
    final list = await _databaseGet(
      'live_classes',
      queryParams: {
        'id': 'eq.$liveClassId',
        'limit': '1',
      },
    );
    if (list.isEmpty) return null;
    return list.first;
  }

  Future<Map<String, dynamic>?> createLiveClass({
    required String title,
    String? description,
    required DateTime scheduledAtUtc,
    required String platform,
    required String meetingUrl,
    required String audienceType, // 'group' | 'student'
    String? groupId,
    String? studentUserId,
  }) async {
    final userId = _requireUserId();
    final created = await _databasePost(
      'live_classes',
      [
        {
          'teacher_user_id': userId,
          'title': title,
          'description': description,
          'status': 'scheduled',
          'scheduled_at': scheduledAtUtc.toIso8601String(),
          'platform': platform,
          'meeting_url': meetingUrl,
          'audience_type': audienceType,
          'group_id': groupId,
          'student_user_id': studentUserId,
        }
      ],
    );
    if (created.isEmpty) return null;
    return created.first;
  }

  Future<Map<String, dynamic>?> endLiveClass(String liveClassId) async {
    final updated = await _databasePatch(
      'live_classes',
      {
        'status': 'ended',
        'ended_at': DateTime.now().toUtc().toIso8601String(),
      },
      queryParams: {'id': 'eq.$liveClassId'},
    );
    if (updated.isEmpty) return null;
    return updated.first;
  }

  Future<Map<String, dynamic>?> joinLiveClass({
    required String liveClassId,
    required String participantRole,
  }) async {
    final userId = _requireUserId();
    final existing = await _databaseGet(
      'live_class_participants',
      queryParams: {
        'live_class_id': 'eq.$liveClassId',
        'user_id': 'eq.$userId',
        'limit': '1',
      },
    );
    if (existing.isNotEmpty) {
      final updated = await _databasePatch(
        'live_class_participants',
        {
          'is_connected': true,
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        },
        queryParams: {'id': 'eq.${existing.first['id']}'},
      );
      return updated.isEmpty ? null : updated.first;
    }
    final created = await _databasePost(
      'live_class_participants',
      [
        {
          'live_class_id': liveClassId,
          'user_id': userId,
          'participant_role': participantRole,
          'is_connected': true,
        }
      ],
    );
    if (created.isEmpty) return null;
    return created.first;
  }

  Future<void> leaveLiveClass(String liveClassId) async {
    final userId = _requireUserId();
    await _databasePatch(
      'live_class_participants',
      {
        'is_connected': false,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      },
      queryParams: {
        'live_class_id': 'eq.$liveClassId',
        'user_id': 'eq.$userId',
      },
      returnRepresentation: false,
    );
  }

  Future<List<Map<String, dynamic>>> getLiveClassParticipants(
    String liveClassId,
  ) async {
    return _databaseGet(
      'live_class_participants',
      queryParams: {
        'live_class_id': 'eq.$liveClassId',
        'order': 'joined_at.asc',
        'limit': '200',
      },
    );
  }

  Future<List<Map<String, dynamic>>> getLiveClassChatMessages(
    String liveClassId,
  ) async {
    return _databaseGet(
      'live_class_chat_messages',
      queryParams: {
        'live_class_id': 'eq.$liveClassId',
        'order': 'created_at.asc',
        'limit': '300',
      },
    );
  }

  Future<Map<String, dynamic>?> sendLiveClassChatMessage({
    required String liveClassId,
    required String body,
  }) async {
    final userId = _requireUserId();
    final created = await _databasePost(
      'live_class_chat_messages',
      [
        {
          'live_class_id': liveClassId,
          'sender_user_id': userId,
          'body': body,
        }
      ],
    );
    if (created.isEmpty) return null;
    return created.first;
  }

  Future<Map<String, dynamic>?> getRoutineById(String id) async {
    final list = await _databaseGet(
      'routines',
      queryParams: {
        'id': 'eq.$id',
        'limit': '1',
      },
    );
    if (list.isEmpty) return null;
    return list.first;
  }

  Future<List<Map<String, dynamic>>> getRoutineExercises(
      String routineId) async {
    final items = await _databaseGet(
      'routine_exercises',
      queryParams: {
        'routine_id': 'eq.$routineId',
        'order': 'order_index.asc',
      },
    );
    if (items.isEmpty) return [];

    final exerciseIds = items
        .map((e) => e['exercise_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    final exercises = exerciseIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _databaseGet(
            'exercises',
            queryParams: {
              'id': 'in.(${exerciseIds.join(',')})',
            },
          );
    final exerciseMap = {
      for (final exercise in exercises) exercise['id'].toString(): exercise,
    };

    return items
        .map((item) => {
              ...item,
              'exercises': exerciseMap[item['exercise_id']?.toString()],
            })
        .toList();
  }

  Future<Map<String, dynamic>?> createRoutine({
    required String name,
    String? description,
    String level = 'principiante',
    bool isPublic = false,
    required List<Map<String, dynamic>> exercises,
  }) async {
    final userId = _requireUserId();
    final created = await _databasePost(
      'routines',
      [
        {
          'user_id': userId,
          'name': name,
          'description': description,
          'level': level,
          'is_public': isPublic,
        }
      ],
    );
    if (created.isEmpty) return null;
    final routine = created.first;
    final routineId = routine['id']?.toString();
    if (routineId == null || routineId.isEmpty) return routine;

    if (exercises.isNotEmpty) {
      await _databasePost(
        'routine_exercises',
        exercises
            .map((exercise) => {
                  'routine_id': routineId,
                  ...exercise,
                })
            .toList(),
        returnRepresentation: false,
      );
    }

    return routine;
  }

  Future<List<Map<String, dynamic>>> getRoutineAssignments({
    required bool asTeacher,
    String? status,
    String? studentUserId,
    String? routineId,
  }) async {
    final userId = _requireUserId();
    final params = <String, String>{
      asTeacher ? 'teacher_user_id' : 'student_user_id': 'eq.$userId',
      'order': 'assigned_at.desc',
      'limit': '100',
    };
    if (status != null && status.isNotEmpty) {
      params['status'] = 'eq.$status';
    }
    if (studentUserId != null && studentUserId.isNotEmpty) {
      params['student_user_id'] = 'eq.$studentUserId';
    }
    if (routineId != null && routineId.isNotEmpty) {
      params['routine_id'] = 'eq.$routineId';
    }
    return _databaseGet('routine_assignments', queryParams: params);
  }

  Map<String, dynamic> _routineAssignmentSchedulePayload({
    List<int>? scheduleDays,
    int? scheduleHour,
    int scheduleMinute = 0,
  }) {
    final days = scheduleDays ?? [];
    final sorted = days.where((d) => d >= 1 && d <= 7).toSet().toList()..sort();
    final mm = scheduleMinute.clamp(0, 59);
    return {
      'schedule_days': sorted.isEmpty ? null : sorted,
      'schedule_hour': scheduleHour,
      'schedule_minute': scheduleHour != null ? mm : 0,
    };
  }

  Future<Map<String, dynamic>?> assignRoutineToStudent({
    required String routineId,
    required String studentUserId,
    String? notes,
    DateTime? startDate,
    List<int>? scheduleDays,
    int? scheduleHour,
    int scheduleMinute = 0,
  }) async {
    final teacherUserId = _requireUserId();
    final schedule = _routineAssignmentSchedulePayload(
      scheduleDays: scheduleDays,
      scheduleHour: scheduleHour,
      scheduleMinute: scheduleMinute,
    );
    final created = await _databasePost(
      'routine_assignments',
      [
        {
          'routine_id': routineId,
          'teacher_user_id': teacherUserId,
          'student_user_id': studentUserId,
          'status': 'active',
          'notes': notes,
          'start_date': startDate?.toIso8601String().split('T').first,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          ...schedule,
        }
      ],
      mergeDuplicates: true,
    );
    if (created.isEmpty) return null;
    return created.first;
  }

  Future<List<Map<String, dynamic>>> getAssignedRoutines() async {
    // Nota: en algunos despliegues de Insforge el "select" con embedding
    // devuelve metadatos (relationship/embedding/cardinality) en vez de filas.
    // Por eso hacemos 2 pasos: assignments -> (routines + teachers) por ids.
    final assignments = await getRoutineAssignments(
      asTeacher: false,
      status: 'active',
    );
    if (assignments.isEmpty) return [];

    final routineIds = assignments
        .map(assignmentRoutineId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final teacherIds = assignments
        .map(assignmentTeacherUserId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final routines = routineIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _databaseGet(
            'routines',
            queryParams: {
              'id': 'in.(${routineIds.join(',')})',
              'order': 'created_at.desc',
            },
          );
    final teachers = teacherIds.isEmpty ? <Map<String, dynamic>>[] : await getUsersByIds(teacherIds);

    final routineMap = <String, Map<String, dynamic>>{
      for (final routine in routines) routine['id'].toString(): routine,
    };

    // Si el `in.(…)` devolvió vacío por RLS/sintaxis pero `eq.id` sí permite leer la fila.
    final missingRoutineIds =
        routineIds.where((id) => routineMap[id] == null).toList();
    if (missingRoutineIds.isNotEmpty) {
      await Future.wait(
        missingRoutineIds.map((id) async {
          try {
            final row = await getRoutineById(id);
            if (row != null) routineMap[id] = row;
          } catch (_) {}
        }),
      );
    }

    final teacherMap = {
      for (final teacher in teachers) teacher['id'].toString(): teacher,
    };

    return assignments
        .map(
          (assignment) {
            final rid = assignmentRoutineId(assignment);
            final tid = assignmentTeacherUserId(assignment);
            return {
              ...assignment,
              'routine': rid != null ? routineMap[rid] : null,
              'teacher_user': tid != null ? teacherMap[tid] : null,
            };
          },
        )
        .toList();
  }

  Future<void> saveProgress({
    required String routineId,
    int? durationSeconds,
    String? notes,
  }) async {
    final userId = _requireUserId();
    await _databasePost(
      'user_progress',
      [
        {
          'user_id': userId,
          'routine_id': routineId,
          'duration_seconds': durationSeconds,
          'notes': notes,
        }
      ],
      returnRepresentation: false,
    );
  }

  Future<Map<String, dynamic>> getUserStats() async {
    final entries = await getUserProgressList(limit: 1000);
    final totalSesiones = entries.length;
    final tiempoTotal = entries.fold<int>(
      0,
      (sum, entry) => sum + ((entry['duration_seconds'] as int?) ?? 0),
    );

    final days = entries
        .map((entry) => entry['completed_at']?.toString())
        .whereType<String>()
        .map((value) => DateTime.tryParse(value))
        .whereType<DateTime>()
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    int currentStreak = 0;
    int maxStreak = 0;
    DateTime expected = DateTime.now();
    if (days.isNotEmpty) {
      expected = DateTime(expected.year, expected.month, expected.day);
      final yesterday = expected.subtract(const Duration(days: 1));
      if (days.first != expected && days.first != yesterday) {
        currentStreak = 0;
      } else {
        expected = days.first;
        for (final day in days) {
          if (day == expected) {
            currentStreak++;
            expected = expected.subtract(const Duration(days: 1));
          } else {
            break;
          }
        }
      }

      int streak = 0;
      DateTime? previous;
      for (final day in days.reversed) {
        if (previous == null || day.difference(previous).inDays == 1) {
          streak++;
        } else if (day != previous) {
          streak = 1;
        }
        if (streak > maxStreak) maxStreak = streak;
        previous = day;
      }
    }

    return {
      'total_sesiones': totalSesiones,
      'tiempo_total_segundos': tiempoTotal,
      'racha_actual': currentStreak,
      'racha_maxima': maxStreak,
    };
  }

  Future<List<Map<String, dynamic>>> getUserProgressList(
      {int limit = 50}) async {
    return _databaseGet(
      'user_progress',
      queryParams: {
        'select': 'id,routine_id,completed_at,duration_seconds,notes',
        'order': 'completed_at.desc',
        'limit': limit.toString(),
      },
    );
  }

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final userId = _requireUserId();
    final list = await _databaseGet(
      'users',
      queryParams: {
        'id': 'eq.$userId',
        'limit': '1',
      },
    );
    if (list.isEmpty) return null;
    return list.first;
  }

  Future<Map<String, dynamic>?> updateCurrentUserProfile({
    String? username,
    String? avatarUrl,
    String? nivel,
  }) async {
    final userId = _requireUserId();
    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    if (nivel != null) body['nivel'] = nivel;
    if (body.isEmpty) return getCurrentUserProfile();
    final list = await _databasePatch(
      'users',
      body,
      queryParams: {'id': 'eq.$userId'},
    );
    if (list.isEmpty) return null;
    return list.first;
  }

  /// Preferencias de notificaciones del usuario (Insforge).
  Future<Map<String, dynamic>> getNotificationPreferences() async {
    final profile = await getCurrentUserProfile();
    return {
      'notify_message_reply': profile?['notify_message_reply'] ?? true,
      'notify_routine_proposed': profile?['notify_routine_proposed'] ?? true,
    };
  }

  /// Actualiza preferencias de notificaciones en Insforge.
  Future<void> updateNotificationPreferences({
    required bool notifyMessageReply,
    required bool notifyRoutineProposed,
  }) async {
    _requireUserId();
    await _databasePatch(
      'users',
      {
        'notify_message_reply': notifyMessageReply,
        'notify_routine_proposed': notifyRoutineProposed,
      },
      queryParams: {'id': 'eq.$_userId'},
    );
  }

  Future<String?> uploadAvatar(List<int> fileBytes, String mimeType) async {
    // El proyecto actual no tiene bucket de avatars creado en Insforge.
    // Devolvemos null para que la UI pueda informar sin romperse.
    if (fileBytes.isEmpty || mimeType.isEmpty) return null;
    return null;
  }
}

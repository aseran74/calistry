import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:calistenia_app/core/config/api_config.dart';

final adminApiClientProvider = Provider<AdminApiClient>((ref) {
  return AdminApiClient();
});

class AdminApiClient {
  Map<String, String> _headers({String? accessToken}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (ApiConfig.anonKey.isNotEmpty) {
      headers['apikey'] = ApiConfig.anonKey;
    }
    final token = accessToken ?? '';
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _dbUri(String table, [Map<String, String>? queryParameters]) {
    return Uri.parse('${ApiConfig.baseUrl}/api/database/records/$table')
        .replace(
      queryParameters: queryParameters,
    );
  }

  Future<List<Map<String, dynamic>>> listUsers({
    required String accessToken,
    String search = '',
  }) async {
    final params = <String, String>{
      'order': 'created_at.desc',
      'limit': '200',
    };
    if (search.trim().isNotEmpty) {
      params['or'] =
          '(email.ilike.*${search.trim()}*,username.ilike.*${search.trim()}*)';
    }
    return _databaseGet(
      'users',
      accessToken: accessToken,
      queryParameters: params,
    );
  }

  Future<List<Map<String, dynamic>>> listExercises({
    required String accessToken,
    String search = '',
    String? ownerUserId,
  }) async {
    final params = <String, String>{
      'order': 'created_at.desc',
      'limit': '200',
    };
    if (search.trim().isNotEmpty) {
      params['name'] = 'ilike.*${search.trim()}*';
    }
    if (ownerUserId != null && ownerUserId.isNotEmpty) {
      params['owner_user_id'] = 'eq.$ownerUserId';
    }
    return _databaseGet(
      'exercises',
      accessToken: accessToken,
      queryParameters: params,
    );
  }

  Future<List<Map<String, dynamic>>> listRoutines({
    required String accessToken,
    String search = '',
    String? userId,
  }) async {
    final params = <String, String>{
      'order': 'created_at.desc',
      'limit': '200',
    };
    if (search.trim().isNotEmpty) {
      params['name'] = 'ilike.*${search.trim()}*';
    }
    if (userId != null && userId.isNotEmpty) {
      params['user_id'] = 'eq.$userId';
    }
    return _databaseGet(
      'routines',
      accessToken: accessToken,
      queryParameters: params,
    );
  }

  Future<List<Map<String, dynamic>>> listExerciseSubmissions({
    required String accessToken,
    String? status,
    String? userId,
    String search = '',
  }) async {
    final params = <String, String>{
      'order': 'created_at.desc',
      'limit': '200',
    };
    if (status != null && status.isNotEmpty) {
      params['status'] = 'eq.$status';
    }
    if (userId != null && userId.isNotEmpty) {
      params['proposed_by_user_id'] = 'eq.$userId';
    }
    if (search.trim().isNotEmpty) {
      params['name'] = 'ilike.*${search.trim()}*';
    }
    return _databaseGet(
      'exercise_submissions',
      accessToken: accessToken,
      queryParameters: params,
    );
  }

  Future<List<Map<String, dynamic>>> listTeacherApplications({
    required String accessToken,
    String? status,
    String search = '',
  }) async {
    final params = <String, String>{
      'order': 'created_at.desc',
      'limit': '200',
    };
    if (status != null && status.isNotEmpty) {
      params['status'] = 'eq.$status';
    }
    if (search.trim().isNotEmpty) {
      params['or'] =
          '(display_name.ilike.*${search.trim()}*,specialty.ilike.*${search.trim()}*,bio.ilike.*${search.trim()}*)';
    }
    return _databaseGet(
      'teacher_applications',
      accessToken: accessToken,
      queryParameters: params,
    );
  }

  Future<List<Map<String, dynamic>>> listProgress({
    required String accessToken,
    int limit = 50,
  }) async {
    return _databaseGet(
      'user_progress',
      accessToken: accessToken,
      queryParameters: {
        'select': 'id,user_id,routine_id,completed_at,duration_seconds,notes',
        'order': 'completed_at.desc',
        'limit': '$limit',
      },
    );
  }

  Future<List<Map<String, dynamic>>> listMediaObjects({
    required String accessToken,
    String prefix = 'exercises/',
  }) async {
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/storage/buckets/exercises-media/objects',
      ).replace(
        queryParameters: {
          'prefix': prefix,
          'limit': '200',
        },
      ),
      headers: _headers(accessToken: accessToken),
    );
    final json = _parseMapResponse(response);
    final data = json['data'];
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  Future<Map<String, dynamic>?> createExercise({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final created = await _databasePost(
      'exercises',
      accessToken: accessToken,
      rows: [payload],
    );
    return created.isEmpty ? null : created.first;
  }

  Future<Map<String, dynamic>?> updateExercise({
    required String accessToken,
    required String exerciseId,
    required Map<String, dynamic> payload,
  }) async {
    final updated = await _databasePatch(
      'exercises',
      accessToken: accessToken,
      body: payload,
      queryParameters: {'id': 'eq.$exerciseId'},
    );
    return updated.isEmpty ? null : updated.first;
  }

  Future<void> deleteExercise({
    required String accessToken,
    required String exerciseId,
  }) async {
    await _databaseDelete(
      'exercises',
      accessToken: accessToken,
      queryParameters: {'id': 'eq.$exerciseId'},
    );
  }

  Future<Map<String, dynamic>?> createRoutine({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final created = await _databasePost(
      'routines',
      accessToken: accessToken,
      rows: [payload],
    );
    return created.isEmpty ? null : created.first;
  }

  Future<Map<String, dynamic>?> updateRoutine({
    required String accessToken,
    required String routineId,
    required Map<String, dynamic> payload,
  }) async {
    final updated = await _databasePatch(
      'routines',
      accessToken: accessToken,
      body: payload,
      queryParameters: {'id': 'eq.$routineId'},
    );
    return updated.isEmpty ? null : updated.first;
  }

  Future<void> deleteRoutine({
    required String accessToken,
    required String routineId,
  }) async {
    await _databaseDelete(
      'routine_exercises',
      accessToken: accessToken,
      queryParameters: {'routine_id': 'eq.$routineId'},
    );
    await _databaseDelete(
      'routines',
      accessToken: accessToken,
      queryParameters: {'id': 'eq.$routineId'},
    );
  }

  Future<Map<String, dynamic>?> updateUser({
    required String accessToken,
    required String userId,
    required Map<String, dynamic> payload,
  }) async {
    final updated = await _databasePatch(
      'users',
      accessToken: accessToken,
      body: payload,
      queryParameters: {'id': 'eq.$userId'},
    );
    return updated.isEmpty ? null : updated.first;
  }

  Future<Map<String, dynamic>?> approveExerciseSubmission({
    required String accessToken,
    required Map<String, dynamic> submission,
    required String reviewerUserId,
    String? reviewNotes,
  }) async {
    final created = await createExercise(
      accessToken: accessToken,
      payload: {
        'owner_user_id': submission['proposed_by_user_id']?.toString(),
        'name': submission['name']?.toString() ?? '',
        'description': submission['description']?.toString(),
        'category': submission['category']?.toString() ?? 'fuerza',
        'difficulty': submission['difficulty']?.toString() ?? 'principiante',
        'muscle_groups': ((submission['muscle_groups'] as List?) ?? const [])
            .map((item) => item.toString())
            .toList(),
        'gif_url': submission['gif_url']?.toString(),
        'video_url': submission['video_url']?.toString(),
        'thumbnail_url': submission['thumbnail_url']?.toString(),
        'duration_seconds': submission['duration_seconds'],
        'is_active': true,
      },
    );

    final updated = await _databasePatch(
      'exercise_submissions',
      accessToken: accessToken,
      body: {
        'status': 'approved',
        'review_notes': reviewNotes,
        'reviewed_by_user_id': reviewerUserId,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        'published_exercise_id': created?['id']?.toString(),
      },
      queryParameters: {'id': 'eq.${submission['id']}'},
    );
    return updated.isEmpty ? null : updated.first;
  }

  Future<Map<String, dynamic>?> rejectExerciseSubmission({
    required String accessToken,
    required String submissionId,
    required String reviewerUserId,
    String? reviewNotes,
  }) async {
    final updated = await _databasePatch(
      'exercise_submissions',
      accessToken: accessToken,
      body: {
        'status': 'rejected',
        'review_notes': reviewNotes,
        'reviewed_by_user_id': reviewerUserId,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      },
      queryParameters: {'id': 'eq.$submissionId'},
    );
    return updated.isEmpty ? null : updated.first;
  }

  Future<Map<String, dynamic>?> approveTeacherApplication({
    required String accessToken,
    required String reviewerUserId,
    required Map<String, dynamic> application,
    String? reviewNotes,
  }) async {
    await updateUser(
      accessToken: accessToken,
      userId: application['user_id'].toString(),
      payload: {
        'role': 'teacher',
      },
    );

    final updated = await _databasePatch(
      'teacher_applications',
      accessToken: accessToken,
      body: {
        'status': 'approved',
        'review_notes': reviewNotes,
        'reviewed_by_user_id': reviewerUserId,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      },
      queryParameters: {'id': 'eq.${application['id']}'},
    );
    return updated.isEmpty ? null : updated.first;
  }

  Future<Map<String, dynamic>?> rejectTeacherApplication({
    required String accessToken,
    required String reviewerUserId,
    required String applicationId,
    required String userId,
    String? reviewNotes,
  }) async {
    await updateUser(
      accessToken: accessToken,
      userId: userId,
      payload: {
        'role': 'user',
      },
    );

    final updated = await _databasePatch(
      'teacher_applications',
      accessToken: accessToken,
      body: {
        'status': 'rejected',
        'review_notes': reviewNotes,
        'reviewed_by_user_id': reviewerUserId,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      },
      queryParameters: {'id': 'eq.$applicationId'},
    );
    return updated.isEmpty ? null : updated.first;
  }

  Future<String> uploadMedia({
    required String accessToken,
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    final strategyResponse = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/storage/buckets/exercises-media/upload-strategy',
      ),
      headers: _headers(accessToken: accessToken),
      body: jsonEncode({
        'filename': filename,
        'contentType': contentType,
        'size': bytes.length,
      }),
    );

    final strategy = _parseMapResponse(strategyResponse);
    final method = strategy['method']?.toString() ?? 'direct';
    final uploadUrl = _normalizeUrl(strategy['uploadUrl']?.toString() ?? '');
    final key = strategy['key']?.toString() ?? filename;

    if (method == 'presigned') {
      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      final fields = strategy['fields'];
      if (fields is Map) {
        for (final entry in fields.entries) {
          request.fields[entry.key.toString()] = entry.value.toString();
        }
      }
      request.files
          .add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      final streamed = await request.send();
      final presignedResponse = await http.Response.fromStream(streamed);
      if (presignedResponse.statusCode >= 400) {
        throw Exception('No se pudo subir el archivo al storage.');
      }

      final confirmUrl =
          _normalizeUrl(strategy['confirmUrl']?.toString() ?? '');
      final confirmResponse = await http.post(
        Uri.parse(confirmUrl),
        headers: _headers(accessToken: accessToken),
        body: jsonEncode({
          'size': bytes.length,
          'contentType': contentType,
        }),
      );
      final uploaded = _parseMapResponse(confirmResponse);
      return _normalizeUrl(uploaded['url']?.toString() ?? '');
    }

    final request = http.MultipartRequest('PUT', Uri.parse(uploadUrl));
    if (ApiConfig.anonKey.isNotEmpty) {
      request.headers['apikey'] = ApiConfig.anonKey;
    }
    request.headers['Authorization'] = 'Bearer $accessToken';
    request.files
        .add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await request.send();
    final directResponse = await http.Response.fromStream(streamed);
    final uploaded = _parseMapResponse(directResponse);
    if (uploaded['url'] != null) {
      return _normalizeUrl(uploaded['url'].toString());
    }
    return _normalizeUrl('/api/storage/buckets/exercises-media/objects/$key');
  }

  Future<List<Map<String, dynamic>>> _databaseGet(
    String table, {
    required String accessToken,
    Map<String, String>? queryParameters,
  }) async {
    final response = await http.get(
      _dbUri(table, queryParameters),
      headers: _headers(accessToken: accessToken),
    );
    return _parseListResponse(response);
  }

  Future<List<Map<String, dynamic>>> _databasePost(
    String table, {
    required String accessToken,
    required List<Map<String, dynamic>> rows,
  }) async {
    final response = await http.post(
      _dbUri(table),
      headers: {
        ..._headers(accessToken: accessToken),
        'Prefer': 'return=representation',
      },
      body: jsonEncode(rows),
    );
    return _parseListResponse(response);
  }

  Future<List<Map<String, dynamic>>> _databasePatch(
    String table, {
    required String accessToken,
    required Map<String, dynamic> body,
    required Map<String, String> queryParameters,
  }) async {
    final response = await http.patch(
      _dbUri(table, queryParameters),
      headers: {
        ..._headers(accessToken: accessToken),
        'Prefer': 'return=representation',
      },
      body: jsonEncode(body),
    );
    return _parseListResponse(response);
  }

  Future<void> _databaseDelete(
    String table, {
    required String accessToken,
    required Map<String, String> queryParameters,
  }) async {
    final response = await http.delete(
      _dbUri(table, queryParameters),
      headers: _headers(accessToken: accessToken),
    );
    if (response.statusCode >= 400) {
      throw Exception(_extractErrorMessage(response));
    }
  }

  Map<String, dynamic> _parseMapResponse(http.Response response) {
    if (response.statusCode >= 400) {
      throw Exception(_extractErrorMessage(response));
    }
    final body = response.body.trim();
    if (body.isEmpty) return {};
    if (body.startsWith('<!DOCTYPE html') || body.startsWith('<html')) {
      throw Exception('Insforge devolvió HTML en lugar de JSON.');
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw Exception('La respuesta del backend no tiene el formato esperado.');
  }

  List<Map<String, dynamic>> _parseListResponse(http.Response response) {
    if (response.statusCode >= 400) {
      throw Exception(_extractErrorMessage(response));
    }
    final body = response.body.trim();
    if (body.isEmpty) return [];
    if (body.startsWith('<!DOCTYPE html') || body.startsWith('<html')) {
      throw Exception('Insforge devolvió HTML en lugar de JSON.');
    }
    final decoded = jsonDecode(body);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
    if (decoded is Map<String, dynamic> && decoded['data'] is List) {
      return (decoded['data'] as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
    return [];
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
        return decoded['message']?.toString() ??
            decoded['error']?.toString() ??
            'Error ${response.statusCode} del backend.';
      }
    } catch (_) {
      return body;
    }
    return 'Error ${response.statusCode} del backend.';
  }

  String _normalizeUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    return '${ApiConfig.baseUrl}$url';
  }
}

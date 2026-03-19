import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../admin_config.dart';
import '../auth/admin_session.dart';

class AdminApiClient {
  static const _mobileClientType = 'mobile';

  Map<String, String> _headers({String? accessToken}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (AdminConfig.anonKey.isNotEmpty) {
      headers['apikey'] = AdminConfig.anonKey;
    }
    final token = accessToken ?? '';
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _dbUri(String table, [Map<String, String>? queryParameters]) {
    return Uri.parse('${AdminConfig.baseUrl}/api/database/records/$table').replace(
      queryParameters: queryParameters,
    );
  }

  Uri _authUri(String path, [Map<String, String>? queryParameters]) {
    return Uri.parse('${AdminConfig.baseUrl}$path').replace(
      queryParameters: queryParameters,
    );
  }

  Future<AdminSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      _authUri('/api/auth/sessions', const {'client_type': _mobileClientType}),
      headers: _headers(),
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    );
    final baseSession = _parseSessionResponse(response);
    return _buildAdminSession(baseSession);
  }

  Future<AdminSession> signInWithGoogle() async {
    final verifier = _generateCodeVerifier();
    final challenge = _generateCodeChallenge(verifier);
    final redirectUri = Uri.base.resolve('auth.html').replace(query: null).toString();
    final authUrl = await _fetchGoogleAuthUrl(
      codeChallenge: challenge,
      redirectUri: redirectUri,
    );

    final callbackUrl = await FlutterWebAuth2.authenticate(
      url: authUrl,
      callbackUrlScheme: Uri.base.scheme,
    );

    final code = Uri.parse(callbackUrl).queryParameters['insforge_code'];
    if (code == null || code.isEmpty) {
      throw Exception('No se recibió el código OAuth de Insforge.');
    }

    final response = await http.post(
      _authUri('/api/auth/oauth/exchange', const {'client_type': _mobileClientType}),
      headers: _headers(),
      body: jsonEncode({
        'code': code,
        'code_verifier': verifier,
      }),
    );

    final baseSession = _parseSessionResponse(response);
    return _buildAdminSession(baseSession);
  }

  Future<AdminSession> refreshSession(String refreshToken) async {
    final response = await http.post(
      _authUri('/api/auth/refresh', const {'client_type': _mobileClientType}),
      headers: _headers(),
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    final baseSession = _parseSessionResponse(response);
    return _buildAdminSession(baseSession);
  }

  Future<void> logout(String accessToken) async {
    await http.post(
      _authUri('/api/auth/logout'),
      headers: _headers(accessToken: accessToken),
    );
  }

  Future<AdminSession> _buildAdminSession(AdminSession baseSession) async {
    await ensureUserRecord(baseSession);
    final adminUser = await getCurrentAdminUser(baseSession.accessToken);
    if (!_isAdminRole(adminUser.role)) {
      throw Exception('Tu usuario no tiene permisos de administrador.');
    }
    return AdminSession(
      accessToken: baseSession.accessToken,
      refreshToken: baseSession.refreshToken,
      user: adminUser,
    );
  }

  Future<void> ensureUserRecord(AdminSession session) async {
    final existing = await _databaseGet(
      'users',
      accessToken: session.accessToken,
      queryParameters: {
        'id': 'eq.${session.user.id}',
        'limit': '1',
      },
    );
    if (existing.isNotEmpty) return;

    final username = session.user.email.contains('@')
        ? session.user.email.split('@').first
        : session.user.email;

    await _databasePost(
      'users',
      accessToken: session.accessToken,
      rows: [
        {
          'id': session.user.id,
          'email': session.user.email,
          'username': username,
        }
      ],
    );
  }

  Future<AdminUser> getCurrentAdminUser(String accessToken) async {
    final response = await http.get(
      _authUri('/api/auth/sessions/current'),
      headers: _headers(accessToken: accessToken),
    );
    final sessionJson = _parseMapResponse(response);
    final authUser = Map<String, dynamic>.from(
      (sessionJson['user'] as Map?) ?? <String, dynamic>{},
    );
    final authUserId = authUser['id']?.toString() ?? '';
    if (authUserId.isEmpty) {
      throw Exception('No se pudo recuperar el usuario autenticado.');
    }

    final users = await _databaseGet(
      'users',
      accessToken: accessToken,
      queryParameters: {
        'id': 'eq.$authUserId',
        'limit': '1',
      },
    );
    if (users.isEmpty) {
      return AdminUser(
        id: authUserId,
        email: authUser['email']?.toString() ?? '',
        role: 'user',
      );
    }

    final row = users.first;
    return AdminUser(
      id: row['id']?.toString() ?? authUserId,
      email: row['email']?.toString() ?? authUser['email']?.toString() ?? '',
      role: row['role']?.toString() ?? 'user',
      username: row['username']?.toString(),
    );
  }

  Future<String> _fetchGoogleAuthUrl({
    required String codeChallenge,
    required String redirectUri,
  }) async {
    final response = await http.get(
      _authUri('/api/auth/oauth/google', {
        'redirect_uri': redirectUri,
        'code_challenge': codeChallenge,
      }),
      headers: _headers(),
    );
    final json = _parseMapResponse(response);
    final authUrl = json['authUrl']?.toString();
    if (authUrl == null || authUrl.isEmpty) {
      throw Exception('Insforge no devolvió la URL de login con Google.');
    }
    return authUrl;
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
  }) async {
    final params = <String, String>{
      'order': 'created_at.desc',
      'limit': '200',
    };
    if (search.trim().isNotEmpty) {
      params['name'] = 'ilike.*${search.trim()}*';
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
  }) async {
    final params = <String, String>{
      'order': 'created_at.desc',
      'limit': '200',
    };
    if (search.trim().isNotEmpty) {
      params['name'] = 'ilike.*${search.trim()}*';
    }
    return _databaseGet(
      'routines',
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
        '${AdminConfig.baseUrl}/api/storage/buckets/${AdminConfig.mediaBucket}/objects',
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

  Future<String> uploadMedia({
    required String accessToken,
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    final strategyResponse = await http.post(
      Uri.parse(
        '${AdminConfig.baseUrl}/api/storage/buckets/${AdminConfig.mediaBucket}/upload-strategy',
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
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      final streamed = await request.send();
      final presignedResponse = await http.Response.fromStream(streamed);
      if (presignedResponse.statusCode >= 400) {
        throw Exception('No se pudo subir el archivo al storage.');
      }

      final confirmUrl = _normalizeUrl(strategy['confirmUrl']?.toString() ?? '');
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
    if (AdminConfig.anonKey.isNotEmpty) {
      request.headers['apikey'] = AdminConfig.anonKey;
    }
    request.headers['Authorization'] = 'Bearer $accessToken';
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await request.send();
    final directResponse = await http.Response.fromStream(streamed);
    final uploaded = _parseMapResponse(directResponse);
    if (uploaded['url'] != null) {
      return _normalizeUrl(uploaded['url'].toString());
    }
    return _normalizeUrl(
      '/api/storage/buckets/${AdminConfig.mediaBucket}/objects/$key',
    );
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

  AdminSession _parseSessionResponse(http.Response response) {
    final json = _parseMapResponse(response);
    final accessToken = json['accessToken']?.toString() ?? '';
    final refreshToken = json['refreshToken']?.toString() ?? '';
    final user = Map<String, dynamic>.from((json['user'] as Map?) ?? <String, dynamic>{});
    if (accessToken.isEmpty || refreshToken.isEmpty || user.isEmpty) {
      throw Exception('La respuesta de autenticación no es válida.');
    }
    return AdminSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: AdminUser(
        id: user['id']?.toString() ?? '',
        email: user['email']?.toString() ?? '',
        role: user['role']?.toString() ?? 'user',
      ),
    );
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
    return '${AdminConfig.baseUrl}$url';
  }

  String _generateCodeVerifier() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final random = Random.secure();
    return List.generate(
      64,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  bool _isAdminRole(String role) {
    return role == 'admin' || role == 'moderator';
  }
}

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:calistenia_app/core/config/api_config.dart';
import 'package:calistenia_app/features/auth/domain/models/auth_session.dart';

class InsforgeAuthApi {
  static const _mobileClientType = 'mobile';

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (ApiConfig.anonKey.isNotEmpty) {
      headers['apikey'] = ApiConfig.anonKey;
    }
    return headers;
  }

  Future<AuthSession> signInWithGoogle() async {
    final verifier = _generateCodeVerifier();
    final challenge = _generateCodeChallenge(verifier);
    final authUrl = await _fetchGoogleAuthUrl(
      challenge,
      redirectUri: _redirectUri,
    );

    final callbackUrl = await FlutterWebAuth2.authenticate(
      url: authUrl,
      callbackUrlScheme:
          kIsWeb ? Uri.base.scheme : ApiConfig.authCallbackScheme,
    );

    final code = Uri.parse(callbackUrl).queryParameters['insforge_code'];
    if (code == null || code.isEmpty) {
      throw Exception('No se recibió el código OAuth de Insforge.');
    }

    return exchangeCode(
      code: code,
      codeVerifier: verifier,
    );
  }

  Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/sessions')
        .replace(queryParameters: const {'client_type': _mobileClientType});
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    );
    return _parseSessionResponse(response);
  }

  Future<AuthSession> exchangeCode({
    required String code,
    required String codeVerifier,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/oauth/exchange')
        .replace(queryParameters: const {'client_type': _mobileClientType});
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'code': code,
        'code_verifier': codeVerifier,
      }),
    );
    return _parseSessionResponse(response);
  }

  Future<AuthSession> refreshSession(String refreshToken) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/refresh')
        .replace(queryParameters: const {'client_type': _mobileClientType});
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    return _parseSessionResponse(response);
  }

  Future<AuthUser> getCurrentUser(String accessToken) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/sessions/current'),
      headers: {
        ..._headers,
        'Authorization': 'Bearer $accessToken',
      },
    );

    final data = _parseJson(response);
    final user = data['user'];
    if (response.statusCode >= 400 || user is! Map<String, dynamic>) {
      throw Exception(_extractErrorMessage(data));
    }
    return AuthUser.fromJson(user);
  }

  Future<void> logout(String accessToken) async {
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/logout'),
      headers: {
        ..._headers,
        'Authorization': 'Bearer $accessToken',
      },
    );
  }

  Future<void> ensureUserRecord(AuthSession session) async {
    final headers = {
      ..._headers,
      'Authorization': 'Bearer ${session.accessToken}',
    };
    final existingResponse = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/database/records/users').replace(
        queryParameters: {
          'id': 'eq.${session.user.id}',
          'limit': '1',
        },
      ),
      headers: headers,
    );

    final existing = _parseList(existingResponse);
    if (existing.isNotEmpty) return;

    final username = session.user.email.contains('@')
        ? session.user.email.split('@').first
        : session.user.email;

    final createResponse = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/database/records/users'),
      headers: {
        ...headers,
        'Prefer': 'return=representation',
      },
      body: jsonEncode([
        {
          'id': session.user.id,
          'email': session.user.email,
          'username': username,
        }
      ]),
    );

    _parseList(createResponse);
  }

  Future<AuthSession> hydrateSessionRole(AuthSession session) async {
    final headers = {
      ..._headers,
      'Authorization': 'Bearer ${session.accessToken}',
    };
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/database/records/users').replace(
        queryParameters: {
          'id': 'eq.${session.user.id}',
          'limit': '1',
        },
      ),
      headers: headers,
    );

    final rows = _parseList(response);
    if (rows.isEmpty) return session;
    final row = rows.first;
    final profileRole = row['role']?.toString();
    if (profileRole == null || profileRole.isEmpty) return session;

    return AuthSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      user: AuthUser(
        id: session.user.id,
        email: session.user.email,
        role: profileRole,
        providers: session.user.providers,
      ),
    );
  }

  String get _redirectUri {
    if (!kIsWeb) return ApiConfig.authRedirectUri;
    return Uri.base
        .resolve('auth.html')
        .replace(query: null, fragment: '')
        .toString();
  }

  Future<String> _fetchGoogleAuthUrl(
    String codeChallenge, {
    required String redirectUri,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/oauth/google').replace(
      queryParameters: {
        'redirect_uri': redirectUri,
        'code_challenge': codeChallenge,
      },
    );

    final response = await http.get(uri, headers: _headers);
    final data = _parseJson(response);
    final authUrl = data['authUrl'] as String?;
    if (response.statusCode >= 400 || authUrl == null || authUrl.isEmpty) {
      throw Exception(_extractErrorMessage(data));
    }
    return authUrl;
  }

  AuthSession _parseSessionResponse(http.Response response) {
    final data = _parseJson(response);
    if (response.statusCode >= 400) {
      throw Exception(_extractErrorMessage(data));
    }

    final accessToken = data['accessToken'] as String?;
    final refreshToken = data['refreshToken'] as String?;
    final user = data['user'];
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty ||
        user is! Map<String, dynamic>) {
      throw Exception('La respuesta de autenticación no es válida.');
    }

    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: AuthUser.fromJson(user),
    );
  }

  Map<String, dynamic> _parseJson(http.Response response) {
    if (response.body.isEmpty) return {};
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  List<Map<String, dynamic>> _parseList(http.Response response) {
    if (response.statusCode >= 400) {
      throw Exception(_extractErrorMessage(_parseJson(response)));
    }
    if (response.body.isEmpty) return [];
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  String _extractErrorMessage(Map<String, dynamic> json) {
    return json['message'] as String? ??
        json['error'] as String? ??
        'No se pudo completar la autenticación.';
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
}

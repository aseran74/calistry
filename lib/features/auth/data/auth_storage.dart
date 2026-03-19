import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:calistenia_app/features/auth/domain/models/auth_session.dart';

class AuthStorage {
  AuthStorage()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  static const _sessionKey = 'auth_session';

  final FlutterSecureStorage _storage;

  Future<AuthSession?> readSession() async {
    final raw = await _storage.read(key: _sessionKey);
    return AuthSession.decode(raw);
  }

  Future<void> saveSession(AuthSession session) {
    return _storage.write(key: _sessionKey, value: session.encode());
  }

  Future<void> clear() {
    return _storage.delete(key: _sessionKey);
  }
}

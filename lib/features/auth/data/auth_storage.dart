import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calistenia_app/features/auth/domain/models/auth_session.dart';

/// En **web**, `FlutterSecureStorage` (IndexedDB + Web Crypto) suele fallar o no
/// persistir bien en varios navegadores; la sesión se pierde y el router vuelve
/// al login. En móvil/desktop se mantiene el almacenamiento cifrado.
class AuthStorage {
  AuthStorage()
      : _secure = kIsWeb
            ? null
            : const FlutterSecureStorage(
                aOptions: AndroidOptions(encryptedSharedPreferences: true),
              );

  static const _sessionKey = 'auth_session';

  final FlutterSecureStorage? _secure;

  Future<AuthSession?> readSession() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      var raw = prefs.getString(_sessionKey);
      if (raw != null && raw.isNotEmpty) {
        return AuthSession.decode(raw);
      }
      // Una sola migración desde secure storage (versiones anteriores de la app web).
      const legacy = FlutterSecureStorage();
      raw = await legacy.read(key: _sessionKey);
      final migrated = AuthSession.decode(raw);
      if (migrated != null) {
        await prefs.setString(_sessionKey, migrated.encode());
        await legacy.delete(key: _sessionKey);
      }
      return migrated;
    }
    final raw = await _secure!.read(key: _sessionKey);
    return AuthSession.decode(raw);
  }

  Future<void> saveSession(AuthSession session) async {
    final value = session.encode();
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, value);
      return;
    }
    await _secure!.write(key: _sessionKey, value: value);
  }

  Future<void> clear() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      const legacy = FlutterSecureStorage();
      await legacy.delete(key: _sessionKey);
      return;
    }
    await _secure!.delete(key: _sessionKey);
  }
}

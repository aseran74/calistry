import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/admin_api_client.dart';
import 'admin_session.dart';

enum AdminAuthStatus {
  loading,
  authenticated,
  unauthenticated,
}

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

final adminApiClientProvider = Provider<AdminApiClient>((ref) {
  return AdminApiClient();
});

final adminAuthControllerProvider =
    ChangeNotifierProvider<AdminAuthController>((ref) {
  return AdminAuthController(ref);
});

class AdminAuthController extends ChangeNotifier {
  AdminAuthController(this._ref) {
    _bootstrap();
  }

  static const _sessionKey = 'admin_web_session';

  final Ref _ref;

  AdminAuthStatus _status = AdminAuthStatus.loading;
  AdminSession? _session;
  String? _errorMessage;
  bool _busy = false;

  AdminAuthStatus get status => _status;
  AdminSession? get session => _session;
  String? get errorMessage => _errorMessage;
  bool get busy => _busy;
  bool get isAuthenticated =>
      _status == AdminAuthStatus.authenticated && _session != null;

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _runAuthAction(() async {
      final session = await _ref.read(adminApiClientProvider).signInWithEmail(
            email: email,
            password: password,
          );
      await _persistSession(session);
      _applySession(session);
    });
  }

  Future<void> signInWithGoogle() async {
    await _runAuthAction(() async {
      final session = await _ref.read(adminApiClientProvider).signInWithGoogle();
      await _persistSession(session);
      _applySession(session);
    });
  }

  Future<void> logout() async {
    _setBusy(true);
    try {
      final accessToken = _session?.accessToken;
      if (accessToken != null && accessToken.isNotEmpty) {
        await _ref.read(adminApiClientProvider).logout(accessToken);
      }
    } catch (_) {
      // Si falla el logout remoto, limpiamos igualmente la sesión local.
    } finally {
      await _clearPersistedSession();
      _clearSessionState();
      _setBusy(false);
    }
  }

  Future<void> _bootstrap() async {
    _setBusy(true);
    _setError(null);
    try {
      final stored = await _readPersistedSession();
      if (stored == null || stored.refreshToken.isEmpty) {
        _clearSessionState();
        return;
      }
      final refreshed = await _ref
          .read(adminApiClientProvider)
          .refreshSession(stored.refreshToken);
      await _persistSession(refreshed);
      _applySession(refreshed);
    } catch (e) {
      await _clearPersistedSession();
      _clearSessionState();
      _setError(e.toString());
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    _setBusy(true);
    _setError(null);
    try {
      await action();
    } catch (e) {
      await _clearPersistedSession();
      _clearSessionState();
      _setError(e.toString());
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _persistSession(AdminSession session) async {
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    await prefs.setString(_sessionKey, session.encode());
  }

  Future<AdminSession?> _readPersistedSession() async {
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) return null;
    return AdminSession.decode(raw);
  }

  Future<void> _clearPersistedSession() async {
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    await prefs.remove(_sessionKey);
  }

  void _applySession(AdminSession session) {
    _session = session;
    _status = AdminAuthStatus.authenticated;
    notifyListeners();
  }

  void _clearSessionState() {
    _session = null;
    _status = AdminAuthStatus.unauthenticated;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/auth/data/auth_storage.dart';
import 'package:calistenia_app/features/auth/data/insforge_auth_api.dart';
import 'package:calistenia_app/features/auth/domain/models/auth_session.dart';

enum AuthStatus {
  loading,
  authenticated,
  unauthenticated,
}

final authStorageProvider = Provider<AuthStorage>((ref) => AuthStorage());
final authApiProvider = Provider<InsforgeAuthApi>((ref) => InsforgeAuthApi());

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  return AuthController(ref);
});

class AuthController extends ChangeNotifier {
  AuthController(this._ref) {
    _bootstrap();
  }

  final Ref _ref;

  AuthStatus _status = AuthStatus.loading;
  AuthSession? _session;
  String? _errorMessage;
  bool _busy = false;

  AuthStatus get status => _status;
  AuthSession? get session => _session;
  String? get errorMessage => _errorMessage;
  bool get busy => _busy;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _session != null;
  bool get isTeacher => _session?.user.role == 'teacher';
  bool get isAdmin {
    final role = _session?.user.role ?? '';
    return kIsWeb && (role == 'admin' || role == 'moderator');
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _setBusy(true);
    _setError(null);
    try {
      final authApi = _ref.read(authApiProvider);
      final storage = _ref.read(authStorageProvider);
      final session = await authApi.signInWithEmail(
        email: email,
        password: password,
      );
      await authApi.ensureUserRecord(session);
      final hydratedSession = await authApi.hydrateSessionRole(session);
      await storage.saveSession(hydratedSession);
      _applySession(hydratedSession);
    } catch (e) {
      _clearSessionState();
      _setError(e.toString());
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signInWithGoogle() async {
    _setBusy(true);
    _setError(null);
    try {
      final authApi = _ref.read(authApiProvider);
      final storage = _ref.read(authStorageProvider);
      final session = await authApi.signInWithGoogle();
      await authApi.ensureUserRecord(session);
      final hydratedSession = await authApi.hydrateSessionRole(session);
      await storage.saveSession(hydratedSession);
      _applySession(hydratedSession);
    } catch (e) {
      _clearSessionState();
      _setError(e.toString());
    } finally {
      _setBusy(false);
    }
  }

  Future<void> logout() async {
    _setBusy(true);
    try {
      final accessToken = _session?.accessToken;
      if (accessToken != null && accessToken.isNotEmpty) {
        await _ref.read(authApiProvider).logout(accessToken);
      }
    } catch (_) {
      // Si falla el logout remoto, igualmente limpiamos la sesión local.
    } finally {
      await _ref.read(authStorageProvider).clear();
      _clearSessionState();
      _setBusy(false);
    }
  }

  Future<void> _bootstrap() async {
    _setBusy(true);
    _setError(null);
    try {
      final storage = _ref.read(authStorageProvider);
      final storedSession = await storage.readSession();
      if (storedSession == null || storedSession.refreshToken.isEmpty) {
        _clearSessionState();
        return;
      }

      final authApi = _ref.read(authApiProvider);
      try {
        final currentUser =
            await authApi.getCurrentUser(storedSession.accessToken);
        final session = AuthSession(
          accessToken: storedSession.accessToken,
          refreshToken: storedSession.refreshToken,
          user: currentUser,
        );
        await authApi.ensureUserRecord(session);
        final hydratedSession = await authApi.hydrateSessionRole(session);
        await storage.saveSession(hydratedSession);
        _applySession(hydratedSession);
      } catch (_) {
        final refreshed =
            await authApi.refreshSession(storedSession.refreshToken);
        await authApi.ensureUserRecord(refreshed);
        final hydratedSession = await authApi.hydrateSessionRole(refreshed);
        await storage.saveSession(hydratedSession);
        _applySession(hydratedSession);
      }
    } catch (e) {
      await _ref.read(authStorageProvider).clear();
      _clearSessionState();
      _setError(e.toString());
    } finally {
      _setBusy(false);
    }
  }

  void _applySession(AuthSession session) {
    _session = session;
    _status = AuthStatus.authenticated;
    _ref.read(accessTokenProvider.notifier).state = session.accessToken;
    notifyListeners();
  }

  void _clearSessionState() {
    _session = null;
    _status = AuthStatus.unauthenticated;
    _ref.read(accessTokenProvider.notifier).state = null;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }
}

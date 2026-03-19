import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/admin_auth_controller.dart';
import 'features/admin/admin_shell_screen.dart';
import 'features/auth/login_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final adminRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.read(adminAuthControllerProvider);

  return GoRouter(
    initialLocation: '/auth-loading',
    navigatorKey: _rootNavigatorKey,
    refreshListenable: auth,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isLoading = location == '/auth-loading';
      final isLogin = location == '/login';

      if (auth.status == AdminAuthStatus.loading) {
        return isLoading ? null : '/auth-loading';
      }

      if (!auth.isAuthenticated) {
        return isLogin ? null : '/login';
      }

      if (isLoading || isLogin) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/auth-loading',
        builder: (context, state) => const _AuthLoadingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const AdminShellScreen(),
      ),
    ],
  );
});

class AdminWebApp extends ConsumerWidget {
  const AdminWebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(adminRouterProvider);
    return MaterialApp.router(
      title: 'Calistry Admin',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      routerConfig: router,
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        brightness: brightness,
        seedColor: const Color(0xFFB5FF67),
        surface: isDark ? const Color(0xFF121316) : const Color(0xFFF6F7F2),
      ),
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0D0E11) : const Color(0xFFF4F3EC),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF17191E) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF14171C) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFB5FF67),
            width: 1.3,
          ),
        ),
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: isDark ? const Color(0xFFF6F7F2) : const Color(0xFF111318),
        displayColor:
            isDark ? const Color(0xFFF6F7F2) : const Color(0xFF111318),
      ),
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

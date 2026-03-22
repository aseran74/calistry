import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:calistenia_app/core/shell/main_shell.dart';
import 'package:calistenia_app/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:calistenia_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:calistenia_app/features/auth/presentation/screens/auth_loading_screen.dart';
import 'package:calistenia_app/features/auth/presentation/screens/login_screen.dart';
import 'package:calistenia_app/features/exercises/presentation/screens/exercise_detail_screen.dart';
import 'package:calistenia_app/features/exercises/presentation/screens/exercises_screen.dart';
import 'package:calistenia_app/features/home/presentation/screens/home_screen.dart';
import 'package:calistenia_app/features/live_classes/presentation/screens/live_class_room_screen.dart';
import 'package:calistenia_app/features/live_classes/presentation/screens/live_classes_screen.dart';
import 'package:calistenia_app/features/marketing/presentation/screens/landing_screen.dart';
import 'package:calistenia_app/features/messages/presentation/screens/chat_screen.dart';
import 'package:calistenia_app/features/messages/presentation/screens/messages_screen.dart';
import 'package:calistenia_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:calistenia_app/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:calistenia_app/features/profile/presentation/screens/settings_screen.dart';
import 'package:calistenia_app/features/profile/presentation/screens/student_profile_screen.dart';
import 'package:calistenia_app/features/planning/presentation/screens/planning_screen.dart';
import 'package:calistenia_app/features/progress/presentation/screens/progress_screen.dart';
import 'package:calistenia_app/features/routines/presentation/screens/create_routine_screen.dart';
import 'package:calistenia_app/features/routines/presentation/screens/routine_player_screen.dart';
import 'package:calistenia_app/features/routines/presentation/screens/routines_screen.dart';
import 'package:calistenia_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:calistenia_app/features/search/presentation/screens/search_screen.dart';
import 'package:calistenia_app/features/teachers/presentation/screens/teacher_application_screen.dart';
import 'package:calistenia_app/features/teachers/presentation/screens/teacher_dashboard_screen.dart';
import 'package:calistenia_app/features/teachers/presentation/screens/teacher_profile_screen.dart';
import 'package:calistenia_app/features/teachers/presentation/screens/teacher_groups_screen.dart';
import 'package:calistenia_app/features/teachers/presentation/screens/teacher_group_detail_screen.dart';
import 'package:calistenia_app/features/teachers/presentation/screens/teacher_students_screen.dart';
import 'package:calistenia_app/features/teachers/presentation/screens/teacher_exercises_screen.dart';
import 'package:calistenia_app/features/teachers/presentation/screens/teachers_screen.dart';
import 'package:calistenia_app/features/messages/presentation/screens/group_chat_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorHomeKey = GlobalKey<NavigatorState>();
final _shellNavigatorExercisesKey = GlobalKey<NavigatorState>();
final _shellNavigatorRoutinesKey = GlobalKey<NavigatorState>();
final _shellNavigatorPlanningKey = GlobalKey<NavigatorState>();
final _shellNavigatorProfileKey = GlobalKey<NavigatorState>();

/// Ruta estable de la landing en web (evita `matchedLocation` vacío en `/`).
const String kLandingPath = '/welcome';

String _routerLocation(GoRouterState state) {
  var loc = state.matchedLocation;
  if (loc.isEmpty) loc = state.uri.path;
  if (loc.isEmpty && kIsWeb) loc = '/';
  return loc;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.read(authControllerProvider);

  return GoRouter(
    initialLocation: '/auth-loading',
    navigatorKey: _rootNavigatorKey,
    refreshListenable: auth,
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No se encontró la ruta.\n${state.uri}\n${state.error}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    ),
    redirect: (context, state) {
      final location = _routerLocation(state);
      final isLogin = location == '/login';
      final isLoading = location == '/auth-loading';
      final isAdminRoute = location == '/admin';
      final isTeacherDashboardRoute = location == '/teacher';
      final isTeacherWorkspaceRoute = isTeacherDashboardRoute ||
          location == '/teacher-exercises' ||
          location == '/teacher-students' ||
          location == '/teachers' ||
          location.startsWith('/teachers/') ||
          location == '/teacher-groups' ||
          location.startsWith('/teacher-groups/') ||
          location.startsWith('/group-chats/') ||
          location == '/messages' ||
          location.startsWith('/messages/') ||
          location == '/live-classes' ||
          location.startsWith('/live-classes/') ||
          location == '/user/routines' ||
          location.startsWith('/user/routines/');
      final isAuthenticated = auth.isAuthenticated;
      final isWelcome = location == kLandingPath;

      if (auth.status == AuthStatus.loading) {
        return isLoading ? null : '/auth-loading';
      }

      if (!isAuthenticated) {
        if (kIsWeb && isWelcome) return null;
        if (isLogin) return null;
        if (isLoading) return kIsWeb ? kLandingPath : '/login';
        if (kIsWeb && (location == '/' || location.isEmpty)) {
          return kLandingPath;
        }
        return '/login';
      }

      if (isAuthenticated && isWelcome) {
        if (auth.isAdmin) return '/admin';
        if (auth.isTeacher) return '/teacher';
        return '/user';
      }

      if (isAuthenticated && (location == '/' || location.isEmpty)) {
        if (auth.isAdmin) return '/admin';
        if (auth.isTeacher) return '/teacher';
        return '/user';
      }

      if (isAdminRoute && !auth.isAdmin) {
        if (auth.isTeacher) return '/teacher';
        return '/user';
      }

      // En web, un admin debe aterrizar siempre en su dashboard dedicado,
      // aunque el navegador haya conservado una ruta previa del shell normal.
      if (auth.isAdmin && !isAdminRoute) {
        return '/admin';
      }

      // Si es profesor (y no admin), su punto de entrada por defecto
      // debe ser siempre el dashboard de profesor, en cualquier
      // plataforma (no solo web).
      if (auth.isTeacher &&
          !auth.isAdmin &&
          !isTeacherWorkspaceRoute) {
        return '/teacher';
      }

      // Alumno / usuario: inicio y pestañas bajo /user (compat: redirige rutas antiguas).
      final isStudent = auth.isAuthenticated &&
          !auth.isAdmin &&
          !auth.isTeacher;
      if (isStudent) {
        if (location == '/exercises' || location.startsWith('/exercises/')) {
          return location == '/exercises'
              ? '/user/exercises'
              : '/user$location';
        }
        if (location == '/routines' || location.startsWith('/routines/')) {
          return '/user$location';
        }
        if (location == '/planning') return '/user/planning';
        if (location == '/profile') return '/user/profile';
      }

      if (isLogin || isLoading) {
        if (auth.isAdmin) return '/admin';
        if (auth.isTeacher) return '/teacher';
        return '/user';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) {
          if (kIsWeb) return kLandingPath;
          return '/login';
        },
      ),
      GoRoute(
        path: kLandingPath,
        name: 'landing',
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: '/auth-loading',
        name: 'auth-loading',
        builder: (context, state) => const AuthLoadingScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin-dashboard',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(
          navigationShell: navigationShell,
        ),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorHomeKey,
            routes: [
              GoRoute(
                path: '/user',
                name: 'home',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: HomeScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorExercisesKey,
            routes: [
              GoRoute(
                path: '/user/exercises',
                name: 'exercises',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ExercisesScreen(),
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'exercise-detail',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return ExerciseDetailScreen(exerciseId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorRoutinesKey,
            routes: [
              GoRoute(
                path: '/user/routines',
                name: 'routines',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: RoutinesScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'create',
                    name: 'create-routine',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const CreateRoutineScreen(),
                  ),
                  GoRoute(
                    path: ':id/play',
                    name: 'routine-player',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return RoutinePlayerScreen(routineId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorPlanningKey,
            routes: [
              GoRoute(
                path: '/user/planning',
                name: 'planning',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: PlanningScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorProfileKey,
            routes: [
              GoRoute(
                path: '/user/profile',
                name: 'profile',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/progress',
        name: 'progress',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProgressScreen(),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        name: 'profile-edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/teachers',
        name: 'teachers',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TeachersScreen(),
      ),
      GoRoute(
        path: '/teachers/:id',
        name: 'teacher-profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => TeacherProfileScreen(
          teacherUserId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/teacher-application',
        name: 'teacher-application',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TeacherApplicationScreen(),
      ),
      GoRoute(
        path: '/teacher',
        name: 'teacher-dashboard',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TeacherDashboardScreen(),
      ),
      GoRoute(
        path: '/teacher-exercises',
        name: 'teacher-exercises',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TeacherExercisesScreen(),
      ),
      GoRoute(
        path: '/teacher-students',
        name: 'teacher-students',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TeacherStudentsScreen(),
      ),
      GoRoute(
        path: '/teacher-groups',
        name: 'teacher-groups',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TeacherGroupsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            name: 'teacher-group-detail',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => TeacherGroupDetailScreen(
              groupId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/group-chats/:id',
        name: 'group-chat',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => GroupChatScreen(
          groupConversationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/users/:id',
        name: 'student-profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => StudentProfileScreen(
          studentUserId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/messages',
        name: 'messages',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MessagesScreen(),
      ),
      GoRoute(
        path: '/messages/:id',
        name: 'chat',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ChatScreen(
          conversationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/live-classes',
        name: 'live-classes',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LiveClassesScreen(),
      ),
      GoRoute(
        path: '/live-classes/:id',
        name: 'live-class-room',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => LiveClassRoomScreen(
          liveClassId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
});

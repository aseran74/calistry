import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:calistenia_app/features/routines/domain/models/routine.dart';
import 'package:calistenia_app/features/routines/domain/models/routine_exercise_item.dart';

/// Tab: 'mine' | 'assigned' | 'explore'
/// Por defecto "mine": es lo que más se usa y evita confusión con "Asignadas" vacías.
final routinesTabProvider = StateProvider<String>((ref) => 'mine');

final routinesListProvider =
    FutureProvider.family<List<Routine>, String>((ref, tab) async {
  // Evita que el provider se deseche al cambiar de rama del shell (IndexedStack/offstage).
  ref.keepAlive();
  final client = ref.watch(apiClientProvider);
  // Depender explícitamente del id para re-ejecutar al hidratar sesión.
  final myUserId = ref.watch(
    authControllerProvider.select((a) => a.session?.user.id),
  );

  // Sin userId aún: no llamar a la API (evita lista vacía cacheada mal).
  if (tab == 'mine') {
    if (myUserId == null || myUserId.isEmpty) {
      return [];
    }
    final list = await client.getMyRoutines(limit: 100);
    final out = <Routine>[];
    for (final e in list) {
      try {
        out.add(Routine.fromJson(e));
      } catch (_) {
        // Fila rara de la API: no romper toda la lista.
      }
    }
    return out;
  }

  final list = await client.getRoutines(isPublic: true);
  final out = <Routine>[];
  for (final e in list) {
    try {
      out.add(Routine.fromJson(e));
    } catch (_) {
      // Fila rara de la API: no romper toda la lista.
    }
  }
  return out;
});

final assignedRoutinesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.keepAlive();
  final uid = ref.watch(
    authControllerProvider.select((a) => a.session?.user.id),
  );
  if (uid == null || uid.isEmpty) {
    return [];
  }
  final client = ref.watch(apiClientProvider);
  return client.getAssignedRoutines();
});

/// Detalle de una rutina con sus ejercicios (para player o edición).
final routineDetailProvider = FutureProvider.family<
    ({Routine routine, List<RoutineExerciseItem> exercises})?, String>(
  (ref, routineId) async {
    final client = ref.watch(apiClientProvider);
    final routineJson = await client.getRoutineById(routineId);
    if (routineJson == null) return null;
    final routine = Routine.fromJson(routineJson);
    final exList = await client.getRoutineExercises(routineId);
    final exercises =
        exList.map((e) => RoutineExerciseItem.fromJson(e)).toList();
    return (routine: routine, exercises: exercises);
  },
);

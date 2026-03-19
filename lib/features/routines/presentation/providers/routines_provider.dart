import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:calistenia_app/features/routines/domain/models/routine.dart';
import 'package:calistenia_app/features/routines/domain/models/routine_exercise_item.dart';

/// Tab: 'mine' | 'assigned' | 'explore'
final routinesTabProvider = StateProvider<String>((ref) => 'mine');

final routinesListProvider =
    FutureProvider.family<List<Routine>, String>((ref, tab) async {
  final client = ref.watch(apiClientProvider);
  final auth = ref.watch(authControllerProvider);
  final myUserId = auth.session?.user.id;

  // Importante: por permisos/RLS, pedir sin filtros puede devolver vacío.
  final list = tab == 'mine'
      ? await client.getRoutines(userId: myUserId ?? '')
      : await client.getRoutines(isPublic: true);
  return list.map((e) => Routine.fromJson(e)).toList();
});

final assignedRoutinesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/exercises/domain/models/exercise.dart';

/// Ejercicios destacados para la home (limite 6).
final featuredExercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final list = await client.getExercises(limit: 6);
  return list.map((e) => Exercise.fromJson(e)).toList();
});

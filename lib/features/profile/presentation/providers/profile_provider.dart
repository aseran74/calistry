import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/exercises/domain/models/exercise.dart';

final currentUserProfileProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final client = ref.watch(apiClientProvider);
  return client.getCurrentUserProfile();
});

final favoriteExercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final list = await client.getFavoriteExercises();
  return list.map((e) => Exercise.fromJson(e)).toList();
});

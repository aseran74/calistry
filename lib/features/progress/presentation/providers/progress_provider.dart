import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/progress/domain/models/user_progress_entry.dart';

/// Estadísticas del usuario: sesiones, tiempo, rachas.
final userStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(apiClientProvider);
  return client.getUserStats();
});

/// Lista de progreso reciente (historial).
final userProgressListProvider =
    FutureProvider<List<UserProgressEntry>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final list = await client.getUserProgressList(limit: 50);
  return list.map((e) => UserProgressEntry.fromJson(e)).toList();
});

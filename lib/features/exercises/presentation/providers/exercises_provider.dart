import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calistenia_app/core/api/api_client.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/core/utils/user_display_name.dart';
import 'package:calistenia_app/features/exercises/domain/models/exercise.dart';

final exercisesSearchQueryProvider = StateProvider<String>((ref) => '');
final exercisesCategoryProvider = StateProvider<String?>((ref) => null);
final exercisesDifficultyProvider = StateProvider<String?>((ref) => null);

class ExercisesNotifier extends StateNotifier<AsyncValue<List<Exercise>>> {
  ExercisesNotifier(this._client) : super(const AsyncValue.loading()) {
    _load();
  }

  final ApiClient _client;
  int _offset = 0;
  static const int _pageSize = 20;
  final List<Exercise> _all = [];
  String? _lastCategory;
  String? _lastDifficulty;
  String _lastSearch = '';
  bool _hasMore = true;
  bool _loadingMore = false;

  Future<List<Exercise>> _mapExercisesWithOwners(
    List<Map<String, dynamic>> rows,
  ) async {
    final ownerIds = rows
        .map((row) => row['owner_user_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final users = await _client.getUsersByIds(ownerIds);
    final teachers = await _client.getTeacherProfilesByUserIds(ownerIds);
    final usersById = {
      for (final user in users) user['id']?.toString() ?? '': user,
    };
    final teachersById = {
      for (final teacher in teachers)
        teacher['user_id']?.toString() ?? '': teacher,
    };
    return rows.map((row) {
      final ownerId = row['owner_user_id']?.toString();
      final teacher = ownerId == null ? null : teachersById[ownerId];
      final owner = ownerId == null ? null : usersById[ownerId];
      final teacherName = teacher?['display_name']?.toString().trim() ?? '';
      return Exercise.fromJson({
        ...row,
        'owner_display_name': teacherName.isNotEmpty
            ? teacherName
            : userDisplayNameFromJson(
                owner,
                fallback: 'Sin profesor',
              ),
      });
    }).toList();
  }

  Future<void> _load({bool reset = true}) async {
    if (reset) {
      _offset = 0;
      _all.clear();
      _hasMore = true;
      state = const AsyncValue.loading();
    }
    try {
      final list = await _client.getExercises(
        category: _lastCategory,
        difficulty: _lastDifficulty,
        search: _lastSearch.isEmpty ? null : _lastSearch,
        limit: _pageSize,
        offset: _offset,
      );
      final exercises = await _mapExercisesWithOwners(list);
      if (reset) {
        _all.clear();
        _all.addAll(exercises);
        state = AsyncValue.data(List.from(_all));
      } else {
        _all.addAll(exercises);
        state = AsyncValue.data(List.from(_all));
      }
      _offset += exercises.length.toInt();
      _hasMore = exercises.length >= _pageSize;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setFilters({
    String? category,
    String? difficulty,
    String? search,
  }) async {
    _lastCategory = category;
    _lastDifficulty = difficulty;
    _lastSearch = search ?? _lastSearch;
    await _load(reset: true);
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore || state.isLoading) return;
    _loadingMore = true;
    try {
      final list = await _client.getExercises(
        category: _lastCategory,
        difficulty: _lastDifficulty,
        search: _lastSearch.isEmpty ? null : _lastSearch,
        limit: _pageSize,
        offset: _offset,
      );
      final exercises = await _mapExercisesWithOwners(list);
      _all.addAll(exercises);
      _offset += exercises.length.toInt();
      _hasMore = exercises.length >= _pageSize;
      state = AsyncValue.data(List.from(_all));
    } finally {
      _loadingMore = false;
    }
  }

  void refresh() => _load(reset: true);
}

final exercisesProvider =
    StateNotifierProvider<ExercisesNotifier, AsyncValue<List<Exercise>>>((ref) {
  final client = ref.watch(apiClientProvider);
  return ExercisesNotifier(client);
});

final exerciseDetailProvider =
    FutureProvider.family<Exercise?, String>((ref, id) async {
  final client = ref.watch(apiClientProvider);
  final json = await client.getExercise(id);
  if (json == null) return null;
  final ownerId = json['owner_user_id']?.toString();
  Map<String, dynamic>? owner;
  Map<String, dynamic>? teacher;
  if (ownerId != null && ownerId.isNotEmpty) {
    final results = await Future.wait([
      client.getUserById(ownerId),
      client.getTeacherProfile(ownerId),
    ]);
    owner = results[0];
    teacher = results[1];
  }
  final teacherName = teacher?['display_name']?.toString().trim() ?? '';
  return Exercise.fromJson({
    ...json,
    'owner_display_name': teacherName.isNotEmpty
        ? teacherName
        : userDisplayNameFromJson(
            owner,
            fallback: 'Sin profesor',
          ),
  });
});

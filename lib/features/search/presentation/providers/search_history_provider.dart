import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _searchHistoryKey = 'search_history';
const _maxHistoryItems = 20;

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

/// Historial de búsquedas recientes (persistido en SharedPreferences).
final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier(ref);
});

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  SearchHistoryNotifier(this._ref) : super([]) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    final raw = prefs.getStringList(_searchHistoryKey);
    if (raw != null) {
      state = raw;
    }
  }

  Future<void> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final next = [q, ...state.where((s) => s.toLowerCase() != q.toLowerCase())];
    if (next.length > _maxHistoryItems) {
      next.removeRange(_maxHistoryItems, next.length);
    }
    state = next;
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    await prefs.setStringList(_searchHistoryKey, next);
  }

  Future<void> remove(String item) async {
    final next = state.where((s) => s != item).toList();
    state = next;
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    await prefs.setStringList(_searchHistoryKey, next);
  }

  Future<void> clear() async {
    state = [];
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    await prefs.remove(_searchHistoryKey);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/exercises/domain/models/exercise.dart';
import 'package:calistenia_app/features/exercises/presentation/widgets/exercise_card.dart';
import 'package:calistenia_app/features/routines/domain/models/routine.dart';
import 'package:calistenia_app/features/search/presentation/providers/search_history_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';
  bool _searching = false;
  List<Exercise> _exercises = [];
  List<Routine> _routines = [];
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    if (q.trim().isEmpty) {
      setState(() {
        _query = '';
        _exercises = [];
        _routines = [];
        _error = null;
        _searching = false;
      });
      return;
    }
    setState(() {
      _query = q.trim();
      _searching = true;
      _error = null;
    });
    ref.read(searchHistoryProvider.notifier).add(_query);
    try {
      final client = ref.read(apiClientProvider);
      final [exList, routinesList] = await Future.wait([
        client.getExercises(search: _query, limit: 20),
        client.getRoutines(limit: 10),
      ]);
      final routinesFiltered = routinesList
          .map((e) => Routine.fromJson(e))
          .where((r) => r.name.toLowerCase().contains(_query.toLowerCase()))
          .toList();
      if (!mounted) return;
      setState(() {
        _exercises = exList.map((e) => Exercise.fromJson(e)).toList();
        _routines = routinesFiltered;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(searchHistoryProvider);
    final showHistory = _query.isEmpty && _controller.text.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar'),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SearchHero(
                      controller: _controller,
                      focusNode: _focusNode,
                      onSubmit: _runSearch,
                      onChanged: (value) {
                        setState(() {});
                        if (value.trim().isEmpty) {
                          setState(() => _query = '');
                        }
                      },
                      onClear: () {
                        _controller.clear();
                        setState(() {
                          _query = '';
                          _exercises = [];
                          _routines = [];
                          _error = null;
                          _searching = false;
                        });
                      },
                      onSearchTap: () => _runSearch(_controller.text),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
            if (showHistory)
              SliverToBoxAdapter(
                child: _HistorySection(
                  history: history,
                  onTap: (item) {
                    _controller.text = item;
                    _runSearch(item);
                  },
                  onRemove: (item) =>
                      ref.read(searchHistoryProvider.notifier).remove(item),
                  onClear: () =>
                      ref.read(searchHistoryProvider.notifier).clear(),
                ),
              )
            else if (_searching)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _SearchStatePanel(
                      icon: Icons.error_outline,
                      title: 'La búsqueda no se pudo completar',
                      subtitle: 'Error: $_error',
                      actionLabel: 'Reintentar',
                      onTap: () => _runSearch(_query),
                    ),
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: _ResultSection(
                  query: _query,
                  exercises: _exercises,
                  routines: _routines,
                  onExerciseTap: (ex) => context.push(
                    '/exercises/${ex.id}',
                    extra: ex,
                  ),
                  onRoutineTap: (r) => context.push(
                    '/routines/${r.id}/play',
                    extra: r,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

class _SearchHero extends StatelessWidget {
  const _SearchHero({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onChanged,
    required this.onClear,
    required this.onSearchTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmit;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasText = controller.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.2),
            theme.colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Encuentra tu siguiente movimiento',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Busca ejercicios y rutinas desde un mismo sitio para entrenar más rápido.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Buscar ejercicios y rutinas...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: hasText
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: onClear,
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_rounded),
                          onPressed: onSearchTap,
                        ),
                      ],
                    )
                  : null,
            ),
            onSubmitted: onSubmit,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.history,
    required this.onTap,
    required this.onRemove,
    required this.onClear,
  });

  final List<String> history;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: _SearchStatePanel(
          icon: Icons.history,
          title: 'Sin búsquedas recientes',
          subtitle: 'Lo que busques aparecerá aquí para repetirlo más tarde.',
          actionLabel: 'Explorar ejercicios',
          onTap: () => context.pop(),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recientes',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextButton(
                onPressed: onClear,
                child: const Text('Borrar todo'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...history.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.history, color: theme.colorScheme.primary),
                    ),
                    title: Text(item),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => onRemove(item),
                    ),
                    onTap: () => onTap(item),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.query,
    required this.exercises,
    required this.routines,
    required this.onExerciseTap,
    required this.onRoutineTap,
  });

  final String query;
  final List<Exercise> exercises;
  final List<Routine> routines;
  final ValueChanged<Exercise> onExerciseTap;
  final ValueChanged<Routine> onRoutineTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resultados para "$query"',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${exercises.length} ejercicios · ${routines.length} rutinas',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          if (exercises.isNotEmpty) ...[
            Text(
              'Ejercicios',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...exercises.map((ex) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    height: 238,
                    child: ExerciseCard(
                      exercise: ex,
                      onTap: () => onExerciseTap(ex),
                    ),
                  ),
                )),
            const SizedBox(height: 10),
          ],
          if (routines.isNotEmpty) ...[
            Text(
              'Rutinas',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...routines.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.playlist_play_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      title: Text(r.name),
                      subtitle: Text(r.level),
                      trailing: const Icon(Icons.play_arrow_rounded),
                      onTap: () => onRoutineTap(r),
                    ),
                  ),
                )),
          ],
          if (exercises.isEmpty && routines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: _SearchStatePanel(
                icon: Icons.travel_explore_outlined,
                title: 'No hay resultados',
                subtitle: 'No se encontraron coincidencias para "$query".',
                actionLabel: 'Probar otra búsqueda',
                onTap: () => FocusScope.of(context).requestFocus(),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchStatePanel extends StatelessWidget {
  const _SearchStatePanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onTap,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

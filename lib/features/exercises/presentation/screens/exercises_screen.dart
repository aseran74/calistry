import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:calistenia_app/features/exercises/domain/exercise_metadata.dart';
import 'package:calistenia_app/features/exercises/presentation/providers/exercises_provider.dart';
import 'package:calistenia_app/features/exercises/presentation/widgets/exercise_card.dart';
import 'package:calistenia_app/features/exercises/presentation/widgets/exercise_card_shimmer.dart';

class ExercisesScreen extends ConsumerStatefulWidget {
  const ExercisesScreen({super.key});

  @override
  ConsumerState<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends ConsumerState<ExercisesScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  static const _debounceDuration = Duration(milliseconds: 300);
  bool _initialQueryApplied = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialQueryApplied) return;
    final queryCategory =
        GoRouterState.of(context).uri.queryParameters['category'];
    if (queryCategory != null && queryCategory.isNotEmpty) {
      _initialQueryApplied = true;
      ref.read(exercisesCategoryProvider.notifier).state = queryCategory;
      ref.read(exercisesProvider.notifier).setFilters(
            category: queryCategory,
            difficulty: ref.read(exercisesDifficultyProvider),
            search: _searchController.text.trim().isEmpty
                ? null
                : _searchController.text.trim(),
          );
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(_debounceDuration, () {
      ref.read(exercisesSearchQueryProvider.notifier).state =
          _searchController.text.trim();
      ref.read(exercisesProvider.notifier).setFilters(
            search: _searchController.text.trim().isEmpty
                ? null
                : _searchController.text.trim(),
            category: ref.read(exercisesCategoryProvider),
            difficulty: ref.read(exercisesDifficultyProvider),
          );
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openProposalDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final musclesController = TextEditingController();
    final durationController = TextEditingController();
    final gifController = TextEditingController();
    final videoController = TextEditingController();
    final thumbnailController = TextEditingController();
    var category = exerciseCategories.first;
    var difficulty = exerciseDifficulties.first;
    var submitting = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !submitting,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setLocalState) {
              Future<void> submit() async {
                if (nameController.text.trim().isEmpty || submitting) return;
                setLocalState(() => submitting = true);
                try {
                  await ref.read(apiClientProvider).submitExerciseProposal(
                        name: nameController.text.trim(),
                        description: descriptionController.text.trim().isEmpty
                            ? null
                            : descriptionController.text.trim(),
                        category: category,
                        difficulty: difficulty,
                        muscleGroups: musclesController.text
                            .split(',')
                            .map((item) => item.trim())
                            .where((item) => item.isNotEmpty)
                            .toList(),
                        durationSeconds:
                            int.tryParse(durationController.text.trim()),
                        gifUrl: gifController.text.trim().isEmpty
                            ? null
                            : gifController.text.trim(),
                        videoUrl: videoController.text.trim().isEmpty
                            ? null
                            : videoController.text.trim(),
                        thumbnailUrl: thumbnailController.text.trim().isEmpty
                            ? null
                            : thumbnailController.text.trim(),
                      );
                  if (!context.mounted || !mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Propuesta enviada. Un admin la revisará antes de publicarla.',
                      ),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  setLocalState(() => submitting = false);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }

              return AlertDialog(
                title: const Text('Proponer ejercicio'),
                content: SizedBox(
                  width: 520,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del ejercicio',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descriptionController,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Descripción',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          items: exerciseCategories
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(exerciseCategoryLabel(item)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setLocalState(() => category = value);
                          },
                          decoration:
                              const InputDecoration(labelText: 'Categoría'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: difficulty,
                          items: exerciseDifficulties
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(exerciseDifficultyLabel(item)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setLocalState(() => difficulty = value);
                          },
                          decoration:
                              const InputDecoration(labelText: 'Dificultad'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: musclesController,
                          decoration: const InputDecoration(
                            labelText: 'Grupos musculares separados por coma',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: durationController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Duración estimada (segundos)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: gifController,
                          decoration:
                              const InputDecoration(labelText: 'GIF URL'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: videoController,
                          decoration:
                              const InputDecoration(labelText: 'Video URL'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: thumbnailController,
                          decoration: const InputDecoration(
                            labelText: 'Thumbnail URL',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        submitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: submitting ? null : submit,
                    child:
                        Text(submitting ? 'Enviando...' : 'Enviar propuesta'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      descriptionController.dispose();
      musclesController.dispose();
      durationController.dispose();
      gifController.dispose();
      videoController.dispose();
      thumbnailController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final exercisesState = ref.watch(exercisesProvider);
    final category = ref.watch(exercisesCategoryProvider);
    final difficulty = ref.watch(exercisesDifficultyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ejercicios'),
        actions: [
          if (auth.isAuthenticated && !auth.isAdmin)
            IconButton(
              tooltip: 'Proponer ejercicio',
              icon: const Icon(Icons.lightbulb_outline),
              onPressed: _openProposalDialog,
            ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notificaciones',
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(exercisesProvider.notifier).refresh();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ExercisesHero(
                      total: exercisesState.valueOrNull?.length ?? 0,
                      category: category,
                      difficulty: difficulty,
                    ),
                    if (auth.isAuthenticated && !auth.isAdmin) ...[
                      const SizedBox(height: 14),
                      _ProposalCtaCard(
                        onTap: _openProposalDialog,
                      ),
                    ],
                    const SizedBox(height: 18),
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Buscar ejercicios, técnica o categoría',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FilterSection(
                      title: 'Categorías',
                      children: exerciseCategories.map((c) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8, bottom: 8),
                          child: FilterChip(
                            label: Text(_labelCategory(c)),
                            selected: category == c,
                            onSelected: (_) {
                              final next = category == c ? null : c;
                              ref
                                  .read(exercisesCategoryProvider.notifier)
                                  .state = next;
                              ref.read(exercisesProvider.notifier).setFilters(
                                    category: next,
                                    difficulty: difficulty,
                                    search:
                                        _searchController.text.trim().isEmpty
                                            ? null
                                            : _searchController.text.trim(),
                                  );
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 6),
                    _FilterSection(
                      title: 'Dificultad',
                      children: exerciseDifficulties.map((d) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8, bottom: 8),
                          child: FilterChip(
                            label: Text(_labelDifficulty(d)),
                            selected: difficulty == d,
                            onSelected: (_) {
                              final next = difficulty == d ? null : d;
                              ref
                                  .read(exercisesDifficultyProvider.notifier)
                                  .state = next;
                              ref.read(exercisesProvider.notifier).setFilters(
                                    difficulty: next,
                                    category: category,
                                    search:
                                        _searchController.text.trim().isEmpty
                                            ? null
                                            : _searchController.text.trim(),
                                  );
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Biblioteca',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${exercisesState.valueOrNull?.length ?? 0} resultados',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            exercisesState.when(
              loading: () => SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 0.64,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, __) => const ExerciseCardShimmer(),
                    childCount: 8,
                  ),
                ),
              ),
              error: (err, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _StatePanel(
                      icon: Icons.error_outline,
                      title: 'No se pudieron cargar los ejercicios',
                      subtitle: 'Detalle: $err',
                      actionLabel: 'Reintentar',
                      onTap: () =>
                          ref.read(exercisesProvider.notifier).refresh(),
                    ),
                  ),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _StatePanel(
                          icon: Icons.filter_alt_off_outlined,
                          title: 'No hay ejercicios con estos filtros',
                          subtitle:
                              'Prueba otra combinación para descubrir más movimientos.',
                          actionLabel: 'Limpiar filtros',
                          onTap: () {
                            _searchController.clear();
                            ref.read(exercisesCategoryProvider.notifier).state =
                                null;
                            ref
                                .read(exercisesDifficultyProvider.notifier)
                                .state = null;
                            ref.read(exercisesProvider.notifier).setFilters();
                          },
                        ),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      childAspectRatio: 0.64,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == list.length) {
                          ref.read(exercisesProvider.notifier).loadMore();
                          return const SizedBox.shrink();
                        }
                        final exercise = list[index];
                        return ExerciseCard(
                          exercise: exercise,
                          onTap: () => context.push(
                            '/exercises/${exercise.id}',
                            extra: exercise,
                          ),
                        );
                      },
                      childCount: list.length + 1,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _labelCategory(String c) {
    return exerciseCategoryLabel(c);
  }

  String _labelDifficulty(String d) {
    return exerciseDifficultyLabel(d);
  }
}

class _ProposalCtaCard extends StatelessWidget {
  const _ProposalCtaCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.lightbulb_outline,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Proponer ejercicio',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Envía tu idea y un admin la revisará antes de publicarla.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExercisesHero extends StatelessWidget {
  const _ExercisesHero({
    required this.total,
    required this.category,
    required this.difficulty,
  });

  final int total;
  final String? category;
  final String? difficulty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFilter = category != null || difficulty != null;

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
            'Ejercicios',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilter
                ? 'Filtra la biblioteca y afina el trabajo que quieres hacer hoy.'
                : 'Explora la biblioteca completa y descubre nuevos movimientos.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroBadge(label: '$total disponibles'),
              if (category != null) _HeroBadge(label: category!),
              if (difficulty != null) _HeroBadge(label: difficulty!),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(children: children),
      ],
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge,
      ),
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
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
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
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

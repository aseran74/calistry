import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:calistenia_app/core/router/student_shell_routes.dart';
import 'package:calistenia_app/core/shell/student_shell_layout.dart';
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
            ownerUserId: ref.read(exercisesOwnerUserIdProvider),
            search: _searchController.text.trim().isEmpty
                ? null
                : _searchController.text.trim(),
          );
    }
  }

  void _applyFilters() {
    ref.read(exercisesProvider.notifier).setFilters(
          search: _searchController.text.trim(),
          category: ref.read(exercisesCategoryProvider),
          difficulty: ref.read(exercisesDifficultyProvider),
          ownerUserId: ref.read(exercisesOwnerUserIdProvider),
        );
  }

  void _onSearchChanged() {
    setState(() {});
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(_debounceDuration, () {
      ref.read(exercisesSearchQueryProvider.notifier).state =
          _searchController.text.trim();
      _applyFilters();
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
    final repsController = TextEditingController();
    final setsController = TextEditingController();
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
                        reps: int.tryParse(repsController.text.trim()),
                        sets: int.tryParse(setsController.text.trim()),
                        gifUrl: null,
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
                          controller: repsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Nº repeticiones',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: setsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Nº series',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: videoController,
                          decoration: const InputDecoration(
                            labelText: 'Vídeo URL (mp4/webm)',
                            hintText: 'Se reproduce en bucle sin sonido',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: thumbnailController,
                          decoration: const InputDecoration(
                            labelText: 'Thumbnail URL (opcional)',
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
      repsController.dispose();
      setsController.dispose();
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
    final ownerUserId = ref.watch(exercisesOwnerUserIdProvider);
    final teachersAsync = ref.watch(approvedTeachersForFilterProvider);

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
                      teacherName: teachersAsync.valueOrNull
                          ?.where((t) => t.id == ownerUserId)
                          .map((t) => t.name)
                          .firstOrNull,
                    ),
                    if (auth.isAuthenticated && !auth.isAdmin) ...[
                      const SizedBox(height: 14),
                      _ProposalCtaCard(
                        onTap: _openProposalDialog,
                      ),
                    ],
                    const SizedBox(height: 18),
                    _ExercisesFilterPanel(
                      searchController: _searchController,
                      category: category,
                      difficulty: difficulty,
                      ownerUserId: ownerUserId,
                      teachers: teachersAsync.valueOrNull ?? const [],
                      teachersLoading: teachersAsync.isLoading,
                      hasActiveFilters: category != null ||
                          difficulty != null ||
                          ownerUserId != null ||
                          _searchController.text.trim().isNotEmpty,
                      onTeacherChanged: (value) {
                        ref.read(exercisesOwnerUserIdProvider.notifier).state =
                            value;
                        _applyFilters();
                      },
                      onCategoryChanged: (value) {
                        ref.read(exercisesCategoryProvider.notifier).state =
                            value;
                        _applyFilters();
                      },
                      onDifficultyChanged: (value) {
                        ref.read(exercisesDifficultyProvider.notifier).state =
                            value;
                        _applyFilters();
                      },
                      onClear: () {
                        _searchController.clear();
                        ref.read(exercisesCategoryProvider.notifier).state =
                            null;
                        ref.read(exercisesDifficultyProvider.notifier).state =
                            null;
                        ref.read(exercisesOwnerUserIdProvider.notifier).state =
                            null;
                        ref.read(exercisesProvider.notifier).setFilters(
                              category: null,
                              difficulty: null,
                              ownerUserId: null,
                              search: '',
                            );
                      },
                    ),
                    const SizedBox(height: 18),
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
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  StudentShellLayout.bodyBottomPadding(context),
                ),
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
                            ref
                                .read(exercisesOwnerUserIdProvider.notifier)
                                .state = null;
                            ref.read(exercisesProvider.notifier).setFilters(
                                  category: null,
                                  difficulty: null,
                                  ownerUserId: null,
                                  search: '',
                                );
                          },
                        ),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  StudentShellLayout.bodyBottomPadding(context),
                ),
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
                            StudentShellRoutes.exerciseDetail(exercise.id),
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

class _ExercisesFilterPanel extends StatelessWidget {
  const _ExercisesFilterPanel({
    required this.searchController,
    required this.category,
    required this.difficulty,
    required this.ownerUserId,
    required this.teachers,
    required this.teachersLoading,
    required this.hasActiveFilters,
    required this.onTeacherChanged,
    required this.onCategoryChanged,
    required this.onDifficultyChanged,
    required this.onClear,
  });

  final TextEditingController searchController;
  final String? category;
  final String? difficulty;
  final String? ownerUserId;
  final List<({String id, String name})> teachers;
  final bool teachersLoading;
  final bool hasActiveFilters;
  final ValueChanged<String?> onTeacherChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onDifficultyChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final teacherValue = ownerUserId != null &&
            teachers.any((t) => t.id == ownerUserId)
        ? ownerUserId
        : null;

    final teacherDropdown = DropdownButtonFormField<String?>(
      key: ValueKey('teacher-$teacherValue-${teachers.length}'),
      initialValue: teacherValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Profesor',
        hintText: teachersLoading ? 'Cargando…' : 'Todos',
        prefixIcon: const Icon(Icons.school_outlined),
        filled: true,
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Todos los profesores'),
        ),
        ...teachers.map(
          (t) => DropdownMenuItem<String?>(
            value: t.id,
            child: Text(t.name, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: teachersLoading ? null : onTeacherChanged,
    );

    final categoryDropdown = DropdownButtonFormField<String?>(
      key: ValueKey('category-$category'),
      initialValue: category,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Categoría',
        prefixIcon: Icon(Icons.category_outlined),
        filled: true,
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Todas las categorías'),
        ),
        ...exerciseCategories.map(
          (c) => DropdownMenuItem<String?>(
            value: c,
            child: Text(exerciseCategoryLabel(c)),
          ),
        ),
      ],
      onChanged: onCategoryChanged,
    );

    final difficultyDropdown = DropdownButtonFormField<String?>(
      key: ValueKey('difficulty-$difficulty'),
      initialValue: difficulty,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Nivel',
        prefixIcon: Icon(Icons.signal_cellular_alt),
        filled: true,
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Todos los niveles'),
        ),
        ...exerciseDifficulties.map(
          (d) => DropdownMenuItem<String?>(
            value: d,
            child: Text(exerciseDifficultyLabel(d)),
          ),
        ),
      ],
      onChanged: onDifficultyChanged,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Buscar y filtrar',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (hasActiveFilters)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: const Text('Limpiar'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Elige profesor, categoría o nivel, o escribe el nombre del ejercicio.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            decoration: const InputDecoration(
              hintText: 'Nombre del ejercicio…',
              prefixIcon: Icon(Icons.search),
              filled: true,
            ),
          ),
          const SizedBox(height: 12),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: teacherDropdown),
                const SizedBox(width: 12),
                Expanded(child: categoryDropdown),
                const SizedBox(width: 12),
                Expanded(child: difficultyDropdown),
              ],
            )
          else ...[
            teacherDropdown,
            const SizedBox(height: 10),
            categoryDropdown,
            const SizedBox(height: 10),
            difficultyDropdown,
          ],
        ],
      ),
    );
  }
}

class _ExercisesHero extends StatelessWidget {
  const _ExercisesHero({
    required this.total,
    required this.category,
    required this.difficulty,
    this.teacherName,
  });

  final int total;
  final String? category;
  final String? difficulty;
  final String? teacherName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFilter =
        category != null || difficulty != null || teacherName != null;

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
                ? 'Resultados filtrados por tus criterios.'
                : 'Usa el panel de filtros para buscar por profesor, categoría o nivel.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroBadge(label: '$total disponibles'),
              if (teacherName != null) _HeroBadge(label: teacherName!),
              if (category != null)
                _HeroBadge(label: exerciseCategoryLabel(category!)),
              if (difficulty != null)
                _HeroBadge(label: exerciseDifficultyLabel(difficulty!)),
            ],
          ),
        ],
      ),
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

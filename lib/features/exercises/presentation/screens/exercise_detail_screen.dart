import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:calistenia_app/features/exercises/presentation/providers/exercises_provider.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/core/theme/theme.dart';
import 'package:calistenia_app/features/exercises/domain/exercise_metadata.dart';
import 'package:calistenia_app/features/exercises/presentation/widgets/exercise_video_player.dart';

class ExerciseDetailScreen extends ConsumerStatefulWidget {
  const ExerciseDetailScreen({
    super.key,
    required this.exerciseId,
  });

  final String exerciseId;

  @override
  ConsumerState<ExerciseDetailScreen> createState() =>
      _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends ConsumerState<ExerciseDetailScreen> {
  bool _isFavorite = false;

  @override
  Widget build(BuildContext context) {
    final exerciseAsync = ref.watch(exerciseDetailProvider(widget.exerciseId));
    final theme = Theme.of(context);

    return Scaffold(
      body: exerciseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _DetailStatePanel(
              icon: Icons.error_outline,
              title: 'No se pudo cargar el ejercicio',
              subtitle: '$e',
              actionLabel: 'Reintentar',
              onTap: () => ref.invalidate(
                exerciseDetailProvider(widget.exerciseId),
              ),
            ),
          ),
        ),
        data: (exercise) {
          if (exercise == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: _DetailStatePanel(
                  icon: Icons.search_off_outlined,
                  title: 'Ejercicio no encontrado',
                  subtitle: 'No hay datos disponibles para este elemento.',
                ),
              ),
            );
          }
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                actions: [
                  IconButton.filledTonal(
                    onPressed: () async {
                      setState(() => _isFavorite = !_isFavorite);
                      try {
                        await ref
                            .read(apiClientProvider)
                            .toggleFavorite(exercise.id);
                      } catch (_) {
                        setState(() => _isFavorite = !_isFavorite);
                      }
                    },
                    icon: Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: (exercise.gifUrl ?? exercise.thumbnailUrl ?? '').trim().isNotEmpty
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Hero(
                              tag: 'exercise-${exercise.id}',
                              child: CachedNetworkImage(
                                imageUrl: exercise.gifUrl ?? exercise.thumbnailUrl ?? '',
                                fit: BoxFit.cover,
                              ),
                            ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black54,
                                  ],
                                ),
                              ),
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.82),
                                    Colors.black.withValues(alpha: 0.1),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 20,
                              right: 20,
                              bottom: 28,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: DifficultyColors.fromString(
                                        exercise.difficulty,
                                      ).withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      exerciseDifficultyLabel(
                                        exercise.difficulty,
                                      ).toUpperCase(),
                                      style: TextStyle(
                                        color: DifficultyColors.fromString(
                                          exercise.difficulty,
                                        ),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    exercise.name,
                                    style: theme.textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (exercise.category.isNotEmpty)
                                        _DetailBadge(
                                          label: exerciseCategoryLabel(
                                            exercise.category,
                                          ),
                                        ),
                                      if ((exercise.durationSeconds ?? 0) > 0)
                                        _DetailBadge(
                                          label: '${exercise.durationSeconds}s',
                                        ),
                                      if ((exercise.ownerDisplayName ?? '')
                                          .trim()
                                          .isNotEmpty)
                                        _DetailBadge(
                                          label:
                                              'Usuario: ${exercise.ownerDisplayName}',
                                        ),
                                      if (exercise.muscleGroups.isNotEmpty)
                                        _DetailBadge(
                                          label:
                                              '${exercise.muscleGroups.length} grupos',
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.fitness_center,
                            size: 80,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (exercise.videoUrl != null && exercise.videoUrl!.trim().isNotEmpty) ...[
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: ExerciseVideoPlayer(
                            videoUrl: exercise.videoUrl!,
                            aspectRatio: 16 / 9,
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Músculos trabajados',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (exercise.muscleGroups.isEmpty)
                                Text(
                                  'No hay grupos musculares definidos para este ejercicio.',
                                  style: theme.textTheme.bodySmall,
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: exercise.muscleGroups
                                      .map((m) => Chip(label: Text(m)))
                                      .toList(),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (exercise.description != null &&
                          exercise.description!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Descripción',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  exercise.description!,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _QuickStatsRow(
                        durationSeconds: exercise.durationSeconds,
                        hasVideo:
                            exercise.videoUrl != null &&
                            exercise.videoUrl!.isNotEmpty,
                        hasGif:
                            exercise.gifUrl != null &&
                            exercise.gifUrl!.isNotEmpty,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Agregar a rutina (próximamente)'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Agregar a rutina'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({
    required this.durationSeconds,
    required this.hasVideo,
    required this.hasGif,
  });

  final int? durationSeconds;
  final bool hasVideo;
  final bool hasGif;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickStatCard(
            icon: Icons.timer_outlined,
            label: 'Duración',
            value: durationSeconds != null ? '${durationSeconds}s' : '-',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickStatCard(
            icon: Icons.ondemand_video_outlined,
            label: 'Video',
            value: hasVideo ? 'Sí' : 'No',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickStatCard(
            icon: Icons.gif_box_outlined,
            label: 'GIF',
            value: hasGif ? 'Sí' : 'No',
          ),
        ),
      ],
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _DetailBadge extends StatelessWidget {
  const _DetailBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _DetailStatePanel extends StatelessWidget {
  const _DetailStatePanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onTap;

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
            if (actionLabel != null && onTap != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onTap,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

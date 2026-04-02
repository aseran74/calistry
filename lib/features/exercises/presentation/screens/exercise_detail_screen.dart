import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:calistenia_app/features/exercises/presentation/providers/exercises_provider.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/core/theme/theme.dart';
import 'package:calistenia_app/features/exercises/domain/exercise_metadata.dart';
import 'package:calistenia_app/features/exercises/domain/models/exercise.dart';
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

  int? _totalSecondsForExercise(Exercise exercise) {
    final duration = exercise.durationSeconds;
    final sets = exercise.sets;
    if (duration == null || duration <= 0) return null;
    if (sets == null || sets <= 0) return duration;
    return duration * sets;
  }

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
                              left: 14,
                              right: 14,
                              top: 68,
                              child: _ExerciseInfoMenu(
                                totalSeconds: _totalSecondsForExercise(exercise),
                                reps: exercise.reps,
                                sets: exercise.sets,
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
                                      if ((exercise.reps ?? 0) > 0)
                                        _DetailBadge(
                                          label: '${exercise.reps} reps',
                                        ),
                                      if ((exercise.sets ?? 0) > 0)
                                        _DetailBadge(
                                          label: '${exercise.sets} series',
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
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.fitness_center,
                                size: 80,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            Positioned(
                              left: 14,
                              right: 14,
                              top: 68,
                              child: _ExerciseInfoMenu(
                                totalSeconds: _totalSecondsForExercise(exercise),
                                reps: exercise.reps,
                                sets: exercise.sets,
                                darkText: true,
                              ),
                            ),
                          ],
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

class _ExerciseInfoMenu extends StatelessWidget {
  const _ExerciseInfoMenu({
    required this.totalSeconds,
    required this.reps,
    required this.sets,
    this.darkText = false,
  });

  final int? totalSeconds;
  final int? reps;
  final int? sets;
  final bool darkText;

  String get _timeLabel {
    final seconds = totalSeconds;
    if (seconds == null || seconds <= 0) return '-';
    final minutes = seconds ~/ 60;
    final rem = seconds % 60;
    if (minutes <= 0) return '${seconds}s';
    return rem == 0 ? '${minutes}m' : '${minutes}m ${rem}s';
  }

  @override
  Widget build(BuildContext context) {
    final fg = darkText ? Colors.black87 : Colors.white;
    final bg = darkText
        ? Colors.white.withValues(alpha: 0.82)
        : Colors.black.withValues(alpha: 0.52);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    final isCompact = width < 420;
    final horizontalPadding = isWide ? 16.0 : (isCompact ? 10.0 : 14.0);
    final verticalPadding = isWide ? 12.0 : (isCompact ? 9.0 : 11.0);
    final spacing = isWide ? 16.0 : (isCompact ? 8.0 : 14.0);
    final runSpacing = isWide ? 10.0 : (isCompact ? 7.0 : 10.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: darkText
              ? Colors.black.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.16),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            _DetailMetric(
              label: 'Tiempo total',
              value: _timeLabel,
              color: fg,
              isWide: isWide,
              isCompact: isCompact,
            ),
            _DetailMetric(
              label: 'Nº repeticiones',
              value: reps?.toString() ?? '-',
              color: fg,
              isWide: isWide,
              isCompact: isCompact,
            ),
            _DetailMetric(
              label: 'Nº series',
              value: sets?.toString() ?? '-',
              color: fg,
              isWide: isWide,
              isCompact: isCompact,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.isWide,
    required this.isCompact,
  });

  final String label;
  final String value;
  final Color color;
  final bool isWide;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: color.withValues(alpha: 0.92),
          fontWeight: FontWeight.w700,
          fontSize: isWide ? 15 : (isCompact ? 12 : null),
        );
    final valueSize = isWide ? 20.0 : (isCompact ? 16.0 : 18.0);

    return RichText(
      text: TextSpan(
        style: labelStyle,
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: valueSize,
            ),
          ),
        ],
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

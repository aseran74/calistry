import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/exercises/domain/exercise_metadata.dart';

final teacherExercisesCatalogProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(apiClientProvider).getExercises(limit: 200, offset: 0);
});

class TeacherExercisesScreen extends ConsumerWidget {
  const TeacherExercisesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _TeacherExercisesView();
  }
}

class _TeacherExercisesView extends ConsumerStatefulWidget {
  const _TeacherExercisesView();

  @override
  ConsumerState<_TeacherExercisesView> createState() =>
      _TeacherExercisesViewState();
}

class _TeacherExercisesViewState extends ConsumerState<_TeacherExercisesView> {
  bool _studentStyleView = false;

  Widget _exerciseCard(BuildContext context, Map<String, dynamic> exercise) {
    final theme = Theme.of(context);
    final name = exercise['name']?.toString() ?? '';
    final description =
        (exercise['description']?.toString() ?? '').trim().isEmpty
            ? 'Sin descripción'
            : exercise['description']!.toString();
    final category = exercise['category']?.toString() ?? '-';
    final difficulty = exercise['difficulty']?.toString() ?? '-';
    final thumb = exercise['thumbnail_url']?.toString() ?? '';
    final gif = exercise['gif_url']?.toString() ?? '';
    final video = exercise['video_url']?.toString() ?? '';
    final previewUrl = thumb.isNotEmpty
        ? thumb
        : (gif.isNotEmpty ? gif : (video.isNotEmpty ? video : ''));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: previewUrl.isEmpty
                    ? Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported_outlined),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            previewUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                          if (video.isNotEmpty)
                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${exerciseCategoryLabel(category)} · ${exerciseDifficultyLabel(difficulty)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _studentStyleCard(BuildContext context, Map<String, dynamic> exercise) {
    final theme = Theme.of(context);
    final name = exercise['name']?.toString() ?? '';
    final description =
        (exercise['description']?.toString() ?? '').trim().isEmpty
            ? 'Sin descripción'
            : exercise['description']!.toString();
    final category = exercise['category']?.toString() ?? '-';
    final difficulty = exercise['difficulty']?.toString() ?? '-';
    final muscles = ((exercise['muscle_groups'] as List?) ?? const [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .join(', ');
    final reps = exercise['reps']?.toString() ?? '-';
    final sets = exercise['sets']?.toString() ?? '-';
    final rest = exercise['rest_seconds']?.toString() ?? '-';
    final duration = exercise['duration_seconds']?.toString() ?? '-';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _Tag(text: 'Categoría: ${exerciseCategoryLabel(category)}'),
                _Tag(text: 'Dificultad: ${exerciseDifficultyLabel(difficulty)}'),
                _Tag(text: 'Series: $sets'),
                _Tag(text: 'Reps: $reps'),
                _Tag(text: 'Descanso: $rest s'),
                _Tag(text: 'Duración: $duration s'),
                _Tag(text: 'Músculos: ${muscles.isEmpty ? "-" : muscles}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncItems = ref.watch(teacherExercisesCatalogProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ejercicios (solo lectura)'),
        actions: [
          IconButton(
            tooltip: _studentStyleView ? 'Vista rápida (4 columnas)' : 'Vista alumno',
            onPressed: () => setState(() => _studentStyleView = !_studentStyleView),
            icon: Icon(
              _studentStyleView
                  ? Icons.grid_view_rounded
                  : Icons.view_agenda_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => ref.refresh(teacherExercisesCatalogProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: asyncItems.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No se pudieron cargar ejercicios: $e'),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No hay ejercicios disponibles.'));
          }
          if (_studentStyleView) {
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _studentStyleCard(context, items[index]),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) => _exerciseCard(context, items[index]),
          );
        },
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:calistenia_app/features/exercises/domain/models/exercise.dart';
import 'package:calistenia_app/features/exercises/presentation/widgets/exercise_video_player.dart';

/// Preview visual del ejercicio: prioriza vídeo en autoplay mute+loop;
/// si no hay vídeo, usa GIF/thumbnail.
class ExerciseMediaPreview extends StatelessWidget {
  const ExerciseMediaPreview({
    super.key,
    required this.exercise,
    this.aspectRatio = 1.02,
    this.heroTag,
    this.fit = BoxFit.cover,
  });

  final Exercise exercise;
  final double aspectRatio;
  final String? heroTag;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final video = exercise.videoUrl?.trim() ?? '';
    final image = exercise.imageUrl;

    Widget child;
    if (video.isNotEmpty) {
      child = ExerciseVideoPlayer(
        videoUrl: video,
        aspectRatio: aspectRatio,
        autoplayLoopMuted: true,
        fit: fit,
      );
    } else if (image.isNotEmpty) {
      child = CachedNetworkImage(
        imageUrl: image,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
        errorWidget: (_, __, ___) => _placeholder(theme),
      );
    } else {
      child = _placeholder(theme);
    }

    if (heroTag != null && heroTag!.isNotEmpty) {
      child = Hero(tag: heroTag!, child: child);
    }

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: child,
      ),
    );
  }

  Widget _placeholder(ThemeData theme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.surface,
          ],
        ),
      ),
      child: Icon(
        Icons.fitness_center,
        size: 48,
        color: theme.colorScheme.outline,
      ),
    );
  }
}

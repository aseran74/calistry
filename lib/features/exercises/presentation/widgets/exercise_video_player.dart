import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

/// Reproductor de video para la URL de un ejercicio.
/// Usa [video_player] + [Chewie] y hace dispose al salir.
///
/// Con [autoplayLoopMuted] = true actúa como preview (sin controles, mute, loop).
class ExerciseVideoPlayer extends StatefulWidget {
  const ExerciseVideoPlayer({
    super.key,
    required this.videoUrl,
    this.aspectRatio = 16 / 9,
    this.autoplayLoopMuted = false,
    this.fit = BoxFit.contain,
  });

  final String videoUrl;
  final double aspectRatio;

  /// Preview tipo GIF: autoplay, loop, mute, sin controles.
  final bool autoplayLoopMuted;
  final BoxFit fit;

  @override
  State<ExerciseVideoPlayer> createState() => _ExerciseVideoPlayerState();
}

class _ExerciseVideoPlayerState extends State<ExerciseVideoPlayer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _error = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant ExerciseVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.autoplayLoopMuted != widget.autoplayLoopMuted) {
      _disposePlayers();
      _error = false;
      _errorMessage = null;
      _init();
    }
  }

  Future<void> _init() async {
    if (widget.videoUrl.trim().isEmpty) {
      return;
    }
    final uri = Uri.tryParse(widget.videoUrl.trim());
    if (uri == null || !uri.hasScheme) {
      if (mounted) {
        setState(() {
          _error = true;
          _errorMessage = 'URL de video no válida';
        });
      }
      return;
    }
    try {
      final controller = VideoPlayerController.networkUrl(uri);
      await controller.initialize();
      await controller.setLooping(widget.autoplayLoopMuted);
      await controller.setVolume(widget.autoplayLoopMuted ? 0 : 1);
      if (!mounted) {
        controller.dispose();
        return;
      }
      _videoController = controller;

      if (widget.autoplayLoopMuted) {
        await controller.play();
        if (mounted) setState(() {});
        return;
      }

      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: false,
        looping: false,
        showControls: true,
      );
      setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _disposePlayers() {
    _chewieController?.dispose();
    _chewieController = null;
    _videoController?.dispose();
    _videoController = null;
  }

  @override
  void dispose() {
    _disposePlayers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _errorMessage ?? 'No se pudo cargar el video',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (widget.autoplayLoopMuted) {
      final controller = _videoController;
      if (controller == null || !controller.value.isInitialized) {
        return AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(child: CircularProgressIndicator()),
          ),
        );
      }
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: FittedBox(
          fit: widget.fit,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
      );
    }

    if (_chewieController == null) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Chewie(controller: _chewieController!),
    );
  }
}

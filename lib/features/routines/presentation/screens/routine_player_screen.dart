import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calistenia_app/features/routines/presentation/providers/routines_provider.dart';
import 'package:calistenia_app/features/routines/domain/models/routine_exercise_item.dart';
import 'package:calistenia_app/features/exercises/presentation/widgets/exercise_video_player.dart';

class RoutinePlayerScreen extends ConsumerStatefulWidget {
  const RoutinePlayerScreen({super.key, required this.routineId});
  final String routineId;

  @override
  ConsumerState<RoutinePlayerScreen> createState() => _RoutinePlayerScreenState();
}

class _RoutinePlayerScreenState extends ConsumerState<RoutinePlayerScreen> {
  int _currentIndex = 0;
  bool _isResting = false;
  int _restSecondsLeft = 0;
  Timer? _timer;
  Timer? _mediaOverlayTimer;
  bool _showMediaPrescription = false;
  String? _lastOverlayItemId;

  @override
  void dispose() {
    _timer?.cancel();
    _mediaOverlayTimer?.cancel();
    super.dispose();
  }

  void _showMediaPrescriptionFor(RoutineExerciseItem item) {
    _mediaOverlayTimer?.cancel();
    setState(() {
      _showMediaPrescription = true;
      _lastOverlayItemId = item.id;
    });
    _mediaOverlayTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _showMediaPrescription = false);
    });
  }

  void _startRest(int seconds) {
    setState(() {
      _isResting = true;
      _restSecondsLeft = seconds;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSecondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _isResting = false;
          _currentIndex++;
        });
      } else {
        setState(() => _restSecondsLeft--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(routineDetailProvider(widget.routineId));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface, // Dinámico
      appBar: AppBar(
        title: const Text('Entrenando'),
        elevation: 0,
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data == null || data.exercises.isEmpty) return const Center(child: Text('Sin ejercicios'));
          final exercises = data.exercises;
          if (_currentIndex >= exercises.length) return _buildSummary(data.routine.name, theme);
          if (_isResting) return _buildRestView(theme);

          final item = exercises[_currentIndex];
          final exercise = item.exercise;
          if (_lastOverlayItemId != item.id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _showMediaPrescriptionFor(item);
            });
          }

          return Column(
            children: [
              LinearProgressIndicator(
                value: (_currentIndex + 1) / exercises.length,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 20),
              Text('EJERCICIO ${_currentIndex + 1} DE ${exercises.length}',
                  style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),

              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(
                          child: (exercise?.videoUrl != null &&
                                  exercise!.videoUrl!.isNotEmpty)
                              ? ExerciseVideoPlayer(
                                  videoUrl: exercise.videoUrl!,
                                  aspectRatio: 16 / 9,
                                )
                              : (exercise?.gifUrl != null &&
                                      exercise!.gifUrl!.isNotEmpty)
                                  ? Image.network(
                                      exercise.gifUrl!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.fitness_center,
                                        size: 80,
                                        color: theme.colorScheme.primary,
                                      ),
                                    )
                                  : Icon(
                                      Icons.fitness_center,
                                      size: 80,
                                      color: theme.colorScheme.primary,
                                    ),
                        ),
                        if (_showMediaPrescription)
                          Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              margin: const EdgeInsets.only(top: 16),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${item.sets ?? 1} x ${item.reps ?? '--'}',
                                style:
                                    theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              Text(exercise?.name ?? 'Ejercicio', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('${item.sets ?? 1} Series x ${item.reps ?? '--'} Reps',
                  style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.secondary)),

              Padding(
                padding: const EdgeInsets.all(30),
                child: Row(
                  children: [
                    IconButton.outlined(
                      onPressed: _currentIndex > 0 ? () => setState(() => _currentIndex--) : null,
                      icon: const Icon(Icons.arrow_back_ios_new),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: () {
                          final rest = item.restSeconds ?? 30;
                          if (rest > 0 && _currentIndex < exercises.length - 1) {
                            _startRest(rest);
                          } else {
                            setState(() => _currentIndex++);
                          }
                        },
                        child: Text(_currentIndex < exercises.length - 1 ? 'LISTO' : 'FINALIZAR'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRestView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('DESCANSO', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 30),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(width: 180, height: 180, child: CircularProgressIndicator(value: _restSecondsLeft / 30, strokeWidth: 8)),
              Text('${_restSecondsLeft}s', style: theme.textTheme.displayMedium),
            ],
          ),
          const SizedBox(height: 40),
          TextButton(onPressed: () => setState(() { _isResting = false; _currentIndex++; }),
              child: const Text('SALTAR DESCANSO')),
        ],
      ),
    );
  }

  Widget _buildSummary(String name, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events, size: 100, color: theme.colorScheme.primary),
          const SizedBox(height: 20),
          Text('¡COMPLETADO!', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(name),
          const SizedBox(height: 40),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('SALIR')),
        ],
      ),
    );
  }
}
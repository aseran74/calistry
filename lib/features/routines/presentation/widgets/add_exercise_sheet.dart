import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:calistenia_app/features/exercises/domain/models/exercise.dart';
import 'package:calistenia_app/features/routines/domain/models/routine_exercise_item.dart';

class AddExerciseSheet extends StatelessWidget {
  const AddExerciseSheet({
    super.key,
    required this.exercises,
    required this.onSelect,
  });

  final List<Map<String, dynamic>> exercises;
  final void Function(RoutineExerciseItem item) onSelect;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Agregar ejercicio',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: exercises.length,
                itemBuilder: (context, index) {
                  final ex = exercises[index];
                  final exercise = Exercise.fromJson(ex);
                  return ListTile(
                    leading: exercise.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: exercise.imageUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          )
                        : const Icon(Icons.fitness_center),
                    title: Text(exercise.name),
                    onTap: () {
                      final item = RoutineExerciseItem(
                        id: '',
                        routineId: '',
                        exerciseId: exercise.id,
                        orderIndex: 0,
                        sets: 3,
                        reps: 10,
                        restSeconds: 60,
                        exercise: exercise,
                      );
                      onSelect(item);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

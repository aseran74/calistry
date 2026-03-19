import 'package:calistenia_app/features/exercises/domain/models/exercise.dart';

/// Item de ejercicio dentro de una rutina (con sets, reps, descanso).
class RoutineExerciseItem {
  final String id;
  final String routineId;
  final String exerciseId;
  final int orderIndex;
  final int? sets;
  final int? reps;
  final int? restSeconds;
  final Exercise? exercise;

  const RoutineExerciseItem({
    required this.id,
    required this.routineId,
    required this.exerciseId,
    required this.orderIndex,
    this.sets,
    this.reps,
    this.restSeconds,
    this.exercise,
  });

  factory RoutineExerciseItem.fromJson(Map<String, dynamic> json) {
    Exercise? ex;
    final exData = json['exercises'];
    if (exData is Map<String, dynamic>) {
      ex = Exercise.fromJson(exData);
    }
    return RoutineExerciseItem(
      id: json['id'] as String,
      routineId: json['routine_id'] as String,
      exerciseId: json['exercise_id'] as String,
      orderIndex: json['order_index'] as int? ?? 0,
      sets: json['sets'] as int?,
      reps: json['reps'] as int?,
      restSeconds: json['rest_seconds'] as int?,
      exercise: ex,
    );
  }

  Map<String, dynamic> toCreateJson() => {
        'exercise_id': exerciseId,
        'order_index': orderIndex,
        'sets': sets,
        'reps': reps,
        'rest_seconds': restSeconds,
      };

  RoutineExerciseItem copyWith({
    String? id,
    String? routineId,
    String? exerciseId,
    int? orderIndex,
    int? sets,
    int? reps,
    int? restSeconds,
    Exercise? exercise,
  }) {
    return RoutineExerciseItem(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      exerciseId: exerciseId ?? this.exerciseId,
      orderIndex: orderIndex ?? this.orderIndex,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      restSeconds: restSeconds ?? this.restSeconds,
      exercise: exercise ?? this.exercise,
    );
  }
}

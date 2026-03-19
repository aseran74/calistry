import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/exercises/domain/models/exercise.dart';
import 'package:calistenia_app/features/routines/domain/models/routine_exercise_item.dart';
import 'package:calistenia_app/features/routines/presentation/widgets/add_exercise_sheet.dart';

/// Items para crear rutina: exerciseId + orderIndex + sets + reps + restSeconds.
/// Puede tener exercise cargado para mostrar nombre/thumbnail.
class CreateRoutineState {
  final String name;
  final String description;
  final String level;
  final bool isPublic;
  final List<RoutineExerciseItem> items;

  const CreateRoutineState({
    this.name = '',
    this.description = '',
    this.level = 'principiante',
    this.isPublic = false,
    this.items = const [],
  });

  int get estimatedSeconds {
    int total = 0;
    for (final item in items) {
      final duration = item.exercise?.durationSeconds ?? 45;
      final sets = item.sets ?? 3;
      total += duration * sets;
      total += (item.restSeconds ?? 60) * (sets - 1);
    }
    return total;
  }

  CreateRoutineState copyWith({
    String? name,
    String? description,
    String? level,
    bool? isPublic,
    List<RoutineExerciseItem>? items,
  }) {
    return CreateRoutineState(
      name: name ?? this.name,
      description: description ?? this.description,
      level: level ?? this.level,
      isPublic: isPublic ?? this.isPublic,
      items: items ?? this.items,
    );
  }
}

class CreateRoutineNotifier extends StateNotifier<CreateRoutineState> {
  CreateRoutineNotifier() : super(const CreateRoutineState());

  void setName(String v) => state = state.copyWith(name: v);
  void setDescription(String v) => state = state.copyWith(description: v);
  void setLevel(String v) => state = state.copyWith(level: v);
  void setPublic(bool v) => state = state.copyWith(isPublic: v);

  void addItem(RoutineExerciseItem item) {
    final items = List<RoutineExerciseItem>.from(state.items)
      ..add(item.copyWith(orderIndex: state.items.length));
    state = state.copyWith(items: items);
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final items = List<RoutineExerciseItem>.from(state.items);
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);
    for (var i = 0; i < items.length; i++) {
      items[i] = items[i].copyWith(orderIndex: i);
    }
    state = state.copyWith(items: items);
  }

  void updateItem(int index, {int? sets, int? reps, int? restSeconds}) {
    final items = List<RoutineExerciseItem>.from(state.items);
    items[index] = items[index].copyWith(sets: sets, reps: reps, restSeconds: restSeconds);
    state = state.copyWith(items: items);
  }

  void removeItem(int index) {
    final items = List<RoutineExerciseItem>.from(state.items)..removeAt(index);
    for (var i = 0; i < items.length; i++) {
      items[i] = items[i].copyWith(orderIndex: i);
    }
    state = state.copyWith(items: items);
  }

  void clear() => state = const CreateRoutineState();
}

final createRoutineProvider =
    StateNotifierProvider<CreateRoutineNotifier, CreateRoutineState>((ref) {
  return CreateRoutineNotifier();
});

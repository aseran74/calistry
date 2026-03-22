import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:calistenia_app/features/routines/domain/models/routine_exercise_item.dart';

/// Estado del formulario "Nueva rutina" (solo borrador local hasta guardar en API).
class CreateRoutineDraft {
  const CreateRoutineDraft({
    this.name = '',
    this.description = '',
    this.level = 'principiante',
    this.isPublic = false,
    this.items = const [],
  });

  final String name;
  final String description;
  final String level;
  final bool isPublic;
  final List<RoutineExerciseItem> items;

  int get estimatedSeconds {
    var total = 0;
    for (final item in items) {
      final duration = item.exercise?.durationSeconds ?? 45;
      final sets = item.sets ?? 3;
      total += duration * sets;
      total += (item.restSeconds ?? 60) * (sets - 1);
    }
    return total;
  }

  bool get canSubmit => name.trim().isNotEmpty && items.isNotEmpty;

  CreateRoutineDraft copyWith({
    String? name,
    String? description,
    String? level,
    bool? isPublic,
    List<RoutineExerciseItem>? items,
  }) {
    return CreateRoutineDraft(
      name: name ?? this.name,
      description: description ?? this.description,
      level: level ?? this.level,
      isPublic: isPublic ?? this.isPublic,
      items: items ?? this.items,
    );
  }
}

/// Lógica del borrador; sin dependencias de UI.
class CreateRoutineNotifier extends Notifier<CreateRoutineDraft> {
  static const _uuid = Uuid();

  @override
  CreateRoutineDraft build() => const CreateRoutineDraft();

  void reset() => state = const CreateRoutineDraft();

  void setName(String v) => state = state.copyWith(name: v);
  void setDescription(String v) => state = state.copyWith(description: v);
  void setLevel(String v) => state = state.copyWith(level: v);
  void setPublic(bool v) => state = state.copyWith(isPublic: v);

  /// Añade ejercicio desde el sheet (asigna id estable único para claves de lista).
  void addExercise(RoutineExerciseItem fromPicker) {
    final id = _uuid.v4();
    final next = List<RoutineExerciseItem>.from(state.items)
      ..add(
        fromPicker.copyWith(
          id: id,
          routineId: '',
          orderIndex: state.items.length,
        ),
      );
    state = state.copyWith(items: next);
  }

  void removeAt(int index) {
    if (index < 0 || index >= state.items.length) return;
    final next = List<RoutineExerciseItem>.from(state.items)..removeAt(index);
    state = state.copyWith(items: _withOrderIndex(next));
  }

  void moveUp(int index) {
    if (index <= 0 || index >= state.items.length) return;
    final next = List<RoutineExerciseItem>.from(state.items);
    final t = next[index - 1];
    next[index - 1] = next[index];
    next[index] = t;
    state = state.copyWith(items: _withOrderIndex(next));
  }

  void moveDown(int index) {
    if (index < 0 || index >= state.items.length - 1) return;
    final next = List<RoutineExerciseItem>.from(state.items);
    final t = next[index + 1];
    next[index + 1] = next[index];
    next[index] = t;
    state = state.copyWith(items: _withOrderIndex(next));
  }

  void updateItem(
    int index, {
    int? sets,
    int? reps,
    int? restSeconds,
  }) {
    if (index < 0 || index >= state.items.length) return;
    final next = List<RoutineExerciseItem>.from(state.items);
    next[index] = next[index].copyWith(
      sets: sets,
      reps: reps,
      restSeconds: restSeconds,
    );
    state = state.copyWith(items: next);
  }

  List<RoutineExerciseItem> _withOrderIndex(List<RoutineExerciseItem> list) {
    return [
      for (var i = 0; i < list.length; i++) list[i].copyWith(orderIndex: i),
    ];
  }
}

final createRoutineProvider =
    NotifierProvider<CreateRoutineNotifier, CreateRoutineDraft>(
  CreateRoutineNotifier.new,
);

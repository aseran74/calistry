import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/routines/domain/models/routine_exercise_item.dart';
import 'package:calistenia_app/features/routines/presentation/providers/create_routine_provider.dart';
import 'package:calistenia_app/features/routines/presentation/providers/routines_provider.dart';
import 'package:calistenia_app/features/routines/presentation/widgets/add_exercise_sheet.dart';

class CreateRoutineScreen extends ConsumerStatefulWidget {
  const CreateRoutineScreen({super.key});

  @override
  ConsumerState<CreateRoutineScreen> createState() => _CreateRoutineScreenState();
}

class _CreateRoutineScreenState extends ConsumerState<CreateRoutineScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(createRoutineProvider.notifier).clear();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createRoutineProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva rutina'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
              onChanged: ref.read(createRoutineProvider.notifier).setName,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: ref.read(createRoutineProvider.notifier).setDescription,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: state.level,
              decoration: const InputDecoration(
                labelText: 'Nivel',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'principiante', child: Text('Principiante')),
                DropdownMenuItem(value: 'intermedio', child: Text('Intermedio')),
                DropdownMenuItem(value: 'avanzado', child: Text('Avanzado')),
              ],
              onChanged: (v) {
                if (v != null) ref.read(createRoutineProvider.notifier).setLevel(v);
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Rutina pública'),
              value: state.isPublic,
              onChanged: ref.read(createRoutineProvider.notifier).setPublic,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ejercicios', style: theme.textTheme.titleMedium),
                Text(
                  'Duración aprox: ${_formatDuration(state.estimatedSeconds)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (state.items.isEmpty)
              OutlinedButton.icon(
                onPressed: () => _openAddExercise(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Buscar y agregar ejercicios'),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.items.length,
                onReorder: (oldIndex, newIndex) {
                  ref.read(createRoutineProvider.notifier).reorder(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final item = state.items[index];
                  return _OrderableRoutineItem(
                    key: ValueKey(item.exerciseId + '$index'),
                    item: item,
                    index: index,
                    onUpdate: (s, r, rest) {
                      ref.read(createRoutineProvider.notifier).updateItem(
                            index,
                            sets: s,
                            reps: r,
                            restSeconds: rest,
                          );
                    },
                    onRemove: () =>
                        ref.read(createRoutineProvider.notifier).removeItem(index),
                  );
                },
              ),
            if (state.items.isNotEmpty) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _openAddExercise(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Agregar más ejercicios'),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: state.name.trim().isEmpty || state.items.isEmpty
                  ? null
                  : () => _saveRoutine(context, ref),
              child: const Text('Crear rutina'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (s == 0) return '${m}min';
    return '${m}min ${s}s';
  }

  Future<void> _openAddExercise(BuildContext context, WidgetRef ref) async {
    final client = ref.read(apiClientProvider);
    final list = await client.getExercises(limit: 50);
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddExerciseSheet(
        exercises: list,
        onSelect: (item) {
          ref.read(createRoutineProvider.notifier).addItem(item);
        },
      ),
    );
  }

  Future<void> _saveRoutine(BuildContext context, WidgetRef ref) async {
    final state = ref.read(createRoutineProvider);
    final client = ref.read(apiClientProvider);
    final exercises = state.items
        .map((e) => e.toCreateJson())
        .toList();
    try {
      final result = await client.createRoutine(
        name: state.name.trim(),
        description: state.description.trim().isEmpty ? null : state.description.trim(),
        level: state.level,
        isPublic: state.isPublic,
        exercises: exercises,
      );
      if (!context.mounted) return;
      if (result != null) {
        ref.read(createRoutineProvider.notifier).clear();
        ref.invalidate(routinesListProvider('mine'));
        ref.invalidate(routinesListProvider('explore'));
        if (!context.mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rutina creada')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al crear la rutina')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

class _OrderableRoutineItem extends StatelessWidget {
  const _OrderableRoutineItem({
    super.key,
    required this.item,
    required this.index,
    required this.onUpdate,
    required this.onRemove,
  });

  final RoutineExerciseItem item;
  final int index;
  final void Function(int? sets, int? reps, int? restSeconds) onUpdate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = item.exercise?.name ?? 'Ejercicio';
    final thumbnail = item.exercise?.imageUrl ?? '';

    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: thumbnail.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: thumbnail,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                )
              : const Icon(Icons.drag_handle),
        ),
        title: Text(name),
        subtitle: Row(
          children: [
            SizedBox(
              width: 48,
              child: TextFormField(
                initialValue: '${item.sets ?? 0}',
                decoration: const InputDecoration(labelText: 'Sets'),
                keyboardType: TextInputType.number,
                onChanged: (v) => onUpdate(int.tryParse(v), item.reps, item.restSeconds),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              child: TextFormField(
                initialValue: '${item.reps ?? 0}',
                decoration: const InputDecoration(labelText: 'Reps'),
                keyboardType: TextInputType.number,
                onChanged: (v) => onUpdate(item.sets, int.tryParse(v), item.restSeconds),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 56,
              child: TextFormField(
                initialValue: '${item.restSeconds ?? 0}',
                decoration: const InputDecoration(labelText: 'Desc'),
                keyboardType: TextInputType.number,
                onChanged: (v) => onUpdate(item.sets, item.reps, int.tryParse(v)),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onRemove,
        ),
      ),
    );
  }
}

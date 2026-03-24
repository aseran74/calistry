import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/routines/domain/models/routine_exercise_item.dart';
import 'package:calistenia_app/features/routines/presentation/providers/create_routine_provider.dart';
import 'package:calistenia_app/features/routines/presentation/providers/routines_provider.dart';
import 'package:calistenia_app/features/routines/presentation/widgets/add_exercise_sheet.dart';

/// Pantalla nueva: una sola [ListView] (sin ReorderableList ni shrinkWrap).
class CreateRoutineScreen extends ConsumerStatefulWidget {
  const CreateRoutineScreen({super.key});

  @override
  ConsumerState<CreateRoutineScreen> createState() =>
      _CreateRoutineScreenState();
}

class _CreateRoutineScreenState extends ConsumerState<CreateRoutineScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(createRoutineProvider.notifier).reset();
      _name.clear();
      _desc.clear();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(createRoutineProvider);
    final notifier = ref.read(createRoutineProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva rutina')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: notifier.setName,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _desc,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  onChanged: notifier.setDescription,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: draft.level,
                  decoration: const InputDecoration(
                    labelText: 'Nivel',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'principiante',
                      child: Text('Principiante'),
                    ),
                    DropdownMenuItem(
                      value: 'intermedio',
                      child: Text('Intermedio'),
                    ),
                    DropdownMenuItem(
                      value: 'avanzado',
                      child: Text('Avanzado'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) notifier.setLevel(v);
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Rutina pública'),
                  value: draft.isPublic,
                  onChanged: notifier.setPublic,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Ejercicios', style: theme.textTheme.titleMedium),
                    Text(
                      'Duración aprox: ${_formatDuration(draft.estimatedSeconds)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _openPicker(context),
                  icon: const Icon(Icons.add),
                  label: Text(
                    draft.items.isEmpty
                        ? 'Buscar y agregar ejercicios'
                        : 'Agregar más ejercicios',
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(draft.items.length, (index) {
                  final item = draft.items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DraftExerciseCard(
                      key: ValueKey(item.id),
                      item: item,
                      index: index,
                      lastIndex: draft.items.length - 1,
                      onMoveUp: () => notifier.moveUp(index),
                      onMoveDown: () => notifier.moveDown(index),
                      onRemove: () => notifier.removeAt(index),
                      onUpdate: (s, r, rest) =>
                          notifier.updateItem(index, sets: s, reps: r, restSeconds: rest),
                    ),
                  );
                }),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                onPressed: draft.canSubmit
                    ? () => _submit(context, draft)
                    : null,
                child: const Text('Crear rutina'),
              ),
            ),
          ),
        ],
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

  Future<void> _openPicker(BuildContext context) async {
    final client = ref.read(apiClientProvider);
    final list = await client.getExercises(limit: 50);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => AddExerciseSheet(
        exercises: list,
        onSelect: (item) {
          ref.read(createRoutineProvider.notifier).addExercise(item);
        },
      ),
    );
  }

  Future<void> _submit(BuildContext context, CreateRoutineDraft draft) async {
    final client = ref.read(apiClientProvider);
    final exercises =
        draft.items.map((e) => e.toCreateJson()).toList();
    try {
      final result = await client.createRoutine(
        name: draft.name.trim(),
        description:
            draft.description.trim().isEmpty ? null : draft.description.trim(),
        level: draft.level,
        isPublic: draft.isPublic,
        exercises: exercises,
      );
      if (!context.mounted) return;
      if (result != null) {
        ref.read(createRoutineProvider.notifier).reset();
        _name.clear();
        _desc.clear();
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

class _DraftExerciseCard extends StatefulWidget {
  const _DraftExerciseCard({
    super.key,
    required this.item,
    required this.index,
    required this.lastIndex,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
    required this.onUpdate,
  });

  final RoutineExerciseItem item;
  final int index;
  final int lastIndex;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;
  final void Function(int? sets, int? reps, int? restSeconds) onUpdate;

  @override
  State<_DraftExerciseCard> createState() => _DraftExerciseCardState();
}

class _DraftExerciseCardState extends State<_DraftExerciseCard> {
  Timer? _overlayTimer;
  bool _showPrescriptionOverlay = false;

  @override
  void dispose() {
    _overlayTimer?.cancel();
    super.dispose();
  }

  void _showOverlayForTwoSeconds() {
    _overlayTimer?.cancel();
    setState(() => _showPrescriptionOverlay = true);
    _overlayTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _showPrescriptionOverlay = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final name = item.exercise?.name ?? 'Ejercicio';
    final thumb = item.exercise?.imageUrl ?? '';
    final prescription =
        '${item.sets ?? 0} x ${item.reps ?? 0}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Subir',
                      onPressed: widget.index > 0 ? widget.onMoveUp : null,
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: 'Bajar',
                      onPressed: widget.index < widget.lastIndex
                          ? widget.onMoveDown
                          : null,
                      icon: const Icon(Icons.arrow_downward),
                    ),
                  ],
                ),
                if (thumb.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CachedNetworkImage(
                          imageUrl: thumb,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                        if (_showPrescriptionOverlay)
                          Container(
                            width: 56,
                            height: 56,
                            color: Colors.black.withValues(alpha: 0.55),
                            alignment: Alignment.center,
                            child: Text(
                              prescription,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  const SizedBox(
                    width: 56,
                    height: 56,
                    child: Icon(Icons.fitness_center),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar',
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('${item.id}_sets'),
                    initialValue: '${item.sets ?? 0}',
                    decoration: const InputDecoration(
                      labelText: 'Sets',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      widget.onUpdate(
                        int.tryParse(v),
                        item.reps,
                        item.restSeconds,
                      );
                      _showOverlayForTwoSeconds();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('${item.id}_reps'),
                    initialValue: '${item.reps ?? 0}',
                    decoration: const InputDecoration(
                      labelText: 'Reps',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      widget.onUpdate(
                        item.sets,
                        int.tryParse(v),
                        item.restSeconds,
                      );
                      _showOverlayForTwoSeconds();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('${item.id}_rest'),
                    initialValue: '${item.restSeconds ?? 0}',
                    decoration: const InputDecoration(
                      labelText: 'Desc (s)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => widget.onUpdate(
                      item.sets,
                      item.reps,
                      int.tryParse(v),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:calistenia_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:calistenia_app/features/routines/presentation/providers/routines_provider.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/progress/presentation/providers/progress_provider.dart';
import 'package:calistenia_app/features/planning/presentation/providers/planning_provider.dart';
import 'package:calistenia_app/features/routines/presentation/widgets/routine_card.dart';
import 'package:calistenia_app/features/routines/domain/models/routine.dart';

class RoutinesScreen extends ConsumerStatefulWidget {
  const RoutinesScreen({super.key});

  @override
  ConsumerState<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends ConsumerState<RoutinesScreen> {
  bool _didAutoSelectTab = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final tab = ref.watch(routinesTabProvider);
    final routinesAsync = ref.watch(routinesListProvider(tab));
    final assignedAsync = ref.watch(assignedRoutinesProvider);

    // En usuario normal, por defecto mostramos "Asignadas" para que vea
    // primero lo que le manda el profesor. En profesor dejamos "Mis Rutinas".
    if (!_didAutoSelectTab && !auth.isTeacher && tab == 'mine') {
      _didAutoSelectTab = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(routinesTabProvider.notifier).state = 'assigned';
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutinas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Selector de pestañas manual (más estable)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                _buildTabButton(
                  value: 'mine',
                  label: 'Mis Rutinas',
                  isSelected: tab == 'mine',
                  theme: theme,
                  onTap: () {
                    ref.read(routinesTabProvider.notifier).state = 'mine';
                    ref.invalidate(routinesListProvider);
                  },
                ),
                const SizedBox(width: 12),
                _buildTabButton(
                  value: 'assigned',
                  label: 'Asignadas',
                  isSelected: tab == 'assigned',
                  theme: theme,
                  onTap: () {
                    ref.read(routinesTabProvider.notifier).state = 'assigned';
                    ref.invalidate(assignedRoutinesProvider);
                  },
                ),
                const SizedBox(width: 12),
                _buildTabButton(
                  value: 'explore',
                  label: 'Explorar',
                  isSelected: tab == 'explore',
                  theme: theme,
                  onTap: () {
                    ref.read(routinesTabProvider.notifier).state = 'explore';
                    ref.invalidate(routinesListProvider);
                  },
                ),
              ],
            ),
          ),

          // Lista de rutinas
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                if (tab == 'assigned') {
                  ref.invalidate(assignedRoutinesProvider);
                } else {
                  ref.invalidate(routinesListProvider);
                }
              },
              child: tab == 'assigned'
                  ? assignedAsync.when(
                      loading: () => ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 120),
                          Center(child: CircularProgressIndicator()),
                        ],
                      ),
                      error: (e, _) => ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          Center(child: Text('Error: $e')),
                        ],
                      ),
                      data: (items) {
                        if (items.isEmpty) {
                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                            children: [
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.assignment_outlined,
                                        size: 34,
                                        color: theme.colorScheme.outline,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'No tienes rutinas asignadas',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Desliza para refrescar. Si un profesor te asigna una rutina, aparecerá aquí.',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        return ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final rawRoutine = item['routine'];
                            final Map<String, dynamic>? routineJson =
                                rawRoutine is Map<String, dynamic>
                                    ? rawRoutine
                                    : (rawRoutine is List && rawRoutine.isNotEmpty)
                                        ? (rawRoutine.first is Map
                                            ? Map<String, dynamic>.from(
                                                rawRoutine.first as Map,
                                              )
                                            : null)
                                        : null;
                            final routineId = (item['routine_id'] ??
                                        item['routineId'] ??
                                        routineJson?['id'])
                                    ?.toString() ??
                                '';
                            final routine = routineJson != null ? Routine.fromJson(routineJson) : null;
                            final rawTeacher = item['teacher_user'];
                            final Map<String, dynamic>? teacher =
                                rawTeacher is Map<String, dynamic>
                                    ? rawTeacher
                                    : (rawTeacher is List && rawTeacher.isNotEmpty)
                                        ? (rawTeacher.first is Map
                                            ? Map<String, dynamic>.from(
                                                rawTeacher.first as Map,
                                              )
                                            : null)
                                        : null;
                            final teacherLabel =
                                teacher?['username']?.toString().isNotEmpty ==
                                        true
                                    ? teacher!['username'].toString()
                                    : teacher?['email']?.toString();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if ((teacherLabel ?? '').isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 6,
                                        bottom: 6,
                                      ),
                                      child: Text(
                                        'Asignada por: $teacherLabel',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: theme.colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  if (routine != null)
                                    RoutineCard(
                                      routine: routine,
                                      exerciseCount: 0,
                                      estimatedSeconds: 0,
                                      firstExerciseImageUrl: null,
                                      onTap: () => context.push(
                                        '/routines/${routine.id}/play',
                                        extra: routine,
                                      ),
                                      onMarkDone: () async {
                                        try {
                                          await ref
                                              .read(apiClientProvider)
                                              .saveProgress(
                                                routineId: routine.id,
                                                durationSeconds: null,
                                                notes: null,
                                              );
                                          ref.invalidate(userProgressListProvider);
                                          ref.invalidate(planningSlotsProvider);
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Rutina marcada como hecha'),
                                            ),
                                          );
                                        } catch (e) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(content: Text('Error: $e')),
                                          );
                                        }
                                      },
                                    )
                                  else
                                    _AssignedRoutineFallbackCard(
                                      routineId: routineId,
                                      teacherLabel: teacherLabel,
                                      debugKeys: item.keys.map((e) => e.toString()).toList(),
                                    ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    )
                  : routinesAsync.when(
              loading: () => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              ),
              error: (e, _) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  Center(child: Text('Error: $e')),
                ],
              ),
              data: (list) {
                final filtered = tab == 'explore'
                    ? list.where((r) => r.isPublic).toList()
                    : list;

                if (filtered.isEmpty) {
                  final title = tab == 'explore'
                      ? 'No hay rutinas públicas'
                      : 'No tienes rutinas todavía';
                  final subtitle = tab == 'explore'
                      ? 'Vuelve más tarde o busca por profesores.'
                      : 'Crea una rutina para empezar a entrenar.';
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.playlist_add_check_rounded,
                                size: 34,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                subtitle,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (tab == 'mine') ...[
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: () => context.push('/routines/create'),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Crear rutina'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final routine = filtered[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RoutineCard(
                        routine: routine,
                        exerciseCount: 0,
                        estimatedSeconds: 0,
                        firstExerciseImageUrl: null,
                        onTap: () => context.push(
                          '/routines/${routine.id}/play',
                          extra: routine,
                        ),
                        onMarkDone: () async {
                          try {
                            await ref.read(apiClientProvider).saveProgress(
                              routineId: routine.id,
                              durationSeconds: null,
                              notes: null,
                            );
                            ref.invalidate(userProgressListProvider);
                            ref.invalidate(planningSlotsProvider);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Rutina marcada como hecha')),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
            ),
          ),
        ],
      ),
      floatingActionButton: tab == 'mine'
          ? FloatingActionButton(
              onPressed: () => context.push('/routines/create'),
              backgroundColor: theme.colorScheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildTabButton({
    required String value,
    required String label,
    required bool isSelected,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    final cs = theme.colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? cs.primary : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? cs.primary : cs.outlineVariant,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? cs.onPrimary : cs.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _AssignedRoutineFallbackCard extends ConsumerWidget {
  const _AssignedRoutineFallbackCard({
    required this.routineId,
    required this.teacherLabel,
    required this.debugKeys,
  });

  final String routineId;
  final String? teacherLabel;
  final List<String> debugKeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (routineId.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.error_outline),
          title: const Text('Rutina asignada'),
          subtitle: Text(
            'No se pudo obtener el id de rutina.\nCampos: ${debugKeys.join(', ')}',
          ),
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: ref.read(apiClientProvider).getRoutineById(routineId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.hourglass_bottom),
              title: Text('Cargando rutina...'),
            ),
          );
        }
        final json = snapshot.data;
        if (json == null) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Rutina no accesible'),
              subtitle: Text('Id: $routineId'),
            ),
          );
        }
        final routine = Routine.fromJson(json);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((teacherLabel ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 6),
                child: Text(
                  'Asignada por: $teacherLabel',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            RoutineCard(
              routine: routine,
              exerciseCount: 0,
              estimatedSeconds: 0,
              firstExerciseImageUrl: null,
              onTap: () => GoRouter.of(context).push(
                '/routines/${routine.id}/play',
                extra: routine,
              ),
            ),
          ],
        );
      },
    );
  }
}

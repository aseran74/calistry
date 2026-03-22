import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:calistenia_app/core/router/student_shell_routes.dart';
import 'package:calistenia_app/core/shell/student_shell_layout.dart';
import 'package:calistenia_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:calistenia_app/features/routines/presentation/providers/routines_provider.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/progress/presentation/providers/progress_provider.dart';
import 'package:calistenia_app/features/planning/presentation/providers/planning_provider.dart';
import 'package:calistenia_app/features/routines/presentation/widgets/routine_card.dart';
import 'package:calistenia_app/features/routines/presentation/widgets/assigned_routine_summary_card.dart';
import 'package:calistenia_app/features/planning/presentation/widgets/plan_routine_dialog.dart';

/// En web, [RefreshIndicator] a veces deja el área de lista sin altura útil.
Widget _maybeRefreshIndicator({
  required bool useIndicator,
  required Future<void> Function() onRefresh,
  required Widget child,
}) {
  if (!useIndicator) return child;
  return RefreshIndicator(onRefresh: onRefresh, child: child);
}

class RoutinesScreen extends ConsumerStatefulWidget {
  const RoutinesScreen({super.key});

  @override
  ConsumerState<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends ConsumerState<RoutinesScreen> {
  /// Evita forzar "mine" al profesor más de una vez por sesión.
  bool _teacherDefaultTabApplied = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);

    if (!auth.isAuthenticated) {
      _teacherDefaultTabApplied = false;
    } else if (auth.isTeacher && !_teacherDefaultTabApplied) {
      _teacherDefaultTabApplied = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ref.read(routinesTabProvider) == 'assigned') {
          ref.read(routinesTabProvider.notifier).state = 'mine';
        }
      });
    }

    final tab = ref.watch(routinesTabProvider);
    // Precargar siempre mine + explore: si solo se observaba tab "assigned",
    // "Mis rutinas" no se cargaba hasta cambiar de pestaña y parecía vacía.
    final mineRoutinesAsync = ref.watch(routinesListProvider('mine'));
    final exploreRoutinesAsync = ref.watch(routinesListProvider('explore'));
    final assignedAsync = ref.watch(assignedRoutinesProvider);
    final routinesAsync =
        tab == 'explore' ? exploreRoutinesAsync : mineRoutinesAsync;

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    ref.invalidate(routinesListProvider('mine'));
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
                    ref.invalidate(routinesListProvider('explore'));
                  },
                ),
              ],
            ),
          ),

          // Lista de rutinas
          Expanded(
            child: _maybeRefreshIndicator(
              useIndicator: !kIsWeb,
              onRefresh: () async {
                if (tab == 'assigned') {
                  ref.invalidate(assignedRoutinesProvider);
                } else if (tab == 'explore') {
                  ref.invalidate(routinesListProvider('explore'));
                } else {
                  ref.invalidate(routinesListProvider('mine'));
                }
              },
              child: tab == 'assigned'
                  ? assignedAsync.when(
                      loading: () => ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                              height: StudentShellLayout.scrollBottomSpacer(
                                  context)),
                          const Center(child: CircularProgressIndicator()),
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
                        // Misma lógica que Home: assignedRoutinesProvider +
                        // AssignedRoutineSummaryCard.parseRoutine / tarjeta única.
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

                        final anyVisible = items.any(
                          (it) =>
                              AssignedRoutineSummaryCard.parseRoutine(it) !=
                              null,
                        );
                        if (!anyVisible) {
                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              16,
                              24,
                              16,
                              StudentShellLayout.bodyBottomPadding(context),
                            ),
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
                                        'Rutina asignada no accesible',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Hay asignaciones pero no se pudieron mostrar. Revisa la conexión o vuelve a entrar.',
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

                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            StudentShellLayout.bodyBottomPadding(context),
                          ),
                          children: [
                            for (final item in items) ...[
                              AssignedRoutineSummaryCard(
                                item: Map<String, dynamic>.from(item),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        );
                      },
                    )
                  : routinesAsync.when(
              loading: () => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                      height:
                          StudentShellLayout.scrollBottomSpacer(context)),
                  const Center(child: CircularProgressIndicator()),
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
                  // ListView + physics: RefreshIndicator y layout web (sidebar).
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      24,
                      16,
                      StudentShellLayout.bodyBottomPadding(context),
                    ),
                    children: [
                      Card(
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
                                  onPressed: () => context.push(
                                    StudentShellRoutes.routineCreate,
                                  ),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Crear rutina'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    StudentShellLayout.bodyBottomPadding(context),
                  ),
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
                          StudentShellRoutes.routinePlay(routine.id),
                          extra: routine,
                        ),
                        onWeeklySchedule: tab == 'mine'
                            ? () => showPlanRoutineDialog(
                                  context,
                                  ref,
                                  presetRoutineId: routine.id,
                                  presetRoutineName: routine.name,
                                  lockRoutineSelection: true,
                                )
                            : null,
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
              onPressed: () =>
                  context.push(StudentShellRoutes.routineCreate),
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

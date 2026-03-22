import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:calistenia_app/core/router/student_shell_routes.dart';
import 'package:calistenia_app/core/shell/student_shell_layout.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:calistenia_app/features/exercises/presentation/widgets/exercise_card.dart';
import 'package:calistenia_app/features/home/presentation/providers/home_provider.dart';
import 'package:calistenia_app/features/planning/presentation/providers/planning_provider.dart';
import 'package:calistenia_app/features/progress/presentation/providers/progress_provider.dart';
import 'package:calistenia_app/features/routines/domain/models/routine.dart';
import 'package:calistenia_app/features/routines/presentation/providers/routines_provider.dart';
import 'package:calistenia_app/features/routines/presentation/widgets/assigned_routine_summary_card.dart';

const _categories = [
  'fuerza',
  'movilidad',
  'cardio',
  'flexibilidad',
];

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static String _saludo() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  static String _labelCategory(String c) {
    switch (c) {
      case 'fuerza':
        return 'Fuerza';
      case 'movilidad':
        return 'Movilidad';
      case 'cardio':
        return 'Cardio';
      case 'flexibilidad':
        return 'Flexibilidad';
      default:
        return c;
    }
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  static String _formatDuration(int seconds) {
    if (seconds <= 0) return '0 min';
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) return '$hours h';
    return '$hours h $remainingMinutes min';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final featuredAsync = ref.watch(featuredExercisesProvider);
    final routinesAsync = ref.watch(routinesListProvider('mine'));
    final assignedRoutinesAsync = ref.watch(assignedRoutinesProvider);
    final progressAsync = ref.watch(userProgressListProvider);
    final statsAsync = ref.watch(userStatsProvider);
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calistry'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notificaciones',
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(featuredExercisesProvider);
          ref.invalidate(routinesListProvider('mine'));
          ref.invalidate(assignedRoutinesProvider);
          ref.invalidate(userProgressListProvider);
          ref.invalidate(userStatsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            StudentShellLayout.bodyBottomPadding(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              progressAsync.when(
                loading: () => _HeroPanel(
                  saludo: _saludo(),
                  totalSemana: 0,
                  totalSesiones: 0,
                  tiempoTotal: '0 min',
                  rachaActual: 0,
                ),
                error: (_, __) => _HeroPanel(
                  saludo: _saludo(),
                  totalSemana: 0,
                  totalSesiones: 0,
                  tiempoTotal: '0 min',
                  rachaActual: 0,
                ),
                data: (progress) {
                  final now = DateTime.now();
                  final weekAgo = now.subtract(const Duration(days: 7));
                  final totalSemana = progress.where((e) {
                    final at = e.completedAt;
                    return at != null && !at.isBefore(weekAgo);
                  }).length;

                  return statsAsync.when(
                    loading: () => _HeroPanel(
                      saludo: _saludo(),
                      totalSemana: totalSemana,
                      totalSesiones: totalSemana,
                      tiempoTotal: '0 min',
                      rachaActual: 0,
                    ),
                    error: (_, __) => _HeroPanel(
                      saludo: _saludo(),
                      totalSemana: totalSemana,
                      totalSesiones: totalSemana,
                      tiempoTotal: '0 min',
                      rachaActual: 0,
                    ),
                    data: (stats) {
                      final totalSesiones =
                          stats['total_sesiones'] as int? ?? 0;
                      final tiempoTotalSegundos =
                          stats['tiempo_total_segundos'] as int? ?? 0;
                      final rachaActual = stats['racha_actual'] as int? ?? 0;
                      return _HeroPanel(
                        saludo: _saludo(),
                        totalSemana: totalSemana,
                        totalSesiones: totalSesiones,
                        tiempoTotal: _formatDuration(tiempoTotalSegundos),
                        rachaActual: rachaActual,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 18),
              _ContinuarEntrenamiento(
                  onTap: () => context.go(StudentShellRoutes.routines)),
              const SizedBox(height: 10),
              _CategoryButton(
                label: 'Planning',
                icon: Icons.calendar_month_outlined,
                onTap: () => context.go(StudentShellRoutes.planning),
              ),
              if (!auth.isTeacher) ...[
                const SizedBox(height: 26),
                const _SectionHeader(
                  title: 'Asignadas por tu profesor',
                  subtitle:
                      'Rutinas privadas que tus profesores han preparado para ti',
                ),
                const SizedBox(height: 10),
                assignedRoutinesAsync.when(
                  loading: () => const _InfoPanel(
                    icon: Icons.assignment_outlined,
                    title: 'Cargando rutinas asignadas',
                    subtitle: 'Buscando sesiones enviadas por tus profesores.',
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (assigned) {
                    if (assigned.isEmpty) {
                      return const _InfoPanel(
                        icon: Icons.assignment_outlined,
                        title: 'Aún no tienes rutinas asignadas',
                        subtitle:
                            'Cuando un profesor te envíe una rutina aparecerá aquí.',
                      );
                    }
                    final anyVisible = assigned.any(
                      (it) => AssignedRoutineSummaryCard.parseRoutine(it) != null,
                    );
                    if (!anyVisible) {
                      return const _InfoPanel(
                        icon: Icons.assignment_outlined,
                        title: 'Rutina asignada no accesible',
                        subtitle:
                            'Hay asignaciones pero no se pudieron cargar las rutinas.',
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final item in assigned) ...[
                          AssignedRoutineSummaryCard(
                            item: Map<String, dynamic>.from(item),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 26),
              const _SectionHeader(
                title: 'Rutina del día',
                subtitle: 'Tu siguiente sesión lista para arrancar',
              ),
              const SizedBox(height: 10),
              routinesAsync.when(
                loading: () => const _RoutineCardPlaceholder(),
                error: (_, __) => const SizedBox.shrink(),
                data: (list) {
                  final rutinaDelDia = list.isNotEmpty ? list.first : null;
                  if (rutinaDelDia == null) {
                    return _EmptyRoutineCard(
                      onTap: () =>
                          context.push(StudentShellRoutes.routineCreate),
                    );
                  }
                  return _RutinaDelDiaCard(
                    routine: rutinaDelDia,
                    onTap: () => context.push(
                      StudentShellRoutes.routinePlay(rutinaDelDia.id),
                      extra: rutinaDelDia,
                    ),
                    onMarkDone: () async {
                      try {
                        await ref.read(apiClientProvider).saveProgress(
                              routineId: rutinaDelDia.id,
                              durationSeconds: null,
                              notes: null,
                            );
                        ref.invalidate(userProgressListProvider);
                        ref.invalidate(planningSlotsProvider);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Rutina marcada como hecha'),
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 26),
              _SectionHeader(
                title: 'Destacados',
                subtitle: 'Movimientos clave para mantener el progreso',
                actionLabel: 'Ver todos',
                onAction: () => context.go(StudentShellRoutes.exercises),
              ),
              const SizedBox(height: 10),
              featuredAsync.when(
                loading: () => const SizedBox(
                  height: 230,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(
                  'Error: $e',
                  style: theme.textTheme.bodySmall,
                ),
                data: (exercises) {
                  if (exercises.isEmpty) {
                    return const _InfoPanel(
                      icon: Icons.fitness_center,
                      title: 'No hay ejercicios destacados',
                      subtitle: 'Cuando cargues más contenido aparecerán aquí.',
                    );
                  }
                  return SizedBox(
                    height: 230,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: exercises.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final ex = exercises[index];
                        return SizedBox(
                          width: 186,
                          child: ExerciseCard(
                            exercise: ex,
                            onTap: () => context.push(
                              StudentShellRoutes.exerciseDetail(ex.id),
                              extra: ex,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 26),
              const _SectionHeader(
                title: 'Progreso semanal',
                subtitle: 'Lo que ya has construido en los últimos días',
              ),
              const SizedBox(height: 10),
              progressAsync.when(
                loading: () => const _ProgressPlaceholder(),
                error: (_, __) => const SizedBox.shrink(),
                data: (list) {
                  final now = DateTime.now();
                  final weekAgo = now.subtract(const Duration(days: 7));
                  final thisWeek = list.where((e) {
                    final at = e.completedAt;
                    return at != null && !at.isBefore(weekAgo);
                  }).length;
                  return statsAsync.when(
                    loading: () => _ProgresoSemanalCard(
                      sesionesSemana: thisWeek,
                      totalSesiones: 0,
                      rachaActual: 0,
                    ),
                    error: (_, __) => _ProgresoSemanalCard(
                      sesionesSemana: thisWeek,
                      totalSesiones: 0,
                      rachaActual: 0,
                    ),
                    data: (stats) {
                      final total = stats['total_sesiones'] as int? ?? 0;
                      final rachaActual = stats['racha_actual'] as int? ?? 0;
                      return _ProgresoSemanalCard(
                        sesionesSemana: thisWeek,
                        totalSesiones: total,
                        rachaActual: rachaActual,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 26),
              const _SectionHeader(
                title: 'Categorías',
                subtitle:
                    'Entra rápido en el tipo de trabajo que te apetece hoy',
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _categories.map((c) {
                  final label = _labelCategory(c);
                  return _CategoryButton(
                    label: label,
                    icon: _categoryIcon(c),
                    onTap: () => context.go(
                          StudentShellRoutes.exercisesWithCategory(c),
                        ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 26),
              const _SectionHeader(
                title: 'Comunidad',
                subtitle:
                    'Descubre profesores, mensajes y clases activas dentro de la app',
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (auth.isTeacher)
                    _CategoryButton(
                      label: 'Panel profesor',
                      icon: Icons.dashboard_customize_outlined,
                      onTap: () => context.push('/teacher'),
                    ),
                  _CategoryButton(
                    label: 'Profesores',
                    icon: Icons.school_outlined,
                    onTap: () => context.push('/teachers'),
                  ),
                  _CategoryButton(
                    label: 'Mensajes',
                    icon: Icons.chat_bubble_outline,
                    onTap: () => context.push('/messages'),
                  ),
                  _CategoryButton(
                    label: 'Directo',
                    icon: Icons.live_tv_outlined,
                    onTap: () => context.push('/live-classes'),
                  ),
                  if (!auth.isTeacher)
                    _CategoryButton(
                      label: 'Ser profesor',
                      icon: Icons.person_add_alt_1,
                      onTap: () => context.push('/teacher-application'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _categoryIcon(String category) {
    switch (category) {
      case 'fuerza':
        return Icons.bolt;
      case 'movilidad':
        return Icons.self_improvement;
      case 'cardio':
        return Icons.monitor_heart_outlined;
      case 'flexibilidad':
        return Icons.accessibility_new;
      default:
        return Icons.category_outlined;
    }
  }
}

class _ContinuarEntrenamiento extends StatelessWidget {
  const _ContinuarEntrenamiento({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.22),
            theme.colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 34,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Continuar entrenamiento',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Abre una rutina, entra en ritmo y sigue empujando tu progreso.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.saludo,
    required this.totalSemana,
    required this.totalSesiones,
    required this.tiempoTotal,
    required this.rachaActual,
  });

  final String saludo;
  final int totalSemana;
  final int totalSesiones;
  final String tiempoTotal;
  final int rachaActual;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.24),
            theme.colorScheme.surface,
            const Color(0xFF101010),
          ],
        ),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              saludo,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Hoy toca construir una versión más fuerte de ti.',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Controla tu ritmo, vuelve a tus rutinas y mantén la consistencia visible cada semana.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MiniStat(label: 'Esta semana', value: '$totalSemana'),
              _MiniStat(label: 'Total sesiones', value: '$totalSesiones'),
              _MiniStat(label: 'Tiempo total', value: tiempoTotal),
              _MiniStat(label: 'Racha actual', value: '$rachaActual días'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 145,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RutinaDelDiaCard extends StatelessWidget {
  const _RutinaDelDiaCard({
    required this.routine,
    required this.onTap,
    this.onMarkDone,
  });

  final Routine routine;
  final VoidCallback onTap;
  final VoidCallback? onMarkDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.22),
                      theme.colorScheme.surfaceContainerHighest,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.playlist_play_rounded,
                  color: theme.colorScheme.primary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routine.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      routine.level.isNotEmpty
                          ? HomeScreen._capitalize(routine.level)
                          : 'Rutina',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        const _Tag(text: 'Rutina sugerida'),
                        _Tag(text: routine.isPublic ? 'Pública' : 'Privada'),
                      ],
                    ),
                  ],
                ),
              ),
              if (onMarkDone != null)
                IconButton(
                  onPressed: onMarkDone,
                  tooltip: 'Marcar como hecha',
                  icon: Icon(
                    Icons.check_circle_outline,
                    color: theme.colorScheme.primary,
                  ),
                ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.play_arrow_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutineCardPlaceholder extends StatelessWidget {
  const _RoutineCardPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 18,
                    width: 180,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 12,
                    width: 96,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRoutineCard extends StatelessWidget {
  const _EmptyRoutineCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child:
                    Icon(Icons.add, color: theme.colorScheme.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Crea tu primera rutina',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Define una sesión y deja preparada tu próxima entrada al entrenamiento.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgresoSemanalCard extends StatelessWidget {
  const _ProgresoSemanalCard({
    required this.sesionesSemana,
    required this.totalSesiones,
    required this.rachaActual,
  });

  final int sesionesSemana;
  final int totalSesiones;
  final int rachaActual;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _ProgressMetric(
                icon: Icons.today_rounded,
                label: 'Esta semana',
                value: '$sesionesSemana',
              ),
            ),
            Expanded(
              child: _ProgressMetric(
                icon: Icons.fitness_center_rounded,
                label: 'Total',
                value: '$totalSesiones',
              ),
            ),
            Expanded(
              child: _ProgressMetric(
                icon: Icons.local_fire_department_rounded,
                label: 'Racha',
                value: '$rachaActual',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressPlaceholder extends StatelessWidget {
  const _ProgressPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Cargando progreso...',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: theme.textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall,
      ),
    );
  }
}

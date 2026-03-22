import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:calistenia_app/core/router/student_shell_routes.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/core/config/api_config.dart';
import 'package:calistenia_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:calistenia_app/features/exercises/domain/exercise_metadata.dart';

class _TeacherSummary {
  const _TeacherSummary({
    required this.approvedStudents,
    required this.pendingStudents,
    required this.groups,
    required this.myExercises,
    required this.myRoutines,
    required this.scheduledClasses,
  });

  final int approvedStudents;
  final int pendingStudents;
  final int groups;
  final int myExercises;
  final int myRoutines;
  final int scheduledClasses;
}

final teacherSummaryProvider = FutureProvider<_TeacherSummary>((ref) async {
  final auth = ref.read(authControllerProvider);
  final userId = auth.session?.user.id;
  if (userId == null || userId.isEmpty) {
    return const _TeacherSummary(
      approvedStudents: 0,
      pendingStudents: 0,
      groups: 0,
      myExercises: 0,
      myRoutines: 0,
      scheduledClasses: 0,
    );
  }

  final api = ref.read(apiClientProvider);
  final results = await Future.wait<dynamic>([
    api.getMyTeacherStudentLinks(asTeacher: true, status: 'approved'),
    api.getMyTeacherStudentLinks(asTeacher: true, status: 'pending'),
    api.getTeacherGroups(),
    api.getExercises(ownerUserId: userId, limit: 200, offset: 0),
    api.getRoutines(userId: userId, limit: 200, offset: 0),
    api.getLiveClasses(teacherUserId: userId, status: 'scheduled'),
  ]);

  return _TeacherSummary(
    approvedStudents: (results[0] as List).length,
    pendingStudents: (results[1] as List).length,
    groups: (results[2] as List).length,
    myExercises: (results[3] as List).length,
    myRoutines: (results[4] as List).length,
    scheduledClasses: (results[5] as List).length,
  );
});

/// Panel principal del profesor: layout lateral como admin.
class TeacherDashboardScreen extends ConsumerStatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  ConsumerState<TeacherDashboardScreen> createState() =>
      _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends ConsumerState<TeacherDashboardScreen> {
  int _sectionIndex = 0;

  Future<void> _showInviteDialog(BuildContext context) async {
    final userId = ref.read(authControllerProvider).session?.user.id ?? '';
    final inviteUrl = userId.isEmpty
        ? ''
        : '${ApiConfig.appWebBaseUrl.replaceFirst(RegExp(r'/$'), '')}/teachers/$userId';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invitar alumno'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Comparte el enlace con el alumno. Al abrirlo podrá iniciar sesión y pulsar “Solicitar ser alumno” en tu perfil.',
              ),
              if (inviteUrl.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Enlace de invitación:',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  inviteUrl,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (userId.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Id de profesor (alternativo):',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                SelectableText(userId, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
          if (inviteUrl.isNotEmpty)
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: inviteUrl));
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enlace copiado. Compártelo con el alumno.'),
                  ),
                );
              },
              icon: const Icon(Icons.link, size: 20),
              label: const Text('Copiar enlace'),
            ),
          if (userId.isNotEmpty)
            OutlinedButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: userId));
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Id copiado al portapapeles')),
                );
              },
              child: const Text('Copiar id'),
            ),
        ],
      ),
    );
  }

  Future<void> _showCreateExerciseDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _CreateExerciseDialogContent(
        ref: ref,
        dialogContext: dialogContext,
        parentContext: context,
      ),
    );
  }

  Widget _actionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionsList(BuildContext context, AsyncValue<_TeacherSummary> summaryAsync) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        Text(
          'Resumen',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        summaryAsync.when(
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (e, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No se pudo cargar el resumen: $e'),
            ),
          ),
          data: (s) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _TeacherMetricCard(label: 'Alumnos', value: '${s.approvedStudents}', subtitle: 'Aprobados'),
              _TeacherMetricCard(label: 'Pendientes', value: '${s.pendingStudents}', subtitle: 'Por revisar'),
              _TeacherMetricCard(label: 'Grupos', value: '${s.groups}', subtitle: 'Creados'),
              _TeacherMetricCard(label: 'Ejercicios', value: '${s.myExercises}', subtitle: 'Propios'),
              _TeacherMetricCard(label: 'Rutinas', value: '${s.myRoutines}', subtitle: 'Propias'),
              _TeacherMetricCard(label: 'Clases', value: '${s.scheduledClasses}', subtitle: 'Programadas'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Acciones rápidas',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        _actionCard(
          context: context,
          icon: Icons.fitness_center,
          title: 'Crear ejercicio',
          subtitle: 'Publica un ejercicio para tus alumnos',
          onTap: () => _showCreateExerciseDialog(context),
        ),
        _actionCard(
          context: context,
          icon: Icons.verified_user_outlined,
          title: 'Aprobar alumnos',
          subtitle: 'Acepta o rechaza solicitudes',
          onTap: () => context.push('/teacher-students'),
        ),
        _actionCard(
          context: context,
          icon: Icons.person_add_alt_1_outlined,
          title: 'Invitar alumno',
          subtitle: 'Comparte tu id para que te soliciten',
          onTap: () => _showInviteDialog(context),
        ),
        _actionCard(
          context: context,
          icon: Icons.playlist_add,
          title: 'Crear rutina',
          subtitle: 'Crea bloques completos de entrenamiento',
          onTap: () => context.push(StudentShellRoutes.routineCreate),
        ),
        _actionCard(
          context: context,
          icon: Icons.assignment_outlined,
          title: 'Asignar rutina',
          subtitle: 'Asigna a un alumno o a un grupo',
          onTap: () => context.push('/teacher-students'),
        ),
        _actionCard(
          context: context,
          icon: Icons.group_outlined,
          title: 'Grupos de alumnos',
          subtitle: 'Crea grupos y gestiona miembros',
          onTap: () => context.push('/teacher-groups'),
        ),
        _actionCard(
          context: context,
          icon: Icons.video_camera_front_outlined,
          title: 'Clases en directo',
          subtitle: 'Crea y gestiona tus clases',
          onTap: () => context.push('/live-classes'),
        ),
        _actionCard(
          context: context,
          icon: Icons.chat_bubble_outline,
          title: 'Mensajes',
          subtitle: 'Habla con alumnos y grupos',
          onTap: () => context.push('/messages'),
        ),
        _actionCard(
          context: context,
          icon: Icons.grid_view_rounded,
          title: 'Ver ejercicios',
          subtitle: 'Catálogo en 4 columnas (solo lectura)',
          onTap: () => context.push('/teacher-exercises'),
        ),
      ],
    );
  }

  Widget _buildSectionContent(BuildContext context) {
    final summaryAsync = ref.watch(teacherSummaryProvider);
    switch (_sectionIndex) {
      case 0:
        return _buildActionsList(context, summaryAsync);
      case 1:
        return Center(
          child: FilledButton.icon(
            onPressed: () => _showCreateExerciseDialog(context),
            icon: const Icon(Icons.fitness_center),
            label: const Text('Crear ejercicio'),
          ),
        );
      case 2:
        return Center(
          child: FilledButton.icon(
            onPressed: () => context.push('/teacher-exercises'),
            icon: const Icon(Icons.grid_view_rounded),
            label: const Text('Abrir catálogo de ejercicios'),
          ),
        );
      case 3:
        return Center(
          child: FilledButton.icon(
            onPressed: () => context.push('/teacher-students'),
            icon: const Icon(Icons.verified_user_outlined),
            label: const Text('Gestionar alumnos'),
          ),
        );
      case 4:
        return Center(
          child: FilledButton.icon(
            onPressed: () => context.push('/teacher-groups'),
            icon: const Icon(Icons.group_outlined),
            label: const Text('Abrir grupos de alumnos'),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final userId = auth.session?.user.id;
    final userEmail = auth.session?.user.email ?? '';

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 280,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              color: const Color(0xFF111318),
              border: Border(
                right: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Panel profesor',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  userEmail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: Column(
                    children: [
                      for (final entry in _teacherSections.indexed)
                        _TeacherNavItem(
                          icon: entry.$2.icon,
                          label: entry.$2.label,
                          selected: _sectionIndex == entry.$1,
                          onTap: () => setState(() => _sectionIndex = entry.$1),
                        ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: userId == null
                      ? null
                      : () => context.push('/teachers/$userId'),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Mi perfil'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => context.push('/notifications'),
                  icon: const Icon(Icons.notifications_outlined),
                  label: const Text('Notificaciones'),
                ),
              ],
            ),
          ),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF0C0D10),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF16191E).withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _teacherSections[_sectionIndex].headline,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: _buildSectionContent(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherMetricCard extends StatelessWidget {
  const _TeacherMetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
  });

  final String label;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherNavItem extends StatelessWidget {
  const _TeacherNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? const Color(0xFF00FF87).withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: selected
                  ? const Color(0xFF00FF87).withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          leading: Icon(
            icon,
            color: selected ? const Color(0xFF00FF87) : Colors.white70,
          ),
          title: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

class _TeacherSectionMeta {
  const _TeacherSectionMeta({
    required this.label,
    required this.headline,
    required this.icon,
  });

  final String label;
  final String headline;
  final IconData icon;
}

const _teacherSections = [
  _TeacherSectionMeta(
    label: 'Inicio',
    headline: 'Acciones rápidas del profesor',
    icon: Icons.dashboard_outlined,
  ),
  _TeacherSectionMeta(
    label: 'Crear ejercicio',
    headline: 'Crear un nuevo ejercicio',
    icon: Icons.fitness_center,
  ),
  _TeacherSectionMeta(
    label: 'Ver ejercicios',
    headline: 'Catálogo de ejercicios (solo lectura)',
    icon: Icons.grid_view_rounded,
  ),
  _TeacherSectionMeta(
    label: 'Alumnos',
    headline: 'Gestión de alumnos y asignaciones',
    icon: Icons.verified_user_outlined,
  ),
  _TeacherSectionMeta(
    label: 'Grupos',
    headline: 'Gestión de grupos de alumnos',
    icon: Icons.group_outlined,
  ),
];

/// Contenido del diálogo Crear ejercicio. Posee el [TextEditingController]
/// y lo elimina al cerrar, evitando fallos al cancelar.
class _CreateExerciseDialogContent extends StatefulWidget {
  const _CreateExerciseDialogContent({
    required this.ref,
    required this.dialogContext,
    required this.parentContext,
  });

  final WidgetRef ref;
  final BuildContext dialogContext;
  final BuildContext parentContext;

  @override
  State<_CreateExerciseDialogContent> createState() =>
      _CreateExerciseDialogContentState();
}

class _CreateExerciseDialogContentState
    extends State<_CreateExerciseDialogContent> {
  late final TextEditingController _nameController;
  late String _category;
  late String _difficulty;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _category = exerciseCategories.first;
    _difficulty = exerciseDifficulties.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.ref.read(apiClientProvider).createTeacherExercise(
            name: name,
            description: null,
            category: _category,
            difficulty: _difficulty,
            muscleGroups: const [],
            durationSeconds: null,
            gifUrl: null,
            videoUrl: null,
            thumbnailUrl: null,
          );
      if (!widget.dialogContext.mounted) return;
      Navigator.of(widget.dialogContext).pop();
      if (!widget.parentContext.mounted) return;
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
        const SnackBar(content: Text('Ejercicio creado')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      if (!widget.parentContext.mounted) return;
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear ejercicio'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
              autofocus: true,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: exerciseCategories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c),
                    ),
                  )
                  .toList(),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _difficulty,
              decoration: const InputDecoration(labelText: 'Dificultad'),
              items: exerciseDifficulties
                  .map(
                    (d) => DropdownMenuItem(
                      value: d,
                      child: Text(d),
                    ),
                  )
                  .toList(),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _difficulty = v ?? _difficulty),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(widget.dialogContext).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Creando...' : 'Crear'),
        ),
      ],
    );
  }
}


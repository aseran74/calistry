import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/core/config/api_config.dart';
import 'package:calistenia_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:calistenia_app/features/exercises/domain/exercise_metadata.dart';

/// Panel principal del profesor: solo acciones clave.
class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({super.key});

  Future<void> _showInviteDialog(BuildContext context, WidgetRef ref) async {
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

  Future<void> _showCreateExerciseDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userId = ref.watch(authControllerProvider).session?.user.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel profesor'),
        actions: [
          IconButton(
            tooltip: 'Perfil',
            icon: const Icon(Icons.person_outline),
            onPressed: userId == null
                ? null
                : () => context.push('/teachers/$userId'),
          ),
          IconButton(
            tooltip: 'Notificaciones',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
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
            onTap: () => _showCreateExerciseDialog(context, ref),
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
            onTap: () => _showInviteDialog(context, ref),
          ),
          _actionCard(
            context: context,
            icon: Icons.playlist_add,
            title: 'Crear rutina',
            subtitle: 'Crea bloques completos de entrenamiento',
            onTap: () => context.push('/routines/create'),
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
        ],
      ),
    );
  }
}

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
              value: _category,
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
              value: _difficulty,
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


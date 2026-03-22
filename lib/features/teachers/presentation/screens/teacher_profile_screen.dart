import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/auth/presentation/providers/auth_controller.dart';

void _teacherLogout(WidgetRef ref, BuildContext context) async {
  await ref.read(authControllerProvider).logout();
  if (context.mounted) context.go('/login');
}

class TeacherProfileScreen extends ConsumerStatefulWidget {
  const TeacherProfileScreen({
    super.key,
    required this.teacherUserId,
  });

  final String teacherUserId;

  @override
  ConsumerState<TeacherProfileScreen> createState() =>
      _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends ConsumerState<TeacherProfileScreen> {
  bool _loading = true;
  Map<String, dynamic>? _teacher;
  Map<String, dynamic>? _link;
  List<Map<String, dynamic>> _exercises = const [];
  List<Map<String, dynamic>> _routines = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final client = ref.read(apiClientProvider);
      final auth = ref.read(authControllerProvider);
      final teacher = await client.getTeacherProfile(widget.teacherUserId);
      final exercises = await client.getExercises(
        ownerUserId: widget.teacherUserId,
        limit: 50,
      );
      final routines = await client.getRoutines(
        userId: widget.teacherUserId,
        isPublic: true,
        limit: 50,
      );
      Map<String, dynamic>? link;
      if (auth.isAuthenticated && !auth.isTeacher) {
        final links = await client.getMyTeacherStudentLinks(asTeacher: false);
        link = links.cast<Map<String, dynamic>?>().firstWhere(
              (item) =>
                  item?['teacher_user_id']?.toString() == widget.teacherUserId,
              orElse: () => null,
            );
      }
      if (!mounted) return;
      setState(() {
        _teacher = teacher;
        _exercises = exercises;
        _routines = routines;
        _link = link;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestFollow() async {
    try {
      final result = await ref
          .read(apiClientProvider)
          .requestTeacherFollow(widget.teacherUserId);
      if (!mounted) return;
      setState(() => _link = result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada al profesor.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _openChat() async {
    final auth = ref.read(authControllerProvider);
    final userId = auth.session?.user.id;
    if (userId == null) return;
    try {
      final conversation = await ref.read(apiClientProvider).ensureConversation(
            teacherUserId: widget.teacherUserId,
            studentUserId: userId,
          );
      if (!mounted || conversation == null) return;
      context.push('/messages/${conversation['id']}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final isOwnTeacherProfile = auth.session?.user.id == widget.teacherUserId;
    final linkStatus = _link?['status']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(isOwnTeacherProfile ? 'Mi perfil' : 'Perfil del profesor'),
        actions: [
          if (isOwnTeacherProfile)
            TextButton.icon(
              onPressed: () => _teacherLogout(ref, context),
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Cerrar sesión'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (isOwnTeacherProfile) ...[
                  Text(
                    'Datos personales',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ProfileRow(
                            label: 'Correo',
                            value: auth.session?.user.email ?? '—',
                          ),
                          const SizedBox(height: 10),
                          _ProfileRow(
                            label: 'Nombre mostrado',
                            value: _teacher?['display_name']?.toString().trim().isNotEmpty == true
                                ? _teacher!['display_name'].toString()
                                : '—',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.18),
                        theme.colorScheme.surface,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _teacher?['display_name']?.toString() ?? 'Profesor',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        () {
                          final s = _teacher?['specialty']?.toString();
                          return (s != null && s.isNotEmpty)
                              ? s
                              : 'Especialidad pendiente';
                        }(),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        () {
                          final b = _teacher?['bio']?.toString();
                          return (b != null && b.isNotEmpty)
                              ? b
                              : 'Este profesor todavía no ha añadido bio.';
                        }(),
                      ),
                      const SizedBox(height: 16),
                      _SocialLinksSection(
                        teacher: _teacher,
                        isOwnProfile: isOwnTeacherProfile,
                        onUpdated: _load,
                        ref: ref,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _MetricChip(
                            label: '${_exercises.length} ejercicios',
                          ),
                          _MetricChip(
                            label: '${_routines.length} rutinas públicas',
                          ),
                          if (linkStatus != null)
                            _MetricChip(label: 'Alumno: $linkStatus'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (!isOwnTeacherProfile &&
                              linkStatus == null &&
                              auth.isAuthenticated &&
                              !auth.isTeacher)
                            FilledButton.icon(
                              onPressed: _requestFollow,
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Text('Solicitar ser alumno'),
                            ),
                          if (linkStatus == 'approved' && !isOwnTeacherProfile)
                            FilledButton.tonalIcon(
                              onPressed: _openChat,
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('Enviar mensaje'),
                            ),
                          if (isOwnTeacherProfile)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  context.push('/teacher-students'),
                              icon: const Icon(Icons.groups_outlined),
                              label: const Text('Gestionar alumnos'),
                            ),
                          if (isOwnTeacherProfile)
                            OutlinedButton.icon(
                              onPressed: () => context.push('/live-classes'),
                              icon: const Icon(Icons.live_tv_outlined),
                              label: const Text('Mis clases en directo'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Ejercicios',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (_exercises.isEmpty)
                  const _TeacherEmptyCard(
                    message:
                        'Este profesor todavía no tiene ejercicios publicados.',
                  )
                else
                  ..._exercises.map(
                    (exercise) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: ListTile(
                          title: Text(exercise['name']?.toString() ?? ''),
                          subtitle: Text(
                            '${exercise['category'] ?? '-'} · ${exercise['difficulty'] ?? '-'}',
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Rutinas públicas',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (_routines.isEmpty)
                  const _TeacherEmptyCard(
                    message:
                        'Este profesor todavía no ha compartido rutinas públicas.',
                  )
                else
                  ..._routines.map(
                    (routine) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: ListTile(
                          title: Text(routine['name']?.toString() ?? ''),
                          subtitle: Text(
                            '${routine['level'] ?? '-'} · ${routine['description'] ?? 'Sin descripción'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: SelectableText(value)),
      ],
    );
  }
}

class _SocialLinksSection extends StatelessWidget {
  const _SocialLinksSection({
    required this.teacher,
    required this.isOwnProfile,
    required this.onUpdated,
    required this.ref,
  });

  final Map<String, dynamic>? teacher;
  final bool isOwnProfile;
  final VoidCallback onUpdated;
  final WidgetRef ref;

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _editSocialLinks(BuildContext context) async {
    final instagramController = TextEditingController(
      text: teacher?['instagram_url']?.toString() ?? '',
    );
    final tiktokController = TextEditingController(
      text: teacher?['tiktok_url']?.toString() ?? '',
    );
    final facebookController = TextEditingController(
      text: teacher?['facebook_url']?.toString() ?? '',
    );
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Redes sociales'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: instagramController,
                  decoration: const InputDecoration(
                    labelText: 'Instagram (URL completa)',
                    hintText: 'https://instagram.com/tu_usuario',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tiktokController,
                  decoration: const InputDecoration(
                    labelText: 'TikTok (URL completa)',
                    hintText: 'https://tiktok.com/@tu_usuario',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: facebookController,
                  decoration: const InputDecoration(
                    labelText: 'Facebook (URL completa)',
                    hintText: 'https://facebook.com/tu_pagina',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
      if (saved == true) {
        await ref.read(apiClientProvider).updateTeacherProfile(
          instagramUrl: instagramController.text.trim(),
          tiktokUrl: tiktokController.text.trim(),
          facebookUrl: facebookController.text.trim(),
        );
        onUpdated();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Redes sociales actualizadas')),
          );
        }
      }
    } finally {
      instagramController.dispose();
      tiktokController.dispose();
      facebookController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final instagram = teacher?['instagram_url']?.toString().trim() ?? '';
    final tiktok = teacher?['tiktok_url']?.toString().trim() ?? '';
    final facebook = teacher?['facebook_url']?.toString().trim() ?? '';
    final hasAny = instagram.isNotEmpty || tiktok.isNotEmpty || facebook.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Redes sociales',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (isOwnProfile) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _editSocialLinks(context),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Editar'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (!hasAny && !isOwnProfile)
          Text(
            'Este profesor no ha añadido enlaces a redes sociales.',
            style: theme.textTheme.bodySmall,
          )
        else if (!hasAny && isOwnProfile)
          Text(
            'Añade tus enlaces para que tus alumnos te encuentren.',
            style: theme.textTheme.bodySmall,
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (instagram.isNotEmpty)
                _SocialLinkChip(
                  label: 'Instagram',
                  icon: Icons.camera_alt_outlined,
                  variant: _SocialChipVariant.instagram,
                  onTap: () => _launchUrl(instagram),
                ),
              if (tiktok.isNotEmpty)
                _SocialLinkChip(
                  label: 'TikTok',
                  icon: Icons.videocam_outlined,
                  variant: _SocialChipVariant.tiktok,
                  onTap: () => _launchUrl(tiktok),
                ),
              if (facebook.isNotEmpty)
                _SocialLinkChip(
                  label: 'Facebook',
                  icon: Icons.facebook,
                  variant: _SocialChipVariant.facebook,
                  onTap: () => _launchUrl(facebook),
                ),
            ],
          ),
      ],
    );
  }
}

class _SocialLinkChip extends StatelessWidget {
  const _SocialLinkChip({
    required this.label,
    required this.icon,
    required this.variant,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final _SocialChipVariant variant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outlineVariant;

    BoxDecoration decoration;
    switch (variant) {
      case _SocialChipVariant.instagram:
        decoration = BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF833AB4), // purple
              Color(0xFFF77737), // orange
              Color(0xFFFD1D1D), // red
            ],
          ),
          borderRadius: BorderRadius.circular(999),
        );
        break;
      case _SocialChipVariant.facebook:
        decoration = BoxDecoration(
          color: const Color(0xFF1877F2),
          borderRadius: BorderRadius.circular(999),
        );
        break;
      case _SocialChipVariant.tiktok:
        decoration = BoxDecoration(
          color: const Color(0xFF0B0B0F),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: const Color(0xFF25F4EE).withValues(alpha: 0.65),
          ),
        );
        break;
      case _SocialChipVariant.neutral:
        decoration = BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: outline),
        );
        break;
    }

    final foreground = switch (variant) {
      _SocialChipVariant.neutral => onSurface,
      _ => Colors.white,
    };

    return DecoratedBox(
      decoration: decoration,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: foreground),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
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

enum _SocialChipVariant {
  instagram,
  facebook,
  tiktok,
  neutral,
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}

class _TeacherEmptyCard extends StatelessWidget {
  const _TeacherEmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message),
      ),
    );
  }
}

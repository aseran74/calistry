import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:calistenia_app/core/shell/student_shell_layout.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:calistenia_app/features/profile/presentation/providers/profile_provider.dart';
import 'package:calistenia_app/features/progress/presentation/providers/progress_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _avatarUrl;
  bool _uploadingAvatar = false;

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 85,
    );
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    final client = ref.read(apiClientProvider);
    setState(() => _uploadingAvatar = true);
    try {
      final url = await client.uploadAvatar(
        bytes,
        xfile.mimeType ?? 'image/jpeg',
      );
      if (!mounted) return;
      if (url != null) {
        setState(() => _avatarUrl = url);
        ref.invalidate(currentUserProfileProvider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No hay almacenamiento de avatares configurado en Insforge.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(userStatsProvider);
    final auth = ref.watch(authControllerProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final favoritesAsync = ref.watch(favoriteExercisesProvider);
    final theme = Theme.of(context);
    final sessionUser = auth.session?.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
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
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          StudentShellLayout.bodyBottomPadding(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            profileAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ProfileStatePanel(
                icon: Icons.person_off_outlined,
                title: 'Perfil no disponible',
                subtitle: '$e',
              ),
              data: (profile) {
                final profileAvatarUrl = profile?['avatar_url']?.toString();
                final avatarUrl = _avatarUrl ?? profileAvatarUrl;
                final username = profile?['username'] as String?;
                final nivel = profile?['nivel'] as String? ?? 'principiante';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProfileHero(
                      avatarUrl: avatarUrl,
                      username: username?.trim().isNotEmpty == true
                          ? username!
                          : 'Usuario',
                      email: sessionUser?.email ?? '',
                      nivel: nivel,
                      uploading: _uploadingAvatar,
                      onAvatarTap:
                          _uploadingAvatar ? null : _pickAndUploadAvatar,
                    ),
                    const SizedBox(height: 18),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nivel actual',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_capitalize(nivel)} · 20% al siguiente',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              value: 0.2,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            statsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ProfileStatePanel(
                icon: Icons.insights_outlined,
                title: 'No se pudieron cargar tus métricas',
                subtitle: '$e',
              ),
              data: (stats) {
                final totalSesiones = stats['total_sesiones'] as int? ?? 0;
                final tiempoTotal = stats['tiempo_total_segundos'] as int? ?? 0;
                final rachaActual = stats['racha_actual'] as int? ?? 0;
                final minutos = tiempoTotal ~/ 60;
                return Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        value: '$rachaActual',
                        label: 'Racha',
                        icon: Icons.local_fire_department_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        value: '$totalSesiones',
                        label: 'Sesiones',
                        icon: Icons.fitness_center,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        value: '$minutos',
                        label: 'Min',
                        icon: Icons.timer_outlined,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            favoritesAsync.when(
              loading: () => const _SettingsTile(
                icon: Icons.favorite,
                title: 'Mis favoritos',
                subtitle: 'Cargando...',
              ),
              error: (_, __) => const _SettingsTile(
                icon: Icons.favorite,
                title: 'Mis favoritos',
                subtitle: 'No se pudieron cargar',
              ),
              data: (favorites) => _SettingsTile(
                icon: Icons.favorite,
                title: 'Mis favoritos',
                subtitle: favorites.isEmpty
                    ? 'Todavía no tienes favoritos'
                    : '${favorites.length} ejercicios guardados',
                onTap: favorites.isEmpty
                    ? null
                    : () => showModalBottomSheet(
                          context: context,
                          builder: (_) => ListView(
                            shrinkWrap: true,
                            children: [
                              const ListTile(title: Text('Mis favoritos')),
                              ...favorites.map(
                                (exercise) => ListTile(
                                  title: Text(exercise.name),
                                  subtitle:
                                      Text(_capitalize(exercise.difficulty)),
                                ),
                              ),
                            ],
                          ),
                        ),
              ),
            ),
            const SizedBox(height: 12),
            const _SectionTitle(title: 'Acciones'),
            const SizedBox(height: 10),
            _SettingsTile(
              icon: Icons.edit,
              title: 'Editar perfil',
              subtitle: 'Cambia tu nombre de usuario y nivel',
              onTap: () => context.push('/profile/edit'),
            ),
            const SizedBox(height: 10),
            _SettingsTile(
              icon: Icons.history,
              title: 'Historial',
              subtitle: 'Revisa tu progreso y sesiones registradas',
              onTap: () => context.push('/progress'),
            ),
            const SizedBox(height: 10),
            _SettingsTile(
              icon: Icons.school_outlined,
              title:
                  auth.isTeacher ? 'Perfil de profesor' : 'Quiero ser profesor',
              subtitle: auth.isTeacher
                  ? 'Gestiona tu estado como profesor'
                  : 'Solicita aprobación para enseñar a alumnos',
              onTap: () => context.push('/teacher-application'),
            ),
            const SizedBox(height: 10),
            _SettingsTile(
              icon: Icons.groups_outlined,
              title: 'Profesores',
              subtitle: 'Explora profesores y solicita seguirlos como alumno',
              onTap: () => context.push('/teachers'),
            ),
            const SizedBox(height: 10),
            _SettingsTile(
              icon: Icons.chat_bubble_outline,
              title: 'Mensajes',
              subtitle: 'Habla con tus profesores o alumnos aprobados',
              onTap: () => context.push('/messages'),
            ),
            const SizedBox(height: 10),
            _SettingsTile(
              icon: Icons.live_tv_outlined,
              title: 'Clases en directo',
              subtitle: 'Entra en salas activas o abre una si eres profesor',
              onTap: () => context.push('/live-classes'),
            ),
            const SizedBox(height: 10),
            if (auth.isTeacher)
              _SettingsTile(
                icon: Icons.dashboard_customize_outlined,
                title: 'Dashboard profesor',
                subtitle:
                    'Gestiona ejercicios, alumnos y rutinas desde tu panel',
                onTap: () => context.push('/teacher'),
              ),
            if (auth.isTeacher) const SizedBox(height: 10),
            if (auth.isTeacher)
              _SettingsTile(
                icon: Icons.manage_accounts_outlined,
                title: 'Mis alumnos',
                subtitle: 'Aprueba solicitudes y coordina tu grupo',
                onTap: () => context.push('/teacher-students'),
              ),
            if (auth.isTeacher) const SizedBox(height: 10),
            _SettingsTile(
              icon: Icons.settings,
              title: 'Configuración',
              subtitle: 'Preferencias y ajustes de cuenta',
              onTap: () => context.push('/settings'),
            ),
            const SizedBox(height: 10),
            _SettingsTile(
              icon: Icons.logout,
              title: 'Cerrar sesión',
              subtitle: 'Salir de la cuenta actual',
              danger: true,
              onTap: auth.busy
                  ? null
                  : () => ref.read(authControllerProvider).logout(),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.avatarUrl,
    required this.username,
    required this.email,
    required this.nivel,
    required this.uploading,
    required this.onAvatarTap,
  });

  final String? avatarUrl;
  final String username;
  final String email;
  final String nivel;
  final bool uploading;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.2),
            theme.colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 54,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(avatarUrl!)
                      : null,
                  child: (avatarUrl == null || avatarUrl!.isEmpty)
                      ? Icon(
                          Icons.person,
                          size: 52,
                          color: theme.colorScheme.outline,
                        )
                      : null,
                ),
                if (uploading)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  )
                else
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.colorScheme.primary,
                      child: Icon(
                        Icons.camera_alt,
                        size: 20,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            username,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(email, style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _ProfileBadge(label: 'Nivel ${nivel.toUpperCase()}'),
              const _ProfileBadge(label: 'Toca para cambiar foto'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: theme.textTheme.labelLarge),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
            const SizedBox(height: 10),
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
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = danger ? theme.colorScheme.error : theme.colorScheme.primary;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _ProfileStatePanel extends StatelessWidget {
  const _ProfileStatePanel({
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
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

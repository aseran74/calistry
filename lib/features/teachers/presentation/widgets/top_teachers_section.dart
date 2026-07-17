import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/auth/presentation/providers/auth_controller.dart';

final topTeachersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(apiClientProvider).getTopTeachers(limit: 10);
});

class TopTeachersSection extends ConsumerWidget {
  const TopTeachersSection({
    super.key,
    this.title = 'Top 10 profesores',
    this.subtitle = 'Ranking por seguidores',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final teachersAsync = ref.watch(topTeachersProvider);
    final canInteract =
        auth.isAuthenticated && !auth.isTeacher && !auth.isAdmin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        teachersAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No se pudo cargar el ranking: $e'),
            ),
          ),
          data: (teachers) {
            if (teachers.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Aún no hay profesores en el ranking. Cuando haya perfiles aprobados aparecerán aquí.',
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (var i = 0; i < teachers.length; i++)
                  _TopTeacherTile(
                    rank: i + 1,
                    teacher: teachers[i],
                    canInteract: canInteract,
                    onChanged: () => ref.invalidate(topTeachersProvider),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TopTeacherTile extends ConsumerStatefulWidget {
  const _TopTeacherTile({
    required this.rank,
    required this.teacher,
    required this.canInteract,
    required this.onChanged,
  });

  final int rank;
  final Map<String, dynamic> teacher;
  final bool canInteract;
  final VoidCallback onChanged;

  @override
  ConsumerState<_TopTeacherTile> createState() => _TopTeacherTileState();
}

class _TopTeacherTileState extends ConsumerState<_TopTeacherTile> {
  late bool _liked;
  late bool _followed;
  late int _likes;
  late int _followers;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _syncFromTeacher(widget.teacher);
  }

  @override
  void didUpdateWidget(covariant _TopTeacherTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teacher != widget.teacher) {
      _syncFromTeacher(widget.teacher);
    }
  }

  void _syncFromTeacher(Map<String, dynamic> teacher) {
    _liked = teacher['liked_by_me'] == true;
    _followed = teacher['followed_by_me'] == true;
    _likes = _asInt(teacher['likes_count']);
    _followers = _asInt(teacher['followers_count']);
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get _teacherId =>
      widget.teacher['teacher_user_id']?.toString() ??
      widget.teacher['user_id']?.toString() ??
      '';

  Future<void> _toggleLike() async {
    if (!widget.canInteract || _busy || _teacherId.isEmpty) {
      _showGate();
      return;
    }
    setState(() => _busy = true);
    final prevLiked = _liked;
    final prevLikes = _likes;
    setState(() {
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
    });
    try {
      final liked =
          await ref.read(apiClientProvider).toggleTeacherLike(_teacherId);
      if (!mounted) return;
      setState(() {
        _liked = liked;
        _likes = prevLikes + (liked ? (prevLiked ? 0 : 1) : (prevLiked ? -1 : 0));
        if (_likes < 0) _likes = 0;
      });
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _liked = prevLiked;
        _likes = prevLikes;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (!widget.canInteract || _busy || _teacherId.isEmpty) {
      _showGate();
      return;
    }
    setState(() => _busy = true);
    final prevFollowed = _followed;
    final prevFollowers = _followers;
    setState(() {
      _followed = !_followed;
      _followers += _followed ? 1 : -1;
    });
    try {
      final followed =
          await ref.read(apiClientProvider).toggleTeacherFollow(_teacherId);
      if (!mounted) return;
      setState(() {
        _followed = followed;
        _followers = prevFollowers +
            (followed ? (prevFollowed ? 0 : 1) : (prevFollowed ? -1 : 0));
        if (_followers < 0) _followers = 0;
      });
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _followed = prevFollowed;
        _followers = prevFollowers;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showGate() {
    final auth = ref.read(authControllerProvider);
    final msg = !auth.isAuthenticated
        ? 'Inicia sesión para dar like o seguir.'
        : 'Solo los alumnos pueden dar like o seguir.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = widget.teacher['display_name']?.toString() ?? 'Profesor';
    final specialty = widget.teacher['specialty']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _teacherId.isEmpty
              ? null
              : () => context.push('/teachers/$_teacherId'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.14),
                  child: Text(
                    '${widget.rank}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (specialty.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          specialty,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '$_followers seguidores · $_likes likes',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _liked ? 'Quitar like' : 'Like',
                  onPressed: _busy ? null : _toggleLike,
                  icon: Icon(
                    _liked ? Icons.favorite : Icons.favorite_border,
                    color: _liked ? theme.colorScheme.error : null,
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _toggleFollow,
                  child: Text(_followed ? 'Siguiendo' : 'Seguir'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/teachers/presentation/widgets/top_teachers_section.dart';

class TeachersScreen extends ConsumerStatefulWidget {
  const TeachersScreen({super.key});

  @override
  ConsumerState<TeachersScreen> createState() => _TeachersScreenState();
}

class _TeachersScreenState extends ConsumerState<TeachersScreen> {
  final _searchController = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> _teachers = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final teachers = await ref.read(apiClientProvider).getApprovedTeachers(
            search: _searchController.text.trim(),
          );
      if (!mounted) return;
      setState(() => _teachers = teachers);
      ref.invalidate(topTeachersProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profesores'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const TopTeachersSection(),
            const SizedBox(height: 24),
            Text(
              'Todos los profesores',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar profesor o especialidad',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
              onSubmitted: (_) => _load(),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_teachers.isEmpty)
              const _TeachersEmptyState()
            else
              ..._teachers.map(
                (teacher) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.14),
                        child: Icon(
                          Icons.school_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        teacher['display_name']?.toString() ?? 'Profesor',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [
                                if (teacher['specialty']
                                        ?.toString()
                                        .isNotEmpty ==
                                    true)
                                  teacher['specialty'].toString(),
                                if (teacher['bio']?.toString().isNotEmpty ==
                                    true)
                                  teacher['bio'].toString(),
                              ].join(' · '),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_hasSocial(teacher)) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  if (_socialUrl(teacher, 'instagram_url')
                                      .isNotEmpty)
                                    const _TeacherSocialChip(
                                      label: 'Instagram',
                                      icon: Icons.camera_alt_outlined,
                                    ),
                                  if (_socialUrl(teacher, 'tiktok_url')
                                      .isNotEmpty)
                                    const _TeacherSocialChip(
                                      label: 'TikTok',
                                      icon: Icons.videocam_outlined,
                                    ),
                                  if (_socialUrl(teacher, 'facebook_url')
                                      .isNotEmpty)
                                    const _TeacherSocialChip(
                                      label: 'Facebook',
                                      icon: Icons.facebook,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push(
                        '/teachers/${teacher['user_id']}',
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

bool _hasSocial(Map<String, dynamic> teacher) {
  return _socialUrl(teacher, 'instagram_url').isNotEmpty ||
      _socialUrl(teacher, 'tiktok_url').isNotEmpty ||
      _socialUrl(teacher, 'facebook_url').isNotEmpty;
}

String _socialUrl(Map<String, dynamic> teacher, String key) {
  return teacher[key]?.toString().trim() ?? '';
}

class _TeacherSocialChip extends StatelessWidget {
  const _TeacherSocialChip({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeachersEmptyState extends StatelessWidget {
  const _TeachersEmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.school_outlined, size: 36),
            const SizedBox(height: 10),
            Text(
              'Todavía no hay profesores visibles',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Cuando se aprueben perfiles de profesor aparecerán aquí con su especialidad y contenido.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

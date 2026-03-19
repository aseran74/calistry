import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/auth/presentation/providers/auth_controller.dart';

class LiveClassesScreen extends ConsumerStatefulWidget {
  const LiveClassesScreen({super.key});

  @override
  ConsumerState<LiveClassesScreen> createState() => _LiveClassesScreenState();
}

class _LiveClassesScreenState extends ConsumerState<LiveClassesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _classes = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final classes = await ref.read(apiClientProvider).getLiveClasses();
      if (!mounted) return;
      setState(() => _classes = classes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createLiveClass() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final urlController = TextEditingController();
    DateTime? scheduledAtLocal;
    var platform = 'zoom';
    var audienceType = 'group';
    String? selectedGroupId;
    String? selectedStudentId;
    try {
      final groups = await ref.read(apiClientProvider).getTeacherGroups();
      final links = await ref
          .read(apiClientProvider)
          .getMyTeacherStudentLinks(asTeacher: true, status: 'approved');
      final studentIds = links
          .map((l) => l['student_user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();
      final students = await ref.read(apiClientProvider).getUsersByIds(studentIds);
      final studentsById = {
        for (final u in students) u['id']?.toString() ?? '': u,
      };

      if (groups.isNotEmpty) {
        selectedGroupId = groups.first['id']?.toString();
      }
      if (studentIds.isNotEmpty) {
        selectedStudentId = studentIds.first;
      }

      final created = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> pickDateTime() async {
              final now = DateTime.now();
              final date = await showDatePicker(
                context: dialogContext,
                initialDate: scheduledAtLocal ?? now,
                firstDate: now.subtract(const Duration(days: 1)),
                lastDate: now.add(const Duration(days: 365)),
              );
              if (date == null) return;
              final time = await showTimePicker(
                context: dialogContext,
                initialTime: TimeOfDay.fromDateTime(scheduledAtLocal ?? now),
              );
              if (time == null) return;
              setLocalState(() {
                scheduledAtLocal = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
              });
            }

            final canCreate = titleController.text.trim().isNotEmpty &&
                urlController.text.trim().isNotEmpty &&
                scheduledAtLocal != null &&
                (audienceType == 'group'
                    ? (selectedGroupId?.isNotEmpty ?? false)
                    : (selectedStudentId?.isNotEmpty ?? false));

            return AlertDialog(
              title: const Text('Programar clase'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Título'),
                        onChanged: (_) => setLocalState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Notas (opcional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: platform,
                        decoration:
                            const InputDecoration(labelText: 'Plataforma'),
                        items: const [
                          DropdownMenuItem(
                            value: 'zoom',
                            child: Text('Zoom'),
                          ),
                          DropdownMenuItem(
                            value: 'google_meet',
                            child: Text('Google Meet'),
                          ),
                          DropdownMenuItem(
                            value: 'instagram_live',
                            child: Text('Instagram Live'),
                          ),
                          DropdownMenuItem(
                            value: 'tiktok_live',
                            child: Text('TikTok Live'),
                          ),
                        ],
                        onChanged: (v) => setLocalState(() {
                          platform = v ?? platform;
                        }),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: urlController,
                        decoration: const InputDecoration(
                          labelText: 'Enlace (https://...)',
                        ),
                        keyboardType: TextInputType.url,
                        onChanged: (_) => setLocalState(() {}),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Fecha y hora'),
                        subtitle: Text(
                          scheduledAtLocal == null
                              ? 'Seleccionar'
                              : scheduledAtLocal!.toString(),
                        ),
                        trailing: const Icon(Icons.calendar_month_outlined),
                        onTap: pickDateTime,
                      ),
                      const Divider(height: 22),
                      DropdownButtonFormField<String>(
                        value: audienceType,
                        decoration:
                            const InputDecoration(labelText: 'Destinatario'),
                        items: const [
                          DropdownMenuItem(
                            value: 'group',
                            child: Text('Un grupo'),
                          ),
                          DropdownMenuItem(
                            value: 'student',
                            child: Text('Un alumno aprobado'),
                          ),
                        ],
                        onChanged: (v) => setLocalState(() {
                          audienceType = v ?? audienceType;
                        }),
                      ),
                      const SizedBox(height: 12),
                      if (audienceType == 'group')
                        DropdownButtonFormField<String>(
                          value: selectedGroupId,
                          decoration:
                              const InputDecoration(labelText: 'Grupo'),
                          items: groups
                              .map(
                                (g) => DropdownMenuItem(
                                  value: g['id']?.toString() ?? '',
                                  child: Text(g['name']?.toString() ?? 'Grupo'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setLocalState(() => selectedGroupId = v),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: selectedStudentId,
                          decoration: const InputDecoration(labelText: 'Alumno'),
                          items: studentIds
                              .map((id) {
                                final u = studentsById[id];
                                final label =
                                    u?['username']?.toString().isNotEmpty ==
                                            true
                                        ? u!['username'].toString()
                                        : u?['email']?.toString() ?? id;
                                return DropdownMenuItem(
                                  value: id,
                                  child: Text(label),
                                );
                              })
                              .toList(),
                          onChanged: (v) =>
                              setLocalState(() => selectedStudentId = v),
                        ),
                      if (audienceType == 'group' && groups.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            'No tienes grupos. Crea un grupo antes de programar una clase para grupo.',
                          ),
                        ),
                      if (audienceType == 'student' && studentIds.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            'No tienes alumnos aprobados todavía.',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: canCreate
                      ? () => Navigator.of(dialogContext).pop({
                            'title': titleController.text.trim(),
                            'description': descriptionController.text.trim(),
                            'platform': platform,
                            'url': urlController.text.trim(),
                            'scheduledAtLocal': scheduledAtLocal,
                            'audienceType': audienceType,
                            'groupId': selectedGroupId,
                            'studentUserId': selectedStudentId,
                          })
                      : null,
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        ),
      );
      if (created == null || created['title']?.toString().isEmpty != false) {
        return;
      }
      final url = created['url']?.toString() ?? '';
      final scheduledLocal = created['scheduledAtLocal'] as DateTime?;
      if (url.isEmpty || scheduledLocal == null) return;
      final scheduledUtc = scheduledLocal.toUtc();
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El enlace debe empezar por http(s)://')),
        );
        return;
      }
      final liveClass = await ref.read(apiClientProvider).createLiveClass(
            title: created['title']!.toString(),
            description: created['description']?.toString().isEmpty == true
                ? null
                : created['description']?.toString(),
            scheduledAtUtc: scheduledUtc,
            platform: created['platform']?.toString() ?? 'zoom',
            meetingUrl: url,
            audienceType: created['audienceType']?.toString() ?? 'group',
            groupId: created['groupId']?.toString(),
            studentUserId: created['studentUserId']?.toString(),
          );
      if (!mounted || liveClass == null) return;
      await _load();
      if (!mounted) return;
      context.push('/live-classes/${liveClass['id']}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      titleController.dispose();
      descriptionController.dispose();
      urlController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final now = DateTime.now().toUtc();
    final upcoming = _classes.where((c) {
      final status = c['status']?.toString() ?? 'scheduled';
      if (status == 'ended') return false;
      final scheduled = DateTime.tryParse(c['scheduled_at']?.toString() ?? '');
      if (scheduled == null) return true;
      return scheduled.isAfter(now.subtract(const Duration(hours: 6)));
    }).toList();
    final past = _classes.where((c) {
      final status = c['status']?.toString() ?? 'scheduled';
      if (status == 'ended') return true;
      final scheduled = DateTime.tryParse(c['scheduled_at']?.toString() ?? '');
      if (scheduled == null) return false;
      return scheduled.isBefore(now.subtract(const Duration(hours: 6)));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clases en directo'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (_classes.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            const Icon(Icons.live_tv_outlined, size: 34),
                            const SizedBox(height: 10),
                            Text(
                              'No hay clases programadas',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Crea una clase con enlace (Zoom/Meet/Instagram/TikTok) y asígnala a un grupo o alumno.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (upcoming.isNotEmpty) ...[
                    Text(
                      'Próximas',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                  ],
                  ...upcoming.map(
                    (liveClass) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            liveClass['title']?.toString() ??
                                'Clase',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${liveClass['platform'] ?? '-'} · ${liveClass['scheduled_at'] ?? '-'}',
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () =>
                              context.push('/live-classes/${liveClass['id']}'),
                        ),
                      ),
                    ),
                  ),
                  if (past.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Pasadas',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                  ],
                  ...past.take(30).map(
                        (liveClass) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(
                                liveClass['title']?.toString() ?? 'Clase',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '${liveClass['platform'] ?? '-'} · ${liveClass['scheduled_at'] ?? '-'} · ${liveClass['status'] ?? '-'}',
                                ),
                              ),
                              trailing:
                                  const Icon(Icons.chevron_right_rounded),
                              onTap: () => context
                                  .push('/live-classes/${liveClass['id']}'),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
      floatingActionButton: auth.isTeacher
          ? FloatingActionButton.extended(
              onPressed: _createLiveClass,
              icon: const Icon(Icons.add_link),
              label: const Text('Programar clase'),
            )
          : null,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:go_router/go_router.dart';

class TeacherGroupsScreen extends ConsumerStatefulWidget {
  const TeacherGroupsScreen({super.key});

  @override
  ConsumerState<TeacherGroupsScreen> createState() => _TeacherGroupsScreenState();
}

class _TeacherGroupsScreenState extends ConsumerState<TeacherGroupsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _groups = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ref.read(apiClientProvider).getTeacherGroups();
      if (!mounted) return;
      setState(() => _groups = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _userLabel(Map<String, dynamic>? user) {
    final username = user?['username']?.toString();
    if (username != null && username.isNotEmpty) return username;
    final email = user?['email']?.toString();
    if (email != null && email.isNotEmpty) return email;
    return 'Alumno';
  }

  Future<void> _createGroup() async {
    final api = ref.read(apiClientProvider);
    List<Map<String, dynamic>> users = const [];
    try {
      final links = await api.getMyTeacherStudentLinks(
        asTeacher: true,
        status: 'approved',
      );
      final studentIds = links
          .map((l) => l['student_user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();
      users = await api.getUsersByIds(studentIds);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar alumnos: $e')),
      );
      return;
    }
    if (!mounted) return;

    final nameController = TextEditingController();
    final selectedIds = <String>{};
    try {
      final result = await showDialog<_CreateGroupResult>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Crear grupo'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del grupo',
                          hintText: 'Ej: Tercera edad Madrid, Mañanas…',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Alumnos en el grupo',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Marca los alumnos que quieras añadir (puedes dejarlo vacío y añadirlos después).',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                      const SizedBox(height: 8),
                      if (users.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Aún no tienes alumnos vinculados y aprobados. Invítalos desde el panel del profesor.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      else
                        ...users.map((u) {
                          final id = u['id']?.toString() ?? '';
                          if (id.isEmpty) return const SizedBox.shrink();
                          final checked = selectedIds.contains(id);
                          return CheckboxListTile(
                            value: checked,
                            onChanged: (v) => setLocal(() {
                              if (v == true) {
                                selectedIds.add(id);
                              } else {
                                selectedIds.remove(id);
                              }
                            }),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            title: Text(_userLabel(u)),
                            subtitle: Text(
                              u['email']?.toString() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Escribe un nombre para el grupo'),
                        ),
                      );
                      return;
                    }
                    Navigator.of(ctx).pop(
                      _CreateGroupResult(
                        name: name,
                        studentUserIds: selectedIds.toList(),
                      ),
                    );
                  },
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        ),
      );
      if (result == null) return;

      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Expanded(child: Text('Creando grupo…')),
              ],
            ),
          ),
        ),
      );

      try {
        final created = await api.createTeacherGroup(name: result.name);
        final groupId = created?['id']?.toString();
        if (groupId == null || groupId.isEmpty) {
          throw Exception('No se recibió el id del grupo');
        }
        for (final sid in result.studentUserIds) {
          await api.addStudentToGroup(
            groupId: groupId,
            studentUserId: sid,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al crear el grupo: $e')),
          );
        }
        return;
      } finally {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }

      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.studentUserIds.isEmpty
                ? 'Grupo creado'
                : 'Grupo creado con ${result.studentUserIds.length} alumno(s)',
          ),
        ),
      );
    } finally {
      nameController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grupos'),
        actions: [
          IconButton(
            tooltip: 'Crear grupo',
            icon: const Icon(Icons.add),
            onPressed: _createGroup,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  if (_groups.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            Icon(Icons.group_outlined, color: theme.colorScheme.outline),
                            const SizedBox(height: 10),
                            Text(
                              'Aún no tienes grupos',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Crea un grupo para organizar alumnos y enviar rutinas o mensajes.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ..._groups.map((g) {
                    final id = g['id']?.toString() ?? '';
                    final name = g['name']?.toString() ?? 'Grupo';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                          child: Icon(Icons.group, color: theme.colorScheme.primary),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('ID: ${id.substring(0, id.length.clamp(0, 8))}'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: id.isEmpty ? null : () => context.push('/teacher-groups/$id'),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

class _CreateGroupResult {
  _CreateGroupResult({
    required this.name,
    required this.studentUserIds,
  });
  final String name;
  final List<String> studentUserIds;
}


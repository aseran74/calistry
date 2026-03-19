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

  Future<void> _createGroup() async {
    final controller = TextEditingController();
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Crear grupo'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre del grupo',
              hintText: 'Ej: Mañanas, Avanzados',
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Crear'),
            ),
          ],
        ),
      );
      if (name == null || name.trim().isEmpty) return;
      await ref.read(apiClientProvider).createTeacherGroup(name: name.trim());
      if (!mounted) return;
      await _load();
    } finally {
      controller.dispose();
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


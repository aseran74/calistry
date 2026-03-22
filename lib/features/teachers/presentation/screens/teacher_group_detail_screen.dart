import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:calistenia_app/features/planning/presentation/widgets/routine_schedule_picker_section.dart';

class TeacherGroupDetailScreen extends ConsumerStatefulWidget {
  const TeacherGroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<TeacherGroupDetailScreen> createState() =>
      _TeacherGroupDetailScreenState();
}

class _TeacherGroupDetailScreenState
    extends ConsumerState<TeacherGroupDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _group;
  List<Map<String, dynamic>> _members = const [];
  Map<String, Map<String, dynamic>> _usersById = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final groups = await api.getTeacherGroups();
      final group = groups.cast<Map<String, dynamic>?>().firstWhere(
            (g) => g?['id']?.toString() == widget.groupId,
            orElse: () => null,
          );
      final members = await api.getTeacherGroupMembers(widget.groupId);
      final userIds = members
          .map((m) => m['student_user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();
      final users = await api.getUsersByIds(userIds);
      if (!mounted) return;
      setState(() {
        _group = group;
        _members = members;
        _usersById = {for (final u in users) u['id'].toString(): u};
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

  String _userLabel(Map<String, dynamic>? user) {
    final username = user?['username']?.toString();
    if (username != null && username.isNotEmpty) return username;
    final email = user?['email']?.toString();
    if (email != null && email.isNotEmpty) return email;
    return 'Alumno';
  }

  Future<void> _addMember() async {
    final api = ref.read(apiClientProvider);
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
      final users = await api.getUsersByIds(studentIds);

      if (!mounted) return;

      final selectedId = await showDialog<String>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Añadir alumno'),
            content: SizedBox(
              width: 520,
              child: ListView(
                shrinkWrap: true,
                children: users
                    .map((u) => ListTile(
                          title: Text(_userLabel(u)),
                          subtitle: Text(u['email']?.toString() ?? ''),
                          trailing: const Icon(Icons.add),
                          onTap: () =>
                              Navigator.of(ctx).pop(u['id'].toString()),
                        ))
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      );
      if (selectedId == null || selectedId.isEmpty) return;
      await api.addStudentToGroup(groupId: widget.groupId, studentUserId: selectedId);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _removeMember(String studentUserId) async {
    try {
      await ref.read(apiClientProvider).removeStudentFromGroup(
            groupId: widget.groupId,
            studentUserId: studentUserId,
          );
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _assignRoutineToGroup() async {
    final me = ref.read(authControllerProvider).session?.user.id;
    if (me == null || me.isEmpty) return;
    final api = ref.read(apiClientProvider);
    try {
      final routines = await api.getRoutines(userId: me, limit: 200);
      if (!mounted) return;
      if (routines.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Primero crea una rutina.')),
        );
        return;
      }
      String routineId = routines.first['id'].toString();
      final notesController = TextEditingController();
      var submitting = false;
      var scheduleDays = <int>{};
      TimeOfDay? scheduleTime = const TimeOfDay(hour: 10, minute: 0);

      try {
        await showDialog<void>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (context, setLocal) {
              Future<void> submit() async {
                if (submitting) return;
                setLocal(() => submitting = true);
                try {
                  final daysList = scheduleDays.toList()..sort();
                  await api.assignRoutineToGroup(
                    routineId: routineId,
                    groupId: widget.groupId,
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                    scheduleDays: daysList,
                    scheduleHour: scheduleTime?.hour,
                    scheduleMinute: scheduleTime?.minute ?? 0,
                  );
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Rutina enviada al grupo')),
                  );
                } catch (e) {
                  setLocal(() => submitting = false);
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }

              return AlertDialog(
                title: const Text('Enviar rutina al grupo'),
                content: SizedBox(
                  width: 520,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          value: routineId,
                          decoration:
                              const InputDecoration(labelText: 'Rutina'),
                          items: routines
                              .map((r) => DropdownMenuItem(
                                    value: r['id'].toString(),
                                    child: Text(
                                        r['name']?.toString() ?? 'Rutina'),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setLocal(() => routineId = v ?? routineId),
                        ),
                        const SizedBox(height: 16),
                        RoutineSchedulePickerSection(
                          daysTitle: '¿Qué días debe hacerla?',
                          daysHint:
                              'Opcional. Misma pauta para todos los alumnos del grupo.',
                          timeSubtitle:
                              'Cada alumno lo verá en inicio y en Rutinas → Asignadas.',
                          selectedDays: scheduleDays,
                          onDaysChanged: (d) =>
                              setLocal(() => scheduleDays = d),
                          selectedTime: scheduleTime,
                          onTimeChanged: (t) =>
                              setLocal(() => scheduleTime = t),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: notesController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Notas (opcional)',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: submitting ? null : submit,
                    child: Text(submitting ? 'Enviando...' : 'Enviar'),
                  ),
                ],
              );
            },
          ),
        );
      } finally {
        notesController.dispose();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _openGroupChat() async {
    final api = ref.read(apiClientProvider);
    try {
      final conversation = await api.ensureGroupConversation(groupId: widget.groupId);
      final conversationId = conversation?['id']?.toString();
      if (conversationId == null || conversationId.isEmpty) return;
      await api.ensureGroupConversationParticipants(
        groupConversationId: conversationId,
        groupId: widget.groupId,
      );
      if (!mounted) return;
      context.push('/group-chats/$conversationId');
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
    final name = _group?['name']?.toString() ?? 'Grupo';

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            tooltip: 'Chat de grupo',
            icon: const Icon(Icons.forum_outlined),
            onPressed: _openGroupChat,
          ),
          IconButton(
            tooltip: 'Añadir alumno',
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: _addMember,
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Acciones',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.tonal(
                                onPressed: _assignRoutineToGroup,
                                child: const Text('Enviar rutina'),
                              ),
                              OutlinedButton(
                                onPressed: _openGroupChat,
                                child: const Text('Abrir chat'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Alumnos (${_members.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_members.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Este grupo aún no tiene alumnos.'),
                      ),
                    ),
                  ..._members.map((m) {
                    final studentId = m['student_user_id']?.toString() ?? '';
                    final user = _usersById[studentId];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: const Icon(Icons.person_outline),
                        ),
                        title: Text(_userLabel(user)),
                        subtitle: Text(user?['email']?.toString() ?? ''),
                        trailing: IconButton(
                          tooltip: 'Quitar del grupo',
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: studentId.isEmpty ? null : () => _removeMember(studentId),
                        ),
                        onTap: studentId.isEmpty ? null : () => context.push('/users/$studentId'),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}


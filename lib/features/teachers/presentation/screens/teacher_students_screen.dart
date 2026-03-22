import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:calistenia_app/features/routines/domain/routine_assignment_schedule.dart';
import 'package:calistenia_app/features/planning/presentation/widgets/routine_schedule_picker_section.dart';

class TeacherStudentsScreen extends ConsumerStatefulWidget {
  const TeacherStudentsScreen({super.key});

  @override
  ConsumerState<TeacherStudentsScreen> createState() =>
      _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends ConsumerState<TeacherStudentsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _links = const [];
  List<Map<String, dynamic>> _routines = const [];
  Map<String, Map<String, dynamic>> _usersById = const {};
  Map<String, List<Map<String, dynamic>>> _assignmentsByStudent = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final teacherUserId = ref.read(authControllerProvider).session?.user.id;
    if (teacherUserId == null || teacherUserId.isEmpty) return;
    setState(() => _loading = true);
    try {
      final client = ref.read(apiClientProvider);
      final links = await client.getMyTeacherStudentLinks(asTeacher: true);
      final userIds = links
          .map((link) => link['student_user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();
      final users = await client.getUsersByIds(userIds);
      final routines = await client.getRoutines(userId: teacherUserId);
      final assignments = await client.getRoutineAssignments(asTeacher: true);
      if (!mounted) return;
      setState(() {
        _links = links;
        _routines = _uniqueById(routines);
        _usersById = {
          for (final user in users) user['id'].toString(): user,
        };
        _assignmentsByStudent = {
          for (final studentId in assignments
              .map((item) => item['student_user_id']?.toString())
              .whereType<String>()
              .toSet())
            studentId: assignments
                .where(
                  (assignment) =>
                      assignment['student_user_id']?.toString() == studentId,
                )
                .toList(),
        };
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

  List<Map<String, dynamic>> _uniqueById(List<Map<String, dynamic>> items) {
    final seen = <String>{};
    final unique = <Map<String, dynamic>>[];
    for (final item in items) {
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) continue;
      if (seen.add(id)) unique.add(item);
    }
    return unique;
  }

  String _studentLabel(Map<String, dynamic>? student) {
    final username = student?['username']?.toString();
    if (username != null && username.isNotEmpty) return username;
    final email = student?['email']?.toString();
    if (email != null && email.isNotEmpty) return email;
    return 'Alumno';
  }

  String _routineLabel(String? routineId) {
    return _routines
            .cast<Map<String, dynamic>?>()
            .firstWhere(
              (routine) => routine?['id']?.toString() == routineId,
              orElse: () => null,
            )?['name']
            ?.toString() ??
        'Rutina';
  }

  String _assignmentChipLabel(Map<String, dynamic> assignment) {
    final name = _routineLabel(assignment['routine_id']?.toString());
    final schedule = _formatScheduleShort(assignment);
    if (schedule.isEmpty) return name;
    return '$name · $schedule';
  }

  String _formatScheduleShort(Map<String, dynamic> assignment) {
    return RoutineAssignmentSchedule.formatAssignmentRow(assignment);
  }

  /// Agrupa enlaces: primero pendientes/rechazados, luego aprobados por group_name (Insforge).
  List<Widget> _buildGroupedLinks(ThemeData theme) {
    const pendingStatuses = ['pending', 'rejected'];
    final pending = _links.where((l) => pendingStatuses.contains(l['status']?.toString())).toList();
    final approved = _links.where((l) => (l['status']?.toString() ?? '') == 'approved').toList();
    final byGroup = <String, List<Map<String, dynamic>>>{};
    for (final link in approved) {
      final name = (link['group_name']?.toString() ?? '').trim();
      final key = name.isEmpty ? 'Sin grupo' : name;
      byGroup.putIfAbsent(key, () => []).add(link);
    }
    final groupNames = byGroup.keys.toList()
      ..sort((a, b) {
        if (a == 'Sin grupo' && b != 'Sin grupo') return -1;
        if (b == 'Sin grupo' && a != 'Sin grupo') return 1;
        return a.compareTo(b);
      });

    final widgets = <Widget>[];
    if (pending.isNotEmpty) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'Solicitudes',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ));
      for (final link in pending) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _studentCard(theme, link),
        ));
      }
      widgets.add(const SizedBox(height: 16));
    }
    for (final groupName in groupNames) {
      final links = byGroup[groupName]!;
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          groupName,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ));
      for (final link in links) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _studentCard(theme, link),
        ));
      }
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  Widget _studentCard(ThemeData theme, Map<String, dynamic> link) {
    final student = _usersById[link['student_user_id']?.toString()];
    final status = link['status']?.toString() ?? 'pending';
    final assignments = _assignmentsByStudent[link['student_user_id']?.toString()] ?? const [];
    final groupName = (link['group_name']?.toString() ?? '').trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _studentLabel(student),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (status == 'approved' && groupName.isEmpty)
                  IconButton(
                    icon: const Icon(Icons.label_outline),
                    tooltip: 'Asignar grupo',
                    onPressed: () => _editGroupName(link),
                  ),
                if (status == 'approved' && groupName.isNotEmpty)
                  InkWell(
                    onTap: () => _editGroupName(link),
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.group, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(groupName, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              student?['email']?.toString() ?? '',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: switch (status) {
                  'approved' => const Color(0xFF00FF87).withValues(alpha: 0.14),
                  'rejected' => const Color(0xFFFF4444).withValues(alpha: 0.14),
                  _ => const Color(0xFFFFD36B).withValues(alpha: 0.14),
                },
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('Estado: $status'),
            ),
            if (status == 'approved') ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(label: '${assignments.length} rutinas asignadas'),
                  if (assignments.isNotEmpty)
                    ...assignments.take(3).map(
                          (a) => _InfoChip(
                            label: _assignmentChipLabel(a),
                          ),
                        ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (status == 'pending')
                  FilledButton(
                    onPressed: () => _approveWithGroupDialog(link),
                    child: const Text('Aprobar'),
                  ),
                if (status == 'pending')
                  OutlinedButton(
                    onPressed: () => _review(link, 'rejected'),
                    child: const Text('Rechazar'),
                  ),
                if (status == 'approved')
                  FilledButton.tonal(
                    onPressed: () => context.push('/users/${link['student_user_id']}'),
                    child: const Text('Ver perfil'),
                  ),
                if (status == 'approved')
                  FilledButton.tonal(
                    onPressed: () => _openChat(link),
                    child: const Text('Enviar mensaje'),
                  ),
                if (status == 'approved')
                  OutlinedButton(
                    onPressed: () => _assignRoutine(link),
                    child: const Text('Asignar rutina'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _review(Map<String, dynamic> link, String status, {String? groupName}) async {
    try {
      await ref.read(apiClientProvider).reviewTeacherStudentLink(
            linkId: link['id'].toString(),
            status: status,
            groupName: groupName,
          );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Solicitud $status')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _approveWithGroupDialog(Map<String, dynamic> link) async {
    final groupController = TextEditingController(
      text: link['group_name']?.toString() ?? '',
    );
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Aprobar alumno'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Opcionalmente asigna un nombre de grupo para organizar a tus alumnos.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: groupController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del grupo',
                    hintText: 'Ej: Principiantes, Mañanas',
                  ),
                  onSubmitted: (_) => Navigator.of(ctx).pop(true),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Aprobar'),
              ),
            ],
          );
        },
      );
      if (confirmed == true && mounted) {
        await _review(link, 'approved', groupName: groupController.text.trim());
      }
    } finally {
      groupController.dispose();
    }
  }

  Future<void> _editGroupName(Map<String, dynamic> link) async {
    final current = link['group_name']?.toString() ?? '';
    final controller = TextEditingController(text: current);
    try {
      final value = await showDialog<String>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Nombre del grupo'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Ej: Principiantes',
              ),
              autofocus: true,
              onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(current),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      );
      if (value != null && mounted) {
        await ref.read(apiClientProvider).updateTeacherStudentLinkGroupName(
              linkId: link['id'].toString(),
              groupName: value.isEmpty ? null : value,
            );
        if (!mounted) return;
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grupo actualizado')),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _assignRoutine(Map<String, dynamic> link) async {
    final availableRoutines = _uniqueById(_routines);
    final routineOptions = <String, String>{
      for (final routine in availableRoutines)
        if ((routine['id']?.toString() ?? '').isNotEmpty)
          routine['id'].toString(): routine['name']?.toString() ?? 'Rutina',
    };
    if (routineOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero crea una rutina para poder asignarla.'),
        ),
      );
      return;
    }

    final studentUserId = link['student_user_id']?.toString();
    if (studentUserId == null || studentUserId.isEmpty) return;
    final notesController = TextEditingController();
    var routineId = routineOptions.keys.first;
    var submitting = false;
    var scheduleDays = <int>{};
    TimeOfDay? scheduleTime = const TimeOfDay(hour: 10, minute: 0);

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setLocalState) {
              Future<void> submit() async {
                if (submitting) return;
                setLocalState(() => submitting = true);
                try {
                  final daysList = scheduleDays.toList()..sort();
                  await ref.read(apiClientProvider).assignRoutineToStudent(
                        routineId: routineId,
                        studentUserId: studentUserId,
                        notes: notesController.text.trim().isEmpty
                            ? null
                            : notesController.text.trim(),
                        scheduleDays: daysList,
                        scheduleHour: scheduleTime?.hour,
                        scheduleMinute: scheduleTime?.minute ?? 0,
                      );
                  if (!dialogContext.mounted || !mounted) return;
                  Navigator.of(dialogContext).pop();
                  await _load();
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Rutina asignada correctamente.'),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  setLocalState(() => submitting = false);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }

              return AlertDialog(
                title: const Text('Asignar rutina'),
                content: SizedBox(
                  width: 440,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          value: routineId,
                          decoration:
                              const InputDecoration(labelText: 'Rutina'),
                          items: routineOptions.entries
                              .map(
                                (entry) => DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setLocalState(() => routineId = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        RoutineSchedulePickerSection(
                          daysTitle: '¿Qué días debe hacerla?',
                          daysHint:
                              'Opcional. Ejemplo: fuerza lunes, miércoles y viernes a las 10:00.',
                          timeSubtitle:
                              'El alumno lo verá en inicio y en Rutinas → Asignadas.',
                          selectedDays: scheduleDays,
                          onDaysChanged: (d) =>
                              setLocalState(() => scheduleDays = d),
                          selectedTime: scheduleTime,
                          onTimeChanged: (t) =>
                              setLocalState(() => scheduleTime = t),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: notesController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Notas para el alumno',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: submitting
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: submitting ? null : submit,
                    child: Text(submitting ? 'Asignando...' : 'Asignar'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      notesController.dispose();
    }
  }

  Future<void> _openChat(Map<String, dynamic> link) async {
    try {
      final conversation = await ref.read(apiClientProvider).ensureConversation(
            teacherUserId: link['teacher_user_id'].toString(),
            studentUserId: link['student_user_id'].toString(),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis alumnos'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (_links.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child:
                            Text('Todavía no tienes solicitudes ni alumnos.'),
                      ),
                    ),
                  ..._buildGroupedLinks(theme),
                ],
              ),
            ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
      ),
      child: Text(label),
    );
  }
}

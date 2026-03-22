import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:calistenia_app/core/router/student_shell_routes.dart';
import 'package:calistenia_app/features/admin/data/admin_api_client.dart';
import 'package:calistenia_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:calistenia_app/core/utils/user_display_name.dart';
import 'package:calistenia_app/features/exercises/domain/exercise_metadata.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _sectionIndex = 0;
  bool _bootstrapped = false;
  bool _loading = false;
  String? _error;
  String _userSearch = '';
  String _exerciseSearch = '';
  String _routineSearch = '';
  String _submissionSearch = '';
  String _teacherApplicationSearch = '';
  String? _exerciseTypeFilter;
  String? _exerciseOwnerUserIdFilter;
  String? _routineUserIdFilter;
  String? _selectedExerciseIdForMedia;

  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _exercises = const [];
  List<Map<String, dynamic>> _routines = const [];
  List<Map<String, dynamic>> _submissions = const [];
  List<Map<String, dynamic>> _teacherApplications = const [];
  List<Map<String, dynamic>> _progress = const [];
  List<Map<String, dynamic>> _mediaObjects = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = ref.read(authControllerProvider);
    if (!_bootstrapped && auth.isAuthenticated && auth.isAdmin) {
      _bootstrapped = true;
      _reloadAll();
    }
  }

  Future<void> _reloadAll() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(adminApiClientProvider);
      final criticalErrors = <String>[];

      Future<List<Map<String, dynamic>>> loadCritical(
        String label,
        Future<List<Map<String, dynamic>>> future,
      ) async {
        try {
          return await future;
        } catch (e) {
          criticalErrors.add('$label: $e');
          return const [];
        }
      }

      Future<List<Map<String, dynamic>>> loadOptional(
        Future<List<Map<String, dynamic>>> future,
      ) async {
        try {
          return await future;
        } catch (_) {
          return const [];
        }
      }

      final users = await loadCritical(
        'Usuarios',
        api.listUsers(accessToken: session.accessToken, search: _userSearch),
      );
      final exercises = await loadCritical(
        'Ejercicios',
        api.listExercises(
          accessToken: session.accessToken,
          search: _exerciseSearch,
          category: _exerciseTypeFilter,
          ownerUserId: _exerciseOwnerUserIdFilter,
        ),
      );
      final routines = await loadCritical(
        'Rutinas',
        api.listRoutines(
          accessToken: session.accessToken,
          search: _routineSearch,
          userId: _routineUserIdFilter,
        ),
      );
      final submissions = await loadCritical(
        'Propuestas',
        api.listExerciseSubmissions(
          accessToken: session.accessToken,
          search: _submissionSearch,
        ),
      );
      final teacherApplications = await loadCritical(
        'Solicitudes profesor',
        api.listTeacherApplications(
          accessToken: session.accessToken,
          search: _teacherApplicationSearch,
        ),
      );
      final progress = await loadOptional(
        api.listProgress(accessToken: session.accessToken, limit: 80),
      );
      final mediaObjects = await loadOptional(
        api.listMediaObjects(accessToken: session.accessToken),
      );

      if (!mounted) return;
      setState(() {
        _users = users;
        _exercises = exercises;
        _routines = routines;
        _submissions = submissions;
        _teacherApplications = teacherApplications;
        _progress = progress;
        _mediaObjects = mediaObjects;
        _error = criticalErrors.isEmpty ? null : criticalErrors.join('\n');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveUser(Map<String, dynamic> user) async {
    final payload = await _showUserEditor(user: user);
    if (payload == null) return;
    await _runMutation(
      message: 'Usuario actualizado',
      action: () {
        final session = ref.read(authControllerProvider).session!;
        return ref.read(adminApiClientProvider).updateUser(
              accessToken: session.accessToken,
              userId: user['id'].toString(),
              payload: payload,
            );
      },
    );
  }

  Future<void> _createOrEditExercise({Map<String, dynamic>? exercise}) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    final payload = await _showExerciseEditor(
      exercise: exercise,
      currentUserId: session.user.id,
    );
    if (payload == null) return;

    await _runMutation(
      message: exercise == null ? 'Ejercicio creado' : 'Ejercicio actualizado',
      action: () {
        final session = ref.read(authControllerProvider).session!;
        final api = ref.read(adminApiClientProvider);
        if (exercise == null) {
          return api.createExercise(
            accessToken: session.accessToken,
            payload: payload,
          );
        }
        return api.updateExercise(
          accessToken: session.accessToken,
          exerciseId: exercise['id'].toString(),
          payload: payload,
        );
      },
    );
  }

  Future<void> _deleteExercise(Map<String, dynamic> exercise) async {
    final confirmed = await _confirm(
      title: 'Eliminar ejercicio',
      message: 'Se eliminará "${exercise['name']}" de forma permanente.',
    );
    if (!confirmed) return;

    await _runMutation(
      message: 'Ejercicio eliminado',
      action: () {
        final session = ref.read(authControllerProvider).session!;
        return ref.read(adminApiClientProvider).deleteExercise(
              accessToken: session.accessToken,
              exerciseId: exercise['id'].toString(),
            );
      },
    );
  }

  Future<void> _createOrEditRoutine({Map<String, dynamic>? routine}) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    final payload = await _showRoutineEditor(
      routine: routine,
      currentUserId: session.user.id,
    );
    if (payload == null) return;

    await _runMutation(
      message: routine == null ? 'Rutina creada' : 'Rutina actualizada',
      action: () async {
        final api = ref.read(adminApiClientProvider);
        if (routine == null) {
          await api.createRoutine(
            accessToken: session.accessToken,
            payload: payload,
          );
        } else {
          await api.updateRoutine(
            accessToken: session.accessToken,
            routineId: routine['id'].toString(),
            payload: payload,
          );
        }
      },
    );
  }

  Future<void> _deleteRoutine(Map<String, dynamic> routine) async {
    final confirmed = await _confirm(
      title: 'Eliminar rutina',
      message: 'Se eliminará "${routine['name']}" y sus ejercicios asociados.',
    );
    if (!confirmed) return;

    await _runMutation(
      message: 'Rutina eliminada',
      action: () {
        final session = ref.read(authControllerProvider).session!;
        return ref.read(adminApiClientProvider).deleteRoutine(
              accessToken: session.accessToken,
              routineId: routine['id'].toString(),
            );
      },
    );
  }

  Future<void> _uploadExerciseAsset({
    required Map<String, dynamic> exercise,
    required String field,
    required String label,
    required List<String> allowedExtensions,
  }) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      _showSnack('No se pudieron leer los bytes del archivo.');
      return;
    }

    await _runMutation(
      message: '$label subido y vinculado al ejercicio',
      action: () async {
        final api = ref.read(adminApiClientProvider);
        final uploadedUrl = await api.uploadMedia(
          accessToken: session.accessToken,
          bytes: bytes,
          filename: file.name,
          contentType: _guessContentType(file.name),
        );
        await api.updateExercise(
          accessToken: session.accessToken,
          exerciseId: exercise['id'].toString(),
          payload: {field: uploadedUrl},
        );
      },
    );
  }

  Future<void> _copyText(String value) async {
    if (value.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    _showSnack('Copiado al portapapeles');
  }

  Future<void> _runMutation({
    required String message,
    required Future<dynamic> Function() action,
  }) async {
    try {
      setState(() => _loading = true);
      await action();
      await _reloadAll();
      if (!mounted) return;
      _showSnack(message);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    final value = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return value ?? false;
  }

  String _userLabel(String? userId) {
    if (userId == null || userId.isEmpty) return 'Sin asignar';
    final user = _users.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['id']?.toString() == userId,
          orElse: () => null,
        );
    return userDisplayNameFromJson(user, fallback: 'Usuario');
  }

  Future<String?> _askReviewNotes({
    required String title,
    required String actionLabel,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Notas de revisión',
              hintText: 'Opcional',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }


  Future<void> _approveSubmission(Map<String, dynamic> submission) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    final confirmed = await _confirm(
      title: 'Aprobar propuesta',
      message:
          'Se publicará "${submission['name']}" como ejercicio del catálogo.',
    );
    if (!confirmed) return;
    final reviewNotes = await _askReviewNotes(
      title: 'Notas de aprobación',
      actionLabel: 'Aprobar',
    );
    if (reviewNotes == null) return;

    await _runMutation(
      message: 'Propuesta aprobada y publicada',
      action: () {
        return ref.read(adminApiClientProvider).approveExerciseSubmission(
              accessToken: session.accessToken,
              submission: submission,
              reviewerUserId: session.user.id,
              reviewNotes: reviewNotes.isEmpty ? null : reviewNotes,
            );
      },
    );
  }

  Future<void> _rejectSubmission(Map<String, dynamic> submission) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    final reviewNotes = await _askReviewNotes(
      title: 'Rechazar propuesta',
      actionLabel: 'Rechazar',
    );
    if (reviewNotes == null) return;

    await _runMutation(
      message: 'Propuesta rechazada',
      action: () {
        return ref.read(adminApiClientProvider).rejectExerciseSubmission(
              accessToken: session.accessToken,
              submissionId: submission['id'].toString(),
              reviewerUserId: session.user.id,
              reviewNotes: reviewNotes.isEmpty ? null : reviewNotes,
            );
      },
    );
  }

  Future<void> _approveTeacherApplication(
      Map<String, dynamic> application) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    final confirmed = await _confirm(
      title: 'Aprobar profesor',
      message:
          'El usuario ${application['display_name'] ?? application['user_id']} pasará a rol teacher.',
    );
    if (!confirmed) return;
    final reviewNotes = await _askReviewNotes(
      title: 'Notas de aprobación',
      actionLabel: 'Aprobar',
    );
    if (reviewNotes == null) return;

    await _runMutation(
      message: 'Solicitud de profesor aprobada',
      action: () {
        return ref.read(adminApiClientProvider).approveTeacherApplication(
              accessToken: session.accessToken,
              reviewerUserId: session.user.id,
              application: application,
              reviewNotes: reviewNotes.isEmpty ? null : reviewNotes,
            );
      },
    );
  }

  Future<void> _rejectTeacherApplication(
      Map<String, dynamic> application) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    final reviewNotes = await _askReviewNotes(
      title: 'Rechazar profesor',
      actionLabel: 'Rechazar',
    );
    if (reviewNotes == null) return;

    await _runMutation(
      message: 'Solicitud de profesor rechazada',
      action: () {
        return ref.read(adminApiClientProvider).rejectTeacherApplication(
              accessToken: session.accessToken,
              reviewerUserId: session.user.id,
              applicationId: application['id'].toString(),
              userId: application['user_id'].toString(),
              reviewNotes: reviewNotes.isEmpty ? null : reviewNotes,
            );
      },
    );
  }

  Future<void> _showUserDetail(Map<String, dynamic> user) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      setState(() => _loading = true);
      final api = ref.read(adminApiClientProvider);
      final routines = await api.listRoutines(
        accessToken: session.accessToken,
        userId: user['id']?.toString(),
      );
      final submissions = await api.listExerciseSubmissions(
        accessToken: session.accessToken,
        userId: user['id']?.toString(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(user['email']?.toString() ?? 'Detalle de usuario'),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Rutinas: ${routines.length}'),
                  const SizedBox(height: 10),
                  if (routines.isEmpty)
                    const Text('Este usuario no tiene rutinas registradas.'),
                  ...routines.map(
                    (routine) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(routine['name']?.toString() ?? 'Sin nombre'),
                      subtitle: Text(
                        'Nivel ${routine['level'] ?? '-'} | ${routine['is_public'] == true ? 'pública' : 'privada'}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Propuestas: ${submissions.length}'),
                  const SizedBox(height: 10),
                  if (submissions.isEmpty)
                    const Text('Este usuario no ha enviado propuestas.'),
                  ...submissions.map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item['name']?.toString() ?? 'Sin nombre'),
                      subtitle: Text(
                        'Estado ${item['status'] ?? 'pending'} | ${item['category'] ?? '-'} | ${item['difficulty'] ?? '-'}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _routineUserIdFilter = user['id']?.toString();
                  _sectionIndex = 4;
                });
                _reloadAll();
              },
              child: const Text('Ver sus rutinas'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _showUserEditor({
    required Map<String, dynamic> user,
  }) async {
    final usernameController =
        TextEditingController(text: user['username']?.toString() ?? '');
    final emailController =
        TextEditingController(text: user['email']?.toString() ?? '');
    final levelController =
        TextEditingController(text: user['nivel']?.toString() ?? '');
    var role = user['role']?.toString() ?? 'user';
    var isActive = user['is_active'] as bool? ?? true;

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Editar usuario'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: emailController,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: 'Correo'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: levelController,
                      decoration: const InputDecoration(labelText: 'Nivel'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      items: const [
                        DropdownMenuItem(value: 'user', child: Text('user')),
                        DropdownMenuItem(
                          value: 'teacher',
                          child: Text('teacher'),
                        ),
                        DropdownMenuItem(
                          value: 'moderator',
                          child: Text('moderator'),
                        ),
                        DropdownMenuItem(value: 'admin', child: Text('admin')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setLocalState(() => role = value);
                      },
                      decoration: const InputDecoration(labelText: 'Rol'),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: isActive,
                      onChanged: (value) =>
                          setLocalState(() => isActive = value),
                      title: const Text('Usuario activo'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'username': usernameController.text.trim(),
                      'nivel': levelController.text.trim().isEmpty
                          ? null
                          : levelController.text.trim(),
                      'role': role,
                      'is_active': isActive,
                    });
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    usernameController.dispose();
    emailController.dispose();
    levelController.dispose();
    return payload;
  }

  Future<Map<String, dynamic>?> _showExerciseEditor({
    Map<String, dynamic>? exercise,
    required String currentUserId,
  }) async {
    final nameController =
        TextEditingController(text: exercise?['name']?.toString() ?? '');
    final descController =
        TextEditingController(text: exercise?['description']?.toString() ?? '');
    final musclesController = TextEditingController(
      text: ((exercise?['muscle_groups'] as List?) ?? const [])
          .map((item) => item.toString())
          .join(', '),
    );
    final durationController = TextEditingController(
      text: exercise?['duration_seconds']?.toString() ?? '',
    );
    final gifController =
        TextEditingController(text: exercise?['gif_url']?.toString() ?? '');
    final videoController =
        TextEditingController(text: exercise?['video_url']?.toString() ?? '');
    final thumbnailController = TextEditingController(
        text: exercise?['thumbnail_url']?.toString() ?? '');
    var category = exerciseCategories.contains(
      exercise?['category']?.toString(),
    )
        ? exercise!['category'].toString()
        : exerciseCategories.first;
    const customCategorySentinel = '__other__';
    final bool isCustomCategory = !exerciseCategories.contains(
      exercise?['category']?.toString(),
    );
    var useCustomCategory = isCustomCategory;
    final customCategoryController = TextEditingController(
      text: useCustomCategory ? category : '',
    );
    var difficulty = exerciseDifficulties.contains(
      exercise?['difficulty']?.toString(),
    )
        ? exercise!['difficulty'].toString()
        : exerciseDifficulties.first;
    var ownerUserId = exercise?['owner_user_id']?.toString() ?? currentUserId;
    final ownerOptions = <Map<String, dynamic>>[
      ..._users,
      if (_users.every((user) => user['id']?.toString() != ownerUserId))
        {
          'id': ownerUserId,
          'username': _userLabel(ownerUserId),
        },
    ];
    var isActive = exercise?['is_active'] as bool? ?? true;

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text(
                  exercise == null ? 'Nuevo ejercicio' : 'Editar ejercicio'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descController,
                        minLines: 3,
                        maxLines: 5,
                        decoration:
                            const InputDecoration(labelText: 'Descripción'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: useCustomCategory ? customCategorySentinel : category,
                        decoration:
                            const InputDecoration(labelText: 'Categoría'),
                        items: [
                          ...exerciseCategories
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(exerciseCategoryLabel(item)),
                              ),
                            ),
                          const DropdownMenuItem(
                            value: customCategorySentinel,
                            child: Text('Otro (escribe)'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          if (value == customCategorySentinel) {
                            setLocalState(() {
                              useCustomCategory = true;
                              category = customCategoryController.text.trim().isEmpty
                                  ? ''
                                  : customCategoryController.text.trim();
                            });
                            return;
                          }
                          setLocalState(() {
                            useCustomCategory = false;
                            category = value;
                            customCategoryController.text = '';
                          });
                        },
                      ),
                      if (useCustomCategory)
                        const SizedBox(height: 12),
                      if (useCustomCategory)
                        TextField(
                          controller: customCategoryController,
                          decoration: const InputDecoration(
                            labelText: 'Nueva categoría (escribe)',
                          ),
                          onChanged: (v) {
                            final trimmed = v.trim();
                            setLocalState(() => category = trimmed);
                          },
                        ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: difficulty,
                        decoration:
                            const InputDecoration(labelText: 'Dificultad'),
                        items: exerciseDifficulties
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(exerciseDifficultyLabel(item)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setLocalState(() => difficulty = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: musclesController,
                        decoration: const InputDecoration(
                          labelText: 'Grupos musculares separados por coma',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duración por serie (segundos)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: gifController,
                        decoration: const InputDecoration(labelText: 'GIF URL'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: videoController,
                        decoration:
                            const InputDecoration(labelText: 'Video URL'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: thumbnailController,
                        decoration:
                            const InputDecoration(labelText: 'Thumbnail URL'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: ownerOptions.any(
                          (user) => user['id']?.toString() == ownerUserId,
                        )
                            ? ownerUserId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Usuario propietario',
                        ),
                        items: ownerOptions
                            .map(
                              (user) => DropdownMenuItem<String>(
                                value: user['id']?.toString(),
                                child: Text(
                                  userDisplayNameFromJson(
                                    user,
                                    fallback: 'Usuario',
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null || value.isEmpty) return;
                          setLocalState(() => ownerUserId = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: isActive,
                        onChanged: (value) =>
                            setLocalState(() => isActive = value),
                        title: const Text('Activo'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final resolvedCategory = category.trim();
                    if (resolvedCategory.isEmpty) {
                      _showSnack(
                        'La categoría no puede estar vacía.',
                        isError: true,
                      );
                      return;
                    }

                    Navigator.of(context).pop({
                      'name': nameController.text.trim(),
                      'description': descController.text.trim(),
                      'category': resolvedCategory,
                      'difficulty': difficulty,
                      'muscle_groups': musclesController.text
                          .split(',')
                          .map((item) => item.trim())
                          .where((item) => item.isNotEmpty)
                          .toList(),
                      'duration_seconds':
                          int.tryParse(durationController.text.trim()),
                      'gif_url': gifController.text.trim().isEmpty
                          ? null
                          : gifController.text.trim(),
                      'video_url': videoController.text.trim().isEmpty
                          ? null
                          : videoController.text.trim(),
                      'thumbnail_url': thumbnailController.text.trim().isEmpty
                          ? null
                          : thumbnailController.text.trim(),
                      'owner_user_id': ownerUserId.isEmpty
                          ? currentUserId
                          : ownerUserId,
                      'is_active': isActive,
                    });
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descController.dispose();
    musclesController.dispose();
    durationController.dispose();
    gifController.dispose();
    videoController.dispose();
    thumbnailController.dispose();
    customCategoryController.dispose();
    return payload;
  }

  Future<Map<String, dynamic>?> _showRoutineEditor({
    Map<String, dynamic>? routine,
    required String currentUserId,
  }) async {
    final nameController =
        TextEditingController(text: routine?['name']?.toString() ?? '');
    final descController =
        TextEditingController(text: routine?['description']?.toString() ?? '');
    final levelController =
        TextEditingController(text: routine?['level']?.toString() ?? '');
    final ownerController = TextEditingController(
      text: routine?['user_id']?.toString() ?? currentUserId,
    );
    var isPublic = routine?['is_public'] as bool? ?? false;

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text(routine == null ? 'Nueva rutina' : 'Editar rutina'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descController,
                        minLines: 3,
                        maxLines: 5,
                        decoration:
                            const InputDecoration(labelText: 'Descripción'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: levelController,
                        decoration: const InputDecoration(labelText: 'Nivel'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: ownerController,
                        decoration:
                            const InputDecoration(labelText: 'User ID dueño'),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: isPublic,
                        onChanged: (value) =>
                            setLocalState(() => isPublic = value),
                        title: const Text('Visible públicamente'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'user_id': ownerController.text.trim().isEmpty
                          ? currentUserId
                          : ownerController.text.trim(),
                      'name': nameController.text.trim(),
                      'description': descController.text.trim(),
                      'level': levelController.text.trim().isEmpty
                          ? 'principiante'
                          : levelController.text.trim(),
                      'is_public': isPublic,
                    });
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descController.dispose();
    levelController.dispose();
    ownerController.dispose();
    return payload;
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final session = auth.session;

    if (session == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!auth.isAdmin) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'No tienes acceso a este panel.',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Solo los usuarios con rol admin o moderator pueden usar el dashboard.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.go(StudentShellRoutes.home),
                      child: const Text('Ir a la app'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final totalMinutes = _progress.fold<int>(
      0,
      (sum, item) =>
          sum + (((item['duration_seconds'] as num?) ?? 0) / 60).round(),
    );
    final adminCount = _users.where((user) {
      final role = user['role']?.toString() ?? '';
      return role == 'admin' || role == 'moderator';
    }).length;
    final pendingSubmissions = _submissions
        .where((item) => item['status']?.toString() == 'pending')
        .length;
    final pendingTeacherApplications = _teacherApplications
        .where((item) => item['status']?.toString() == 'pending')
        .length;

    final sections = [
      _buildDashboard(theme,
          totalMinutes: totalMinutes,
          adminCount: adminCount,
          pendingSubmissions: pendingSubmissions,
          pendingTeacherApplications: pendingTeacherApplications),
      _buildUsers(theme),
      _buildExercises(theme),
      _buildMedia(theme),
      _buildRoutines(theme),
      _buildSubmissions(theme),
      _buildTeacherApplications(theme),
    ];

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 292,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              color: const Color(0xFF111318),
              border: Border(
                right: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calistry Admin',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  session.user.email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rol: ${session.user.role}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF00FF87),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final entry in _adminSections.indexed)
                        _NavItem(
                          icon: entry.$2.icon,
                          label: entry.$2.label,
                          selected: _sectionIndex == entry.$1,
                          onTap: () => setState(() => _sectionIndex = entry.$1),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _reloadAll,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refrescar'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: auth.busy
                        ? null
                        : () => ref.read(authControllerProvider).logout(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF0C0D10),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF16191E).withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _adminSections[_sectionIndex].headline,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (_loading)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Card(
                        color: theme.colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline),
                              const SizedBox(width: 12),
                              Expanded(child: Text(_error!)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _reloadAll,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        children: [
                          sections[_sectionIndex],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget? _buildFloatingActionButton() {
    switch (_sectionIndex) {
      case 2:
        return FloatingActionButton.extended(
          onPressed: () => _createOrEditExercise(),
          label: const Text('Nuevo ejercicio'),
          icon: const Icon(Icons.add),
        );
      case 4:
        return FloatingActionButton.extended(
          onPressed: () => _createOrEditRoutine(),
          label: const Text('Nueva rutina'),
          icon: const Icon(Icons.add),
        );
      default:
        return null;
    }
  }

  Widget _buildDashboard(
    ThemeData theme, {
    required int totalMinutes,
    required int adminCount,
    required int pendingSubmissions,
    required int pendingTeacherApplications,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _MetricCard(
              title: 'Usuarios',
              value: '${_users.length}',
              subtitle: '$adminCount con rol admin/moderator',
              accent: const Color(0xFF00FF87),
            ),
            _MetricCard(
              title: 'Ejercicios',
              value: '${_exercises.length}',
              subtitle:
                  '${_exercises.where((e) => e['is_active'] == true).length} activos',
              accent: const Color(0xFFFF9567),
            ),
            _MetricCard(
              title: 'Rutinas',
              value: '${_routines.length}',
              subtitle:
                  '${_routines.where((r) => r['is_public'] == true).length} públicas',
              accent: const Color(0xFF7AD6FF),
            ),
            _MetricCard(
              title: 'Media',
              value: '${_mediaObjects.length}',
              subtitle: '$totalMinutes minutos registrados',
              accent: const Color(0xFFE3A6FF),
            ),
            _MetricCard(
              title: 'Propuestas',
              value: '${_submissions.length}',
              subtitle: '$pendingSubmissions pendientes',
              accent: const Color(0xFFFFD36B),
            ),
            _MetricCard(
              title: 'Profesores',
              value: '${_teacherApplications.length}',
              subtitle: '$pendingTeacherApplications por revisar',
              accent: const Color(0xFFA6B8FF),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _PanelCard(
                title: 'Actividad reciente',
                child: _progress.isEmpty
                    ? const Text('Todavía no hay sesiones registradas.')
                    : Column(
                        children: _progress.take(8).map((item) {
                          final completedAt =
                              item['completed_at']?.toString() ?? '';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              child: Icon(Icons.bolt),
                            ),
                            title: Text('Rutina ${item['routine_id']}'),
                            subtitle: Text(
                              completedAt.isEmpty
                                  ? 'Sin fecha'
                                  : completedAt.replaceFirst('T', ' '),
                            ),
                            trailing: Text(
                              '${((item['duration_seconds'] as num?) ?? 0).round()} s',
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _PanelCard(
                title: 'Media reciente',
                child: _mediaObjects.isEmpty
                    ? const Text('No hay objetos subidos todavía.')
                    : Column(
                        children: _mediaObjects.take(8).map((item) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item['key']?.toString() ?? ''),
                            subtitle: Text(
                              '${item['size'] ?? 0} bytes',
                              maxLines: 1,
                            ),
                            trailing: IconButton(
                              onPressed: () =>
                                  _copyText(item['url']?.toString() ?? ''),
                              icon: const Icon(Icons.copy),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUsers(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SearchHeader(
          hintText: 'Buscar usuario por correo o username',
          initialValue: _userSearch,
          onSearch: (value) {
            setState(() => _userSearch = value);
            _reloadAll();
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Usuarios cargados: ${_users.length}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_users.isEmpty)
          const _EmptyState(message: 'No hay usuarios que mostrar.'),
        ..._users.map((user) {
          final role = user['role']?.toString() ?? 'user';
          final isActive = user['is_active'] == true;
          final email = user['email']?.toString() ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Username: ${user['username'] ?? '-'}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Nivel: ${user['nivel'] ?? '-'}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Rol: $role | Estado: ${isActive ? 'activo' : 'bloqueado'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton(
                          onPressed: () => _saveUser(user),
                          child: const Text('Editar'),
                        ),
                        FilledButton.tonal(
                          onPressed: () => _showUserDetail(user),
                          child: const Text('Ver detalle'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildExercises(ThemeData theme) {
    final categories = <String>[
      ...exerciseCategories,
      if (_exerciseTypeFilter != null &&
          _exerciseTypeFilter!.isNotEmpty &&
          !exerciseCategories.contains(_exerciseTypeFilter))
        _exerciseTypeFilter!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SearchHeader(
          hintText: 'Buscar ejercicio por nombre',
          initialValue: _exerciseSearch,
          onSearch: (value) {
            setState(() => _exerciseSearch = value);
            _reloadAll();
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _exerciseTypeFilter,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Todas las categorías'),
                  ),
                  ...categories.map(
                    (type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(exerciseCategoryLabel(type)),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    setState(() => _exerciseTypeFilter = null);
                    _reloadAll();
                    return;
                  }
                  setState(() => _exerciseTypeFilter = value);
                  _reloadAll();
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _exerciseOwnerUserIdFilter,
                decoration: const InputDecoration(
                  labelText: 'Propietario',
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Todos los propietarios'),
                  ),
                  ..._users.map(
                    (user) => DropdownMenuItem<String>(
                      value: user['id']?.toString(),
                      child: Text(_userLabel(user['id']?.toString())),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _exerciseOwnerUserIdFilter = value);
                  _reloadAll();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Ejercicios cargados: ${_exercises.length}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_exercises.isEmpty)
          const _EmptyState(message: 'No hay ejercicios que mostrar.'),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _exercises.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.74,
          ),
          itemBuilder: (context, index) {
            final exercise = _exercises[index];
            final muscles =
                ((exercise['muscle_groups'] as List?) ?? const []).map((e) {
              return e.toString();
            }).join(', ');
            final isActive = exercise['is_active'] == true;
            final thumbUrl = exercise['thumbnail_url']?.toString() ?? '';
            final gifUrl = exercise['gif_url']?.toString() ?? '';
            final videoUrl = exercise['video_url']?.toString() ?? '';
            final previewUrl = thumbUrl.isNotEmpty
                ? thumbUrl
                : (gifUrl.isNotEmpty ? gifUrl : (videoUrl.isNotEmpty ? videoUrl : ''));
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: previewUrl.isEmpty
                            ? Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                                alignment: Alignment.center,
                                child: const Icon(Icons.image_not_supported_outlined),
                              )
                            : Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    previewUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                                  if (videoUrl.isNotEmpty)
                                    Align(
                                      alignment: Alignment.center,
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.48),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            exercise['name']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _StatusChip(
                          label: isActive ? 'activo' : 'inactivo',
                          color: isActive
                              ? const Color(0xFF00FF87)
                              : const Color(0xFFFF4444),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      exercise['description']?.toString() ?? 'Sin descripción',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MiniMeta(
                          label: 'Tipo',
                          value: exerciseCategoryLabel(
                              exercise['category']?.toString() ?? '-'),
                        ),
                        _MiniMeta(
                          label: 'Dificultad',
                          value: exerciseDifficultyLabel(
                              exercise['difficulty']?.toString() ?? '-'),
                        ),
                        _MiniMeta(
                          label: 'Prop.',
                          value: _userLabel(
                            exercise['owner_user_id']?.toString(),
                          ),
                        ),
                        if (muscles.isNotEmpty)
                          _MiniMeta(
                            label: 'Músculos',
                            value: muscles.length > 22
                                ? '${muscles.substring(0, 22)}...'
                                : muscles,
                          ),
                        _MiniMeta(
                          label: 'Duración',
                          value:
                              "${exercise['duration_seconds'] ?? '-'} s",
                        ),
                      ],
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        OutlinedButton(
                          onPressed: () =>
                              _createOrEditExercise(exercise: exercise),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          child: const Text('Editar'),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedExerciseIdForMedia =
                                  exercise['id']?.toString();
                              _sectionIndex = 3;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          child: const Text('Media'),
                        ),
                        TextButton(
                          onPressed: () => _deleteExercise(exercise),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            foregroundColor: Colors.white70,
                          ),
                          child: const Text('Eliminar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMedia(ThemeData theme) {
    final filteredExercises = _selectedExerciseIdForMedia == null
        ? _exercises
        : _exercises
            .where((exercise) =>
                exercise['id']?.toString() == _selectedExerciseIdForMedia)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedExerciseIdForMedia != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _selectedExerciseIdForMedia = null),
                icon: const Icon(Icons.close),
                label: const Text('Mostrar todos los ejercicios'),
              ),
            ),
          ),
        if (filteredExercises.isEmpty)
          const _EmptyState(
              message: 'No hay ejercicios disponibles para media.'),
        ...filteredExercises.map((exercise) {
          final gifUrl = exercise['gif_url']?.toString() ?? '';
          final videoUrl = exercise['video_url']?.toString() ?? '';
          final thumbUrl = exercise['thumbnail_url']?.toString() ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise['name']?.toString() ?? '',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _MediaBlock(
                            title: 'GIF',
                            value: gifUrl,
                            emptyText: 'Este ejercicio todavía no tiene GIF.',
                            onUpload: () => _uploadExerciseAsset(
                              exercise: exercise,
                              field: 'gif_url',
                              label: 'GIF',
                              allowedExtensions: const [
                                'gif',
                                'webp',
                                'png',
                                'jpg',
                                'jpeg'
                              ],
                            ),
                            onCopy:
                                gifUrl.isEmpty ? null : () => _copyText(gifUrl),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _MediaBlock(
                            title: 'Video',
                            value: videoUrl,
                            emptyText: 'Este ejercicio todavía no tiene vídeo.',
                            onUpload: () => _uploadExerciseAsset(
                              exercise: exercise,
                              field: 'video_url',
                              label: 'Vídeo',
                              allowedExtensions: const ['mp4', 'webm', 'mov'],
                            ),
                            onCopy: videoUrl.isEmpty
                                ? null
                                : () => _copyText(videoUrl),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _MiniMeta(
                      label: 'Thumbnail',
                      value: thumbUrl.isEmpty ? '-' : thumbUrl,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () =>
                          _createOrEditExercise(exercise: exercise),
                      child: const Text('Editar URLs manualmente'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRoutines(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SearchHeader(
          hintText: 'Buscar rutina por nombre',
          initialValue: _routineSearch,
          onSearch: (value) {
            setState(() => _routineSearch = value);
            _reloadAll();
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _routineUserIdFilter,
          decoration: const InputDecoration(
            labelText: 'Filtrar por usuario',
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Todos los usuarios'),
            ),
            ..._users.map(
              (user) => DropdownMenuItem<String>(
                value: user['id']?.toString(),
                child: Text(_userLabel(user['id']?.toString())),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() => _routineUserIdFilter = value);
            _reloadAll();
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Rutinas cargadas: ${_routines.length}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_routines.isEmpty)
          const _EmptyState(message: 'No hay rutinas disponibles.'),
        ..._routines.map((routine) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routine['name']?.toString() ?? '',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StatusChip(
                      label:
                          routine['is_public'] == true ? 'pública' : 'privada',
                      color: routine['is_public'] == true
                          ? const Color(0xFF00FF87)
                          : const Color(0xFFFF9567),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      routine['description']?.toString() ?? 'Sin descripción',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Nivel: ${routine['level']?.toString() ?? '-'}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Owner: ${_userLabel(routine['user_id']?.toString())}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Creada: ${routine['created_at']?.toString() ?? '-'}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton(
                          onPressed: () =>
                              _createOrEditRoutine(routine: routine),
                          child: const Text('Editar'),
                        ),
                        TextButton(
                          onPressed: () => _deleteRoutine(routine),
                          child: const Text('Eliminar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSubmissions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SearchHeader(
          hintText: 'Buscar propuesta por nombre',
          initialValue: _submissionSearch,
          onSearch: (value) {
            setState(() => _submissionSearch = value);
            _reloadAll();
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Propuestas cargadas: ${_submissions.length}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_submissions.isEmpty)
          const _EmptyState(
              message: 'No hay propuestas pendientes o históricas.'),
        ..._submissions.map((submission) {
          final muscles = ((submission['muscle_groups'] as List?) ?? const [])
              .map((item) => item.toString())
              .join(', ');
          final status = submission['status']?.toString() ?? 'pending';
          final publishedExerciseId =
              submission['published_exercise_id']?.toString() ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      submission['name']?.toString() ?? '',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StatusChip(
                      label: status,
                      color: switch (status) {
                        'approved' => const Color(0xFF00FF87),
                        'rejected' => const Color(0xFFFF4444),
                        _ => const Color(0xFFFFD36B),
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      submission['description']?.toString() ??
                          'Sin descripción',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Propuesto por: ${_userLabel(submission['proposed_by_user_id']?.toString())}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Categoría: ${exerciseCategoryLabel(submission['category']?.toString() ?? '-')} | Dificultad: ${exerciseDifficultyLabel(submission['difficulty']?.toString() ?? '-')}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Músculos: ${muscles.isEmpty ? '-' : muscles}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Review: ${submission['review_notes']?.toString().isNotEmpty == true ? submission['review_notes'] : '-'}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (publishedExerciseId.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Publicado como ejercicio: $publishedExerciseId',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (status == 'pending')
                          FilledButton(
                            onPressed: () => _approveSubmission(submission),
                            child: const Text('Aprobar'),
                          ),
                        if (status == 'pending')
                          OutlinedButton(
                            onPressed: () => _rejectSubmission(submission),
                            child: const Text('Rechazar'),
                          ),
                        if (submission['proposed_by_user_id'] != null)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _routineUserIdFilter =
                                    submission['proposed_by_user_id']
                                        .toString();
                                _sectionIndex = 4;
                              });
                              _reloadAll();
                            },
                            child: const Text('Ver rutinas del usuario'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTeacherApplications(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SearchHeader(
          hintText: 'Buscar solicitud de profesor',
          initialValue: _teacherApplicationSearch,
          onSearch: (value) {
            setState(() => _teacherApplicationSearch = value);
            _reloadAll();
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Solicitudes de profesor: ${_teacherApplications.length}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_teacherApplications.isEmpty)
          const _EmptyState(message: 'No hay solicitudes de profesor.'),
        ..._teacherApplications.map((application) {
          final status = application['status']?.toString() ?? 'pending';
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application['display_name']?.toString() ?? 'Sin nombre',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StatusChip(
                      label: status,
                      color: switch (status) {
                        'approved' => const Color(0xFF00FF87),
                        'rejected' => const Color(0xFFFF4444),
                        _ => const Color(0xFFA6B8FF),
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Usuario: ${_userLabel(application['user_id']?.toString())}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Especialidad: ${application['specialty']?.toString().isNotEmpty == true ? application['specialty'] : '-'}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      application['bio']?.toString().isNotEmpty == true
                          ? application['bio'].toString()
                          : 'Sin biografía',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Motivación: ${application['motivation']?.toString().isNotEmpty == true ? application['motivation'] : '-'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Review: ${application['review_notes']?.toString().isNotEmpty == true ? application['review_notes'] : '-'}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (status == 'pending')
                          FilledButton(
                            onPressed: () =>
                                _approveTeacherApplication(application),
                            child: const Text('Aprobar profesor'),
                          ),
                        if (status == 'pending')
                          OutlinedButton(
                            onPressed: () =>
                                _rejectTeacherApplication(application),
                            child: const Text('Rechazar'),
                          ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _userSearch = application['display_name']
                                          ?.toString()
                                          .trim()
                                          .isNotEmpty ==
                                      true
                                  ? application['display_name'].toString()
                                  : application['user_id'].toString();
                              _sectionIndex = 1;
                            });
                            _reloadAll();
                          },
                          child: const Text('Ir al usuario'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  String _guessContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return 'video/mp4';
  }
}

class _SearchHeader extends StatefulWidget {
  const _SearchHeader({
    required this.hintText,
    required this.initialValue,
    required this.onSearch,
  });

  final String hintText;
  final String initialValue;
  final ValueChanged<String> onSearch;

  @override
  State<_SearchHeader> createState() => _SearchHeaderState();
}

class _SearchHeaderState extends State<_SearchHeader> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _SearchHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.search),
          ),
          onSubmitted: widget.onSearch,
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: () => widget.onSearch(_controller.text.trim()),
            child: const Text('Buscar'),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white60,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? const Color(0xFF00FF87).withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: selected
                  ? const Color(0xFF00FF87).withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          leading: Icon(
            icon,
            color: selected ? const Color(0xFF00FF87) : Colors.white70,
          ),
          title: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

class _MiniMeta extends StatelessWidget {
  const _MiniMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: Colors.white54),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _MediaBlock extends StatelessWidget {
  const _MediaBlock({
    required this.title,
    required this.value,
    required this.emptyText,
    required this.onUpload,
    this.onCopy,
  });

  final String title;
  final String value;
  final String emptyText;
  final VoidCallback onUpload;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value.isEmpty ? emptyText : value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onUpload,
                icon: const Icon(Icons.upload),
                label: Text('Subir $title'),
              ),
              if (onCopy != null)
                OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar URL'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            const Icon(Icons.inbox_outlined),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class _AdminSectionMeta {
  const _AdminSectionMeta({
    required this.label,
    required this.headline,
    required this.icon,
  });

  final String label;
  final String headline;
  final IconData icon;
}

const _adminSections = [
  _AdminSectionMeta(
    label: 'Dashboard',
    headline: 'Visión general del proyecto',
    icon: Icons.grid_view_rounded,
  ),
  _AdminSectionMeta(
    label: 'Usuarios',
    headline: 'Gestión de usuarios y roles',
    icon: Icons.people_alt_outlined,
  ),
  _AdminSectionMeta(
    label: 'Ejercicios',
    headline: 'Catálogo de ejercicios',
    icon: Icons.fitness_center_outlined,
  ),
  _AdminSectionMeta(
    label: 'Media',
    headline: 'GIF, vídeo y assets del ejercicio',
    icon: Icons.video_library_outlined,
  ),
  _AdminSectionMeta(
    label: 'Rutinas',
    headline: 'Biblioteca de rutinas',
    icon: Icons.view_list_outlined,
  ),
  _AdminSectionMeta(
    label: 'Propuestas',
    headline: 'Revisión de ejercicios propuestos',
    icon: Icons.fact_check_outlined,
  ),
  _AdminSectionMeta(
    label: 'Profesores',
    headline: 'Aprobación de solicitudes de profesor',
    icon: Icons.school_outlined,
  ),
];

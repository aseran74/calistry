import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/admin_auth_controller.dart';

class AdminShellScreen extends ConsumerStatefulWidget {
  const AdminShellScreen({super.key});

  @override
  ConsumerState<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends ConsumerState<AdminShellScreen> {
  int _sectionIndex = 0;
  bool _bootstrapped = false;
  bool _loading = false;
  String? _error;
  String _userSearch = '';
  String _exerciseSearch = '';
  String _routineSearch = '';
  String? _selectedExerciseIdForVideo;

  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _exercises = const [];
  List<Map<String, dynamic>> _routines = const [];
  List<Map<String, dynamic>> _progress = const [];
  List<Map<String, dynamic>> _mediaObjects = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = ref.read(adminAuthControllerProvider).session;
    if (!_bootstrapped && session != null) {
      _bootstrapped = true;
      _reloadAll();
    }
  }

  Future<void> _reloadAll() async {
    final session = ref.read(adminAuthControllerProvider).session;
    if (session == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(adminApiClientProvider);
      final results = await Future.wait<dynamic>([
        api.listUsers(accessToken: session.accessToken, search: _userSearch),
        api.listExercises(
          accessToken: session.accessToken,
          search: _exerciseSearch,
        ),
        api.listRoutines(
          accessToken: session.accessToken,
          search: _routineSearch,
        ),
        api.listProgress(accessToken: session.accessToken, limit: 80),
        api.listMediaObjects(accessToken: session.accessToken),
      ]);
      if (!mounted) return;
      setState(() {
        _users = List<Map<String, dynamic>>.from(results[0] as List);
        _exercises = List<Map<String, dynamic>>.from(results[1] as List);
        _routines = List<Map<String, dynamic>>.from(results[2] as List);
        _progress = List<Map<String, dynamic>>.from(results[3] as List);
        _mediaObjects = List<Map<String, dynamic>>.from(results[4] as List);
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
        final session = ref.read(adminAuthControllerProvider).session!;
        return ref.read(adminApiClientProvider).updateUser(
              accessToken: session.accessToken,
              userId: user['id'].toString(),
              payload: payload,
            );
      },
    );
  }

  Future<void> _createOrEditExercise({Map<String, dynamic>? exercise}) async {
    final payload = await _showExerciseEditor(exercise: exercise);
    if (payload == null) return;

    await _runMutation(
      message: exercise == null ? 'Ejercicio creado' : 'Ejercicio actualizado',
      action: () {
        final session = ref.read(adminAuthControllerProvider).session!;
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
      message: 'Se eliminará `${exercise['name']}` de forma permanente.',
    );
    if (!confirmed) return;

    await _runMutation(
      message: 'Ejercicio eliminado',
      action: () {
        final session = ref.read(adminAuthControllerProvider).session!;
        return ref.read(adminApiClientProvider).deleteExercise(
              accessToken: session.accessToken,
              exerciseId: exercise['id'].toString(),
            );
      },
    );
  }

  Future<void> _createOrEditRoutine({Map<String, dynamic>? routine}) async {
    final session = ref.read(adminAuthControllerProvider).session;
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
      message: 'Se eliminará `${routine['name']}` y sus ejercicios asociados.',
    );
    if (!confirmed) return;

    await _runMutation(
      message: 'Rutina eliminada',
      action: () {
        final session = ref.read(adminAuthControllerProvider).session!;
        return ref.read(adminApiClientProvider).deleteRoutine(
              accessToken: session.accessToken,
              routineId: routine['id'].toString(),
            );
      },
    );
  }

  Future<void> _uploadVideo(Map<String, dynamic> exercise) async {
    final session = ref.read(adminAuthControllerProvider).session;
    if (session == null) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp4', 'webm', 'mov'],
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
      message: 'Vídeo subido y vinculado al ejercicio',
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
          payload: {'video_url': uploadedUrl},
        );
      },
    );
  }

  Future<void> _copyText(String value) async {
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
  }) async {
    final nameController =
        TextEditingController(text: exercise?['name']?.toString() ?? '');
    final descController =
        TextEditingController(text: exercise?['description']?.toString() ?? '');
    final categoryController =
        TextEditingController(text: exercise?['category']?.toString() ?? '');
    final difficultyController =
        TextEditingController(text: exercise?['difficulty']?.toString() ?? '');
    final musclesController = TextEditingController(
      text: ((exercise?['muscle_groups'] as List?) ?? const [])
          .map((item) => item.toString())
          .join(', '),
    );
    final durationController = TextEditingController(
      text: exercise?['duration_seconds']?.toString() ?? '',
    );
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
                        controller: categoryController,
                        decoration:
                            const InputDecoration(labelText: 'Categoría'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: difficultyController,
                        decoration:
                            const InputDecoration(labelText: 'Dificultad'),
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
                    Navigator.of(context).pop({
                      'name': nameController.text.trim(),
                      'description': descController.text.trim(),
                      'category': categoryController.text.trim(),
                      'difficulty': difficultyController.text.trim().isEmpty
                          ? 'principiante'
                          : difficultyController.text.trim(),
                      'muscle_groups': musclesController.text
                          .split(',')
                          .map((item) => item.trim())
                          .where((item) => item.isNotEmpty)
                          .toList(),
                      'duration_seconds':
                          int.tryParse(durationController.text.trim()),
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
    categoryController.dispose();
    difficultyController.dispose();
    musclesController.dispose();
    durationController.dispose();
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
    final auth = ref.watch(adminAuthControllerProvider);
    final session = auth.session;

    if (session == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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

    final sections = [
      _buildDashboard(theme,
          totalMinutes: totalMinutes, adminCount: adminCount),
      _buildUsers(theme),
      _buildExercises(theme),
      _buildVideos(theme),
      _buildRoutines(theme),
    ];

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 280,
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
                    color: const Color(0xFFB5FF67),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: Column(
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
                FilledButton.icon(
                  onPressed: _loading ? null : _reloadAll,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refrescar'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: auth.busy
                      ? null
                      : () => ref.read(adminAuthControllerProvider).logout(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
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
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: sections[_sectionIndex],
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

  Widget _buildDashboard(ThemeData theme,
      {required int totalMinutes, required int adminCount}) {
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
              accent: const Color(0xFFB5FF67),
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
        if (_users.isEmpty)
          const _EmptyState(message: 'No hay usuarios que mostrar.'),
        ..._users.map((user) {
          final role = user['role']?.toString() ?? 'user';
          final isActive = user['is_active'] == true;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          const Color(0xFFB5FF67).withValues(alpha: 0.18),
                      child: Text(
                        (((user['email']?.toString() ?? '').isNotEmpty)
                                ? user['email'].toString()[0]
                                : '?')
                            .toUpperCase(),
                        style: const TextStyle(color: Color(0xFFB5FF67)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['email']?.toString() ?? '',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'username: ${user['username'] ?? '-'}  |  nivel: ${user['nivel'] ?? '-'}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusChip(
                      label: role,
                      color: role == 'admin'
                          ? const Color(0xFFB5FF67)
                          : role == 'moderator'
                              ? const Color(0xFF7AD6FF)
                              : const Color(0xFFFF9567),
                    ),
                    const SizedBox(width: 12),
                    _StatusChip(
                      label: isActive ? 'activo' : 'bloqueado',
                      color: isActive
                          ? const Color(0xFF7AD6FF)
                          : const Color(0xFFE26B6B),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => _saveUser(user),
                      child: const Text('Editar'),
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
        if (_exercises.isEmpty)
          const _EmptyState(message: 'No hay ejercicios que mostrar.'),
        ..._exercises.map((exercise) {
          final muscles = ((exercise['muscle_groups'] as List?) ?? const [])
              .map((item) => item.toString())
              .join(', ');
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            exercise['name']?.toString() ?? '',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _StatusChip(
                          label: exercise['is_active'] == true
                              ? 'activo'
                              : 'inactivo',
                          color: exercise['is_active'] == true
                              ? const Color(0xFFB5FF67)
                              : const Color(0xFFE26B6B),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      exercise['description']?.toString() ?? 'Sin descripción',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _MiniMeta(
                            label: 'Categoría',
                            value: exercise['category']?.toString() ?? '-'),
                        _MiniMeta(
                            label: 'Dificultad',
                            value: exercise['difficulty']?.toString() ?? '-'),
                        _MiniMeta(
                            label: 'Músculos',
                            value: muscles.isEmpty ? '-' : muscles),
                        _MiniMeta(
                          label: 'Duración',
                          value: '${exercise['duration_seconds'] ?? '-'} s',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () =>
                              _createOrEditExercise(exercise: exercise),
                          child: const Text('Editar'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedExerciseIdForVideo =
                                  exercise['id']?.toString();
                              _sectionIndex = 3;
                            });
                          },
                          child: const Text('Vídeo'),
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: () => _deleteExercise(exercise),
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

  Widget _buildVideos(ThemeData theme) {
    final filteredExercises = _selectedExerciseIdForVideo == null
        ? _exercises
        : _exercises
            .where((exercise) =>
                exercise['id']?.toString() == _selectedExerciseIdForVideo)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedExerciseIdForVideo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _selectedExerciseIdForVideo = null),
                icon: const Icon(Icons.close),
                label: const Text('Mostrar todos los ejercicios'),
              ),
            ),
          ),
        if (filteredExercises.isEmpty)
          const _EmptyState(
              message: 'No hay ejercicios disponibles para vídeos.'),
        ...filteredExercises.map((exercise) {
          final videoUrl = exercise['video_url']?.toString();
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
                    const SizedBox(height: 8),
                    Text(
                      videoUrl?.isNotEmpty == true
                          ? videoUrl!
                          : 'Este ejercicio todavía no tiene vídeo.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _uploadVideo(exercise),
                          icon: const Icon(Icons.upload),
                          label: const Text('Subir vídeo'),
                        ),
                        if (videoUrl?.isNotEmpty == true)
                          OutlinedButton.icon(
                            onPressed: () => _copyText(videoUrl!),
                            icon: const Icon(Icons.copy),
                            label: const Text('Copiar URL'),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            routine['name']?.toString() ?? '',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _StatusChip(
                          label: routine['is_public'] == true
                              ? 'pública'
                              : 'privada',
                          color: routine['is_public'] == true
                              ? const Color(0xFFB5FF67)
                              : const Color(0xFFFF9567),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      routine['description']?.toString() ?? 'Sin descripción',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _MiniMeta(
                            label: 'Nivel',
                            value: routine['level']?.toString() ?? '-'),
                        _MiniMeta(
                            label: 'Owner',
                            value: routine['user_id']?.toString() ?? '-'),
                        _MiniMeta(
                            label: 'Creada',
                            value: routine['created_at']?.toString() ?? '-'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () =>
                              _createOrEditRoutine(routine: routine),
                          child: const Text('Editar'),
                        ),
                        const SizedBox(width: 10),
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

  String _guessContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.mov')) return 'video/quicktime';
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
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: const Icon(Icons.search),
            ),
            onSubmitted: widget.onSearch,
          ),
        ),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: () => widget.onSearch(_controller.text.trim()),
          child: const Text('Buscar'),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFB5FF67).withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? const Color(0xFFB5FF67).withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? const Color(0xFFB5FF67) : Colors.white70,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
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
    label: 'Vídeos',
    headline: 'Media y subida de vídeos',
    icon: Icons.video_library_outlined,
  ),
  _AdminSectionMeta(
    label: 'Rutinas',
    headline: 'Biblioteca de rutinas',
    icon: Icons.view_list_outlined,
  ),
];

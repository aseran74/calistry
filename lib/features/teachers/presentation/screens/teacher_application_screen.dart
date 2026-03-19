import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/auth/presentation/providers/auth_controller.dart';

class TeacherApplicationScreen extends ConsumerStatefulWidget {
  const TeacherApplicationScreen({super.key});

  @override
  ConsumerState<TeacherApplicationScreen> createState() =>
      _TeacherApplicationScreenState();
}

class _TeacherApplicationScreenState
    extends ConsumerState<TeacherApplicationScreen> {
  final _displayNameController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _bioController = TextEditingController();
  final _motivationController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic>? _application;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _specialtyController.dispose();
    _bioController.dispose();
    _motivationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final client = ref.read(apiClientProvider);
      final profile = await client.getCurrentUserProfile();
      final application = await client.getMyTeacherApplication();
      if (!mounted) return;
      _application = application;
      _displayNameController.text = application?['display_name']?.toString() ??
          profile?['username']?.toString() ??
          '';
      _specialtyController.text = application?['specialty']?.toString() ?? '';
      _bioController.text = application?['bio']?.toString() ?? '';
      _motivationController.text = application?['motivation']?.toString() ?? '';
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_displayNameController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final result = await ref.read(apiClientProvider).submitTeacherApplication(
            displayName: _displayNameController.text.trim(),
            specialty: _specialtyController.text.trim().isEmpty
                ? null
                : _specialtyController.text.trim(),
            bio: _bioController.text.trim().isEmpty
                ? null
                : _bioController.text.trim(),
            motivation: _motivationController.text.trim().isEmpty
                ? null
                : _motivationController.text.trim(),
          );
      if (!mounted) return;
      setState(() => _application = result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud enviada. El admin la revisará.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final status = _application?['status']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiero ser profesor'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.18),
                        theme.colorScheme.surface,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.isTeacher
                            ? 'Ya tienes rol de profesor'
                            : 'Solicita tu perfil de profesor',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        auth.isTeacher
                            ? 'Ya puedes abrir clases, gestionar alumnos y hablar con ellos.'
                            : 'Cuéntanos qué enseñas y por qué quieres acompañar a alumnos en directo.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (status != null) ...[
                        const SizedBox(height: 12),
                        _StatusPill(status: status),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre visible',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _specialtyController,
                  decoration: const InputDecoration(
                    labelText: 'Especialidad',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bioController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Bio pública',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _motivationController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Motivación para el admin',
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving || auth.isTeacher ? null : _submit,
                  icon: const Icon(Icons.school_outlined),
                  label: Text(
                    _saving
                        ? 'Enviando...'
                        : _application == null
                            ? 'Enviar solicitud'
                            : 'Actualizar y reenviar',
                  ),
                ),
                if (_application?['review_notes']?.toString().isNotEmpty ==
                    true) ...[
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notas de revisión',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(_application!['review_notes'].toString()),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' => const Color(0xFF00FF87),
      'rejected' => const Color(0xFFFF4444),
      _ => const Color(0xFFFFD36B),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Estado: $status',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

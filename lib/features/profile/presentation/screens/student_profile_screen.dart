import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Perfil de un alumno visto por su profesor (datos persistentes Insforge).
class StudentProfileScreen extends ConsumerStatefulWidget {
  const StudentProfileScreen({super.key, required this.studentUserId});

  final String studentUserId;

  @override
  ConsumerState<StudentProfileScreen> createState() =>
      _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ref.read(apiClientProvider);
      final user = await client.getUserById(widget.studentUserId);
      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openChat() async {
    final teacherUserId = ref.read(authControllerProvider).session?.user.id;
    if (teacherUserId == null || teacherUserId.isEmpty) return;
    try {
      final conversation = await ref.read(apiClientProvider).ensureConversation(
            teacherUserId: teacherUserId,
            studentUserId: widget.studentUserId,
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

  String _displayName(Map<String, dynamic>? user) {
    final username = user?['username']?.toString();
    if (username != null && username.isNotEmpty) return username;
    final email = user?['email']?.toString();
    if (email != null && email.isNotEmpty) return email;
    return 'Alumno';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del alumno'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_off_outlined,
                          size: 48,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No se pudo cargar el perfil',
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 52,
                          backgroundColor:
                              theme.colorScheme.primaryContainer,
                          backgroundImage:
                              _user!['avatar_url'] != null &&
                                      (_user!['avatar_url'] as String)
                                          .isNotEmpty
                                  ? CachedNetworkImageProvider(
                                      _user!['avatar_url'] as String)
                                  : null,
                          child:
                              _user!['avatar_url'] == null ||
                                      (_user!['avatar_url'] as String).isEmpty
                                  ? Icon(
                                      Icons.person,
                                      size: 52,
                                      color: theme.colorScheme.onPrimaryContainer,
                                    )
                                  : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _displayName(_user),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _user!['email']?.toString() ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      FilledButton.icon(
                        onPressed: _openChat,
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Enviar mensaje'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

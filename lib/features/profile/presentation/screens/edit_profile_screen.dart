import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/profile/presentation/providers/profile_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _usernameController = TextEditingController();
  String _nivel = 'Principiante';
  bool _saving = false;
  bool _initialized = false;

  String _normalizeNivel(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == 'principiante') return 'Principiante';
    if (v == 'intermedio') return 'Intermedio';
    if (v == 'avanzado') return 'Avanzado';
    // Fallback seguro para evitar crash del Dropdown (value debe existir en items).
    return 'Principiante';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).updateCurrentUserProfile(
            username: _usernameController.text.trim(),
            nivel: _nivel,
          );
      ref.invalidate(currentUserProfileProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado')),
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
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Guardando...' : 'Guardar'),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No se pudo cargar el perfil: $e'),
          ),
        ),
        data: (profile) {
          if (!_initialized) {
            _initialized = true;
            _usernameController.text = profile?['username']?.toString() ?? '';
            final rawNivel = profile?['nivel']?.toString() ?? '';
            if (rawNivel.trim().isNotEmpty) {
              _nivel = _normalizeNivel(rawNivel);
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(
                'Datos',
                style:
                    theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de usuario',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _nivel,
                        decoration: const InputDecoration(
                          labelText: 'Nivel',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Principiante',
                            child: Text('Principiante'),
                          ),
                          DropdownMenuItem(
                            value: 'Intermedio',
                            child: Text('Intermedio'),
                          ),
                          DropdownMenuItem(
                            value: 'Avanzado',
                            child: Text('Avanzado'),
                          ),
                        ],
                        onChanged:
                            _saving ? null : (v) => setState(() => _nivel = v ?? _nivel),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}


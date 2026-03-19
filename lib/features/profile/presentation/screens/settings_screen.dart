import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:calistenia_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:calistenia_app/features/notifications/presentation/providers/notification_preferences_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final prefsAsync = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            'Preferencias',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Card(
            child: prefsAsync.when(
              loading: () => const ListTile(
                leading: Icon(Icons.notifications_outlined),
                title: Text('Notificaciones'),
                subtitle: Text('Cargando...'),
              ),
              error: (e, _) => ListTile(
                leading: const Icon(Icons.notifications_off_outlined),
                title: const Text('Notificaciones'),
                subtitle: Text('No se pudieron cargar: $e'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/notifications'),
              ),
              data: (prefs) => Column(
                children: [
                  SwitchListTile(
                    value: prefs.notifyMessageReply,
                    onChanged: (value) {
                      ref
                          .read(notificationPreferencesProvider.notifier)
                          .setNotifyMessageReply(value);
                    },
                    title: const Text('Respuestas a mensajes'),
                    subtitle: const Text('Avisarme cuando alguien me responda'),
                    secondary: Icon(
                      Icons.chat_bubble_outline,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  SwitchListTile(
                    value: prefs.notifyRoutineProposed,
                    onChanged: (value) {
                      ref
                          .read(notificationPreferencesProvider.notifier)
                          .setNotifyRoutineProposed(value);
                    },
                    title: const Text('Rutina asignada/propuesta'),
                    subtitle: const Text('Avisarme cuando un profesor me asigne'),
                    secondary: Icon(
                      Icons.assignment_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.tune),
                    title: const Text('Más opciones'),
                    subtitle: const Text('Ver pantalla completa de notificaciones'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/notifications'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Cuenta',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Editar perfil'),
                  subtitle: const Text('Nombre de usuario y nivel'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/profile/edit'),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: Icon(Icons.logout, color: theme.colorScheme.error),
                  title: Text(
                    'Cerrar sesión',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: auth.busy ? null : () => ref.read(authControllerProvider).logout(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


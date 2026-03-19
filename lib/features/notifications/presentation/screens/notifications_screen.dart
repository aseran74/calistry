import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calistenia_app/features/notifications/presentation/providers/notification_preferences_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefsAsync = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
      ),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se pudieron cargar las preferencias: $e',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (prefs) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            Text(
              'Recibe avisos cuando ocurra lo siguiente:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: prefs.notifyMessageReply,
              onChanged: (value) {
                ref.read(notificationPreferencesProvider.notifier).setNotifyMessageReply(value);
              },
              title: const Text('Respuestas a mensajes'),
              subtitle: const Text('Cuando alguien te responde en una conversación'),
              secondary: Icon(
                Icons.chat_bubble_outline,
                color: theme.colorScheme.primary,
              ),
            ),
            SwitchListTile(
              value: prefs.notifyRoutineProposed,
              onChanged: (value) {
                ref.read(notificationPreferencesProvider.notifier).setNotifyRoutineProposed(value);
              },
              title: const Text('Rutina propuesta o asignada'),
              subtitle: const Text('Cuando un profesor te asigna o propone una rutina'),
              secondary: Icon(
                Icons.assignment_outlined,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

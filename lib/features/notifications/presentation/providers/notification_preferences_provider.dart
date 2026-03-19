import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calistenia_app/core/api/api_providers.dart';

/// Preferencias de notificaciones (persistidas en Insforge, tabla users).
class NotificationPreferences {
  const NotificationPreferences({
    this.notifyMessageReply = true,
    this.notifyRoutineProposed = true,
  });

  final bool notifyMessageReply;
  final bool notifyRoutineProposed;

  NotificationPreferences copyWith({
    bool? notifyMessageReply,
    bool? notifyRoutineProposed,
  }) {
    return NotificationPreferences(
      notifyMessageReply: notifyMessageReply ?? this.notifyMessageReply,
      notifyRoutineProposed: notifyRoutineProposed ?? this.notifyRoutineProposed,
    );
  }
}

final notificationPreferencesProvider =
    StateNotifierProvider<NotificationPreferencesNotifier, AsyncValue<NotificationPreferences>>((ref) {
  return NotificationPreferencesNotifier(ref);
});

class NotificationPreferencesNotifier extends StateNotifier<AsyncValue<NotificationPreferences>> {
  NotificationPreferencesNotifier(this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    try {
      final api = _ref.read(apiClientProvider);
      final raw = await api.getNotificationPreferences();
      state = AsyncValue.data(NotificationPreferences(
        notifyMessageReply: raw['notify_message_reply'] == true,
        notifyRoutineProposed: raw['notify_routine_proposed'] == true,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setNotifyMessageReply(bool value) async {
    final current = state.valueOrNull ?? const NotificationPreferences();
    state = AsyncValue.data(current.copyWith(notifyMessageReply: value));
    final api = _ref.read(apiClientProvider);
    await api.updateNotificationPreferences(
      notifyMessageReply: value,
      notifyRoutineProposed: current.notifyRoutineProposed,
    );
  }

  Future<void> setNotifyRoutineProposed(bool value) async {
    final current = state.valueOrNull ?? const NotificationPreferences();
    state = AsyncValue.data(current.copyWith(notifyRoutineProposed: value));
    final api = _ref.read(apiClientProvider);
    await api.updateNotificationPreferences(
      notifyMessageReply: current.notifyMessageReply,
      notifyRoutineProposed: value,
    );
  }
}

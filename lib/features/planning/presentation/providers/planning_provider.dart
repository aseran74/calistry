import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:calistenia_app/features/planning/domain/planning_slot.dart';
import 'package:calistenia_app/features/planning/data/planning_storage.dart';

final planningSlotsProvider =
    StateNotifierProvider<PlanningSlotsNotifier, AsyncValue<List<PlanningSlot>>>(
  (ref) {
    final notifier = PlanningSlotsNotifier(ref);
    notifier.load();
    return notifier;
  },
);

class PlanningSlotsNotifier extends StateNotifier<AsyncValue<List<PlanningSlot>>> {
  PlanningSlotsNotifier(this._ref) : super(const AsyncValue.loading());

  final Ref _ref;

  bool get _isAuthenticated =>
      _ref.read(authControllerProvider).isAuthenticated;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      if (_isAuthenticated) {
        try {
          final client = _ref.read(apiClientProvider);
          final rows = await client.getPlanningSlots();
          final slots = rows.map(PlanningSlot.fromJson).toList();
          state = AsyncValue.data(slots);
          await savePlanningSlots(slots);
          return;
        } catch (_) {
          // Fallback a local si el backend falla
        }
      }
      final local = await loadPlanningSlots();
      state = AsyncValue.data(local);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addSlot(PlanningSlot slot) async {
    final list = state.valueOrNull ?? [];
    if (_isAuthenticated) {
      try {
        final client = _ref.read(apiClientProvider);
        final created = await client.addPlanningSlot(
          dayOfWeek: slot.dayOfWeek,
          hour: slot.hour,
          minute: slot.minute,
          routineId: slot.routineId,
          routineName: slot.routineName,
        );
        if (created != null) {
          final withId = PlanningSlot(
            id: created['id'] as String?,
            dayOfWeek: slot.dayOfWeek,
            hour: slot.hour,
            minute: slot.minute,
            routineId: slot.routineId,
            routineName: slot.routineName,
          );
          final next = [...list, withId];
          state = AsyncValue.data(next);
          await savePlanningSlots(next);
          return;
        }
      } catch (_) {}
    }
    state = AsyncValue.data([...list, slot]);
    await savePlanningSlots(state.valueOrNull!);
  }

  Future<void> removeSlot(PlanningSlot slot) async {
    final list = state.valueOrNull ?? [];
    List<PlanningSlot> next;
    if (slot.id != null) {
      next = list.where((s) => s.id != slot.id).toList();
      if (_isAuthenticated) {
        try {
          await _ref.read(apiClientProvider).deletePlanningSlot(slot.id!);
        } catch (_) {}
      }
    } else {
      next = list.where((s) =>
          !(s.dayOfWeek == slot.dayOfWeek &&
              s.hour == slot.hour &&
              s.minute == slot.minute &&
              s.routineId == slot.routineId)).toList();
    }
    state = AsyncValue.data(next);
    await savePlanningSlots(next);
  }

  /// Añade varios huecos (misma rutina, varios días / una hora).
  Future<void> addSlotsBulk(List<PlanningSlot> newSlots) async {
    if (newSlots.isEmpty) return;
    final list = state.valueOrNull ?? [];
    final added = <PlanningSlot>[];

    if (_isAuthenticated) {
      try {
        final client = _ref.read(apiClientProvider);
        for (final slot in newSlots) {
          try {
            final created = await client.addPlanningSlot(
              dayOfWeek: slot.dayOfWeek,
              hour: slot.hour,
              minute: slot.minute,
              routineId: slot.routineId,
              routineName: slot.routineName,
            );
            if (created != null) {
              added.add(
                PlanningSlot(
                  id: created['id'] as String?,
                  dayOfWeek: slot.dayOfWeek,
                  hour: slot.hour,
                  minute: slot.minute,
                  routineId: slot.routineId,
                  routineName: slot.routineName,
                ),
              );
            } else {
              added.add(slot);
            }
          } catch (_) {
            added.add(slot);
          }
        }
      } catch (_) {
        added.addAll(newSlots);
      }
    } else {
      added.addAll(newSlots);
    }

    final next = [...list, ...added];
    state = AsyncValue.data(next);
    await savePlanningSlots(next);
  }

  Future<void> removeAt(int dayOfWeek, int hour, int minute) async {
    final list = state.valueOrNull ?? [];
    final next = list.where((s) =>
        !(s.dayOfWeek == dayOfWeek && s.hour == hour && s.minute == minute)).toList();
    for (final s in list) {
      if (s.dayOfWeek == dayOfWeek && s.hour == hour && s.minute == minute && s.id != null && _isAuthenticated) {
        try {
          await _ref.read(apiClientProvider).deletePlanningSlot(s.id!);
        } catch (_) {}
      }
    }
    state = AsyncValue.data(next);
    await savePlanningSlots(next);
  }
}

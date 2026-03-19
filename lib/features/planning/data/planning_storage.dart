import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calistenia_app/features/planning/domain/planning_slot.dart';

const _key = 'planning_slots';

Future<List<PlanningSlot>> loadPlanningSlots() async {
  final prefs = await SharedPreferences.getInstance();
  final json = prefs.getString(_key);
  if (json == null || json.isEmpty) return [];
  try {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map(PlanningSlot.fromJson)
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> savePlanningSlots(List<PlanningSlot> slots) async {
  final prefs = await SharedPreferences.getInstance();
  final list = slots.map((e) => e.toJson()).toList();
  await prefs.setString(_key, jsonEncode(list));
}

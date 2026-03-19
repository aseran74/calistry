import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:calistenia_app/features/planning/domain/planning_slot.dart';
import 'package:calistenia_app/features/planning/presentation/providers/planning_provider.dart';

class PlanningMonthlyView extends ConsumerStatefulWidget {
  const PlanningMonthlyView({super.key, required this.slots});

  final List<PlanningSlot> slots;

  @override
  ConsumerState<PlanningMonthlyView> createState() => _PlanningMonthlyViewState();
}

class _PlanningMonthlyViewState extends ConsumerState<PlanningMonthlyView> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  /// Slots that repeat by weekday: para cada fecha mostramos los slots de ese día de la semana.
  /// So for a given day (1-31) in _month, we get weekday and filter slots by that.
  List<PlanningSlot> _slotsForDate(DateTime date) {
    final wd = date.weekday;
    return widget.slots.where((s) => s.dayOfWeek == wd).toList()
      ..sort((a, b) => a.hour != b.hour
          ? a.hour.compareTo(b.hour)
          : a.minute.compareTo(b.minute));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifier = ref.read(planningSlotsProvider.notifier);
    final year = _month.year;
    final month = _month.month;
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0);
    final daysInMonth = last.day;
    final firstWeekday = first.weekday;
    const rows = 6;

    return RefreshIndicator(
      onRefresh: () => notifier.load(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _month = DateTime(year, month - 1);
                    });
                  },
                ),
                Text(
                  _monthLabel(month, year),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _month = DateTime(year, month + 1);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Table(
              border: TableBorder.all(color: theme.colorScheme.outlineVariant),
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  children: ['L', 'M', 'X', 'J', 'V', 'S', 'D'].map((d) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Text(
                        d,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
                for (int row = 0; row < rows; row++)
                  TableRow(
                    children: List.generate(7, (col) {
                      final day = row * 7 + col + 2 - firstWeekday;
                      if (day < 1 || day > daysInMonth) {
                        return const SizedBox(height: 72);
                      }
                      final date = DateTime(year, month, day);
                      final daySlots = _slotsForDate(date);
                      return _DayCell(
                        day: day,
                        slots: daySlots,
                        onSlotTap: (slot) => context.push(
                          '/routines/${slot.routineId}/play',
                        ),
                      );
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _monthLabel(int month, int year) {
    const names = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    return '${names[month]} $year';
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.slots,
    required this.onSlotTap,
  });

  final int day;
  final List<PlanningSlot> slots;
  final void Function(PlanningSlot) onSlotTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 72,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.colorScheme.outlineVariant),
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$day',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: slots.isEmpty
                ? const SizedBox.shrink()
                : ListView.builder(
                    itemCount: slots.length,
                    itemBuilder: (context, i) {
                      final slot = slots[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Material(
                          color: theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                          child: InkWell(
                            onTap: () => onSlotTap(slot),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              child: Text(
                                '${slot.timeLabel} ${slot.routineName}',
                                style: theme.textTheme.labelSmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

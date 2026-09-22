import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/adaptive/adaptive.dart';

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

Future<DateTime?> showMatchAwareDatePicker(
  BuildContext context, {
  required Set<DateTime> matchDates,
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final now = DateTime.now();
  final start = _dateOnly(firstDate ?? DateTime(now.year - 2));
  final end = _dateOnly(lastDate ?? DateTime(now.year + 2));
  final normalizedMatchDates = matchDates.map(_dateOnly).toSet();
  final initial = _dateOnly(initialDate ?? now);
  final clampedInitial = initial.isBefore(start)
      ? start
      : (initial.isAfter(end) ? end : initial);

  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) {
      DateTime focusedDay = clampedInitial;
      DateTime? selectedDay = clampedInitial;
      return StatefulBuilder(
        builder: (context, setState) {
          final colorScheme = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;
          return AlertDialog(
            title: const Text('Select date'),
            content: SizedBox(
              width: (340 * AppResponsive.widthScaleOf(context))
                  .clamp(240.0, MediaQuery.sizeOf(context).width - 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TableCalendar<void>(
                    firstDay: start,
                    lastDay: end,
                    focusedDay: focusedDay,
                    availableGestures: AvailableGestures.horizontalSwipe,
                    selectedDayPredicate: (day) =>
                        isSameDay(selectedDay, day),
                    eventLoader: (day) => normalizedMatchDates.contains(_dateOnly(day))
                        ? const [null]
                        : const [],
                    onDaySelected: (selected, focused) {
                      setState(() {
                        selectedDay = _dateOnly(selected);
                        focusedDay = _dateOnly(focused);
                      });
                    },
                    onPageChanged: (focused) {
                      setState(() => focusedDay = _dateOnly(focused));
                    },
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      markerDecoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      markersMaxCount: 1,
                      markerSize: 4.5,
                      todayDecoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      leftChevronIcon: const Icon(Icons.chevron_left),
                      rightChevronIcon: const Icon(Icons.chevron_right),
                      titleTextStyle: textTheme.titleMedium ??
                          const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, day, events) {
                        if (events.isEmpty) return const SizedBox.shrink();
                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 5),
                            width: 4.5,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Dates with matches',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (selectedDay == null) {
                    Navigator.of(dialogContext).pop();
                    return;
                  }
                  Navigator.of(dialogContext).pop(_dateOnly(selectedDay!));
                },
                child: const Text('Go'),
              ),
            ],
          );
        },
      );
    },
  );
}

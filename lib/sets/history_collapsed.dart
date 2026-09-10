import 'dart:io';

import 'package:flexify/database/database.dart';
import 'package:flexify/sets/edit_set_page.dart';
import 'package:flexify/sets/history_page.dart';
import 'package:flexify/settings/settings_state.dart';
import 'package:flexify/utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sticky_headers/sticky_headers/widget.dart';
import 'package:timeago/timeago.dart' as timeago;

class HistoryCollapsed extends StatefulWidget {
  final List<HistoryDay> days;
  final ScrollController scroll;
  final Function(int) onSelect;
  final Set<int> selected;
  final Function onNext;
  const HistoryCollapsed({
    super.key,
    required this.days,
    required this.onSelect,
    required this.selected,
    required this.onNext,
    required this.scroll,
  });

  @override
  State<HistoryCollapsed> createState() => _HistoryCollapsedState();
}

class _HistoryCollapsedState extends State<HistoryCollapsed> {
  bool goingNext = false;
  Map<DateTime, List<HistoryDay>> _grouped = {};
  @override
  Widget build(BuildContext context) {
    final showImages = context
        .select<SettingsState, bool>((settings) => settings.value.showImages);
    final sortedDays = List<HistoryDay>.from(widget.days)
      ..sort((a, b) => b.day.compareTo(a.day));
    _grouped = _groupByDay(sortedDays);

    return ListView.builder(
      controller: widget.scroll,
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: _grouped.entries.length,
      itemBuilder: (context, sectionIndex) {
        final entry = _grouped.entries.elementAt(sectionIndex);
        final date = entry.key;
        final sets = entry.value;

        return StickyHeader(
          header: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.center,
            child: _buildSectionDivider(
              date,
              sets,
            ),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(
              sets.length,
              (index) => historyChildren(sets[index], context, showImages),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
    widget.scroll.removeListener(scrollListener);
  }

  Widget _buildSectionDivider(DateTime date, List<HistoryDay> day) {
    final formats = context.read<SettingsState>().value;
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: Text(formatDateWithOrdinal(date)),
              content: getLastWorkout(day),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text("Close"),
                ),
              ],
            );
          },
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Expanded(child: Divider(thickness: 1)),
            const SizedBox(width: 4),
            const Icon(Icons.today, size: 16),
            const SizedBox(width: 4),
            Text(
              DateFormat(formats.shortDateFormat).format(date),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            const Expanded(child: Divider(thickness: 1)),
          ],
        ),
      ),
    );
  }

  Widget historyChildren(
    HistoryDay history,
    BuildContext context,
    bool showImages,
  ) {
    return ExpansionTile(
      title: Text("${history.name} (${history.gymSets.length})"),
      shape: const Border.symmetric(),
      children: history.gymSets.map(
        (gymSet) {
          final minutes = gymSet.duration.floor();
          final seconds =
              ((gymSet.duration * 60) % 60).floor().toString().padLeft(2, '0');
          final distance = toString(gymSet.distance);
          final reps = toString(gymSet.reps);
          final weight = toString(gymSet.weight);
          String incline = '';
          if (gymSet.incline != null && gymSet.incline! > 0)
            incline = '@ ${gymSet.incline}%';

          Widget? leading = SizedBox(
            height: 24,
            width: 24,
            child: Checkbox(
              value: widget.selected.contains(gymSet.id),
              onChanged: (value) {
                widget.onSelect(gymSet.id);
              },
            ),
          );

          if (widget.selected.isEmpty && showImages && gymSet.image != null) {
            leading = GestureDetector(
              onTap: () => widget.onSelect(gymSet.id),
              child: Image.file(
                File(gymSet.image!),
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.error),
              ),
            );
          } else if (widget.selected.isEmpty) {
            leading = GestureDetector(
              onTap: () => widget.onSelect(gymSet.id),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    gymSet.name.isNotEmpty ? gymSet.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            );
          }

          leading = AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: leading,
          );

          return ListTile(
            leading: leading,
            title: Text(
              gymSet.cardio
                  ? "$distance ${gymSet.unit} / $minutes:$seconds $incline"
                  : "$reps x $weight ${gymSet.unit}",
            ),
            selected: widget.selected.contains(gymSet.id),
            subtitle: Selector<SettingsState, String>(
              selector: (context, settings) => settings.value.longDateFormat,
              builder: (context, dateFormat, child) => Text(
                dateFormat == 'timeago'
                    ? timeago.format(gymSet.created)
                    : DateFormat(dateFormat).format(gymSet.created),
              ),
            ),
            onLongPress: () {
              widget.onSelect(gymSet.id);
            },
            onTap: () {
              if (widget.selected.isNotEmpty)
                widget.onSelect(gymSet.id);
              else
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditSetPage(gymSet: gymSet),
                  ),
                );
            },
          );
        },
      ).toList(),
    );
  }

  Map<DateTime, List<HistoryDay>> _groupByDay(List<HistoryDay> days) {
    final map = <DateTime, List<HistoryDay>>{};

    for (final day in days) {
      map.putIfAbsent(day.day, () => []);
      map[day.day]!.add(day);
    }

    // Optional: sort newest first
    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));

    return {
      for (final key in sortedKeys) key: map[key]!,
    };
  }

  Widget getLastWorkout(List<HistoryDay> sets) {
    String plural(int s) => s > 1 ? 's' : '';
    if (sets.isEmpty) return SizedBox.shrink();

    var sortedDays = sets;
    sortedDays.sort((a, b) => a.day.compareTo(b.day));
    var totalWorkout =
        sortedDays.where((d) => d.day == sortedDays.first.day).toList();

    var cardioUnit = totalWorkout.first.gymSets.any((n) => n.cardio)
        ? totalWorkout.first.gymSets.firstWhere((n) => n.cardio).unit
        : '';
    var weightUnit = totalWorkout.first.gymSets.any((n) => !n.cardio)
        ? totalWorkout.first.gymSets.firstWhere((n) => !n.cardio).unit
        : '';
    var totalSets = 0;
    var totalReps = 0;
    var totalExercises = totalWorkout.length;
    double totalDistance = 0;
    double totalWeight = 0;
    for (var exercise in totalWorkout) {
      totalSets += exercise.gymSets.length;
      for (var set in exercise.gymSets) {
        totalReps += set.reps.toInt();
        totalDistance += set.distance;
        totalWeight += (set.weight * set.reps);
      }
    }
    return Selector<SettingsState, String>(
      selector: (context, settings) {
        final format = settings.value.shortDateFormat;
        return DateFormat(format).format(sortedDays.first.day);
      },
      builder: (context, formattedDate, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              const SizedBox(height: 8),
              Text(
                '$totalExercises exercise${plural(totalExercises)} completed',
              ),
              Text('$totalSets set${plural(totalSets)} completed'),
              Text('$totalReps rep${plural(totalReps)} completed'),
              if (totalWeight > 0)
                Text(
                  '${num.parse(totalWeight.toStringAsFixed(3))}$weightUnit total lifted',
                ),
              if (totalDistance > 0)
                Text('$totalDistance$cardioUnit total travelled'),
            ],
          ),
        );
      },
    );
  }

  List<HistoryDay> getHistoryDays(List<GymSet> gymSets) {
    List<HistoryDay> historyDays = [];
    for (final gymSet in gymSets) {
      final day = DateUtils.dateOnly(gymSet.created);
      final index = historyDays
          .indexWhere((hd) => isSameDay(hd.day, day) && hd.name == gymSet.name);
      if (index == -1)
        historyDays.add(
          HistoryDay(name: gymSet.name, gymSets: [gymSet], day: day),
        );
      else
        historyDays[index].gymSets.add(gymSet);
    }
    return historyDays;
  }

  String formatDateWithOrdinal(DateTime date) {
    String suffix(int day) {
      if (day >= 11 && day <= 13) return 'th';
      switch (day % 10) {
        case 1:
          return 'st';
        case 2:
          return 'nd';
        case 3:
          return 'rd';
        default:
          return 'th';
      }
    }

    return '${DateFormat('EEE').format(date)}, '
        '${date.day}${suffix(date.day)} '
        '${DateFormat('MMM yy').format(date)}';
  }

  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(scrollListener);
  }

  void scrollListener() {
    if (widget.scroll.position.pixels <
            widget.scroll.position.maxScrollExtent - 200 ||
        goingNext) return;
    setState(() {
      goingNext = true;
    });
    try {
      widget.onNext();
    } finally {
      setState(() {
        goingNext = false;
      });
    }
  }
}

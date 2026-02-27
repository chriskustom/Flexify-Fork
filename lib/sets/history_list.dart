import 'dart:io';

import 'package:flexify/database/database.dart';
import 'package:flexify/sets/edit_set_page.dart';
import 'package:flexify/settings/settings_state.dart';
import 'package:flexify/utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sticky_headers/sticky_headers.dart';
import 'package:timeago/timeago.dart' as timeago;

class HistoryList extends StatefulWidget {
  final List<GymSet> sets;
  final ScrollController scroll;
  final Function(int) onSelect;
  final Set<int> selected;
  final Function onNext;
  final bool? peek;

  const HistoryList({
    super.key,
    required this.sets,
    required this.onSelect,
    required this.selected,
    required this.onNext,
    required this.scroll,
    this.peek = false,
  });

  @override
  State<HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<HistoryList> {
  bool goingNext = false;
  final GlobalKey<AnimatedListState> _key = GlobalKey<AnimatedListState>();
  List<GymSet> _current = [];
  Map<DateTime, List<GymSet>> _grouped = {};
  bool _peek = false;
  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(scrollListener);
    _current = List.from(widget.sets);
    _peek = widget.peek ?? false;
  }

  @override
  void didUpdateWidget(HistoryList oldWidget) {
    super.didUpdateWidget(oldWidget);

    final toRemove = _current
        .where(
          (oldSet) => !widget.sets.contains(oldSet),
        )
        .toList();

    for (var setToRemove in toRemove) {
      final index = _current.indexOf(setToRemove);
      if (index != -1) {
        final removedSet = _current.removeAt(index);
        _key.currentState?.removeItem(
          index,
          (context, animation) => _buildItem(
            removedSet,
            animation,
            index,
            context.read<SettingsState>().value.showImages,
          ),
          duration: const Duration(milliseconds: 300),
        );
      }
    }

    final toAdd = widget.sets
        .where(
          (newSet) => !_current.contains(newSet),
        )
        .toList();

    for (var setToAdd in toAdd) {
      final insertIndex = widget.sets.indexOf(setToAdd);
      if (insertIndex >= 0 && insertIndex <= _current.length) {
        _current.insert(insertIndex, setToAdd);
        _key.currentState?.insertItem(insertIndex, duration: Duration.zero);
      }
    }
  }

  Widget _buildItem(
    GymSet gymSet,
    Animation<double> animation,
    int index,
    bool showImages,
  ) {
    final offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: const Offset(0.0, 0.0),
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(animation);

    final sizeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(animation);

    return SizeTransition(
      sizeFactor: sizeAnimation,
      child: FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: offsetAnimation,
          child: _buildListItem(gymSet, index, showImages),
        ),
      ),
    );
  }

  Widget _buildListItem(
    GymSet gymSet,
    int index,
    bool showImages,
  ) {
    final minutes = gymSet.duration.floor();
    final seconds =
        ((gymSet.duration * 60) % 60).floor().toString().padLeft(2, '0');
    final distance = toString(gymSet.distance);
    final reps = toString(gymSet.reps);
    final weight = toString(gymSet.weight);
    String incline = '';
    if (gymSet.incline != null && gymSet.incline! > 0) {
      incline = '@ ${gymSet.incline}%';
    }

    Widget? leading = SizedBox(
      height: 24,
      width: 24,
      child: Checkbox(
        value: widget.selected.contains(gymSet.id),
        onChanged: (_) => widget.onSelect(gymSet.id),
      ),
    );

    if (widget.selected.isEmpty && showImages && gymSet.image != null) {
      leading = GestureDetector(
        onTap: () => widget.onSelect(gymSet.id),
        child: Image.file(
          File(gymSet.image!),
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
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
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: leading,
    );

    String trailing = "$reps x $weight ${gymSet.unit}";
    if (gymSet.cardio &&
        (gymSet.unit == 'kg' ||
            gymSet.unit == 'lb' ||
            gymSet.unit == 'stone')) {
      trailing = "$weight ${gymSet.unit} / $minutes:$seconds $incline";
    } else if (gymSet.cardio &&
        (gymSet.unit == 'km' || gymSet.unit == 'mi' || gymSet.unit == 'kcal')) {
      trailing = "$distance ${gymSet.unit} / $minutes:$seconds $incline";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: widget.selected.contains(gymSet.id)
                ? Theme.of(context).colorScheme.primary.withValues(alpha: .08)
                : Colors.transparent,
            border: Border.all(
              color: widget.selected.contains(gymSet.id)
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: .3)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: _getListItem(leading, gymSet, trailing),
        ),
      ],
    );
  }

  Widget _getListItem(Widget leading, GymSet gymSet, String trailing) {
    final title = Text(_peek ? _getSetNumber(gymSet) : gymSet.name);
    final subtitle = Selector<SettingsState, String>(
      selector: (context, settings) => settings.value.longDateFormat,
      builder: (context, dateFormat, child) => Text(
        dateFormat == 'timeago'
            ? timeago.format(gymSet.created)
            : DateFormat(dateFormat).format(gymSet.created),
      ),
    );
    return ListTile(
      leading: leading,
      title: title,
      subtitle: _peek ? null : subtitle,
      trailing: Text(
        trailing,
        style: const TextStyle(fontSize: 16),
      ),
      onLongPress: () => widget.onSelect(gymSet.id),
      onTap: () {
        if (widget.selected.isNotEmpty) {
          widget.onSelect(gymSet.id);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditSetPage(gymSet: gymSet),
            ),
          );
        }
      },
    );
  }

  String _getSetNumber(GymSet gymSet) {
    final currentDate = gymSet.created.toLocal();
    final sameDayEntries = _current
        .where(
          (entry) =>
              entry.created.toLocal().year == currentDate.year &&
              entry.created.toLocal().month == currentDate.month &&
              entry.created.toLocal().day == currentDate.day,
        )
        .toList()
        .reversed
        .toList();
    final positionOnThisDay = sameDayEntries.indexOf(gymSet) + 1;
    return 'Set #$positionOnThisDay';
  }

  @override
  Widget build(BuildContext context) {
    final showImages = context
        .select<SettingsState, bool>((settings) => settings.value.showImages);
    _grouped = _groupByDay(_current);

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
            child: _buildSectionDivider(date),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(
              sets.length,
              (index) => _buildListItem(sets[index], index, showImages),
            ),
          ),
        );
      },
    );
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

  @override
  void dispose() {
    widget.scroll.removeListener(scrollListener);
    super.dispose();
  }

  Widget _buildSectionDivider(DateTime date) {
    final format = context.read<SettingsState>().value.shortDateFormat;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(child: Divider(thickness: 1)),
          const SizedBox(width: 4),
          const Icon(Icons.today, size: 16),
          const SizedBox(width: 4),
          Text(
            DateFormat(format).format(date),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          const Expanded(child: Divider(thickness: 1)),
        ],
      ),
    );
  }

  Map<DateTime, List<GymSet>> _groupByDay(List<GymSet> sets) {
    final map = <DateTime, List<GymSet>>{};

    for (final set in sets) {
      final day = DateTime(
        set.created.year,
        set.created.month,
        set.created.day,
      );

      map.putIfAbsent(day, () => []);
      map[day]!.add(set);
    }

    // Optional: sort newest first
    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));

    return {
      for (final key in sortedKeys) key: map[key]!,
    };
  }
}

class DateHeaderDelegate extends SliverPersistentHeaderDelegate {
  final DateTime date;

  DateHeaderDelegate(this.date);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Selector<SettingsState, String>(
      selector: (context, settings) {
        final format = settings.value.shortDateFormat;
        return format;
      },
      builder: (context, format, child) {
        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            DateFormat(format).format(date),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        );
      },
    );
  }

  @override
  double get maxExtent => 44;

  @override
  double get minExtent => 44;

  @override
  bool shouldRebuild(DateHeaderDelegate oldDelegate) =>
      oldDelegate.date != date;
}

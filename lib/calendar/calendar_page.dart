import 'package:drift/drift.dart' hide Column;
import 'package:flexify/database/database.dart';
import 'package:flexify/main.dart';
import 'package:flexify/sets/edit_sets_page.dart';
import 'package:flexify/sets/history_collapsed.dart';
import 'package:flexify/sets/history_list.dart';
import 'package:flexify/sets/history_page.dart';
import 'package:flexify/settings/settings_page.dart';
import 'package:flexify/settings/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarPage extends StatefulWidget {
  final TabController tabController;

  const CalendarPage({
    super.key,
    required this.tabController,
  });

  @override
  State<CalendarPage> createState() => CalendarPageState();
}

class CalendarPageState extends State<CalendarPage>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return NavigatorPopHandler(
      onPopWithResult: (result) {
        if (navKey.currentState!.canPop() == false) return;

        final settings = context.read<SettingsState>().value;
        final index = settings.tabs.split(',').indexOf('CalendarPage');

        if (widget.tabController.index == index) {
          navKey.currentState!.pop();
        }
      },
      child: Navigator(
        key: navKey,
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (context) => _CalendarPageWidget(
            navKey: navKey,
          ),
          settings: settings,
        ),
      ),
    );
  }
}

class _CalendarPageWidget extends StatefulWidget {
  final GlobalKey<NavigatorState> navKey;

  const _CalendarPageWidget({
    required this.navKey,
  });

  @override
  State<_CalendarPageWidget> createState() => _CalendarPageWidgetState();
}

class _CalendarPageWidgetState extends State<_CalendarPageWidget> {
  late final Stream<List<GymSet>> stream;

  DateTime? _selectedDay;
  DateTime _focusedDay = DateTime.now();

  final Set<int> selected = {};
  final ScrollController scroll = ScrollController();

  int monthToFilter = DateTime.now().month;
  int yearToFilter = DateTime.now().year;

  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    final query = db.gymSets.select()
      ..orderBy(
        [
          (u) => OrderingTerm(
                expression: u.created,
                mode: OrderingMode.desc,
              ),
        ],
      )
      ..where(
        (tbl) => tbl.hidden.equals(false),
      );

    stream = query.watch();
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: StreamBuilder<List<GymSet>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              children: [
                _buildTitleBar([]),
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ],
            );
          }

          if (snapshot.hasError) {
            return Column(
              children: [
                _buildTitleBar([]),
                Expanded(
                  child: Center(
                    child: Text(
                      'Error loading workouts:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            );
          }
          final allGymSets = snapshot.data ?? <GymSet>[];

          final thisMonthsGymSets = allGymSets
              .where(
                (t) =>
                    t.created.month == monthToFilter &&
                    t.created.year == yearToFilter,
              )
              .toList();

          final exerciseItems = _getExerciseItems(thisMonthsGymSets);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitleBar(exerciseItems),
              Expanded(
                child: _getCalendar(exerciseItems),
              ),
            ],
          );
        },
      ),
    );
  }

  final GlobalKey _menuKey = GlobalKey();
  Widget _buildTitleBar(List<ExerciseItem> monthlyExercises) {
    final hasSelection = selected.isNotEmpty;
    var selectedDayGymSets = monthlyExercises
        .where(
          (exercise) => isSameDay(
            exercise.date,
            _selectedDay,
          ),
        )
        .toList()
        .expand((g) => g.sets);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withValues(alpha: .5),
              spreadRadius: 0,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: ListTile(
          tileColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40),
          ),
          title: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Calendar',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          leading: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: animation,
                child: child,
              );
            },
            child: hasSelection
                ? IconButton(
                    key: const ValueKey('backButton'),
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      setState(() {
                        selected.clear();
                      });
                    },
                  )
                : const Icon(Icons.calendar_month_rounded),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: child,
                  );
                },
                child: hasSelection
                    ? IconButton(
                        key: const ValueKey('deleteButton'),
                        icon: const Icon(Icons.delete),
                        tooltip: 'Delete selected',
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) {
                              return AlertDialog(
                                title: const Text('Confirm Delete'),
                                content: Text(
                                  'Are you sure you want to delete '
                                  '${selected.length} records? '
                                  'This action is not reversible.',
                                ),
                                actions: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.close),
                                    label: const Text('Cancel'),
                                    onPressed: () {
                                      Navigator.pop(dialogContext, false);
                                    },
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.delete),
                                    label: const Text('Delete'),
                                    onPressed: () {
                                      Navigator.pop(dialogContext, true);
                                    },
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirmed != true || !context.mounted) return;

                          final ids = selected.toList();

                          await (db.delete(db.gymSets)
                                ..where((tbl) => tbl.id.isIn(ids)))
                              .go();

                          if (!context.mounted) return;

                          setState(() {
                            selected.clear();
                          });
                        },
                      )
                    : const SizedBox(
                        key: ValueKey('emptyWidget'),
                        width: 0,
                      ),
              ),
              Badge.count(
                count: selected.length,
                isLabelVisible: hasSelection,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: IconButton(
                  key: _menuKey,
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Show menu',
                  onPressed: () async {
                    final RenderBox button = _menuKey.currentContext!
                        .findRenderObject() as RenderBox;

                    final RenderBox overlay = Overlay.of(context)
                        .context
                        .findRenderObject() as RenderBox;

                    final Offset buttonPosition = button.localToGlobal(
                      Offset.zero,
                      ancestor: overlay,
                    );

                    final RelativeRect position = RelativeRect.fromRect(
                      Rect.fromLTWH(
                        buttonPosition.dx,
                        buttonPosition.dy,
                        button.size.width,
                        button.size.height,
                      ),
                      Offset.zero & overlay.size,
                    );

                    final action = await showMenu<String>(
                      context: context,
                      position: position,
                      items: [
                        if (selectedDayGymSets.isNotEmpty)
                          const PopupMenuItem<String>(
                            value: 'select_all',
                            child: ListTile(
                              leading: Icon(Icons.done_all),
                              title: Text('Select all'),
                            ),
                          ),
                        if (hasSelection)
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit),
                              title: Text('Edit'),
                            ),
                          ),
                        if (!hasSelection)
                          const PopupMenuItem<String>(
                            value: 'settings',
                            child: ListTile(
                              leading: Icon(Icons.settings),
                              title: Text('Settings'),
                            ),
                          ),
                      ],
                    );

                    if (!mounted) return;

                    switch (action) {
                      case 'select_all':
                        setState(() {
                          selected
                            ..clear()
                            ..addAll(
                              selectedDayGymSets.map((gymSet) => gymSet.id),
                            );
                        });
                        break;

                      case 'edit':
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditSetsPage(
                              ids: selected.toList(),
                            ),
                          ),
                        );
                        break;

                      case 'settings':
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsPage(),
                          ),
                        );
                        break;

                      case null:
                        break;
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getCalendar(List<ExerciseItem> exerciseItems) {
    final today = DateUtils.dateOnly(
      DateTime.now(),
    );

    final selectedDate = _selectedDay ?? _focusedDay;
    final selectedDayExercises = exerciseItems
        .where(
          (exercise) => isSameDay(
            exercise.date,
            selectedDate,
          ),
        )
        .toList();

    return Column(
      children: [
        _CalendarHeader(
          focusedDay: _focusedDay,
          clearButtonVisible: false,
          onTodayButtonTap: () {
            setState(() {
              _focusedDay = today;
              _selectedDay = today;
            });
          },
          onClearButtonTap: () {},
          onLeftArrowTap: () {
            _pageController.previousPage(
              duration: const Duration(
                milliseconds: 300,
              ),
              curve: Curves.easeOut,
            );
          },
          onRightArrowTap: () {
            _pageController.nextPage(
              duration: const Duration(
                milliseconds: 300,
              ),
              curve: Curves.easeOut,
            );
          },
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: TableCalendar<ExerciseItem>(
            firstDay: DateTime(1900, 1, 1),
            lastDay: DateTime(2100, 12, 31),
            focusedDay: _focusedDay,
            headerVisible: false,
            startingDayOfWeek: StartingDayOfWeek.monday,
            selectedDayPredicate: (day) {
              return isSameDay(
                _selectedDay,
                day,
              );
            },
            rowHeight: 40,
            calendarFormat: CalendarFormat.month,
            rangeSelectionMode: RangeSelectionMode.disabled,
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return SizedBox();
                return Container(
                  width: double.infinity,
                  height: 4,
                  margin: EdgeInsets.only(top: 2, left: 15, right: 15),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
            eventLoader: (day) {
              final exercise = exerciseItems
                  .where(
                    (e) => isSameDay(
                      e.date,
                      day,
                    ),
                  )
                  .firstOrNull;

              return exercise == null ? <ExerciseItem>[] : [exercise];
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onCalendarCreated: (controller) {
              _pageController = controller;
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
                monthToFilter = focusedDay.month;
                yearToFilter = focusedDay.year;
              });
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.secondary,
                ),
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
              cellMargin: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              todayTextStyle:
                  TextStyle(color: Theme.of(context).colorScheme.primary),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              selectedTextStyle:
                  TextStyle(color: Theme.of(context).colorScheme.onPrimary),
              markerDecoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(
          height: 8.0,
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              if (selectedDayExercises.isEmpty) {
                return Center(
                  child: Text('No gains made on this day.'),
                );
              }

              final groupHistory = context.select<SettingsState, bool>(
                (settings) => settings.value.groupHistory,
              );

              if (groupHistory) {
                return HistoryCollapsed(
                  scroll: scroll,
                  days: selectedDayExercises.reversed.toList(),
                  onSelect: (id) {
                    if (selected.contains(id))
                      setState(() {
                        selected.remove(id);
                      });
                    else
                      setState(() {
                        selected.add(id);
                      });
                  },
                  selected: selected,
                  onNext: () {},
                );
              } else {
                return HistoryList(
                  peek: false,
                  scroll: scroll,
                  sets: selectedDayExercises.expand((e) => e.sets).toList(),
                  onSelect: (id) {
                    if (selected.contains(id))
                      setState(() {
                        selected.remove(id);
                      });
                    else
                      setState(() {
                        selected.add(id);
                      });
                  },
                  selected: selected,
                  onNext: () {},
                );
              }
            },
          ),
        ),
      ],
    );
  }

  List<ExerciseItem> _getExerciseItems(List<GymSet> gymSets) {
    List<ExerciseItem> exerciseItems = [];
    for (final gymSet in gymSets) {
      final day = DateUtils.dateOnly(gymSet.created);
      final index = exerciseItems.indexWhere(
        (hd) => isSameDay(hd.date, day) && hd.name == gymSet.name,
      );
      if (index == -1)
        exerciseItems.add(
          ExerciseItem(name: gymSet.name, sets: [gymSet], date: day),
        );
      else
        exerciseItems[index].sets.add(gymSet);
    }
    return exerciseItems;
  }
}

class _CalendarHeader extends StatelessWidget {
  final DateTime focusedDay;
  final VoidCallback onLeftArrowTap;
  final VoidCallback onRightArrowTap;
  final VoidCallback onTodayButtonTap;
  final VoidCallback onClearButtonTap;
  final bool clearButtonVisible;

  const _CalendarHeader({
    required this.focusedDay,
    required this.onLeftArrowTap,
    required this.onRightArrowTap,
    required this.onTodayButtonTap,
    required this.onClearButtonTap,
    required this.clearButtonVisible,
  });

  @override
  Widget build(BuildContext context) {
    final headerText = DateFormat.yMMM().format(
      focusedDay,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8.0,
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16.0,
          ),
          SizedBox(
            width: 130.0,
            child: Text(
              headerText,
              style: const TextStyle(
                fontSize: 26.0,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.calendar_today,
              size: 20.0,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: onTodayButtonTap,
          ),
          if (clearButtonVisible)
            IconButton(
              icon: const Icon(
                Icons.clear,
                size: 20.0,
              ),
              visualDensity: VisualDensity.compact,
              onPressed: onClearButtonTap,
            ),
          const Spacer(),
          IconButton(
            icon: const Icon(
              Icons.chevron_left,
            ),
            onPressed: onLeftArrowTap,
          ),
          IconButton(
            icon: const Icon(
              Icons.chevron_right,
            ),
            onPressed: onRightArrowTap,
          ),
        ],
      ),
    );
  }
}

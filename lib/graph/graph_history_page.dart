import 'package:drift/drift.dart';
import 'package:flexify/database/database.dart';
import 'package:flexify/main.dart';
import 'package:flexify/sets/history_list.dart';
import 'package:flexify/settings/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GraphHistoryPage extends StatefulWidget {
  final String name;
  final List<GymSet> gymSets;
  final bool? peek;

  const GraphHistoryPage({
    super.key,
    required this.name,
    required this.gymSets,
    this.peek = false,
  });

  @override
  createState() => _GraphHistoryPageState();
}

class _GraphHistoryPageState extends State<GraphHistoryPage> {
  late List<GymSet> sets = widget.gymSets;
  int limit = 20;
  final scroll = ScrollController();
  TabController? ctrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(widget.name),
      ),
      body: Builder(
        builder: (context) {
          if (sets.isEmpty)
            return ListTile(
              title: Text("No data yet for ${widget.name}"),
              subtitle: const Text("Enter some data to view graphs here"),
            );

          return HistoryList(
            scroll: scroll,
            sets: sets,
            onSelect: (_) {},
            selected: const {},
            onNext: () {
              setState(() {
                limit += 10;
              });
              setSets();
            },
            peek: widget.peek,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    ctrl?.removeListener(tabListener);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        ctrl = DefaultTabController.of(context);
        ctrl?.addListener(tabListener);
      } catch (_) {/* ignored */}
    });
  }

  void setSets() async {
    final result = await (db.gymSets.select()
          ..orderBy(
            [
              (u) => OrderingTerm(
                    expression: u.created,
                    mode: OrderingMode.desc,
                  ),
            ],
          )
          ..where((tbl) => tbl.name.equals(widget.name))
          ..where((tbl) => tbl.hidden.equals(false))
          ..limit(limit))
        .get();
    setState(() {
      sets = result;
    });
  }

  void tabListener() {
    final settings = context.read<SettingsState>().value;
    final index = settings.tabs.split(',').indexOf('GraphsPage');
    if (ctrl!.indexIsChanging == true) return;
    if (ctrl!.index != index) return;
    setSets();
  }
}

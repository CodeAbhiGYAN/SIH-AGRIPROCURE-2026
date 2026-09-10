import 'package:flutter/material.dart';
import '../main.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../services/load_model.dart';
import '../services/procurement_timing.dart';
import '../scheduling/rescheduling.dart';

class OfficialShellScreen extends StatefulWidget {
  final AppState state;
  const OfficialShellScreen({super.key, required this.state});

  @override
  State<OfficialShellScreen> createState() => _OfficialShellScreenState();
}

class _OfficialShellScreenState extends State<OfficialShellScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final user = widget.state.officialUser!;
    final titles = const [
      'Dashboard',
      'Farmers',
      'Queue',
      'Scheduling',
      'Operations',
      'Performance',
    ];
    final pages = [
      OfficialDashboard(state: widget.state),
      OfficialFarmers(state: widget.state),
      OfficialQueue(state: widget.state),
      OfficialScheduling(state: widget.state),
      OfficialOperations(state: widget.state),
      OfficialPerformance(state: widget.state),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titles[tab], style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(
              user.role == OfficialRole.centreManager
                  ? '${user.name} • Centre ${user.centreId}'
                  : '${user.name} • Network view',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: widget.state.logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Farmers',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Queue',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'Operations',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Performance',
          ),
        ],
      ),
    );
  }
}

List<Centre> _visibleCentres(AppState state) {
  final user = state.officialUser;
  if (user == null || user.centreId == '*') return state.data.centres;
  return state.data.centres.where((c) => c.id == user.centreId).toList();
}

class OfficialDashboard extends StatelessWidget {
  final AppState state;
  const OfficialDashboard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final centres = _visibleCentres(state);
    final activeAllotted = _activeAllotted(state, centres);
    final queueNow = centres.fold<int>(0, (sum, c) => sum + _waitingCount(state, c.id) + _processingCount(state, c.id));
    final dailyCapacity = centres.fold<int>(0, (sum, c) => sum + _dailySchedulingCapacity(c));
    final capacityUsed = dailyCapacity == 0 ? 0 : ((activeAllotted / dailyCapacity) * 100).round().clamp(0, 100);
    final alerts = centres.where((c) => c.status == CentreStatus.degraded || c.status == CentreStatus.unavailable).length
        + centres.where((c) => _centreLoad(state, c).status == 'bottleneck').length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Procurement operations', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(state.officialUser?.role == OfficialRole.centreManager
            ? 'Centre-level monitoring and farmer processing.'
            : 'Network-wide procurement monitoring and intervention.'),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.7,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _metric('Active allotted', '$activeAllotted', Icons.event_available),
            _metric('Queue right now', '$queueNow', Icons.groups),
            _metric('Capacity used', '$capacityUsed%', Icons.speed),
            _metric('Active alerts', '$alerts', Icons.warning_amber_rounded),
          ],
        ),
        const SizedBox(height: 14),
        ...centres.map((centre) => _CentreCard(centre: centre, state: state)),
      ],
    );
  }

  Widget _metric(String label, String value, IconData icon) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const Spacer(),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}

class _CentreCard extends StatelessWidget {
  final Centre centre;
  final AppState state;
  const _CentreCard({required this.centre, required this.state});

  @override
  Widget build(BuildContext context) {
    final waiting = _waitingCount(state, centre.id);
    final processing = _processingCount(state, centre.id);
    final load = _centreLoad(state, centre);
    final physical = waiting + processing;
    final dailyCapacity = _dailySchedulingCapacity(centre);
    final used = _activeAllottedForCentre(state, centre.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${centre.name} • ${LoadModel.label(load.status)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ),
                StatusChip(
                  LoadModel.label(load.status),
                  good: load.status == 'normal',
                  warning: load.status == 'moderate',
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: dailyCapacity == 0 ? 0 : (used / dailyCapacity).clamp(0, 1).toDouble(), minHeight: 9),
            const SizedBox(height: 8),
            Text('Appointments today $used / $dailyCapacity'),
            Text('Queue now $physical • Waiting $waiting • Processing $processing'),
            Text('Peak slot workload ${load.workloadMinutes.toStringAsFixed(1)} / 30 min'),
            Text('Slot overload ${load.overloadPercent.toStringAsFixed(1)}%'),
            Text('Available staff ${centre.activeStaff}/${centre.staffTotal} • Weighbridges ${centre.weighbridgesWorking}/${centre.weighbridgesTotal}'),
          ],
        ),
      ),
    );
  }
}

class _TabCountLabel extends StatelessWidget {
  final String label;
  final int count;

  const _TabCountLabel({
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class OfficialFarmers extends StatefulWidget {
  final AppState state;
  const OfficialFarmers({super.key, required this.state});

  @override
  State<OfficialFarmers> createState() => _OfficialFarmersState();
}

class _OfficialFarmersState extends State<OfficialFarmers> {
  String query = '';
  bool incomplete = true;

  @override
  Widget build(BuildContext context) {
    final visibleCentres = _visibleCentres(widget.state).map((c) => c.id).toSet();
    final all = widget.state.data.farmers
        .where((f) => visibleCentres.contains(f.centreId))
        .where((f) {
      final q = query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return f.id.toLowerCase().contains(q) ||
          f.name.toLowerCase().contains(q) ||
          f.mobile.toLowerCase().contains(q) ||
          f.village.toLowerCase().contains(q);
    }).toList();

    final incompleteCount = all.where((f) => !f.procurementComplete).length;
    final completeCount = all.where((f) => f.procurementComplete).length;

    final farmers = all
        .where((f) => incomplete ? !f.procurementComplete : f.procurementComplete)
        .toList()
      ..sort((a, b) {
        if (incomplete) {
          final stateCompare = _actionPriority(b).compareTo(_actionPriority(a));
          if (stateCompare != 0) return stateCompare;
          return b.priorityScore.compareTo(a.priorityScore);
        }
        return a.id.compareTo(b.id);
      });

    return Column(
      children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: true,
                label: _TabCountLabel(
                  label: 'Incomplete',
                  count: incompleteCount,
                ),
              ),
              ButtonSegment(
                value: false,
                label: _TabCountLabel(
                  label: 'Complete',
                  count: completeCount,
                ),
              ),
            ],
            selected: {incomplete},
            onSelectionChanged: (value) {
              setState(() => incomplete = value.first);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search farmer ID, name, mobile or village',
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: farmers.length,
            itemBuilder: (_, i) {
              final f = farmers[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(f.id.substring(1))),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${f.id} • ${f.name}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (incomplete) _JourneyChip(farmer: f),
                    ],
                  ),
                  subtitle: Text(
                    incomplete
                        ? '${f.crop} • ${f.expectedQuantity.toStringAsFixed(0)} q • ${f.procurementDay} • ${f.window}\n${_journeyText(f)}'
                        : '${f.crop} • ${f.expectedQuantity.toStringAsFixed(0)} q • Completed',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => FarmerDetailDialog(
                      state: widget.state,
                      farmer: f,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

int _actionPriority(Farmer f) {
  switch (f.state) {
    case FarmerState.processing:
      return 5;
    case FarmerState.waiting:
      return 4;
    case FarmerState.arrived:
      return 3;
    case FarmerState.travelling:
      return 2;
    case FarmerState.assigned:
    case FarmerState.rescheduled:
      return 1;
    case FarmerState.completed:
    case FarmerState.cancelled:
      return 0;
  }
}

String _journeyText(Farmer f) {
  if (f.state == FarmerState.processing) return 'At centre • Processing';
  if (f.state == FarmerState.waiting) return 'At centre • Waiting';
  if (f.state == FarmerState.arrived) return 'At centre • Arrived';
  if (f.state == FarmerState.travelling) return 'On the way';
  if (f.state == FarmerState.rescheduled) return 'At home • Rescheduled';
  return 'At home';
}

class _JourneyChip extends StatelessWidget {
  final Farmer farmer;
  const _JourneyChip({required this.farmer});

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final String label;
    switch (farmer.state) {
      case FarmerState.processing:
        icon = Icons.settings;
        label = 'At Centre';
        break;
      case FarmerState.waiting:
      case FarmerState.arrived:
        icon = Icons.location_on;
        label = 'At Centre';
        break;
      case FarmerState.travelling:
        icon = Icons.directions_car;
        label = 'On Way';
        break;
      default:
        icon = Icons.home;
        label = 'At Home';
    }
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class FarmerDetailDialog extends StatefulWidget {
  final AppState state;
  final Farmer farmer;
  const FarmerDetailDialog({super.key, required this.state, required this.farmer});

  @override
  State<FarmerDetailDialog> createState() => _FarmerDetailDialogState();
}

class _FarmerDetailDialogState extends State<FarmerDetailDialog> {
  late Set<String> done;
  bool saving = false;
  final stages = const [
    'Attendance',
    'Arrival',
    'Quality check',
    'Weighing',
    'Procurement',
    'Bill',
    'Payment',
  ];

  @override
  void initState() {
    super.initState();
    done = {...widget.state.procurementDone[widget.farmer.id] ?? {}};
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('${widget.farmer.id} • ${widget.farmer.name}'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${widget.farmer.crop} • ${widget.farmer.expectedQuantity.toStringAsFixed(0)} q'),
                Text('Centre ${widget.farmer.centreId} • ${widget.farmer.procurementDay} • ${widget.farmer.window}'),
                const SizedBox(height: 14),
                ...stages.map(
                  (stage) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: done.contains(stage),
                    title: Text(stage),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          done.add(stage);
                        } else {
                          done.remove(stage);
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    setState(() => saving = true);
                    try {
                      await widget.state.setProcurementStages(
                        widget.farmer.id,
                        done,
                      );
                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      if (!mounted) return;
                      setState(() => saving = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Unable to save status: $e'),
                        ),
                      );
                    }
                  },
            child: Text(saving ? 'Saving...' : 'Save status'),
          ),
        ],
      );
}

class OfficialQueue extends StatelessWidget {
  final AppState state;
  const OfficialQueue({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final centres = _visibleCentres(state);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Queue monitoring', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        ...centres.map((c) {
          final waiting = _waitingCount(state, c.id);
          final processing = _processingCount(state, c.id);
          final total = waiting + processing;
          final minutes = total * ProcurementTiming.defaultProcessingMinutesPerFarmer;
          final rate = ProcurementTiming.defaultProcessingRatePerHour;
          final progress = (minutes / ProcurementTiming.slotMinutes).clamp(0.0, 1.0).toDouble();
          return InfoCard(
            title: c.name,
            icon: Icons.groups,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Currently serving: $processing'),
                Text('Waiting now: $waiting'),
                Text('Physical load: $total'),
                Text('Processing model: ${ProcurementTiming.defaultProcessingMinutesPerFarmer.toStringAsFixed(0)} min/farmer (${rate.toStringAsFixed(1)} farmers/hr)'),
                Text('Estimated queue clearance: ${formatDuration(minutes.round())}'),
                Text('Available staff: ${c.activeStaff}/${c.staffTotal}'),
                Text('Working weighbridges: ${c.weighbridgesWorking}/${c.weighbridgesTotal}'),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: progress),
              ],
            ),
          );
        }),
        const SizedBox(height: 10),
        const InfoCard(
          title: 'Queue model',
          icon: Icons.sync,
          child: Text('Only farmers who are physically at the centre and are in an active arrival/waiting/processing state contribute to the live operational queue. Scheduled farmers at home are not counted as a physical queue.'),
        ),
      ],
    );
  }
}

class OfficialScheduling extends StatefulWidget {
  final AppState state;
  const OfficialScheduling({super.key, required this.state});

  @override
  State<OfficialScheduling> createState() => _OfficialSchedulingState();
}

class _OfficialSchedulingState extends State<OfficialScheduling> {
  DateTime selectedDate = DateTime.now();
  final Set<DateTime> selectedDates = <DateTime>{};

  DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  void _toggle(DateTime date) {
    final day = _dayOnly(date);
    setState(() {
      if (!selectedDates.add(day)) selectedDates.remove(day);
      selectedDate = day;
    });
  }

  Future<void> _markSelectedUnavailable() async {
    if (selectedDates.isEmpty) return;
    final changes = <String, Set<DateTime>>{};
    for (final centre in _visibleCentres(widget.state)) {
      changes[centre.id] = Set<DateTime>.from(selectedDates);
    }
    await widget.state.setCentreUnavailableBatch(changes);
    if (mounted) setState(selectedDates.clear);
  }

  Future<void> _makeSelectedAvailable() async {
    if (selectedDates.isEmpty) return;
    try {
      for (final centre in _visibleCentres(widget.state)) {
        for (final date in selectedDates) {
          await widget.state.setCentreUnavailable(centre.id, date, false);
        }
      }
      if (mounted) setState(selectedDates.clear);
    } catch (_) {
      // AppState reconciles availability on failure.
    }
  }

  @override
  Widget build(BuildContext context) {
    final centres = _visibleCentres(widget.state);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Scheduling', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('Generated appointment capacity uses the shared 7-minute prototype service-time model.'),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              _MultiSelectCalendar(
                monthDate: selectedDate,
                selectedDates: selectedDates,
                onSelected: _toggle,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    Expanded(child: Text('${selectedDates.length} date${selectedDates.length == 1 ? '' : 's'} selected')),
                    if (selectedDates.isNotEmpty)
                      TextButton(onPressed: () => setState(selectedDates.clear), child: const Text('Clear')),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    Expanded(child: FilledButton.icon(onPressed: selectedDates.isEmpty ? null : _markSelectedUnavailable, icon: const Icon(Icons.event_busy), label: const Text('Mark unavailable'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(onPressed: selectedDates.isEmpty ? null : _makeSelectedAvailable, icon: const Icon(Icons.event_available), label: const Text('Make available'))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...centres.map((centre) => _ScheduleForCentre(
              state: widget.state,
              centre: centre,
              selectedDate: selectedDate,
            )),
      ],
    );
  }
}

class _MultiSelectCalendar extends StatefulWidget {
  final DateTime monthDate;
  final Set<DateTime> selectedDates;
  final ValueChanged<DateTime> onSelected;

  const _MultiSelectCalendar({
    required this.monthDate,
    required this.selectedDates,
    required this.onSelected,
  });

  @override
  State<_MultiSelectCalendar> createState() => _MultiSelectCalendarState();
}

class _MultiSelectCalendarState extends State<_MultiSelectCalendar> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.monthDate.year, widget.monthDate.month);
  }

  @override
  void didUpdateWidget(covariant _MultiSelectCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.monthDate.year != widget.monthDate.year ||
        oldWidget.monthDate.month != widget.monthDate.month) {
      _month = DateTime(widget.monthDate.year, widget.monthDate.month);
    }
  }

  void _moveMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    if (next.isBefore(DateTime(2026, 1)) || next.isAfter(DateTime(2027, 12))) return;
    setState(() => _month = next);
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(_month.year, _month.month, 1);
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    final leading = first.weekday % 7;
    final total = ((leading + days) / 7).ceil() * 7;
    final cells = List<DateTime?>.filled(total, null);
    for (var d = 1; d <= days; d++) {
      cells[leading + d - 1] = DateTime(_month.year, _month.month, d);
    }
    const names = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _moveMonth(-1)),
              Expanded(child: Text('${_monthName(_month.month)} ${_month.year}', style: const TextStyle(fontWeight: FontWeight.w800))),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _moveMonth(1)),
            ],
          ),
          Row(children: [for (final n in names) Expanded(child: Center(child: Text(n, style: const TextStyle(fontWeight: FontWeight.w700))))]),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
            itemBuilder: (_, i) {
              final date = cells[i];
              if (date == null) return const SizedBox.shrink();
              final day = DateTime(date.year, date.month, date.day);
              final selected = widget.selectedDates.contains(day);
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => widget.onSelected(day),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                      ),
                    ),
                    child: Text('${date.day}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _monthName(int month) => const [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ][month];
}

class _ScheduleForCentre extends StatelessWidget {
  final AppState state;
  final Centre centre;
  final DateTime selectedDate;
  const _ScheduleForCentre({required this.state, required this.centre, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    final unavailable = state.isCentreUnavailable(centre.id, selectedDate);
    final bookedBySlot = _bookedBySlot(state, centre, selectedDate);
    if (unavailable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${centre.name} • ${_formatDate(selectedDate)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Card(child: ListTile(leading: Icon(Icons.event_busy), title: Text('Centre unavailable'), subtitle: Text('No appointment slots are available on this date.'))),
          const SizedBox(height: 12),
        ],
      );
    }

    final slots = _generatedSlots(centre, bookedBySlot);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${centre.name} • ${_formatDate(selectedDate)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        ...slots.map((slot) => Card(
          child: ListTile(
            leading: CircleAvatar(child: Text(slot.slotNumber.toString())),
            title: Text(slot.label),
            subtitle: Text('${slot.booked} / ${slot.capacity} booked • ${slot.remaining} remaining • system generated'),
            trailing: StatusChip(
              slot.remaining <= 0 ? 'FULL' : slot.remaining <= 1 ? 'NEAR FULL' : 'AVAILABLE',
              good: slot.remaining > 1,
              warning: slot.remaining == 1,
            ),
          ),
        )),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _GeneratedSlot {
  final int slotNumber;
  final String label;
  final int capacity;
  final int booked;

  const _GeneratedSlot({
    required this.slotNumber,
    required this.label,
    required this.capacity,
    required this.booked,
  });

  int get remaining => (capacity - booked).clamp(0, capacity);
}

List<_GeneratedSlot> _generatedSlots(
  Centre centre,
  Map<String, int> bookedBySlot,
) {
  final capacity = 4;
  final slots = <_GeneratedSlot>[];

  for (var i = 0;
      i < AppointmentScheduler.workingSlotLabels.length;
      i++) {
    final label = AppointmentScheduler.workingSlotLabels[i];
    final booked = bookedBySlot[label] ?? 0;

    slots.add(
      _GeneratedSlot(
        slotNumber: i + 1,
        label: label,
        capacity: capacity,
        booked: booked,
      ),
    );
  }

  return slots;
}

Map<String, int> _bookedBySlot(
  AppState state,
  Centre centre,
  DateTime date,
) {
  final day = AppointmentScheduler.dayLabel(date);
  final counts = <String, int>{};

  for (final farmer in state.data.farmers) {
    if (farmer.centreId != centre.id) continue;
    if (farmer.procurementDay != day) continue;
    if (farmer.procurementComplete) continue;

    final label = AppointmentScheduler.normalizeWindow(
      farmer.window,
    );

    if (!AppointmentScheduler.workingSlotLabels.contains(label)) {
      continue;
    }

    counts[label] = (counts[label] ?? 0) + 1;
  }

  return counts;
}

class OfficialOperations extends StatelessWidget {
  final AppState state;
  const OfficialOperations({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final centres = _visibleCentres(state);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Operations', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        ...centres.map(
          (c) => Column(
            children: [
              InfoCard(
                title: '${c.name} • Weighbridges',
                icon: Icons.precision_manufacturing,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _row('Total installed', '${c.weighbridgesTotal}'),
                    _row('Working', '${c.weighbridgesWorking}'),
                    _row('Not working', '${c.weighbridgesTotal - c.weighbridgesWorking}'),
                    const SizedBox(height: 8),
                    BigAction(
                      text: 'Update weighbridge count',
                      icon: Icons.edit,
                      onTap: () => _showWeighbridgeEditor(context, state, c),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Effective processing: ${c.effectiveProcessingRate.toStringAsFixed(1)} farmers/hr',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              InfoCard(
                title: '${c.name} • Procurement Staff',
                icon: Icons.badge_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Available staff: ${c.activeStaff}/${c.staffTotal}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const Chip(label: Text('Attendance source')),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('The app reads the available count from the attendance source; individual staff attendance is not managed here.'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
        const InfoCard(
          title: 'Operational issues',
          icon: Icons.notifications_active,
          child: Text(
            'Operational issues are used to explain changes in centre conditions. The scheduling engine responds to capacity changes automatically; officials do not manually reallocate ordinary cases.',
          ),
        ),
      ],
    );
  }

  Widget _row(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(a)),
            Text(b, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

Future<void> _showWeighbridgeEditor(
  BuildContext context,
  AppState state,
  Centre centre,
) async {
  var total = centre.weighbridgesTotal;
  var working = centre.weighbridgesWorking;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('${centre.name} • Weighbridges'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: total,
                  decoration: const InputDecoration(labelText: 'Total installed'),
                  items: List.generate(
                    21,
                    (i) => DropdownMenuItem(value: i, child: Text('$i')),
                  ),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() {
                      total = value;
                      if (working > total) working = total;
                    });
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: working.clamp(0, total),
                  decoration: const InputDecoration(labelText: 'Working now'),
                  items: List.generate(
                    total + 1,
                    (i) => DropdownMenuItem(value: i, child: Text('$i')),
                  ),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => working = value);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  state.updateWeighbridges(
                    centreId: centre.id,
                    totalInstalled: total,
                    working: working,
                  );
                  Navigator.pop(dialogContext);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

class OfficialPerformance extends StatelessWidget {
  final AppState state;
  const OfficialPerformance({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final centres = _visibleCentres(state);
    final records = state.data.farmers
        .where((f) => centres.any((c) => c.id == f.centreId))
        .length;
    final completed = state.data.farmers
        .where((f) => centres.any((c) => c.id == f.centreId))
        .where((f) => f.procurementComplete)
        .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('History & Performance', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        InfoCard(
          title: 'Operational snapshot',
          icon: Icons.insights,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kpi('Farmers tracked', '$records'),
              _kpi('Completed procurements', '$completed'),
              _kpi('Centres monitored', '${centres.length}'),
              _kpi('Automatic reassignments', '${state.reassignmentCount}'),
              _kpi(
                'Average queue',
                '${centres.isEmpty ? 0 : (centres.map((c) => _waitingCount(state, c.id)).reduce((a, b) => a + b) / centres.length).round()}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const InfoCard(
          title: 'Historical data foundation',
          icon: Icons.model_training,
          child: Text(
            'Procurement stage updates and operational conditions are structured so arrival, quality, weighing, procurement, bill, payment, queue, staffing and equipment history can later be stored in shared backend records for trends and prediction.',
          ),
        ),
      ],
    );
  }

  Widget _kpi(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(child: Text(a)),
            Text(b, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          ],
        ),
      );
}

int _activeAllotted(AppState state, List<Centre> centres) =>
    centres.fold<int>(0, (sum, centre) => sum + _activeAllottedForCentre(state, centre.id));

int _activeAllottedForCentre(AppState state, String centreId) => state.data.farmers
    .where((f) => f.centreId == centreId && !f.procurementComplete && f.procurementDay != 'Not assigned')
    .length;

int _waitingCount(AppState state, String centreId) => state.data.farmers
    .where((f) => f.centreId == centreId && (f.state == FarmerState.arrived || f.state == FarmerState.waiting) && f.queueEnteredAt != null)
    .length;

int _processingCount(AppState state, String centreId) => state.data.farmers
    .where((f) => f.centreId == centreId && f.state == FarmerState.processing)
    .length;

int _dailySchedulingCapacity(Centre centre) =>
    (AppointmentScheduler.workingSlotLabels.length * 4).clamp(0, centre.capacity.round());

LoadResult _centreLoad(AppState state, Centre centre) {
  final day = DateUtils.dateOnly(DateTime.now());
  LoadResult? peak;
  for (final slot in AppointmentScheduler.workingSlotLabels) {
    final dayLabel = AppointmentScheduler.dayLabel(day);
    final farmerTimes = state.data.farmers
        .where((f) => f.centreId == centre.id && f.procurementDay == dayLabel && !f.procurementComplete)
        .where((f) => AppointmentScheduler.normalizeWindow(f.window) == slot)
        .map((f) => f.predictedProcessingMinutes);
    final result = LoadModel.forSlot(farmerTimes);
    if (peak == null || result.overloadPercent > peak.overloadPercent) peak = result;
  }
  return peak ?? const LoadResult(workloadMinutes: 0, overloadPercent: -100, status: 'normal');
}

String centreStatus(CentreStatus status) {
  switch (status) {
    case CentreStatus.normal: return 'NORMAL';
    case CentreStatus.busy: return 'BUSY';
    case CentreStatus.highLoad: return 'HIGH LOAD';
    case CentreStatus.delayed: return 'DELAYED';
    case CentreStatus.degraded: return 'DEGRADED';
    case CentreStatus.unavailable: return 'UNAVAILABLE';
  }
}

String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  if (hours < 24) {
    if (mins == 0) return '$hours hr';
    return '$hours hr $mins min';
  }
  final days = hours ~/ 24;
  final remainingHours = hours % 24;
  if (remainingHours == 0) return '$days day${days == 1 ? '' : 's'}';
  return '$days day${days == 1 ? '' : 's'} $remainingHours hr';
}

String _timeLabel(int hour24, int minute) {
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minuteText = minute == 0 ? '00' : '$minute';
  final endMinute = minute == 0 ? 30 : 0;
  var endHour = hour24;
  if (minute == 30) endHour += 1;
  final endPeriod = endHour >= 12 ? 'PM' : 'AM';
  final endDisplayHour = endHour % 12 == 0 ? 12 : endHour % 12;
  final endMinuteText = endMinute == 0 ? '00' : '$endMinute';
  return '$hour:$minuteText $period – $endDisplayHour:$endMinuteText $endPeriod';
}

String _dayLabel(DateTime date) => AppointmentScheduler.dayLabel(date);

String _formatDate(DateTime date) =>
    '${date.day}/${date.month}/${date.year}';

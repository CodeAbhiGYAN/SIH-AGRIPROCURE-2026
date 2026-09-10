import 'package:flutter/material.dart';
import '../main.dart';
import '../widgets/common.dart';

class StatusScreen extends StatelessWidget {
  final AppState state;
  const StatusScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final stages = [
      'Verification',
      'Attendance',
      'Arrival',
      'Quality check',
      'Weighing',
      'Procurement',
      'Bill',
      'Payment',
    ];
    final payments = const [
      ('18 Mar 2026', '₹48,250', 'Wheat', 'Centre A'),
      ('22 Apr 2025', '₹41,800', 'Mustard', 'Centre B'),
      ('11 Mar 2024', '₹38,600', 'Wheat', 'Centre C'),
    ];

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(state.t('procurement_status')),
            bottom: TabBar(tabs: [
              Tab(text: state.t('current_status_tab')),
              Tab(text: state.t('payment_history')),
            ]),
          ),
          body: TabBarView(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(state.t('procurement_journey'), style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  ...List.generate(stages.length, (i) {
                    final stage = stages[i];
                    final done = stage == 'Verification'
                        ? state.verified
                        : (state.procurementDone[state.farmerId]?.contains(stage) ?? false);
                    final previousDone = i == 0
                        ? true
                        : (stages[i - 1] == 'Verification'
                            ? state.verified
                            : (state.procurementDone[state.farmerId]?.contains(stages[i - 1]) ?? false));
                    final isCurrent = !done && previousDone;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        done ? Icons.check_circle : isCurrent ? Icons.play_circle_fill : Icons.radio_button_unchecked,
                        color: done ? Colors.green : isCurrent ? Colors.blue : Colors.grey,
                      ),
                      title: Text(_stageLabel(state, stage), style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(done ? state.t('completed') : isCurrent ? state.t('current_step') : state.t('pending')),
                    );
                  }),
                  const SizedBox(height: 12),
                  InfoCard(
                    title: state.t('next_action'),
                    icon: Icons.arrow_forward,
                    child: Text(_nextStage(stages, state) == null
                        ? state.t('procurement_journey_complete')
                        : _stageLabel(state, _nextStage(stages, state)!)),
                  ),
                ],
              ),
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(state.t('payment_history'), style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  ...payments.map(
                    (payment) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.receipt_long),
                        title: Text(payment.$2, style: const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text('${payment.$3} • ${payment.$4}\n${payment.$1}'),
                        isThreeLine: true,
                        trailing: StatusChip(state.t('completed'), good: true),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _stageLabel(AppState state, String stage) {
    switch (stage) {
      case 'Verification': return state.t('verification');
      case 'Attendance': return state.t('attendance');
      case 'Arrival': return state.t('arrival');
      case 'Quality check': return state.t('quality_check');
      case 'Weighing': return state.t('weighing');
      case 'Procurement': return state.t('procurement');
      case 'Bill': return state.t('bill');
      case 'Payment': return state.t('payment');
      default: return stage;
    }
  }

  String? _nextStage(List<String> stages, AppState state) {
    for (final stage in stages) {
      final done = stage == 'Verification'
          ? state.verified
          : (state.procurementDone[state.farmerId]?.contains(stage) ?? false);
      if (!done) return stage;
    }
    return null;
  }
}

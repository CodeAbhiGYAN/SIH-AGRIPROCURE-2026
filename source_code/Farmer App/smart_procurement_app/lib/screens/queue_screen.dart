import 'package:flutter/material.dart';
import '../main.dart';
import '../widgets/common.dart';

class QueueScreen extends StatelessWidget {
  final AppState state;
  const QueueScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (!state.appointmentAssigned) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InfoCard(title: state.t('queue'), icon: Icons.groups, child: Text(state.t('queue_after_assignment'))),
        ],
      );
    }

    final centre = state.assignedCentre;
    final q = state.queueSnapshot;
    final token = q.queueToken > 0 ? q.queueToken : state.farmer.queueToken;
    final positionText = q.hasQueuePosition ? '${q.position}' : '--';
    final aheadText = q.hasQueuePosition ? '${q.farmersAhead}' : '--';
    final waitText = q.hasQueuePosition ? '${q.estimatedWaitMinutes} min' : '--';
    final physical = q.currentWaiting + q.currentProcessing;
    final progress = (physical * 7 / 30).clamp(0.0, 1.0).toDouble();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(state.t('live_queue'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        InfoCard(
          title: state.t('your_token_status'),
          icon: Icons.confirmation_number,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Metric(token > 0 ? '$token' : '--', state.t('token')),
                  _Metric(positionText, 'Position'),
                  _Metric(aheadText, state.t('ahead')),
                  _Metric(waitText, state.t('wait')),
                ],
              ),
              const SizedBox(height: 18),
              LinearProgressIndicator(value: progress, minHeight: 10),
              const SizedBox(height: 10),
              Text('Waiting now: ${q.currentWaiting} • Processing now: ${q.currentProcessing}', textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(state.t('queue_auto'), textAlign: TextAlign.center),
            ],
          ),
        ),
        const SizedBox(height: 14),
        InfoCard(title: state.t('centre'), icon: Icons.location_on, child: Text('${centre.name}\n${centre.address}')),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  const _Metric(this.value, this.label);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
          Text(label),
        ],
      );
}

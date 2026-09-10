import 'package:flutter/material.dart';
import '../main.dart';
import '../models/models.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  final AppState state;
  const HomeScreen({super.key, required this.state});

  String _loadLabel(String value) {
    switch (value) {
      case 'moderate': return 'MODERATE LOAD';
      case 'high': return 'HIGH LOAD';
      case 'bottleneck': return 'BOTTLENECK';
      default: return 'NORMAL';
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmer = state.farmer;
    final attendanceMarked = state.procurementDone[state.farmerId]?.contains('Attendance') ?? false;

    if (!state.verified) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('NAMASTE, ${farmer.name.toUpperCase()} 👋', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          StatusChip(state.t('procurement_verification_required'), warning: true),
          const SizedBox(height: 16),
          InfoCard(
            title: state.t('next_step'),
            icon: Icons.verified_user,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.t('complete_details')),
                const SizedBox(height: 12),
                BigAction(text: state.t('start_verification'), icon: Icons.verified_user, onTap: () => state.setTab(3)),
              ],
            ),
          ),
        ],
      );
    }

    final ce = state.assignedCentre;
    final q = state.queueSnapshot;
    final hasPosition = q.hasQueuePosition;
    final loadLabel = _loadLabel(q.loadStatus);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('NAMASTE, ${farmer.name.toUpperCase()} 👋', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        StatusChip(
          state.appointmentAssigned ? state.t('appointment_confirmed_status') : state.t('appointment_not_assigned'),
          good: state.appointmentAssigned,
        ),
        const SizedBox(height: 16),
        if (state.appointmentAssigned)
          InfoCard(
            title: state.t('your_appointment'),
            icon: Icons.calendar_month,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ce.name, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                Text('${farmer.procurementDay} • ${farmer.window}'),
                const SizedBox(height: 10),
                Text(hasPosition
                    ? state.t('current_queue_farmers').replaceAll('{n}', '${q.farmersAhead}')
                    : 'Queue position appears after check-in.'),
                if (hasPosition)
                  Text(state.t('expected_wait_min').replaceAll('{n}', '${q.estimatedWaitMinutes}')),
                const SizedBox(height: 10),
                StatusChip('Centre load: $loadLabel', good: q.loadStatus == 'normal', warning: q.loadStatus == 'moderate'),
              ],
            ),
          )
        else
          InfoCard(
            title: state.t('appointment'),
            icon: Icons.schedule,
            child: Text(state.t('verification_complete_arranging')),
          ),
        if (state.appointmentAssigned) ...[
          const SizedBox(height: 12),
          InfoCard(
            title: state.t('check_in'),
            icon: attendanceMarked ? Icons.check_circle : Icons.how_to_reg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(attendanceMarked ? state.t('attendance_done') : state.t('check_in_sub_home')),
                const SizedBox(height: 12),
                BigAction(
                  text: attendanceMarked ? state.t('attendance_done') : state.t('mark_attendance'),
                  icon: attendanceMarked ? Icons.check_circle : Icons.how_to_reg,
                  onTap: attendanceMarked ? null : () => state.markAttendance(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          BigAction(text: state.t('view_queue'), icon: Icons.groups, onTap: () => state.setTab(1)),
          const SizedBox(height: 10),
          BigAction(text: state.t('travel_plan'), icon: Icons.route, onTap: () => state.setTab(2)),
        ],
        const SizedBox(height: 10),
        BigAction(text: state.t('verification'), icon: Icons.verified_user, onTap: () => state.setTab(3)),
        const SizedBox(height: 10),
        BigAction(text: state.t('msp_information'), icon: Icons.currency_rupee, onTap: () => state.setTab(4)),
        const SizedBox(height: 10),
        BigAction(text: state.t('ask_assistant'), icon: Icons.chat_bubble_outline, onTap: () => state.setTab(5)),
      ],
    );
  }
}

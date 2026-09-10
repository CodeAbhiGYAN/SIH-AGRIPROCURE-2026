import '../models/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FarmerRemoteBundle {
  final Map<String, dynamic> farmer;
  final Map<String, dynamic> verification;
  final Map<String, dynamic>? appointment;
  final Map<String, dynamic> status;
  final Map<String, dynamic> procurement;
  final Map<String, dynamic> payment;
  final Map<String, dynamic>? centre;
  final List<Map<String, dynamic>> unreadNotifications;
  final QueueSnapshot queueSnapshot;

  FarmerRemoteBundle({
    required this.farmer,
    required this.verification,
    required this.appointment,
    required this.status,
    required this.procurement,
    required this.payment,
    required this.centre,
    required this.unreadNotifications,
    required this.queueSnapshot,
  });
}

class SupabaseBackend {
  SupabaseClient get client => Supabase.instance.client;

  Future<Map<String, dynamic>?> farmerById(String farmerId) async {
    final row = await client
        .from('farmers')
        .select()
        .eq('farmer_id', farmerId)
        .maybeSingle();
    return row;
  }

  Future<FarmerRemoteBundle?> loadFarmer(String farmerId) async {
    final farmer = await farmerById(farmerId);
    if (farmer == null) return null;

    final verification = await client
        .from('verification')
        .select()
        .eq('farmer_id', farmerId)
        .single();

    final appointment = await client
        .from('appointments')
        .select()
        .eq('farmer_id', farmerId)
        .maybeSingle();

    final status = await client
        .from('farmer_status')
        .select()
        .eq('farmer_id', farmerId)
        .single();

    final procurement = await client
        .from('procurement')
        .select()
        .eq('farmer_id', farmerId)
        .single();

    final payment = await client
        .from('payments')
        .select()
        .eq('farmer_id', farmerId)
        .single();

    Map<String, dynamic>? centre;
    final centreId = appointment?['centre_id']?.toString();
    if (centreId != null && centreId.isNotEmpty) {
      centre = await client
          .from('centres')
          .select()
          .eq('centre_id', centreId)
          .maybeSingle();
    }

    final unread = await client
        .from('notifications')
        .select()
        .eq('farmer_id', farmerId)
        .eq('is_read', false)
        .order('created_at', ascending: true);

    QueueSnapshot queueSnapshot = const QueueSnapshot.empty();
    try {
      final queueRaw = await client.rpc(
        'get_farmer_queue_snapshot',
        params: {'p_farmer_id': farmerId},
      );
      if (queueRaw is Map) {
        final q = Map<String, dynamic>.from(queueRaw);
        queueSnapshot = QueueSnapshot(
          queueToken: (q['queue_token'] as num?)?.toInt() ?? 0,
          position: (q['position'] as num?)?.toInt() ?? 0,
          farmersAhead: (q['farmers_ahead'] as num?)?.toInt() ?? 0,
          estimatedWaitMinutes: (q['estimated_wait_minutes'] as num?)?.toInt() ?? 0,
          currentWaiting: (q['current_waiting'] as num?)?.toInt() ?? 0,
          currentProcessing: (q['current_processing'] as num?)?.toInt() ?? 0,
          slotWorkloadMinutes: (q['slot_workload_minutes'] as num?)?.toDouble() ?? 0,
          overloadPercent: (q['overload_percent'] as num?)?.toDouble() ?? 0,
          loadStatus: q['load_status']?.toString() ?? 'normal',
          queueEnteredAt: DateTime.tryParse(q['queue_entered_at']?.toString() ?? '')?.toLocal(),
        );
      }
    } catch (_) {
      // Older databases may not have the new queue RPC until the SQL patch is applied.
    }

    return FarmerRemoteBundle(
      farmer: Map<String, dynamic>.from(farmer),
      verification: Map<String, dynamic>.from(verification),
      appointment: appointment == null
          ? null
          : Map<String, dynamic>.from(appointment),
      status: Map<String, dynamic>.from(status),
      procurement: Map<String, dynamic>.from(procurement),
      payment: Map<String, dynamic>.from(payment),
      centre: centre == null ? null : Map<String, dynamic>.from(centre),
      unreadNotifications: unread
          .map((row) => Map<String, dynamic>.from(row))
          .toList(),
      queueSnapshot: queueSnapshot,
    );
  }

  Future<void> updateVerificationStage({
    required String farmerId,
    required String stage,
    String? bankName,
    String? bankAccount,
    String? bankIfsc,
    String? selectedCrop,
    num? cropQuantity,
    String? cropSeason,
  }) async {
    final field = switch (stage) {
      'Identity' => 'identity_status',
      'Land Record' => 'land_status',
      'Bank Account' => 'bank_status',
      'Crop' => 'crop_status',
      'Eligibility' => 'eligibility_status',
      _ => null,
    };
    if (field == null) return;

    final values = <String, dynamic>{field: 'verified'};
    if (stage == 'Bank Account') {
      values.addAll({
        'bank_name': bankName,
        'bank_account': bankAccount,
        'bank_ifsc': bankIfsc,
      });
    }
    if (stage == 'Crop') {
      values.addAll({
        'selected_crop': selectedCrop,
        'crop_quantity': cropQuantity,
        'crop_season': cropSeason,
      });
    }

    await client.from('verification').update(values).eq('farmer_id', farmerId);

    if (stage == 'Crop') {
      final farmerValues = <String, dynamic>{
        'crop': selectedCrop,
        if (cropQuantity != null) 'expected_quantity': cropQuantity,
      };
      await client.from('farmers').update(farmerValues).eq('farmer_id', farmerId);
    }

    // Centre assignment is intentionally performed separately after the
    // Farmer-side appointment-arranging delay.
  }

  Future<void> finalizeVerification({required String farmerId}) async {
    // Mark verification complete first. Centre A is intentionally assigned
    // later by the Farmer App after its appointment-arranging delay.
    await client.from('verification').update({
      'identity_status': 'verified',
      'land_status': 'verified',
      'bank_status': 'verified',
      'crop_status': 'verified',
      'eligibility_status': 'verified',
    }).eq('farmer_id', farmerId);

    await client.from('farmers').update({
      'workflow_state': 'verified',
    }).eq('farmer_id', farmerId);
  }

  Future<Map<String, dynamic>> assignDemoCentreA({required String farmerId}) async {
    final result = await client.rpc(
      'assign_demo_centre_a',
      params: {'p_farmer_id': farmerId},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>?> appointmentFor(String farmerId) async {
    final row = await client
        .from('appointments')
        .select()
        .eq('farmer_id', farmerId)
        .maybeSingle();
    return row;
  }

  Future<void> markAppointmentNotificationsRead(String farmerId) async {
    final rows = await client
        .from('notifications')
        .select('notification_id')
        .eq('farmer_id', farmerId)
        .eq('is_read', false)
        .inFilter('kind', ['appointment', 'reschedule']);

    for (final row in rows) {
      final id = row['notification_id'];
      if (id == null) continue;
      await client
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('notification_id', id);
    }
  }

  Future<void> updateLanguage(String farmerId, String language) async {
    await client
        .from('farmers')
        .update({'language': language})
        .eq('farmer_id', farmerId);
  }

  Future<void> updateLocationStatus({
    required String farmerId,
    required String locationStatus,
  }) async {
    await client.from('farmer_status').update({
      'location_status': locationStatus,
    }).eq('farmer_id', farmerId);

    await client.from('farmers').update({
      'has_left_home': locationStatus != 'HOME',
      'workflow_state': switch (locationStatus) {
        'ON_WAY' => 'travelling',
        'AT_CENTRE' => 'arrived',
        _ => 'assigned',
      },
    }).eq('farmer_id', farmerId);
  }

  Future<void> markAttendance(String farmerId) async {
    await client.rpc(
      'mark_farmer_attendance',
      params: {'p_farmer_id': farmerId},
    );
  }

  Future<List<Map<String, dynamic>>> unreadNotifications(String farmerId) async {
    final rows = await client
        .from('notifications')
        .select()
        .eq('farmer_id', farmerId)
        .eq('is_read', false)
        .order('created_at', ascending: true);
    return rows
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> saveProcurementStages(
    String farmerId,
    Set<String> stages,
  ) async {
    const ordered = <String>[
      'Attendance',
      'Arrival',
      'Quality check',
      'Weighing',
      'Procurement',
      'Bill',
      'Payment',
    ];
    final selected = stages.where(ordered.contains).toSet();
    final stageList = [for (final stage in ordered) if (selected.contains(stage)) stage];
    await client.rpc(
      'save_procurement_stage_update',
      params: {'p_farmer_id': farmerId, 'p_stages': stageList},
    );
  }

  Future<void> markNotificationRead(int notificationId) async {
    await client.from('notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('notification_id', notificationId);
  }
}

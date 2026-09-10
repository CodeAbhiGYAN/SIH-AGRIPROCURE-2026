import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBackend {
  SupabaseClient get client => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> loadCentres() async {
    final rows = await client
        .from('centres')
        .select()
        .order('centre_id');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> loadGovernmentFarmers() async {
    final farmers = await client
        .from('farmers')
        .select()
        .order('farmer_id');
    final verification = await client.from('verification').select();
    final appointments = await client.from('appointments').select();
    final statuses = await client.from('farmer_status').select();
    final procurements = await client.from('procurement').select();

    final verificationById = <String, Map<String, dynamic>>{
      for (final row in verification)
        row['farmer_id'].toString(): Map<String, dynamic>.from(row),
    };
    final appointmentById = <String, Map<String, dynamic>>{
      for (final row in appointments)
        row['farmer_id'].toString(): Map<String, dynamic>.from(row),
    };
    final statusById = <String, Map<String, dynamic>>{
      for (final row in statuses)
        row['farmer_id'].toString(): Map<String, dynamic>.from(row),
    };
    final procurementById = <String, Map<String, dynamic>>{
      for (final row in procurements)
        row['farmer_id'].toString(): Map<String, dynamic>.from(row),
    };

    final result = <Map<String, dynamic>>[];
    for (final raw in farmers) {
      final farmer = Map<String, dynamic>.from(raw);
      final id = farmer['farmer_id'].toString();
      final v = verificationById[id];
      final appointment = appointmentById[id];

      // Government Farmers tab is intentionally a workflow view, not the
      // master farmer registry. Only fully eligible farmers with an assigned
      // procurement centre are shown.
      final eligible = v?['eligibility_status']?.toString() == 'verified' &&
          v?['identity_status']?.toString() == 'verified' &&
          v?['land_status']?.toString() == 'verified' &&
          v?['bank_status']?.toString() == 'verified' &&
          v?['crop_status']?.toString() == 'verified';
      final assigned = appointment?['centre_id'] != null &&
          (appointment?['status']?.toString() == 'assigned' ||
              appointment?['status']?.toString() == 'rescheduled');

      if (!eligible || !assigned) continue;

      final status = statusById[id] ?? const <String, dynamic>{};
      final procurement =
          procurementById[id] ?? const <String, dynamic>{};
      result.add({
        ...farmer,
        'verification': v ?? <String, dynamic>{},
        'appointment': appointment ?? <String, dynamic>{},
        'status': status,
        'procurement': procurement,
      });
    }
    return result;
  }

  Future<void> updateCentre(String centreId, Map<String, dynamic> values) async {
    if (values.isEmpty) return;
    await client.from('centres').update(values).eq('centre_id', centreId);
  }

  Future<void> updateProcurementStages(
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

    final normalized = stages
        .map((stage) => stage.trim())
        .where((stage) => stage.isNotEmpty)
        .toSet();

    for (final stage in normalized) {
      if (!ordered.contains(stage)) {
        throw StateError('Invalid procurement stage: $stage');
      }
    }

    final stageList = <String>[];
    for (final stage in ordered) {
      if (normalized.contains(stage)) stageList.add(stage);
    }

    // Persist the whole Government status change atomically in Supabase.
    // The database function validates the workflow, writes the related
    // attendance/procurement/payment state, creates the farmer-specific
    // notification, and records the audit event.
    await client.rpc(
      'save_procurement_stage_update',
      params: {
        'p_farmer_id': farmerId,
        'p_stages': stageList,
      },
    );
  }

  Future<Set<String>> loadUnavailableCentreDates() async {
    try {
      final rows = await client
          .from('centre_unavailability')
          .select('centre_id, service_date');
      return rows
          .map((row) => '${row['centre_id']}|${row['service_date']}')
          .toSet();
    } catch (_) {
      // The old database can still be used until the migration is run.
      return <String>{};
    }
  }

  Future<void> setCentreUnavailable({
    required String centreId,
    required DateTime date,
    required bool unavailable,
  }) async {
    final dateKey = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    if (unavailable) {
      await client.from('centre_unavailability').upsert({
        'centre_id': centreId,
        'service_date': dateKey,
      });
    } else {
      await client.from('centre_unavailability')
          .delete()
          .eq('centre_id', centreId)
          .eq('service_date', dateKey);
    }
  }

}

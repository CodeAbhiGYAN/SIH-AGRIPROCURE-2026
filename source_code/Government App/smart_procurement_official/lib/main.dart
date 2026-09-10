import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'models/models.dart';
import 'services/data_service.dart';
import 'services/procurement_timing.dart';
import 'services/supabase_backend.dart';
import 'scheduling/rescheduling.dart';
import 'screens/official_auth_screen.dart';
import 'screens/official_shell_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  runApp(const SmartProcurementOfficialApp());
}

class AppState extends ChangeNotifier {
  final DataService data = DataService();
  final SupabaseBackend backend = SupabaseBackend();
  RealtimeChannel? _realtimeChannel;
  Timer? _sharedSyncTimer;
  bool loadingSharedData = false;
  bool _sharedRefreshPending = false;

  OfficialIdentity? officialUser;
  bool authenticated = false;

  final Map<String, Set<String>> procurementDone = <String, Set<String>>{};

  int reassignmentCount = 0;

  /// Centre/date keys in the form CentreID|yyyy-mm-dd.
  final Set<String> unavailableCentreDates = <String>{};

  AppState();

  // ---------------------------------------------------------------------------
  // OFFICIAL LOGIN
  // ---------------------------------------------------------------------------

  Future<void> loginOfficial(OfficialIdentity user) async {
    officialUser = user;
    authenticated = true;
    await loadSharedData();
    _startRealtime();
    _startSharedSyncFallback();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // LOGOUT
  // ---------------------------------------------------------------------------

  void logout() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    _sharedSyncTimer?.cancel();
    _sharedSyncTimer = null;
    authenticated = false;
    officialUser = null;
    notifyListeners();
  }

  Future<void> loadSharedData() async {
    if (loadingSharedData) return;
    loadingSharedData = true;
    try {
      final centreRows = await backend.loadCentres();
      final farmerRows = await backend.loadGovernmentFarmers();
      final remoteUnavailable = await backend.loadUnavailableCentreDates();
      unavailableCentreDates
        ..clear()
        ..addAll(remoteUnavailable);

      data.centres
        ..clear()
        ..addAll(centreRows.map(_centreFromRow));
      data.farmers
        ..clear()
        ..addAll(farmerRows.map(_farmerFromRow));

      procurementDone
        ..clear()
        ..addEntries(farmerRows.map((row) {
          final procurement = Map<String, dynamic>.from(
            (row['procurement'] as Map?) ?? const <String, dynamic>{},
          );
          final status = Map<String, dynamic>.from(
            (row['status'] as Map?) ?? const <String, dynamic>{},
          );
          return MapEntry(
            row['farmer_id'].toString(),
            _procurementStagesFromRows(procurement, status),
          );
        }));
    } catch (_) {
      // Keep the official UI usable if Supabase is temporarily unavailable.
    } finally {
      loadingSharedData = false;
    }
    notifyListeners();
  }

  Centre _centreFromRow(Map<String, dynamic> row) {
    return Centre(
      id: row['centre_id'].toString(),
      name: row['name'].toString(),
      address: row['address'].toString(),
      lat: (row['lat'] as num?)?.toDouble() ?? 0,
      lng: (row['lng'] as num?)?.toDouble() ?? 0,
      capacity: (row['capacity'] as num?)?.toDouble() ?? 0,
      currentLoad: (row['current_load'] as num?)?.toDouble() ?? 0,
      processingRate: (row['processing_rate'] as num?)?.toDouble() ?? 0,
      queue: (row['queue_count'] as num?)?.toInt() ?? 0,
      activeStaff: (row['active_staff'] as num?)?.toInt() ?? 0,
      staffTotal: (row['staff_total'] as num?)?.toInt() ?? 0,
      weighbridgesWorking: (row['weighbridges_working'] as num?)?.toInt() ?? 0,
      weighbridgesTotal: (row['weighbridges_total'] as num?)?.toInt() ?? 0,
      status: _centreStatus(row['status']?.toString()),
      qualityTestingOk: row['quality_testing_ok'] != false,
      storageOk: row['storage_ok'] != false,
      transportOk: row['transport_ok'] != false,
    );
  }

  CentreStatus _centreStatus(String? value) {
    return switch (value) {
      'busy' => CentreStatus.busy,
      'highLoad' => CentreStatus.highLoad,
      'delayed' => CentreStatus.delayed,
      'degraded' => CentreStatus.degraded,
      'unavailable' => CentreStatus.unavailable,
      _ => CentreStatus.normal,
    };
  }

  Farmer _farmerFromRow(Map<String, dynamic> row) {
    final appointment = Map<String, dynamic>.from(
      (row['appointment'] as Map?) ?? const <String, dynamic>{},
    );
    final status = Map<String, dynamic>.from(
      (row['status'] as Map?) ?? const <String, dynamic>{},
    );
    final procurement = Map<String, dynamic>.from(
      (row['procurement'] as Map?) ?? const <String, dynamic>{},
    );

    final procurementStatus = procurement['procurement_status']?.toString();
    final location = status['location_status']?.toString();
    final state = procurementStatus == 'completed'
        ? FarmerState.completed
        : procurementStatus == 'in_progress'
            ? FarmerState.processing
            : location == 'AT_CENTRE'
                ? FarmerState.arrived
                : location == 'ON_WAY'
                    ? FarmerState.travelling
                    : FarmerState.assigned;

    return Farmer(
      id: row['farmer_id'].toString(),
      name: row['name'].toString(),
      mobile: row['mobile'].toString(),
      village: row['village'].toString(),
      crop: row['crop'].toString(),
      expectedQuantity: (row['expected_quantity'] as num?)?.toDouble() ?? 0,
      cultivatedArea: (row['cultivated_area'] as num?)?.toDouble() ?? 0,
      priorityScore: (row['priority_score'] as num?)?.toInt() ?? 0,
      procurementDay: _formatDate(appointment['procurement_date']?.toString()),
      window: _formatWindow(
        appointment['window_start']?.toString(),
        appointment['window_end']?.toString(),
      ),
      centreId: appointment['centre_id']?.toString() ?? 'A',
      state: state,
      hasLeftHome: row['has_left_home'] == true || location != 'HOME',
      lat: (row['lat'] as num?)?.toDouble() ?? 0,
      lng: (row['lng'] as num?)?.toDouble() ?? 0,
      queueToken: (appointment['queue_token'] as num?)?.toInt() ?? 0,
      appointmentId: appointment['appointment_id']?.toString(),
      queueEnteredAt: DateTime.tryParse(status['queue_entered_at']?.toString() ?? '')?.toLocal(),
      predictedProcessingMinutes: (appointment['predicted_processing_minutes'] as num?)?.toDouble() ?? 7.0,
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'Not assigned';
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  String _formatWindow(String? start, String? end) {
    String fmt(String? value) {
      if (value == null || value.isEmpty) return '--';
      final parts = value.split(':');
      if (parts.length < 2) return value;
      final h = int.tryParse(parts[0]) ?? 0;
      final m = parts[1];
      final period = h >= 12 ? 'PM' : 'AM';
      final displayH = h % 12 == 0 ? 12 : h % 12;
      return '$displayH:$m $period';
    }
    return '${fmt(start)}–${fmt(end)}';
  }

  Set<String> _procurementStagesFromRows(
    Map<String, dynamic> procurement,
    Map<String, dynamic> status,
  ) {
    final out = <String>{};
    final stored = procurement['stages'];

    if (stored is List) {
      out.addAll(
        stored
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty),
      );
    } else {
      // Backward-compatible fallback.
      if (procurement['quality_check_status']?.toString() == 'completed') {
        out.add('Quality check');
      }
      final p = procurement['procurement_status']?.toString();
      if (p == 'in_progress' || p == 'completed') {
        out.add('Weighing');
        out.add('Procurement');
      }
      if (p == 'completed') out.add('Bill');
    }

    // Attendance is stored as a physical checkpoint in farmer_status.
    if (status['attendance_status'] == true) out.add('Attendance');

    return out;
  }

  void _startRealtime() {
    _realtimeChannel?.unsubscribe();
    const tables = [
      'farmers',
      'verification',
      'appointments',
      'farmer_status',
      'procurement',
      'centre_unavailability',
    ];
    var channel = Supabase.instance.client.channel('government-shared-sync');
    for (final table in tables) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => _requestSharedRefresh(),
      );
    }
    _realtimeChannel = channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _requestSharedRefresh();
      }
    });
  }

  void _startSharedSyncFallback() {
    _sharedSyncTimer?.cancel();
    if (!authenticated) return;
    _sharedSyncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (authenticated) {
        _requestSharedRefresh();
      }
    });
  }

  void _requestSharedRefresh() {
    if (!authenticated) return;
    _sharedRefreshPending = true;
    if (loadingSharedData) return;
    _sharedRefreshPending = false;
    unawaited(_performSharedRefresh());
  }

  Future<void> _performSharedRefresh() async {
    await loadSharedData();
    if (_sharedRefreshPending && authenticated) {
      _sharedRefreshPending = false;
      unawaited(_performSharedRefresh());
    }
  }

  // ---------------------------------------------------------------------------
  // CENTRE DATE AVAILABILITY
  // ---------------------------------------------------------------------------

  String dateKey(DateTime date) =>
      AppointmentScheduler.dateKey(date);

  String centreDateKey(
    String centreId,
    DateTime date,
  ) =>
      AppointmentScheduler.centreDateKey(
        centreId,
        date,
      );

  bool isCentreUnavailable(
    String centreId,
    DateTime date,
  ) {
    return unavailableCentreDates.contains(
      centreDateKey(centreId, date),
    );
  }

  Future<void> setCentreUnavailable(
    String centreId,
    DateTime date,
    bool unavailable,
  ) async {
    final key = centreDateKey(centreId, date);
    if (unavailable) {
      unavailableCentreDates.add(key);
    } else {
      unavailableCentreDates.remove(key);
    }
    notifyListeners();
    try {
      await backend.setCentreUnavailable(
        centreId: centreId,
        date: date,
        unavailable: unavailable,
      );
      await loadSharedData();
    } catch (_) {
      // Reconcile the UI with the authoritative backend state on failure.
      final remote = await backend.loadUnavailableCentreDates();
      unavailableCentreDates
        ..clear()
        ..addAll(remote);
      notifyListeners();
    }
  }

  Future<void> setCentreUnavailableBatch(
    Map<String, Set<DateTime>> changes,
  ) async {
    final previous = Set<String>.from(unavailableCentreDates);
    try {
      for (final entry in changes.entries) {
        for (final date in entry.value) {
          final key = centreDateKey(entry.key, date);
          unavailableCentreDates.add(key);
          await backend.setCentreUnavailable(
            centreId: entry.key,
            date: date,
            unavailable: true,
          );
        }
      }
      await loadSharedData();
    } catch (_) {
      unavailableCentreDates
        ..clear()
        ..addAll(previous);
      notifyListeners();
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // WEIGHBRIDGES
  // ---------------------------------------------------------------------------

  void updateWeighbridges({
    required String centreId,
    required int totalInstalled,
    required int working,
  }) {
    final index = data.centres.indexWhere(
      (centre) => centre.id == centreId,
    );

    if (index < 0) return;

    final safeTotal = totalInstalled.clamp(0, 50).toInt();
    final safeWorking = working.clamp(0, safeTotal).toInt();

    data.centres[index] = data.centres[index].copyWith(
      weighbridgesTotal: safeTotal,
      weighbridgesWorking: safeWorking,
    );

    unawaited(backend.updateCentre(centreId, {
      'weighbridges_total': safeTotal,
      'weighbridges_working': safeWorking,
    }));
    _synchronizeScheduling();
  }

  // ---------------------------------------------------------------------------
  // STAFF AVAILABILITY
  // ---------------------------------------------------------------------------

  /// Represents a fresh count coming from the external attendance source.
  /// The Government UI itself does not manage individual attendance.
  void updateAvailableStaff({
    required String centreId,
    required int availableStaff,
  }) {
    final index = data.centres.indexWhere(
      (centre) => centre.id == centreId,
    );

    if (index < 0) return;

    final centre = data.centres[index];
    final safeStaff = availableStaff
        .clamp(0, centre.staffTotal)
        .toInt();

    data.centres[index] = centre.copyWith(
      activeStaff: safeStaff,
    );

    unawaited(backend.updateCentre(centreId, {
      'active_staff': safeStaff,
    }));
    _synchronizeScheduling();
  }

  // ---------------------------------------------------------------------------
  // CENTRE CONDITIONS
  // ---------------------------------------------------------------------------

  void updateCentreConditions({
    required String centreId,
    CentreStatus? status,
    bool? qualityTestingOk,
    bool? storageOk,
    bool? transportOk,
  }) {
    final index = data.centres.indexWhere(
      (centre) => centre.id == centreId,
    );

    if (index < 0) return;

    data.centres[index] = data.centres[index].copyWith(
      status: status,
      qualityTestingOk: qualityTestingOk,
      storageOk: storageOk,
      transportOk: transportOk,
    );

    unawaited(backend.updateCentre(centreId, {
      if (status != null) 'status': switch (status) {
        CentreStatus.busy => 'busy',
        CentreStatus.highLoad => 'highLoad',
        CentreStatus.delayed => 'delayed',
        CentreStatus.degraded => 'degraded',
        CentreStatus.unavailable => 'unavailable',
        CentreStatus.normal => 'normal',
      },
      if (qualityTestingOk != null) 'quality_testing_ok': qualityTestingOk,
      if (storageOk != null) 'storage_ok': storageOk,
      if (transportOk != null) 'transport_ok': transportOk,
    }));
    _synchronizeScheduling();
  }

  // ---------------------------------------------------------------------------
  // SHARED SCHEDULING UPDATE
  // ---------------------------------------------------------------------------

  void refreshScheduling() {
    _synchronizeScheduling();
  }

  void _synchronizeScheduling({bool notify = true}) {
    // Farmer assignment state is owned by Supabase. The SIH demonstration
    // policy keeps eligible demo farmers on Centre A, so local scheduling
    // logic must not overwrite the remote centre assignment.
    if (notify) notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // PROCUREMENT STATUS
  // ---------------------------------------------------------------------------

  static const Set<String> requiredProcurementStages = <String>{
    'Attendance',
    'Arrival',
    'Quality check',
    'Weighing',
    'Procurement',
    'Bill',
    'Payment',
  };

  Future<void> setProcurementStages(
    String farmerId,
    Set<String> stages,
  ) async {
    final normalized = stages
        .map((stage) => stage.trim())
        .where((stage) => stage.isNotEmpty)
        .toSet();

    // Wait for the authoritative database transaction. We do not mark the
    // Government UI as saved until Supabase confirms the change.
    await backend.updateProcurementStages(farmerId, normalized);
    await loadSharedData();
    notifyListeners();
  }


  bool isProcurementCompleted(Farmer farmer) {
    final done = procurementDone[farmer.id] ?? <String>{};
    return requiredProcurementStages.every(
      done.contains,
    );
  }

  // ---------------------------------------------------------------------------
  // DEMO FAILURE
  // ---------------------------------------------------------------------------

  void simulateFailure() {
    final index = data.centres.indexWhere(
      (centre) => centre.id == 'A',
    );

    if (index < 0) return;

    data.centres[index] = data.centres[index].copyWith(
      currentLoad: 98,
      queue: 86,
      processingRate: 8,
      weighbridgesWorking: 1,
      status: CentreStatus.degraded,
    );

    _synchronizeScheduling();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    _sharedSyncTimer?.cancel();
    _sharedSyncTimer = null;
    super.dispose();
  }
}

// ============================================================================
// APPLICATION ROOT
// ============================================================================

class SmartProcurementOfficialApp
    extends StatefulWidget {
  const SmartProcurementOfficialApp({
    super.key,
  });

  @override
  State<SmartProcurementOfficialApp> createState() =>
      _SmartProcurementOfficialAppState();
}

class _SmartProcurementOfficialAppState
    extends State<SmartProcurementOfficialApp> {
  late final AppState state;

  @override
  void initState() {
    super.initState();
    state = AppState();
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Smart Procurement Official',
          theme: AppTheme.light,
          home: state.authenticated
              ? OfficialShellScreen(
                  state: state,
                )
              : OfficialAuthScreen(
                  state: state,
                ),
        );
      },
    );
  }
}

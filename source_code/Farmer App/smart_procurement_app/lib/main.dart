import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/models.dart';
import 'config/supabase_config.dart';
import 'services/ai_service.dart';
import 'services/data_service.dart';
import 'services/maps_service.dart';
import 'services/notification_service.dart';
import 'services/procurement_timing.dart';
import 'services/queue_service.dart';
import 'services/supabase_backend.dart';
import 'services/localization_service.dart';
import 'scheduling/rescheduling.dart';
import 'screens/assistant_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/queue_screen.dart';
import 'screens/status_screen.dart';
import 'screens/travel_screen.dart';
import 'screens/verification_screen.dart';
import 'screens/msp_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  runApp(const SmartProcurementApp());
}

class AppState extends ChangeNotifier {
  final DataService data = DataService();
  final NotificationService notifications = NotificationService();
  final QueueService queue = QueueService();
  final MapsService maps = MapsService();
  final AiService ai = AiService();
  final SupabaseBackend backend = SupabaseBackend();

  RealtimeChannel? _realtimeChannel;
  Timer? _remoteSyncTimer;
  bool _remoteLoading = false;
  bool _remoteRefreshPending = false;
  bool _remoteRefreshNotificationsPending = false;
  final Set<int> _seenRemoteNotificationIds = <int>{};
  final Set<String> _pendingVerificationStages = <String>{};
  QueueSnapshot queueSnapshot = const QueueSnapshot.empty();

  int tab = 0;
  bool farmerMode = true;
  bool authenticated = false;
  bool sessionReady = false;
  bool verified = false;
  String language = 'English';

  String t(String key) => FarmerLocalizer.text(language, key);

  bool appointmentAssigned = false;
  bool appointmentNotificationVisible = false;
  bool _appointmentDelayActive = false;

  int procurementStage = 1;

  String farmerId = 'F001';
  String farmerName = '';
  String farmerMobile = '';

  Timer? appointmentTimer;
  Timer? notificationTimer;

  AppNotification? activeNotification;

  final Map<String, Set<String>> procurementDone = {};
  final Map<String, DateTime> attendanceAt = {};

  int reassignmentCount = 0;

  final Set<String> verificationCompleted = <String>{};

  String bankName = '';
  String bankAccount = '';
  String bankConfirmAccount = '';
  String bankIfsc = '';

  String selectedCrop = '';
  String cropQuantity = '';
  String cropSeason = '';

  AppState() {
    unawaited(_restoreSession());
  }

  Farmer get farmer =>
      data.farmers.firstWhere((f) => f.id == farmerId);

  Centre get assignedCentre =>
      data.centres.firstWhere((c) => c.id == farmer.centreId);

  Map<String, String> get assistantContext {
    final f = farmer;
    final c = assignedCentre;
    final done = procurementDone[farmerId] ?? <String>{};

    final verificationText =
        verificationCompleted.length == 5
            ? 'Complete'
            : '${verificationCompleted.length}/5 completed';

    final statusText = done.isEmpty
        ? 'Verification complete; centre processing has not started yet'
        : done.join(', ');

    return {
      'leave': recommendedArrivalTime == null ? '--' : _formatDateTime(recommendedArrivalTime!),
      'centre': c.name,
      'date': f.procurementDay,
      'slot': f.window,
      'queue': '${queueSnapshot.farmersAhead}',
      'verification': verificationText,
      'payment': done.contains('Payment') ? 'Completed' : 'Pending',
      'attendance': done.contains('Attendance') ? 'marked' : 'pending',
      'status': statusText,
      'language': language,
    };
  }

  // ---------------------------------------------------------------------------
  // PERSISTENCE
  // ---------------------------------------------------------------------------

  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSession = prefs.getBool('sp_session_active') ?? false;
      if (!savedSession) {
        sessionReady = true;
        notifyListeners();
        return;
      }

      final savedFarmerId = prefs.getString('sp_farmer_id') ?? '';
      if (savedFarmerId.isEmpty ||
          !data.farmers.any((f) => f.id == savedFarmerId)) {
        await _clearSavedSession();
        sessionReady = true;
        notifyListeners();
        return;
      }

      farmerId = savedFarmerId;
      farmerName = prefs.getString('sp_farmer_name') ?? '';
      farmerMobile = prefs.getString('sp_farmer_mobile') ?? '';
      tab = prefs.getInt('sp_tab') ?? 0;
      farmerMode = prefs.getBool('sp_farmer_mode') ?? true;
      language = prefs.getString('sp_language') ?? 'English';
      authenticated = true;

      await _loadRemoteState(showPendingNotifications: true);
      _startRealtime();
    } catch (_) {
      authenticated = false;
    }

    sessionReady = true;
    notifyListeners();
  }

  Future<void> _loadRemoteState({bool showPendingNotifications = false}) async {
    if (_remoteLoading) return;
    _remoteLoading = true;
    try {
      final bundle = await backend.loadFarmer(farmerId);
      if (bundle == null) return;

      final f = bundle.farmer;
      final v = bundle.verification;
      final appointment = bundle.appointment;
      final status = bundle.status;
      final procurement = bundle.procurement;
      final payment = bundle.payment;
      queueSnapshot = bundle.queueSnapshot;
      _lastPaymentStatus = payment['payment_status']?.toString() ?? 'pending';

      farmerName = f['name']?.toString() ?? farmerName;
      farmerMobile = f['mobile']?.toString() ?? farmerMobile;
      language = (f['language']?.toString() == 'Hindi') ? 'Hindi' : 'English';

      final remoteVerified = _verifiedStages(v);

      // Realtime/polling can briefly return a stale verification snapshot
      // immediately after a successful write. Never let that stale snapshot
      // make a just-confirmed checkbox visibly disappear. A stage leaves the
      // pending set only after the server snapshot explicitly confirms it.
      _pendingVerificationStages.removeWhere(remoteVerified.contains);
      verificationCompleted
        ..clear()
        ..addAll(remoteVerified)
        ..addAll(_pendingVerificationStages);
      verified = verificationCompleted.length == 5;

      bankName = v['bank_name']?.toString() ?? '';
      bankAccount = v['bank_account']?.toString() ?? '';
      bankConfirmAccount = bankAccount;
      bankIfsc = v['bank_ifsc']?.toString() ?? '';
      selectedCrop = v['selected_crop']?.toString() ?? f['crop']?.toString() ?? '';
      final remoteQty = v['crop_quantity'];
      cropQuantity = remoteQty == null ? '' : remoteQty.toString();
      cropSeason = v['crop_season']?.toString() ?? '';

      procurementDone
        ..clear()
        ..[farmerId] = _procurementStages(procurement, status);

      attendanceAt.clear();
      final attendanceRaw = status['attendance_at'];
      if (attendanceRaw != null) {
        attendanceAt[farmerId] = DateTime.tryParse(attendanceRaw.toString())?.toLocal() ?? DateTime.now();
      }

      final appointmentAssignedRemote =
          appointment != null &&
          (appointment['status']?.toString() == 'assigned' ||
              appointment['status']?.toString() == 'rescheduled');

      // While the deliberate post-verification appointment delay is active,
      // never let a remote refresh expose the appointment early. The only
      // code allowed to flip this to true during a fresh assignment is the
      // timer callback below, after Centre A has actually been assigned.
      appointmentAssigned = _appointmentDelayActive
          ? false
          : appointmentAssignedRemote;

      // A verified farmer without an appointment is intentionally kept in
      // the appointment-arranging state. When returning to the app during
      // this state, restart the short demo allocation delay rather than
      // exposing Centre A/queue/travel prematurely.
      if (verified && !appointmentAssigned &&
          f['workflow_state']?.toString() == 'verified' &&
          appointmentTimer == null) {
        _scheduleAppointmentAssignmentDelay();
      }

      if (appointment != null) {
        final index = data.farmers.indexWhere((item) => item.id == farmerId);
        if (index >= 0) {
          data.farmers[index] = data.farmers[index].copyWith(
            procurementDay: ProcurementTiming.formatDate(appointment['procurement_date']?.toString()),
            window: ProcurementTiming.formatWindow(
              appointment['window_start']?.toString(),
              appointment['window_end']?.toString(),
            ),
            centreId: appointment['centre_id']?.toString() ?? 'A',
            state: _farmerStateFromRemote(status, procurement, appointment),
            hasLeftHome: f['has_left_home'] == true ||
                status['location_status']?.toString() != 'HOME',
            appointmentId: appointment['appointment_id']?.toString(),
            queueToken: (appointment['queue_token'] as num?)?.toInt() ?? 0,
            queueEnteredAt: DateTime.tryParse(status['queue_entered_at']?.toString() ?? '')?.toLocal(),
            predictedProcessingMinutes: (appointment['predicted_processing_minutes'] as num?)?.toDouble() ?? 7.0,
          );
        }
      } else {
        final index = data.farmers.indexWhere((item) => item.id == farmerId);
        if (index >= 0) {
          data.farmers[index] = data.farmers[index].copyWith(
            procurementDay: 'Not assigned',
            window: 'Not assigned',
            centreId: 'A',
            state: FarmerState.assigned,
            hasLeftHome: false,
            clearAppointment: true,
          );
          queueSnapshot = const QueueSnapshot.empty();
        }
      }

      if (verified && appointmentAssigned) {
        final done = procurementDone[farmerId] ?? <String>{};
        procurementStage = done.isEmpty ? 1 : (done.length + 1).clamp(1, 7);
      }

      if (showPendingNotifications || bundle.unreadNotifications.isNotEmpty) {
        await _handleRemoteNotifications(
          bundle.unreadNotifications,
          allowAppointmentNotification: !_appointmentDelayActive &&
              (appointmentAssigned || appointmentTimer == null),
        );
      }
    } catch (_) {
      // Keep the app usable if Supabase is temporarily unavailable.
    } finally {
      _remoteLoading = false;
      // Remote data is shared application state. Rebuild the visible UI after
      // every successful/attempted synchronization so background changes are
      // immediately reflected without a tab change or app restart.
      if (authenticated) {
        notifyListeners();
      }
    }
  }

  Set<String> _verifiedStages(Map<String, dynamic> v) {
    final out = <String>{};
    if (v['identity_status']?.toString() == 'verified') out.add('Identity');
    if (v['land_status']?.toString() == 'verified') out.add('Land Record');
    if (v['bank_status']?.toString() == 'verified') out.add('Bank Account');
    if (v['crop_status']?.toString() == 'verified') out.add('Crop');
    if (v['eligibility_status']?.toString() == 'verified') out.add('Eligibility');
    return out;
  }

  Set<String> _procurementStages(
    Map<String, dynamic> procurement,
    Map<String, dynamic> status,
  ) {
    final out = <String>{};

    // The database stores the exact Government-selected procurement stages.
    // Start with that authoritative list when present.
    final stored = procurement['stages'];
    if (stored is List) {
      out.addAll(
        stored
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty),
      );
    } else {
      // Backward-compatible fallback for very old records.
      if (procurement['quality_check_status']?.toString() == 'completed') {
        out.add('Quality check');
      }
      final ps = procurement['procurement_status']?.toString();
      if (ps == 'in_progress' || ps == 'completed') {
        out.add('Weighing');
        out.add('Procurement');
      }
      if (ps == 'completed') out.add('Bill');
    }

    // Attendance is a Farmer-side physical checkpoint stored in
    // farmer_status. Always merge it so a realtime refresh, tab change,
    // language change, or app restart cannot erase a saved attendance.
    if (status['attendance_status'] == true) {
      out.add('Attendance');
    }

    if (paymentStateForCurrentFarmer == 'completed') {
      out.add('Payment');
    }

    return out;
  }

  String get paymentStateForCurrentFarmer => _lastPaymentStatus;
  String _lastPaymentStatus = 'pending';

  FarmerState _farmerStateFromRemote(
    Map<String, dynamic> status,
    Map<String, dynamic> procurement,
    Map<String, dynamic> appointment,
  ) {
    if (procurement['procurement_status']?.toString() == 'completed') {
      return FarmerState.completed;
    }
    if (procurement['procurement_status']?.toString() == 'in_progress') {
      return FarmerState.processing;
    }
    switch (status['location_status']?.toString()) {
      case 'AT_CENTRE':
        return FarmerState.arrived;
      case 'ON_WAY':
        return FarmerState.travelling;
      default:
        return FarmerState.assigned;
    }
  }

  void _startRealtime() {
    _realtimeChannel?.unsubscribe();
    final farmerIdFilter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'farmer_id',
      value: farmerId,
    );

    _realtimeChannel = Supabase.instance.client
        .channel('farmer-${farmerId}-sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'farmers',
          filter: farmerIdFilter,
          callback: (_) => _requestRemoteRefresh(showPendingNotifications: true),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'verification',
          filter: farmerIdFilter,
          callback: (_) => _requestRemoteRefresh(showPendingNotifications: true),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'appointments',
          filter: farmerIdFilter,
          callback: (_) => _requestRemoteRefresh(showPendingNotifications: true),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'farmer_status',
          filter: farmerIdFilter,
          callback: (_) => _requestRemoteRefresh(showPendingNotifications: true),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'procurement',
          filter: farmerIdFilter,
          callback: (_) => _requestRemoteRefresh(showPendingNotifications: true),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: farmerIdFilter,
          callback: (_) => _requestRemoteRefresh(showPendingNotifications: true),
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            _requestRemoteRefresh(showPendingNotifications: true);
          } else if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut ||
              status == RealtimeSubscribeStatus.closed) {
            // The periodic fallback below keeps state fresh even when the
            // WebSocket is temporarily unavailable.
          }
        });
  }

  void _startRemoteSyncFallback() {
    _remoteSyncTimer?.cancel();
    if (!authenticated) return;
    _remoteSyncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (authenticated) {
        _requestRemoteRefresh(showPendingNotifications: true);
      }
    });
  }

  void _requestRemoteRefresh({bool showPendingNotifications = false}) {
    if (!authenticated) return;
    _remoteRefreshPending = true;
    _remoteRefreshNotificationsPending =
        _remoteRefreshNotificationsPending || showPendingNotifications;
    if (_remoteLoading) return;

    _remoteRefreshPending = false;
    final showNotifications = _remoteRefreshNotificationsPending;
    _remoteRefreshNotificationsPending = false;
    unawaited(_performRemoteRefresh(showNotifications));
  }

  Future<void> _performRemoteRefresh(bool showPendingNotifications) async {
    await _loadRemoteState(showPendingNotifications: showPendingNotifications);
    if (_remoteRefreshPending && authenticated) {
      // Process any Realtime event / polling tick that arrived while the
      // previous fetch was in flight.
      _remoteRefreshPending = false;
      final showNotifications = _remoteRefreshNotificationsPending;
      _remoteRefreshNotificationsPending = false;
      unawaited(_performRemoteRefresh(showNotifications));
    }
  }

  Future<void> _handleRemoteNotifications(
    List<Map<String, dynamic>> rows, {
    required bool allowAppointmentNotification,
  }) async {
    for (final row in rows) {
      final id = int.tryParse(row['notification_id']?.toString() ?? '');
      if (id == null || _seenRemoteNotificationIds.contains(id)) continue;

      final kind = row['kind']?.toString() ?? 'general';
      if ((kind == 'appointment' || kind == 'reschedule') && !allowAppointmentNotification) {
        continue;
      }

      _seenRemoteNotificationIds.add(id);
      final noteKind = switch (kind) {
        'appointment' => NotificationKind.appointment,
        'reschedule' => NotificationKind.reschedule,
        'otp' => NotificationKind.otp,
        _ => NotificationKind.general,
      };
      final note = AppNotification(
        row['title']?.toString() ?? 'Smart Procurement',
        row['message']?.toString() ?? 'You have a new update.',
        DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
        details: row['details']?.toString() ?? '',
        critical: noteKind == NotificationKind.reschedule,
        kind: noteKind,
      );
      _showNotification(note);
      await backend.markNotificationRead(id);
    }
  }

  Future<void> _saveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final done =
          procurementDone[farmerId] ?? <String>{};

      await prefs.setBool('sp_session_active', authenticated);

      await prefs.setString('sp_farmer_id', farmerId);
      await prefs.setString('sp_farmer_name', farmerName);
      await prefs.setString('sp_farmer_mobile', farmerMobile);

      await prefs.setInt('sp_tab', tab);
      await prefs.setBool('sp_farmer_mode', farmerMode);
      await prefs.setBool('sp_verified', verified);
      await prefs.setString('sp_language', language);

      await prefs.setBool(
        'sp_appointment_assigned',
        appointmentAssigned,
      );

      await prefs.setInt(
        'sp_procurement_stage',
        procurementStage,
      );

      await prefs.setInt(
        'sp_reassignment_count',
        reassignmentCount,
      );

      await prefs.setStringList(
        'sp_verification_completed',
        verificationCompleted.toList(),
      );

      await prefs.setString('sp_bank_name', bankName);
      await prefs.setString('sp_bank_account', bankAccount);
      await prefs.setString(
        'sp_bank_confirm_account',
        bankConfirmAccount,
      );
      await prefs.setString('sp_bank_ifsc', bankIfsc);

      await prefs.setString(
        'sp_selected_crop',
        selectedCrop,
      );
      await prefs.setString(
        'sp_crop_quantity',
        cropQuantity,
      );
      await prefs.setString(
        'sp_crop_season',
        cropSeason,
      );

      await prefs.setStringList(
        'sp_procurement_done',
        done.toList(),
      );

      final attendanceTime = attendanceAt[farmerId];

      if (attendanceTime != null) {
        await prefs.setInt(
          'sp_attendance_time',
          attendanceTime.millisecondsSinceEpoch,
        );
      } else {
        await prefs.remove('sp_attendance_time');
      }

      final currentFarmerIndex = data.farmers.indexWhere(
        (f) => f.id == farmerId,
      );

      if (currentFarmerIndex >= 0) {
        await prefs.setString(
          'sp_farmer_centre_id',
          data.farmers[currentFarmerIndex].centreId,
        );
      }
    } catch (_) {
      // Storage failure must not break the app.
    }
  }

  Future<void> _clearSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      const keys = [
        'sp_session_active',
        'sp_farmer_id',
        'sp_farmer_name',
        'sp_farmer_mobile',
        'sp_tab',
        'sp_farmer_mode',
        'sp_verified',
        'sp_language',
        'sp_appointment_assigned',
        'sp_procurement_stage',
        'sp_reassignment_count',
        'sp_verification_completed',
        'sp_bank_name',
        'sp_bank_account',
        'sp_bank_confirm_account',
        'sp_bank_ifsc',
        'sp_selected_crop',
        'sp_crop_quantity',
        'sp_crop_season',
        'sp_procurement_done',
        'sp_attendance_time',
        'sp_farmer_centre_id',
      ];

      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {
      // Continue with logout even if storage clearing fails.
    }
  }

  // ---------------------------------------------------------------------------
  // LOGIN / LOGOUT
  // ---------------------------------------------------------------------------

  Future<void> login({
    required String farmerId,
    required String name,
    required String mobile,
  }) async {
    authenticated = true;
    farmerMode = true;
    this.farmerId = farmerId;
    farmerName = name;
    farmerMobile = mobile;
    tab = 0;
    activeNotification = null;

    appointmentTimer?.cancel();
    appointmentNotificationVisible = false;
    verificationCompleted.clear();
    _pendingVerificationStages.clear();
    queueSnapshot = const QueueSnapshot.empty();
    bankName = '';
    bankAccount = '';
    bankConfirmAccount = '';
    bankIfsc = '';
    selectedCrop = '';
    cropQuantity = '';
    cropSeason = '';
    procurementDone.clear();
    attendanceAt.clear();
    _seenRemoteNotificationIds.clear();

    await _loadRemoteState(showPendingNotifications: true);
    _startRealtime();
    _startRemoteSyncFallback();
    await _saveSession();
    notifyListeners();
  }

  void logout() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    _remoteSyncTimer?.cancel();
    _remoteSyncTimer = null;
    appointmentTimer?.cancel();
    notificationTimer?.cancel();

    authenticated = false;
    farmerMode = true;
    tab = 0;

    verified = false;
    language = 'English';

    appointmentAssigned = false;
    appointmentNotificationVisible = false;

    procurementStage = 1;

    verificationCompleted.clear();
    _pendingVerificationStages.clear();
    queueSnapshot = const QueueSnapshot.empty();

    bankName = '';
    bankAccount = '';
    bankConfirmAccount = '';
    bankIfsc = '';

    selectedCrop = '';
    cropQuantity = '';
    cropSeason = '';

    activeNotification = null;

    procurementDone.clear();
    attendanceAt.clear();

    reassignmentCount = 0;

    unawaited(_clearSavedSession());

    notifyListeners();
  }

  String _formatDateTime(DateTime value) {
    final period = value.hour >= 12 ? 'PM' : 'AM';
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return '$hour:${value.minute.toString().padLeft(2, '0')} $period';
  }

  // ---------------------------------------------------------------------------
  // GENERAL STATE
  // ---------------------------------------------------------------------------
  DateTime? get appointmentStart {
    if (!appointmentAssigned) return null;
    final day = data.farmers.firstWhere((f) => f.id == farmerId).procurementDay;
    final rawWindow = data.farmers.firstWhere((f) => f.id == farmerId).window;
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)').firstMatch(rawWindow);
    final date = _parseDisplayDay(day);
    if (match == null || date == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)!;
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  DateTime? get recommendedArrivalTime {
    final start = appointmentStart;
    return start?.subtract(const Duration(minutes: ProcurementTiming.arrivalBufferMinutes));
  }

  DateTime? _parseDisplayDay(String value) {
    final now = DateTime.now();
    final match = RegExp(r'^(\d{1,2})\s+([A-Za-z]{3})').firstMatch(value);
    if (match == null) return null;
    const months = <String, int>{
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    final month = months[match.group(2)!];
    final day = int.tryParse(match.group(1)!);
    if (month == null || day == null) return null;
    return DateTime(now.year, month, day);
  }


  void setLanguage(String value) {
    if (value != 'English' && value != 'Hindi') return;

    language = value;
    unawaited(backend.updateLanguage(farmerId, value));
    unawaited(_saveSession());
    notifyListeners();
  }

  void setTab(int index) {
    tab = index;

    unawaited(_saveSession());

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // VERIFICATION
  // ---------------------------------------------------------------------------

  Future<void> markVerificationComplete(String stage) async {
    _pendingVerificationStages.add(stage);
    verificationCompleted.add(stage);
    notifyListeners();
    try {
      await backend.updateVerificationStage(
        farmerId: farmerId,
        stage: stage,
        bankName: bankName,
        bankAccount: bankAccount,
        bankIfsc: bankIfsc,
        selectedCrop: selectedCrop,
        cropQuantity: num.tryParse(cropQuantity),
        cropSeason: cropSeason,
      );
      // Keep the pending marker until Supabase confirms this exact stage.
      // This prevents a stale realtime response from briefly unchecking it.
      await _loadRemoteState(showPendingNotifications: false);
      await _saveSession();
    } catch (e) {
      _pendingVerificationStages.remove(stage);
      await _loadRemoteState(showPendingNotifications: false);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> saveBankDetails(
    String bank,
    String account,
    String confirmAccount,
    String ifsc,
  ) async {
    bankName = bank;
    bankAccount = account;
    bankConfirmAccount = confirmAccount;
    bankIfsc = ifsc;
    await backend.updateVerificationStage(
      farmerId: farmerId,
      stage: 'Bank Account',
      bankName: bank,
      bankAccount: account,
      bankIfsc: ifsc,
    );
    await _saveSession();
    notifyListeners();
  }

  Future<void> saveCropDetails(
    String crop,
    String quantity,
    String season,
  ) async {
    selectedCrop = crop;
    cropQuantity = quantity;
    cropSeason = season;
    await backend.updateVerificationStage(
      farmerId: farmerId,
      stage: 'Crop',
      selectedCrop: crop,
      cropQuantity: num.tryParse(quantity),
      cropSeason: season,
    );
    await _saveSession();
    notifyListeners();
  }

  Future<void> completeVerification() async {
    if (verificationCompleted.length < 5) return;

    _pendingVerificationStages.addAll(const {
      'Identity',
      'Land Record',
      'Bank Account',
      'Crop',
      'Eligibility',
    });
    verified = true;
    data.setVerified();
    appointmentAssigned = false;
    appointmentNotificationVisible = false;
    appointmentTimer?.cancel();
    notifyListeners();

    try {
      await backend.finalizeVerification(farmerId: farmerId);
      // Keep optimistic verification markers until a server snapshot confirms
      // all five stages.
      await _loadRemoteState(showPendingNotifications: false);
      await _saveSession();
      _scheduleAppointmentAssignmentDelay();
    } catch (e) {
      _pendingVerificationStages.clear();
      verified = false;
      await _loadRemoteState(showPendingNotifications: false);
      rethrow;
    }
    notifyListeners();
  }

  void _scheduleAppointmentAssignmentDelay() {
    appointmentTimer?.cancel();
    _appointmentDelayActive = true;
    appointmentAssigned = false;
    appointmentNotificationVisible = false;
    notifyListeners();

    appointmentTimer = Timer(const Duration(seconds: 12), () async {
      try {
        // The RPC result is the exact moment the appointment has been
        // successfully assigned in Supabase. Trigger the Android notification
        // directly from that result; do not wait for Realtime/polling.
        final appointment =
            await backend.assignDemoCentreA(farmerId: farmerId);

        appointmentAssigned = true;
        appointmentNotificationVisible = true;
        notifyListeners();

        // Keep the arranging guard active while emitting the direct popup so a
        // concurrent Realtime event cannot create a second/premature popup.
        await _showRemoteAppointmentFromAppointment(appointment);

        // The appointment INSERT also creates a Supabase notification row.
        // The user has already seen that event directly, so mark the duplicate
        // database copy read before normal remote notification handling resumes.
        await backend.markAppointmentNotificationsRead(farmerId);

        _appointmentDelayActive = false;
        appointmentTimer = null;
        await _loadRemoteState(showPendingNotifications: true);
      } catch (_) {
        // Keep the arranging state visible if assignment is temporarily
        // unavailable; realtime/login sync can reconcile it later.
      } finally {
        _appointmentDelayActive = false;
        appointmentTimer = null;
        unawaited(_saveSession());
        notifyListeners();
      }
    });

  }

  Future<void> _finalizeRemoteVerification() async {
    try {
      await backend.finalizeVerification(farmerId: farmerId);
      await _loadRemoteState(showPendingNotifications: true);
      // Do not assign Centre A here. That must happen only after the
      // appointment-arranging delay above.
      appointmentAssigned = false;
      appointmentNotificationVisible = false;
      notifyListeners();
    } catch (_) {
      // Local UI remains usable while the backend can be retried by a later sync.
    }
  }

  Future<bool> _appointmentExists() async {
    try {
      return await backend.appointmentFor(farmerId) != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showRemoteAppointmentFromAppointment(
    Map<String, dynamic> appointment,
  ) async {
    final centreId = appointment['centre_id']?.toString() ?? 'A';
    final centre = data.centres.firstWhere(
      (c) => c.id == centreId,
      orElse: () => data.centres.first,
    );
    final date = ProcurementTiming.formatDate(appointment['procurement_date']?.toString());
    final start = ProcurementTiming.formatTime(appointment['window_start']?.toString());
    final end = ProcurementTiming.formatTime(appointment['window_end']?.toString());
    final note = AppNotification(
      'Appointment confirmed',
      '${centre.name} • $date • $start – $end',
      DateTime.now(),
      details:
          'Your procurement appointment is confirmed.\n\n'
          'Centre: ${centre.name}\n'
          'Address: ${centre.address}\n'
          'Date: $date\n'
          'Slot: $start–$end\n\n'
          'Your queue and travel plan are now available in the app.',
      kind: NotificationKind.appointment,
    );
    _showNotification(note);
  }

  // ---------------------------------------------------------------------------
  // NOTIFICATIONS
  // ---------------------------------------------------------------------------

  void _showNotification(AppNotification note) {
    notificationTimer?.cancel();

    activeNotification = note;

    notifications.add(
      note.title,
      note.message,
      details: note.details,
      critical: note.critical,
      kind: note.kind,
    );

    notifications.showSystemNotification(
      title: note.title,
      message: note.message,
      details: note.details,
      id: DateTime.now()
          .millisecondsSinceEpoch
          .remainder(1000000000),
    );

    notifyListeners();

    notificationTimer = Timer(
      const Duration(seconds: 5),
      () {
        activeNotification = null;
        appointmentNotificationVisible = false;
        notifyListeners();
      },
    );
  }

  void dismissNotification() {
    notificationTimer?.cancel();

    activeNotification = null;
    appointmentNotificationVisible = false;

    notifyListeners();
  }

  void showNotificationDetails(BuildContext context) {
    final note = activeNotification;

    if (note == null) return;

    notificationTimer?.cancel();

    activeNotification = null;
    appointmentNotificationVisible = false;

    notifyListeners();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.notifications_active),
            const SizedBox(width: 8),
            Expanded(
              child: Text(note.title),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            note.details.isEmpty
                ? note.message
                : note.details,
          ),
        ),
        actions: [
          if (note.kind == NotificationKind.appointment ||
              note.kind == NotificationKind.reschedule)
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                setTab(0);
              },
              child: const Text('Open Appointment'),
            )
          else
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DYNAMIC CENTRE RESCHEDULING
  // ---------------------------------------------------------------------------

  void simulateFailure() {
    final index = data.centres.indexWhere(
      (c) => c.id == 'A',
    );

    if (index < 0) return;

    data.centres[index] =
        data.centres[index].copyWith(
      currentLoad: 98,
      queue: 86,
      processingRate: 4,
      weighbridgesWorking: 1,
      status: CentreStatus.degraded,
    );

    final oldCentreId = farmer.centreId;

    final affected =
        ReschedulingEngine().redistribute(
      farmers: data.farmers,
      centres: data.centres,
    );

    for (var i = 0; i < data.farmers.length; i++) {
      data.farmers[i] = affected[i];
    }

    if (farmer.centreId != oldCentreId) {
      reassignmentCount += 1;

      unawaited(_saveSession());

      final note = AppNotification(
        'Procurement centre updated',
        'Centre changed to ${assignedCentre.name} • ${farmer.procurementDay} • ${farmer.window}',
        DateTime.now(),
        details:
            'Your procurement centre has been rescheduled because Centre A is experiencing a capacity/equipment delay.\n\n'
            'Previous centre: ${data.centres.firstWhere((c) => c.id == oldCentreId).name}\n'
            'New centre: ${assignedCentre.name}\n'
            'Date: ${farmer.procurementDay}\n'
            'Slot: ${farmer.window}\n\n'
            'Your travel and queue information has been updated.',
        critical: true,
        kind: NotificationKind.reschedule,
      );

      _showNotification(note);
    }

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ATTENDANCE
  // ---------------------------------------------------------------------------

  Future<void> markAttendance() async {
    final current = procurementDone[farmerId] ?? <String>{};
    if (current.contains('Attendance')) return;

    try {
      // Wait for the server-side attendance transaction to complete. This
      // prevents closing the app immediately after tapping the button from
      // losing the attendance update.
      await backend.markAttendance(farmerId);
      await _loadRemoteState(showPendingNotifications: false);
      await _saveSession();

      // Show the same SMS-like Messages popup used for other important
      // farmer updates, immediately after home check-in is successfully
      // recorded by Supabase. This is intentionally local/UI driven so it
      // does not depend on a database notification arriving later.
      final note = AppNotification(
        'Attendance Confirmed',
        'Your attendance has been marked successfully.',
        DateTime.now(),
        details:
            'Your attendance for today\'s procurement appointment has been recorded.\n'
            'You are now checked in at ${assignedCentre.name}.',
        kind: NotificationKind.general,
      );
      _showNotification(note);
    } catch (_) {
      // If the server rejects the operation, reconcile with the remote state
      // rather than pretending that attendance is permanently saved.
      await _loadRemoteState(showPendingNotifications: false);
    }

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // PROCUREMENT
  // ---------------------------------------------------------------------------

  Future<void> setProcurementStages(
    String farmerId,
    Set<String> stages,
  ) async {
    await backend.saveProcurementStages(farmerId, stages);
    await _loadRemoteState(showPendingNotifications: true);
    await _saveSession();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // DEMO RESET
  // ---------------------------------------------------------------------------

  void resetDemo() {
    final fresh = DataService();

    data.centres
      ..clear()
      ..addAll(fresh.centres);

    data.farmers
      ..clear()
      ..addAll(fresh.farmers);

    data.verification = fresh.verification;

    verificationCompleted.clear();

    bankName = '';
    bankAccount = '';
    bankConfirmAccount = '';
    bankIfsc = '';

    selectedCrop = '';
    cropQuantity = '';
    cropSeason = '';

    verified = false;
    language = 'English';

    appointmentAssigned = false;
    appointmentNotificationVisible = false;

    procurementStage = 1;

    notifications.items.clear();

    notificationTimer?.cancel();

    activeNotification = null;

    procurementDone.clear();
    attendanceAt.clear();

    reassignmentCount = 0;

    unawaited(_saveSession());

    notifyListeners();
  }

  @override
  void dispose() {
    appointmentTimer?.cancel();
    notificationTimer?.cancel();
    _remoteSyncTimer?.cancel();
    _remoteSyncTimer = null;
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    super.dispose();
  }
}

class SmartProcurementApp extends StatefulWidget {
  const SmartProcurementApp({super.key});

  @override
  State<SmartProcurementApp> createState() =>
      _SmartProcurementAppState();
}

class _SmartProcurementAppState
    extends State<SmartProcurementApp> {
  final AppState state = AppState();

  @override
  void initState() {
    super.initState();

    state.notifications.initialize();
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
          theme: AppTheme.light,
          home: !state.sessionReady
              ? const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : !state.authenticated
                  ? AuthScreen(state: state)
                  : FarmerShell(state: state),
        );
      },
    );
  }
}

class FarmerShell extends StatelessWidget {
  final AppState state;

  const FarmerShell({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(state: state),
      QueueScreen(state: state),
      TravelScreen(state: state),
      VerificationScreen(state: state),
      MspScreen(state: state),
      AssistantScreen(state: state),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Smart Procurement',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProfileScreen(state: state),
                  ),
                );
              } else if (value == 'status') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        StatusScreen(state: state),
                  ),
                );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'status',
                child: Text(
                  state.t('procurement_status'),
                ),
              ),
              PopupMenuItem(
                value: 'profile',
                child: Text(
                  state.t('profile_settings'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: pages[state.tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: state.tab,
        onDestinationSelected: state.setTab,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: state.t('home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups),
            label: state.t('queue_tab'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.route_outlined),
            selectedIcon: const Icon(Icons.route),
            label: state.t('travel_tab'),
          ),
          NavigationDestination(
            icon: const Icon(
              Icons.verified_user_outlined,
            ),
            selectedIcon: const Icon(
              Icons.verified_user,
            ),
            label: state.t('verify_tab'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.currency_rupee),
            selectedIcon: const Icon(
              Icons.currency_rupee,
            ),
            label: state.t('msp'),
          ),
          NavigationDestination(
            icon: const Icon(
              Icons.support_agent_outlined,
            ),
            selectedIcon: const Icon(
              Icons.support_agent,
            ),
            label: state.t('assistant'),
          ),
        ],
      ),
    );
  }
}
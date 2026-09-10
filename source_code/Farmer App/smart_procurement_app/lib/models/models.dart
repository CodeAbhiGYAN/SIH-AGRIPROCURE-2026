enum CentreStatus { normal, busy, highLoad, delayed, degraded, unavailable }

enum FarmerState {
  assigned,
  travelling,
  arrived,
  waiting,
  processing,
  completed,
  cancelled,
  rescheduled,
}

enum VerificationState {
  verified,
  pending,
  actionRequired,
  underReview,
}

enum NotificationKind {
  otp,
  appointment,
  reschedule,
  general,
}

class Centre {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final double capacity;
  final double currentLoad;
  final double processingRate;
  final int queue;
  final int activeStaff;
  final int weighbridgesWorking;
  final int weighbridgesTotal;
  final CentreStatus status;
  final bool qualityTestingOk;
  final bool storageOk;
  final bool transportOk;

  const Centre({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.capacity,
    required this.currentLoad,
    required this.processingRate,
    required this.queue,
    required this.activeStaff,
    required this.weighbridgesWorking,
    required this.weighbridgesTotal,
    required this.status,
    required this.qualityTestingOk,
    required this.storageOk,
    required this.transportOk,
  });

  double get utilization =>
      capacity <= 0 ? 0 : (currentLoad / capacity).clamp(0, 1);

  double get remainingCapacity =>
      (capacity - currentLoad).clamp(0, capacity);

  Centre copyWith({
    double? currentLoad,
    double? processingRate,
    int? queue,
    int? weighbridgesWorking,
    CentreStatus? status,
    bool? qualityTestingOk,
    bool? storageOk,
  }) {
    return Centre(
      id: id,
      name: name,
      address: address,
      lat: lat,
      lng: lng,
      capacity: capacity,
      currentLoad: currentLoad ?? this.currentLoad,
      processingRate: processingRate ?? this.processingRate,
      queue: queue ?? this.queue,
      activeStaff: activeStaff,
      weighbridgesWorking:
          weighbridgesWorking ?? this.weighbridgesWorking,
      weighbridgesTotal: weighbridgesTotal,
      status: status ?? this.status,
      qualityTestingOk:
          qualityTestingOk ?? this.qualityTestingOk,
      storageOk: storageOk ?? this.storageOk,
      transportOk: transportOk,
    );
  }
}

class Farmer {
  final String id;
  final String name;
  final String mobile;
  final String village;
  final String crop;
  final double expectedQuantity;
  final double cultivatedArea;
  final int priorityScore;
  final String procurementDay;
  final String window;
  final String centreId;
  final FarmerState state;
  final bool hasLeftHome;
  final double lat;
  final double lng;
  final int queueToken;
  final String? appointmentId;
  final DateTime? queueEnteredAt;
  final double predictedProcessingMinutes;

  const Farmer({
    required this.id,
    required this.name,
    required this.mobile,
    required this.village,
    required this.crop,
    required this.expectedQuantity,
    required this.cultivatedArea,
    required this.priorityScore,
    required this.procurementDay,
    required this.window,
    required this.centreId,
    required this.state,
    required this.hasLeftHome,
    required this.lat,
    required this.lng,
    this.queueToken = 0,
    this.appointmentId,
    this.queueEnteredAt,
    this.predictedProcessingMinutes = 7.0,
  });

  Farmer copyWith({
    String? procurementDay,
    String? window,
    String? centreId,
    FarmerState? state,
    bool? hasLeftHome,
    int? queueToken,
    String? appointmentId,
    DateTime? queueEnteredAt,
    double? predictedProcessingMinutes,
    bool clearAppointment = false,
  }) {
    return Farmer(
      id: id,
      name: name,
      mobile: mobile,
      village: village,
      crop: crop,
      expectedQuantity: expectedQuantity,
      cultivatedArea: cultivatedArea,
      priorityScore: priorityScore,
      procurementDay: procurementDay ?? this.procurementDay,
      window: window ?? this.window,
      centreId: clearAppointment ? 'A' : (centreId ?? this.centreId),
      state: state ?? this.state,
      hasLeftHome: hasLeftHome ?? this.hasLeftHome,
      lat: lat,
      lng: lng,
      queueToken: clearAppointment ? 0 : (queueToken ?? this.queueToken),
      appointmentId: clearAppointment ? null : (appointmentId ?? this.appointmentId),
      queueEnteredAt: clearAppointment ? null : (queueEnteredAt ?? this.queueEnteredAt),
      predictedProcessingMinutes: predictedProcessingMinutes ?? this.predictedProcessingMinutes,
    );
  }
}

class VerificationItem {
  final String title;
  final VerificationState state;
  final String note;

  const VerificationItem(
    this.title,
    this.state,
    this.note,
  );
}

class QueueSnapshot {
  final int queueToken;
  final int position;
  final int farmersAhead;
  final int estimatedWaitMinutes;
  final int currentWaiting;
  final int currentProcessing;
  final double slotWorkloadMinutes;
  final double overloadPercent;
  final String loadStatus;
  final DateTime? queueEnteredAt;

  const QueueSnapshot({
    required this.queueToken,
    required this.position,
    required this.farmersAhead,
    required this.estimatedWaitMinutes,
    required this.currentWaiting,
    required this.currentProcessing,
    required this.slotWorkloadMinutes,
    required this.overloadPercent,
    required this.loadStatus,
    required this.queueEnteredAt,
  });

  const QueueSnapshot.empty()
      : queueToken = 0,
        position = 0,
        farmersAhead = 0,
        estimatedWaitMinutes = 0,
        currentWaiting = 0,
        currentProcessing = 0,
        slotWorkloadMinutes = 0,
        overloadPercent = 0,
        loadStatus = 'normal',
        queueEnteredAt = null;

  bool get hasQueuePosition => queueEnteredAt != null;
}

class AppNotification {
  final String title;
  final String message;
  final String details;
  final DateTime time;
  final bool critical;
  final NotificationKind kind;

  const AppNotification(
    this.title,
    this.message,
    this.time, {
    this.details = '',
    this.critical = false,
    this.kind = NotificationKind.general,
  });
}
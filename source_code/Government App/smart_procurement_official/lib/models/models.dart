enum CentreStatus { normal, busy, highLoad, delayed, degraded, unavailable }
enum FarmerState { assigned, travelling, arrived, waiting, processing, completed, cancelled, rescheduled }
enum VerificationState { verified, pending, actionRequired, underReview }
enum NotificationKind { otp, appointment, reschedule, general }

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
  final int staffTotal;
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
    required this.staffTotal,
    required this.weighbridgesWorking,
    required this.weighbridgesTotal,
    required this.status,
    required this.qualityTestingOk,
    required this.storageOk,
    required this.transportOk,
  });

  double get utilization =>
      capacity <= 0 ? 0 : (currentLoad / capacity).clamp(0, 1).toDouble();

  double get remainingCapacity =>
      (capacity - currentLoad).clamp(0, capacity).toDouble();

  double get staffAvailabilityRatio =>
      staffTotal <= 0 ? 0 : (activeStaff / staffTotal).clamp(0, 1).toDouble();

  double get weighbridgeAvailabilityRatio =>
      weighbridgesTotal <= 0
          ? 0
          : (weighbridgesWorking / weighbridgesTotal).clamp(0, 1).toDouble();

  // Baseline references. These are calibration points, not percentage caps.
  static const double referenceStaffCount = 4.0;
  static const double referenceWeighbridgeCount = 2.0;

  double get staffSupportedRate {
    if (activeStaff <= 0 || processingRate <= 0) return 0;
    return processingRate * (activeStaff / referenceStaffCount);
  }

  double get weighbridgeSupportedRate {
    if (weighbridgesWorking <= 0 || processingRate <= 0) return 0;
    return processingRate *
        (weighbridgesWorking / referenceWeighbridgeCount);
  }

  double get conditionFactor {
    switch (status) {
      case CentreStatus.normal:
        return 1.0;
      case CentreStatus.busy:
        return 0.95;
      case CentreStatus.highLoad:
        return 0.90;
      case CentreStatus.delayed:
        return 0.80;
      case CentreStatus.degraded:
        return 0.70;
      case CentreStatus.unavailable:
        return 0.0;
    }
  }

  double get operationalConditionFactor {
    double factor = 1.0;
    if (!qualityTestingOk) factor *= 0.92;
    if (!storageOk) factor *= 0.95;
    if (!transportOk) factor *= 0.95;
    return factor.clamp(0, 1).toDouble();
  }

  // The slower resource is the bottleneck.
  double get effectiveProcessingRate {
    if (status == CentreStatus.unavailable) return 0;
    final staffRate = staffSupportedRate;
    final weighbridgeRate = weighbridgeSupportedRate;
    if (staffRate <= 0 || weighbridgeRate <= 0) return 0;
    final bottleneck = staffRate < weighbridgeRate
        ? staffRate
        : weighbridgeRate;
    return (bottleneck * conditionFactor * operationalConditionFactor)
        .clamp(0, double.infinity)
        .toDouble();
  }

  // Nine working hours: 08:00–13:00 and 14:00–18:00.
  int get feasibleFarmerCapacity {
    if (effectiveProcessingRate <= 0 || capacity <= 0) return 0;
    final dailyThroughput = (effectiveProcessingRate * 9).floor();
    return dailyThroughput.clamp(0, capacity.round()).toInt();
  }

  Centre copyWith({
    double? currentLoad,
    double? processingRate,
    int? queue,
    int? activeStaff,
    int? staffTotal,
    int? weighbridgesWorking,
    int? weighbridgesTotal,
    CentreStatus? status,
    bool? qualityTestingOk,
    bool? storageOk,
    bool? transportOk,
  }) {
    final nextTotal = weighbridgesTotal ?? this.weighbridgesTotal;
    final nextWorking = (weighbridgesWorking ?? this.weighbridgesWorking)
        .clamp(0, nextTotal)
        .toInt();
    final nextStaffTotal = staffTotal ?? this.staffTotal;
    final nextActiveStaff = (activeStaff ?? this.activeStaff)
        .clamp(0, nextStaffTotal)
        .toInt();

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
      activeStaff: nextActiveStaff,
      staffTotal: nextStaffTotal,
      weighbridgesWorking: nextWorking,
      weighbridgesTotal: nextTotal,
      status: status ?? this.status,
      qualityTestingOk: qualityTestingOk ?? this.qualityTestingOk,
      storageOk: storageOk ?? this.storageOk,
      transportOk: transportOk ?? this.transportOk,
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

  bool get isAtHome =>
      !hasLeftHome &&
      (state == FarmerState.assigned || state == FarmerState.rescheduled);

  bool get isCommitted =>
      hasLeftHome ||
      state == FarmerState.travelling ||
      state == FarmerState.arrived ||
      state == FarmerState.waiting ||
      state == FarmerState.processing;

  bool get procurementComplete => state == FarmerState.completed;

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
      centreId: centreId ?? this.centreId,
      state: state ?? this.state,
      hasLeftHome: hasLeftHome ?? this.hasLeftHome,
      lat: lat,
      lng: lng,
      queueToken: queueToken ?? this.queueToken,
      appointmentId: appointmentId ?? this.appointmentId,
      queueEnteredAt: queueEnteredAt ?? this.queueEnteredAt,
      predictedProcessingMinutes: predictedProcessingMinutes ?? this.predictedProcessingMinutes,
    );
  }
}

class VerificationItem {
  final String title;
  final VerificationState state;
  final String note;
  const VerificationItem(this.title, this.state, this.note);
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

enum OfficialRole { centreManager, districtOfficer, admin }

class OfficialIdentity {
  final String officialId;
  final String name;
  final String centreId;
  final OfficialRole role;

  const OfficialIdentity({
    required this.officialId,
    required this.name,
    required this.centreId,
    required this.role,
  });
}

import 'dart:math' as math;

import '../models/models.dart';

class AllocationEngine {
  String chooseCentre({
    required List<Centre> centres,
    required double farmerLat,
    required double farmerLng,
    required double expectedQuantity,
    DateTime? scheduledDate,
    Map<String, Set<String>>? unavailableDatesByCentre,
  }) {
    if (centres.isEmpty) {
      throw StateError('No procurement centres are available.');
    }

    double bestScore = double.infinity;
    String? bestId;

    for (final centre in centres) {
      if (centre.status == CentreStatus.unavailable) continue;
      if (centre.effectiveProcessingRate <= 0) continue;
      if (centre.remainingCapacity < expectedQuantity) continue;

      if (scheduledDate != null &&
          _isUnavailableOn(
            centre.id,
            scheduledDate,
            unavailableDatesByCentre,
          )) {
        continue;
      }

      final distance = _distanceKm(
        farmerLat,
        farmerLng,
        centre.lat,
        centre.lng,
      );

      final rate = centre.effectiveProcessingRate;
      final queueHours =
          rate <= 0 ? double.infinity : centre.queue / rate;

      final staffPenalty =
          (1 - centre.staffAvailabilityRatio) * 14;
      final equipmentPenalty =
          (1 - centre.weighbridgeAvailabilityRatio) * 12;
      final conditionPenalty =
          _conditionPenalty(centre);
      final utilizationPenalty = centre.utilization * 22;
      final capacityBonus =
          math.min(centre.remainingCapacity, 100) * 0.05;

      final score =
          distance * 3.0 +
          queueHours * 8.0 +
          utilizationPenalty +
          staffPenalty +
          equipmentPenalty +
          conditionPenalty -
          capacityBonus;

      if (score < bestScore) {
        bestScore = score;
        bestId = centre.id;
      }
    }

    if (bestId == null) {
      throw StateError(
        'No procurement centre can currently accept this farmer.',
      );
    }

    return bestId;
  }

  double _conditionPenalty(Centre centre) {
    double penalty = 0;
    if (!centre.qualityTestingOk) penalty += 8;
    if (!centre.storageOk) penalty += 6;
    if (!centre.transportOk) penalty += 4;

    switch (centre.status) {
      case CentreStatus.normal:
        break;
      case CentreStatus.busy:
        penalty += 4;
      case CentreStatus.highLoad:
        penalty += 10;
      case CentreStatus.delayed:
        penalty += 18;
      case CentreStatus.degraded:
        penalty += 30;
      case CentreStatus.unavailable:
        penalty += 999;
    }

    return penalty;
  }

  bool _isUnavailableOn(
    String centreId,
    DateTime date,
    Map<String, Set<String>>? dates,
  ) {
    if (dates == null) return false;

    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final key = '$year-$month-$day';

    return dates[centreId]?.contains(key) ?? false;
  }

  double _distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;

    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);
    final deltaLat = _toRadians(lat2 - lat1);
    final deltaLon = _toRadians(lon2 - lon1);

    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
            math.cos(lat1Rad) *
                math.cos(lat2Rad) *
                math.sin(deltaLon / 2) *
                math.sin(deltaLon / 2);

    final c =
        2 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));

    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) =>
      degrees * math.pi / 180.0;
}

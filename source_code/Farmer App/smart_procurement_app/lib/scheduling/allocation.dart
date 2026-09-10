import '../models/models.dart';

class AllocationEngine {
  String chooseCentre({
    required List<Centre> centres,
    required double farmerLat,
    required double farmerLng,
    required double expectedQuantity,
  }) {
    double best = double.infinity;
    String bestId = centres.first.id;

    for (final centre in centres) {
      if (centre.status == CentreStatus.unavailable) {
        continue;
      }
      if (centre.remainingCapacity < expectedQuantity) {
        continue;
      }

      final distance =
          _distance(farmerLat, farmerLng, centre.lat, centre.lng);
      final rate = centre.processingRate <= 0 ? 1 : centre.processingRate;
      final wait = centre.queue / rate * 10;

      final statusPenalty = switch (centre.status) {
        CentreStatus.normal => 0,
        CentreStatus.busy => 10,
        CentreStatus.highLoad => 35,
        CentreStatus.delayed => 45,
        CentreStatus.degraded => 55,
        CentreStatus.unavailable => 999,
      };

      final score =
          distance * 5 + wait + statusPenalty - centre.remainingCapacity * 0.05;

      if (score < best) {
        best = score;
        bestId = centre.id;
      }
    }

    return bestId;
  }

  double _distance(
    double aLat,
    double aLng,
    double bLat,
    double bLng,
  ) {
    final dx = (aLat - bLat) * 111;
    final dy = (aLng - bLng) * 95;
    return (dx * dx + dy * dy).sqrt();
  }
}

extension _Sqrt on double {
  double sqrt() => this <= 0 ? 0 : _sqrt(this);
}

double _sqrt(double x) {
  double guess = x > 1 ? x / 2 : 1;

  for (var i = 0; i < 12; i++) {
    guess = (guess + x / guess) / 2;
  }

  return guess;
}

import '../models/models.dart';

class ReschedulingEngine {
  List<Farmer> redistribute({
    required List<Farmer> farmers,
    required List<Centre> centres,
  }) {
    final result = [...farmers];
    final overloaded = centres
        .where(
          (c) =>
              c.status == CentreStatus.highLoad ||
              c.status == CentreStatus.delayed ||
              c.status == CentreStatus.degraded ||
              c.status == CentreStatus.unavailable,
        )
        .map((e) => e.id)
        .toSet();

    final candidates = centres
        .where(
          (c) =>
              !overloaded.contains(c.id) &&
              c.status != CentreStatus.unavailable &&
              c.remainingCapacity > 5,
        )
        .toList();

    if (candidates.isEmpty) return result;

    for (var i = 0; i < result.length; i++) {
      final farmer = result[i];
      if (!overloaded.contains(farmer.centreId) || farmer.hasLeftHome) {
        continue;
      }
      candidates.sort(
        (a, b) => (a.currentLoad / a.capacity).compareTo(
          b.currentLoad / b.capacity,
        ),
      );
      final target = candidates.first;
      result[i] = farmer.copyWith(
        centreId: target.id,
        state: FarmerState.rescheduled,
      );
    }
    return result;
  }
}

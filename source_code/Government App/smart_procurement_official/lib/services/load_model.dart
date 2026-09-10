import 'procurement_timing.dart';

class LoadResult {
  final double workloadMinutes;
  final double overloadPercent;
  final String status;

  const LoadResult({
    required this.workloadMinutes,
    required this.overloadPercent,
    required this.status,
  });
}

class LoadModel {
  static const double slotMinutes = 30.0;

  static LoadResult forSlot(Iterable<double> processingMinutes) {
    final workload = processingMinutes.fold<double>(
      0,
      (sum, value) => sum + (value > 0 ? value : ProcurementTiming.defaultProcessingMinutesPerFarmer),
    );
    final overload = ((workload - slotMinutes) / slotMinutes) * 100.0;
    final status = classify(overload);
    return LoadResult(
      workloadMinutes: workload,
      overloadPercent: overload,
      status: status,
    );
  }

  static String classify(double overloadPercent) {
    if (overloadPercent <= 0) return 'normal';
    if (overloadPercent <= 25) return 'moderate';
    if (overloadPercent <= 50) return 'high';
    return 'bottleneck';
  }

  static String label(String status) {
    switch (status) {
      case 'moderate': return 'MODERATE LOAD';
      case 'high': return 'HIGH LOAD';
      case 'bottleneck': return 'BOTTLENECK';
      default: return 'NORMAL';
    }
  }
}


class PriorityEngine {
  int score({
    required int cropReadiness,
    required int weatherUrgency,
    required int deadlineUrgency,
    required int previousPostponements,
    required int cropVulnerability,
    required int operationalConstraint,
  }) {
    return (cropReadiness * .25 + weatherUrgency * .20 + deadlineUrgency * .20 +
      previousPostponements * .15 + cropVulnerability * .10 +
      operationalConstraint * .10).round().clamp(0, 100);
  }
}

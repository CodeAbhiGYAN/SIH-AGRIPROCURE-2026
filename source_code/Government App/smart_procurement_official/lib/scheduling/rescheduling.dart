import 'dart:math' as math;

import '../models/models.dart';

/// Shared appointment/scheduling calculations used by both the data/state
/// layer and the Government UI. The Farmer.window + Farmer.procurementDay
/// fields hold the current authoritative appointment assignment.
class AppointmentScheduler {
  static const List<String> workingSlotLabels = <String>[
    '8:00 AM – 8:30 AM',
    '8:30 AM – 9:00 AM',
    '9:00 AM – 9:30 AM',
    '9:30 AM – 10:00 AM',
    '10:00 AM – 10:30 AM',
    '10:30 AM – 11:00 AM',
    '11:00 AM – 11:30 AM',
    '11:30 AM – 12:00 PM',
    '12:00 PM – 12:30 PM',
    '12:30 PM – 1:00 PM',
    '2:00 PM – 2:30 PM',
    '2:30 PM – 3:00 PM',
    '3:00 PM – 3:30 PM',
    '3:30 PM – 4:00 PM',
    '4:00 PM – 4:30 PM',
    '4:30 PM – 5:00 PM',
    '5:00 PM – 5:30 PM',
    '5:30 PM – 6:00 PM',
  ];

  /// Number of farmers allowed in one 30-minute slot at the current live
  /// operating rate.
  static int slotCapacity(Centre centre) {
    final rate = centre.effectiveProcessingRate;
    if (rate <= 0) return 0;
    return math.max(1, (rate * 0.5).round());
  }

  static List<String> slotLabels() =>
      List<String>.unmodifiable(workingSlotLabels);

  static int slotIndex(String value) {
    final normalized = normalizeWindow(value);
    return workingSlotLabels.indexOf(normalized);
  }

  static String normalizeWindow(String value) {
    var v = value.trim().replaceAll('–', '-').replaceAll('—', '-');
    v = v.replaceAll(RegExp(r'\s+'), ' ');

    final parts = v.split('-');
    if (parts.length != 2) return value.trim();

    final leftMatch = RegExp(
      r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?$',
      caseSensitive: false,
    ).firstMatch(parts[0].trim());
    final rightMatch = RegExp(
      r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?$',
      caseSensitive: false,
    ).firstMatch(parts[1].trim());

    if (leftMatch == null || rightMatch == null) {
      return value.trim();
    }

    final leftHour = int.tryParse(leftMatch.group(1)!);
    final leftMinute = int.tryParse(leftMatch.group(2) ?? '00');
    final rightHour = int.tryParse(rightMatch.group(1)!);
    final rightMinute = int.tryParse(rightMatch.group(2) ?? '00');

    if (leftHour == null ||
        leftMinute == null ||
        rightHour == null ||
        rightMinute == null ||
        leftHour < 1 ||
        leftHour > 12 ||
        rightHour < 1 ||
        rightHour > 12 ||
        leftMinute < 0 ||
        leftMinute > 59 ||
        rightMinute < 0 ||
        rightMinute > 59) {
      return value.trim();
    }

    String? leftPeriod = leftMatch.group(3)?.toUpperCase();
    String? rightPeriod = rightMatch.group(3)?.toUpperCase();

    if (leftPeriod == null && rightPeriod != null) {
      leftPeriod = rightPeriod;
    }
    if (rightPeriod == null && leftPeriod != null) {
      rightPeriod = leftPeriod;
    }

    // The existing mock data uses a period on the end of the slot for many
    // entries (e.g. 11:00–11:30 AM). Infer the same period for the start.
    if (leftPeriod == null && rightPeriod == null) {
      if (leftHour >= 8 && leftHour < 12) {
        leftPeriod = 'AM';
        rightPeriod = rightHour == 12 ? 'PM' : 'AM';
      } else {
        leftPeriod = 'PM';
        rightPeriod = 'PM';
      }
    }

    return '${leftHour.toString()}:${leftMinute.toString().padLeft(2, '0')} ${leftPeriod ?? 'AM'} – '
        '${rightHour.toString()}:${rightMinute.toString().padLeft(2, '0')} ${rightPeriod ?? leftPeriod ?? 'AM'}';
  }

  static String dayLabel(DateTime date) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  static DateTime? parseDay(String value, {int? year}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final direct = DateTime.tryParse(trimmed);
    if (direct != null) return direct;

    final match = RegExp(
      r'^(\d{1,2})\s+([A-Za-z]{3,9})(?:\s+(\d{4}))?$',
    ).firstMatch(trimmed);
    if (match == null) return null;

    const monthNumbers = <String, int>{
      'jan': 1,
      'january': 1,
      'feb': 2,
      'february': 2,
      'mar': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'may': 5,
      'jun': 6,
      'june': 6,
      'jul': 7,
      'july': 7,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'sept': 9,
      'september': 9,
      'oct': 10,
      'october': 10,
      'nov': 11,
      'november': 11,
      'dec': 12,
      'december': 12,
    };

    final day = int.tryParse(match.group(1)!);
    final month = monthNumbers[match.group(2)!.toLowerCase()];
    final parsedYear = int.tryParse(match.group(3) ?? '');

    if (day == null || month == null) return null;

    return DateTime(
      parsedYear ?? year ?? DateTime.now().year,
      month,
      day,
    );
  }

  static String dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String centreDateKey(String centreId, DateTime date) =>
      '$centreId|${dateKey(date)}';

  static bool isUnavailable(
    Set<String> unavailableCentreDates,
    String centreId,
    DateTime date,
  ) {
    return unavailableCentreDates.contains(
      centreDateKey(centreId, date),
    );
  }

  /// Returns all relevant planning dates already present in farmer data, plus
  /// a short future horizon so a closure/capacity shock always has somewhere
  /// sensible to move a home farmer when capacity exists.
  static List<DateTime> planningDates(List<Farmer> farmers) {
    final dates = <DateTime>{};
    for (final farmer in farmers) {
      final parsed = parseDay(farmer.procurementDay);
      if (parsed != null) {
        dates.add(DateTime(parsed.year, parsed.month, parsed.day));
      }
    }

    if (dates.isEmpty) {
      final today = DateTime.now();
      dates.add(DateTime(today.year, today.month, today.day));
    }

    final maxDate = dates.reduce((a, b) => a.isAfter(b) ? a : b);
    for (var i = 1; i <= 7; i++) {
      dates.add(maxDate.add(Duration(days: i)));
    }

    final result = dates.toList()..sort();
    return result;
  }

  /// Rebuilds all currently eligible home-farmer appointments after an
  /// operational change. Committed farmers are never touched.
  static List<Farmer> rebuildAppointments({
    required List<Farmer> farmers,
    required List<Centre> centres,
    required Set<String> unavailableCentreDates,
  }) {
    if (farmers.isEmpty || centres.isEmpty) {
      return List<Farmer>.from(farmers);
    }

    final result = List<Farmer>.from(farmers);
    final dates = planningDates(farmers);

    final usage = <String, Map<String, int>>{};

    // Reserve slots occupied by committed farmers. Their existing appointment
    // does not move automatically.
    for (final farmer in farmers) {
      if (!farmer.isCommitted || farmer.procurementComplete) continue;

      final date = parseDay(farmer.procurementDay);
      if (date == null) continue;

      final key = centreDateKey(
        farmer.centreId,
        date,
      );

      final slot = normalizeWindow(farmer.window);
      if (!workingSlotLabels.contains(slot)) continue;

      usage.putIfAbsent(key, () => <String, int>{});
      usage[key]![slot] = (usage[key]![slot] ?? 0) + 1;
    }

    final homeIndices = <int>[];
    for (var i = 0; i < result.length; i++) {
      if (result[i].procurementComplete) continue;
      if (result[i].isAtHome) homeIndices.add(i);
    }

    homeIndices.sort((a, b) {
      final pa = result[a].priorityScore;
      final pb = result[b].priorityScore;
      if (pa != pb) return pb.compareTo(pa);
      return result[a].id.compareTo(result[b].id);
    });

    for (final index in homeIndices) {
      final farmer = result[index];
      final currentDate = parseDay(farmer.procurementDay);

      _AppointmentCandidate? selected;

      // First preserve the farmer's current centre/date whenever that
      // appointment still has capacity. This prevents routine scheduler
      // refreshes from randomly moving farmers to a different centre.
      if (currentDate != null) {
        final matchingCentres = centres.where(
          (centre) => centre.id == farmer.centreId,
        ).toList();
        final currentCentre = matchingCentres.isEmpty
            ? null
            : matchingCentres.first;

        if (currentCentre != null &&
            currentCentre.status != CentreStatus.unavailable &&
            currentCentre.effectiveProcessingRate > 0 &&
            !isUnavailable(
              unavailableCentreDates,
              currentCentre.id,
              currentDate,
            )) {
          final key = centreDateKey(
            currentCentre.id,
            currentDate,
          );

          final slotMap = usage.putIfAbsent(
            key,
            () => <String, int>{},
          );

          final freeSlot =
              _firstAvailableSlot(
            slotMap,
            slotCapacity(currentCentre),
          );

          if (freeSlot != null) {
            selected = _AppointmentCandidate(
              centre: currentCentre,
              date: currentDate,
              slot: freeSlot,
              score: slotIndex(freeSlot).toDouble() * 0.01,
            );
          }
        }
      }

      // If the current centre/date cannot take the farmer, find the best
      // alternative centre/date.
      if (selected == null) {
        final candidates = <_AppointmentCandidate>[];

        for (final centre in centres) {
          if (centre.status == CentreStatus.unavailable) continue;
          if (centre.effectiveProcessingRate <= 0) continue;

          final slotCapacityValue =
              slotCapacity(centre);
          if (slotCapacityValue <= 0) continue;

          for (final date in dates) {
            if (isUnavailable(
              unavailableCentreDates,
              centre.id,
              date,
            )) {
              continue;
            }

            final key = centreDateKey(
              centre.id,
              date,
            );

            final slotMap = usage.putIfAbsent(
              key,
              () => <String, int>{},
            );

            final freeSlot = _firstAvailableSlot(
              slotMap,
              slotCapacityValue,
            );

            if (freeSlot == null) continue;

            final distance = _distanceKm(
              farmer.lat,
              farmer.lng,
              centre.lat,
              centre.lng,
            );

            final dateDistance = currentDate == null
                ? 0
                : _dayDistance(currentDate, date);

            final centreChangePenalty =
                centre.id == farmer.centreId ? 0.0 : 24.0;

            final dateChangePenalty =
                currentDate == null ||
                        _sameDate(currentDate, date)
                    ? 0.0
                    : dateDistance * 3.0;

            final queuePressure = centre.queue /
                centre.effectiveProcessingRate;

            final utilisationPenalty =
                centre.utilization * 20.0;

            final conditionPenalty =
                _statusPenalty(centre.status);

            final earliestSlotPenalty =
                slotIndex(freeSlot).toDouble() * 0.20;

            candidates.add(
              _AppointmentCandidate(
                centre: centre,
                date: date,
                slot: freeSlot,
                score:
                    centreChangePenalty +
                    dateChangePenalty +
                    distance * 2.5 +
                    queuePressure * 5.0 +
                    utilisationPenalty +
                    conditionPenalty +
                    earliestSlotPenalty,
              ),
            );
          }
        }

        if (candidates.isNotEmpty) {
          candidates.sort(
            (a, b) => a.score.compareTo(b.score),
          );
          selected = candidates.first;
        }
      }

      if (selected == null) {
        // The whole visible planning horizon is full. Leave the existing
        // assignment unchanged rather than creating an invalid appointment.
        continue;
      }

      final key = centreDateKey(
        selected.centre.id,
        selected.date,
      );

      final slotMap = usage.putIfAbsent(
        key,
        () => <String, int>{},
      );

      slotMap[selected.slot] =
          (slotMap[selected.slot] ?? 0) + 1;

      final changedCentre =
          selected.centre.id != farmer.centreId;

      final changedDate =
          currentDate == null ||
          !_sameDate(
            currentDate,
            selected.date,
          );

      result[index] = farmer.copyWith(
        procurementDay: dayLabel(selected.date),
        window: selected.slot,
        centreId: selected.centre.id,
        // A centre/date movement becomes visibly rescheduled. A slot-only
        // optimisation leaves the existing home status unchanged.
        state: changedCentre || changedDate
            ? FarmerState.rescheduled
            : farmer.state,
        hasLeftHome: false,
      );
    }

    return result;
  }

  static String? _firstAvailableSlot(
    Map<String, int> usage,
    int capacity,
  ) {
    for (final slot in workingSlotLabels) {
      final booked = usage[slot] ?? 0;
      if (booked < capacity) return slot;
    }
    return null;
  }

  static double _statusPenalty(CentreStatus status) {
    switch (status) {
      case CentreStatus.normal:
        return 0;
      case CentreStatus.busy:
        return 4;
      case CentreStatus.highLoad:
        return 10;
      case CentreStatus.delayed:
        return 18;
      case CentreStatus.degraded:
        return 30;
      case CentreStatus.unavailable:
        return double.infinity;
    }
  }

  static bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static int _dayDistance(DateTime a, DateTime b) =>
      DateTime(a.year, a.month, a.day)
          .difference(DateTime(b.year, b.month, b.day))
          .inDays
          .abs();

  static double _distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;

    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
            math.cos(lat1Rad) *
                math.cos(lat2Rad) *
                math.sin(dLon / 2) *
                math.sin(dLon / 2);

    final c = 2 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
    return earthRadiusKm * c;
  }

  static double _toRadians(double degrees) =>
      degrees * math.pi / 180.0;
}

class ReschedulingEngine {
  List<Farmer> redistribute({
    required List<Farmer> farmers,
    required List<Centre> centres,
    Set<String> unavailableAssignments = const <String>{},
  }) {
    // Centre/date changes and time-slot assignments are intentionally rebuilt
    // together so there is one source of truth for appointments.
    return AppointmentScheduler.rebuildAppointments(
      farmers: farmers,
      centres: centres,
      unavailableCentreDates: unavailableAssignments,
    );
  }
}

class _AppointmentCandidate {
  final Centre centre;
  final DateTime date;
  final String slot;
  final double score;

  const _AppointmentCandidate({
    required this.centre,
    required this.date,
    required this.slot,
    required this.score,
  });
}

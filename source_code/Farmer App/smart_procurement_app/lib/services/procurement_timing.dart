class ProcurementTiming {
  /// Prototype assumptions are centralized here so every screen uses exactly
  /// the same timing model. The database may later replace the default with
  /// an individual model prediction.
  static const double defaultProcessingMinutesPerFarmer = 7.0;
  static const int slotMinutes = 30;
  static const int arrivalBufferMinutes = 10;

  static double get defaultProcessingRatePerHour =>
      60.0 / defaultProcessingMinutesPerFarmer;

  static int get defaultSlotCapacity =>
      slotMinutes ~/ defaultProcessingMinutesPerFarmer.round();

  static int waitFromFarmersAhead(int farmersAhead) {
    if (farmersAhead <= 0) return 0;
    return (farmersAhead * defaultProcessingMinutesPerFarmer).round();
  }

  static String formatTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '--';
    final parts = raw.trim().split(':');
    if (parts.length < 2) return raw.trim();
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return raw.trim();
    }
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  static String formatWindow(String? start, String? end) {
    final a = formatTime(start);
    final b = formatTime(end);
    return '$a – $b';
  }

  static String formatDate(String? iso) {
    if (iso == null || iso.trim().isEmpty) return 'Not assigned';
    final date = DateTime.tryParse(iso.trim());
    if (date == null) return iso.trim();
    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  static DateTime? combineDateAndTime(String? date, String? time) {
    if (date == null || time == null) return null;
    final d = DateTime.tryParse(date);
    final parts = time.split(':');
    if (d == null || parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(d.year, d.month, d.day, h, m);
  }
}

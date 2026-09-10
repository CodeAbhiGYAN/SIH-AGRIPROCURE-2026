class MspEntry {
  final String crop;
  final String season;
  final int current;
  final int previous;
  final String unit;
  final String source;
  final String lastUpdated;

  const MspEntry({required this.crop, required this.season, required this.current, required this.previous, required this.unit, required this.source, required this.lastUpdated});

  int get change => current - previous;
  double get percentChange => previous == 0 ? 0 : change * 100 / previous;
}

class MspService {
  // Replace this repository with a secured backend feed later. The app should consume
  // validated official data rather than scrape government pages directly.
  final List<MspEntry> entries = const [
    MspEntry(crop: 'Wheat', season: 'RMS 2026-27', current: 2585, previous: 2425, unit: '₹/quintal', source: 'DFPD / PIB', lastUpdated: '2026-08-06'),
    MspEntry(crop: 'Paddy (Common)', season: 'KMS 2026-27', current: 2441, previous: 2369, unit: '₹/quintal', source: 'PIB', lastUpdated: '2026-05-13'),
    MspEntry(crop: 'Paddy (Grade A)', season: 'KMS 2026-27', current: 2461, previous: 2389, unit: '₹/quintal', source: 'PIB', lastUpdated: '2026-05-13'),
    MspEntry(crop: 'Mustard', season: 'RMS 2026-27', current: 6200, previous: 5950, unit: '₹/quintal', source: 'PIB', lastUpdated: '2025-12-02'),
    MspEntry(crop: 'Gram', season: 'RMS 2026-27', current: 5875, previous: 5650, unit: '₹/quintal', source: 'PIB', lastUpdated: '2025-12-02'),
    MspEntry(crop: 'Masur (Lentil)', season: 'RMS 2026-27', current: 7000, previous: 6700, unit: '₹/quintal', source: 'PIB', lastUpdated: '2025-12-02'),
    MspEntry(crop: 'Bajra', season: 'KMS 2026-27', current: 2900, previous: 2775, unit: '₹/quintal', source: 'PIB', lastUpdated: '2026-05-13'),
    MspEntry(crop: 'Maize', season: 'KMS 2026-27', current: 2410, previous: 2400, unit: '₹/quintal', source: 'PIB', lastUpdated: '2026-05-13'),
  ];

  MspEntry? forCrop(String crop) {
    final normalized = crop.toLowerCase();
    try {
      return entries.firstWhere((e) => e.crop.toLowerCase().contains(normalized) || normalized.contains(e.crop.toLowerCase().split(' ').first));
    } catch (_) {
      return null;
    }
  }
}

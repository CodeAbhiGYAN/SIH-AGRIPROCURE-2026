import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'package:latlong2/latlong.dart';

class RouteEstimate {
  final double km;
  final int minutes;
  final List<LatLng> points;
  final bool fromRoadRouting;

  const RouteEstimate({
    required this.km,
    required this.minutes,
    required this.points,
    required this.fromRoadRouting,
  });
}

class MapsService {
  static const String tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _userAgent = 'SmartProcurement/1.0';

  Future<RouteEstimate> route({
    required double farmerLat,
    required double farmerLng,
    required double centreLat,
    required double centreLng,
  }) async {
    final fallback = _fallbackRoute(
      farmerLat: farmerLat,
      farmerLng: farmerLng,
      centreLat: centreLat,
      centreLng: centreLng,
    );

    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '$farmerLng,$farmerLat;$centreLng,$centreLat'
        '?overview=full&geometries=geojson&steps=false',
      );
      final client = HttpClient()..userAgent = _userAgent;
      try {
        final request = await client.getUrl(uri).timeout(const Duration(seconds: 8));
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        final response = await request.close().timeout(const Duration(seconds: 8));
        if (response.statusCode != HttpStatus.ok) return fallback;
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;
        if (routes == null || routes.isEmpty) return fallback;
        final route = routes.first as Map<String, dynamic>;
        final distanceMeters = (route['distance'] as num?)?.toDouble();
        final durationSeconds = (route['duration'] as num?)?.toDouble();
        final geometry = route['geometry'] as Map<String, dynamic>?;
        final coordinates = geometry?['coordinates'] as List<dynamic>?;
        if (distanceMeters == null || durationSeconds == null || coordinates == null || coordinates.isEmpty) {
          return fallback;
        }
        final points = <LatLng>[];
        for (final item in coordinates) {
          final pair = item as List<dynamic>;
          if (pair.length < 2) continue;
          final lng = (pair[0] as num).toDouble();
          final lat = (pair[1] as num).toDouble();
          if (lat.isFinite && lng.isFinite) points.add(LatLng(lat, lng));
        }
        if (points.length < 2) return fallback;
        return RouteEstimate(
          km: distanceMeters / 1000,
          minutes: math.max(1, (durationSeconds / 60).round()),
          points: points,
          fromRoadRouting: true,
        );
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return fallback;
    }
  }

  RouteEstimate _fallbackRoute({
    required double farmerLat,
    required double farmerLng,
    required double centreLat,
    required double centreLng,
  }) {
    final dx = (farmerLat - centreLat).abs() * 111;
    final dy = (farmerLng - centreLng).abs() * 95;
    final straightLineKm = math.sqrt((dx * dx) + (dy * dy));
    final approxKm = math.max(straightLineKm * 1.22, 0.5).toDouble();
    final minutes = math.max(5, (approxKm / 25 * 60).round());
    return RouteEstimate(
      km: approxKm,
      minutes: minutes,
      points: [LatLng(farmerLat, farmerLng), LatLng(centreLat, centreLng)],
      fromRoadRouting: false,
    );
  }

  DateTime recommendedDeparture(DateTime requiredArrival, int minutes) {
    return requiredArrival.subtract(Duration(minutes: minutes));
  }
}

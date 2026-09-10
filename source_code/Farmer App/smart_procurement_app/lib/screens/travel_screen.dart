import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../services/maps_service.dart';
import '../widgets/common.dart';

class TravelScreen extends StatefulWidget {
  final AppState state;
  const TravelScreen({super.key, required this.state});

  @override
  State<TravelScreen> createState() => _TravelScreenState();
}

class _TravelScreenState extends State<TravelScreen> {
  final MapController mapController = MapController();
  RouteEstimate? route;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  @override
  void didUpdateWidget(covariant TravelScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.farmerId != widget.state.farmerId ||
        oldWidget.state.farmer.centreId != widget.state.farmer.centreId ||
        oldWidget.state.appointmentAssigned != widget.state.appointmentAssigned) {
      _loadRoute();
    }
  }

  Future<void> _loadRoute() async {
    if (!widget.state.appointmentAssigned) return;
    final farmer = widget.state.farmer;
    final centre = widget.state.assignedCentre;
    setState(() => loading = true);
    final result = await widget.state.maps.route(
      farmerLat: farmer.lat,
      farmerLng: farmer.lng,
      centreLat: centre.lat,
      centreLng: centre.lng,
    );
    if (!mounted) return;
    setState(() {
      route = result;
      loading = false;
    });
  }

  Future<void> _openOsmAttribution() async {
    final uri = Uri.parse('https://www.openstreetmap.org/copyright');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    if (!state.appointmentAssigned) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InfoCard(title: state.t('travel_plan'), icon: Icons.route, child: Text(state.t('travel_after_appointment'))),
        ],
      );
    }

    final farmer = state.farmer;
    final centre = state.assignedCentre;
    final currentRoute = route;
    final arrival = state.recommendedArrivalTime;
    if (arrival == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InfoCard(title: state.t('travel_plan'), icon: Icons.route, child: const Text('Appointment time is not available yet.')),
        ],
      );
    }
    final leave = currentRoute == null
        ? arrival.subtract(const Duration(minutes: 30))
        : state.maps.recommendedDeparture(arrival, currentRoute.minutes);
    final center = LatLng((farmer.lat + centre.lat) / 2, (farmer.lng + centre.lng) / 2);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(state.t('travel_plan_title'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 300,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(initialCenter: center, initialZoom: 11),
                  children: [
                    TileLayer(urlTemplate: MapsService.tileUrl, userAgentPackageName: 'com.example.smart_procurement'),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: currentRoute?.points ?? [LatLng(farmer.lat, farmer.lng), LatLng(centre.lat, centre.lng)],
                          strokeWidth: 5,
                          color: Colors.green,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(farmer.lat, farmer.lng),
                          width: 46,
                          height: 46,
                          child: const Icon(Icons.home, size: 40, color: Colors.blue),
                        ),
                        Marker(
                          point: LatLng(centre.lat, centre.lng),
                          width: 46,
                          height: 46,
                          child: const Icon(Icons.location_on, size: 40, color: Colors.red),
                        ),
                      ],
                    ),
                    RichAttributionWidget(
                      attributions: [TextSourceAttribution('OpenStreetMap contributors', onTap: _openOsmAttribution)],
                    ),
                  ],
                ),
                if (loading)
                  const Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: LinearProgressIndicator(minHeight: 4),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          currentRoute?.fromRoadRouting == true ? state.t('road_live') : state.t('road_fallback'),
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        ),
        const SizedBox(height: 12),
        InfoCard(
          title: state.t('assigned_centre'),
          icon: Icons.location_on,
          child: Text('${centre.name}\n${centre.address}', style: const TextStyle(fontSize: 17)),
        ),
        const SizedBox(height: 12),
        InfoCard(
          title: state.t('travel_estimate'),
          icon: Icons.route,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentRoute == null ? state.t('calculating_route') : '${currentRoute.km.toStringAsFixed(1)} km • ${currentRoute.minutes} min',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text('${state.t('arrival_target')}: 11:15 AM'),
              Text('${state.t('leave_by')}: ${_formatTime(leave)}'),
              const SizedBox(height: 8),
              Text(state.t('map_interactive')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        InfoCard(
          title: state.t('travel_guidance'),
          icon: Icons.info_outline,
          child: Text(state.t('no_external_navigation')),
        ),
      ],
    );
  }

  String _formatTime(DateTime value) {
    final hour = value.hour == 0 ? 12 : value.hour > 12 ? value.hour - 12 : value.hour;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}

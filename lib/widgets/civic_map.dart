import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme/app_theme.dart';
import '../models/domain_models.dart';

enum CivicMapMarkerType { project, report, facility }

class CivicMapMarker {
  const CivicMapMarker({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.point,
    required this.type,
    required this.color,
    this.onTap,
  });

  final String id;
  final String title;
  final String subtitle;
  final GeoPoint point;
  final CivicMapMarkerType type;
  final Color color;
  final VoidCallback? onTap;
}

class CivicMap extends StatelessWidget {
  const CivicMap({
    super.key,
    required this.center,
    this.markers = const <CivicMapMarker>[],
    this.height = 320,
    this.zoom = 13,
    this.onTap,
    this.selectedPoint,
  });

  final GeoPoint center;
  final List<CivicMapMarker> markers;
  final double height;
  final double zoom;
  final ValueChanged<GeoPoint>? onTap;
  final GeoPoint? selectedPoint;

  @override
  Widget build(BuildContext context) {
    final mapMarkers = <CivicMapMarker>[...markers];
    if (selectedPoint != null) {
      mapMarkers.add(
        CivicMapMarker(
          id: 'selected-point',
          title: 'Selected location',
          subtitle: selectedPoint!.shortLabel,
          point: selectedPoint!,
          type: CivicMapMarkerType.report,
          color: AppColors.danger,
        ),
      );
    }
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: <Widget>[
            FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(center.latitude, center.longitude),
                initialZoom: zoom,
                onTap: onTap == null
                    ? null
                    : (_, point) =>
                          onTap!(GeoPoint(point.latitude, point.longitude)),
              ),
              children: <Widget>[
                TileLayer(
                  urlTemplate: const String.fromEnvironment(
                    'MAP_TILES_URL',
                    defaultValue:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  ),
                  userAgentPackageName: 'lk.smartsabha.app',
                ),
                MarkerLayer(
                  markers: mapMarkers
                      .map(
                        (marker) => Marker(
                          point: LatLng(
                            marker.point.latitude,
                            marker.point.longitude,
                          ),
                          width: 48,
                          height: 56,
                          child: GestureDetector(
                            onTap: marker.onTap,
                            child: Column(
                              children: <Widget>[
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: marker.color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: const <BoxShadow>[
                                      BoxShadow(
                                        blurRadius: 7,
                                        color: Color(0x33000000),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _iconFor(marker.type),
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                Container(
                                  width: 2,
                                  height: 12,
                                  color: marker.color,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            Positioned(
              right: 8,
              bottom: 7,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 9, color: AppColors.muted),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(CivicMapMarkerType type) => switch (type) {
    CivicMapMarkerType.project => Icons.construction_outlined,
    CivicMapMarkerType.report => Icons.report_problem_outlined,
    CivicMapMarkerType.facility => Icons.location_city_outlined,
  };
}

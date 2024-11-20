import 'package:flutter/material.dart';
import 'package:geofencing_api/geofencing_api.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as map;

class GoogleMapView extends StatefulWidget {
  const GoogleMapView({
    super.key,
    required this.regions,
  });

  final Set<GeofenceRegion> regions;

  @override
  State<StatefulWidget> createState() => _GoogleMapViewState();
}

class _GoogleMapViewState extends State<GoogleMapView> {
  final Set<map.Circle> _circles = {};
  final Set<map.Polygon> _polygons = {};
  final Color _kEnterColor = const Color(0xFF4CAF50);
  final Color _kExitColor = const Color(0xFFF44336);
  final Color _kDwellColor = const Color(0xFF9C27B0);

  Color _getFillColorByStatus(GeofenceStatus status) {
    switch (status) {
      case GeofenceStatus.enter:
        return _kEnterColor.withOpacity(0.5);
      case GeofenceStatus.exit:
        return _kExitColor.withOpacity(0.5);
      case GeofenceStatus.dwell:
        return _kDwellColor.withOpacity(0.5);
    }
  }

  void _updateMapsObject() {
    _circles.clear();
    _polygons.clear();

    map.Circle circle;
    map.Polygon polygon;
    for (final GeofenceRegion region in widget.regions) {
      if (region is GeofenceCircularRegion) {
        circle = map.Circle(
          circleId: map.CircleId(region.id),
          center: map.LatLng(region.center.latitude, region.center.longitude),
          radius: region.radius,
          strokeWidth: 2,
          strokeColor: Colors.black,
          fillColor: _getFillColorByStatus(region.status),
        );
        _circles.add(circle);
        continue;
      }

      if (region is GeofencePolygonRegion) {
        polygon = map.Polygon(
          polygonId: map.PolygonId(region.id),
          points: region.polygon
              .map((e) => map.LatLng(e.latitude, e.longitude))
              .toList(),
          strokeWidth: 2,
          strokeColor: Colors.black,
          fillColor: _getFillColorByStatus(region.status),
        );
        _polygons.add(polygon);
        continue;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _updateMapsObject();
  }

  @override
  void didUpdateWidget(covariant GoogleMapView oldWidget) {
    _updateMapsObject();
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return map.GoogleMap(
      initialCameraPosition: const map.CameraPosition(
        target: map.LatLng(14.501900, 120.997013),
        zoom: 15,
      ),
      circles: _circles,
      polygons: _polygons,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }
}

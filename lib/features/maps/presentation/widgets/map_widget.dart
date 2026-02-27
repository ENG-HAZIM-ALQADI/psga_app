import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'dart:async';

/// Widget خريطة قابل لإعادة الاستخدام
/// Single Responsibility: عرض خريطة Google Maps مع إمكانية التخصيص
class MapWidget extends StatefulWidget {
  final Location? initialLocation;
  final double initialZoom;
  final Set<Marker>? markers;
  final Set<Polyline>? polylines;
  final Set<Circle>? circles;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  final bool zoomControlsEnabled;
  final MapType mapType;
  final Function(GoogleMapController)? onMapCreated;
  final Function(LatLng)? onTap;
  final Function(LatLng)? onLongPress;
  final Function(CameraPosition)? onCameraMove;
  final VoidCallback? onCameraIdle;
  final EdgeInsets? padding;

  const MapWidget({
    this.initialLocation,
    this.initialZoom = 14.0,
    this.markers,
    this.polylines,
    this.circles,
    this.myLocationEnabled = true,
    this.myLocationButtonEnabled = true,
    this.zoomControlsEnabled = true,
    this.mapType = MapType.normal,
    this.onMapCreated,
    this.onTap,
    this.onLongPress,
    this.onCameraMove,
    this.onCameraIdle,
    this.padding,
    super.key,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  GoogleMapController? _controller;
  final Completer<GoogleMapController> _controllerCompleter = Completer();
  bool _isMapLoading = true;

  bool _isDark = false;

  static const String _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#212121"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#757575"}]},
  {"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
  {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#181818"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
  {"featureType":"poi.park","elementType":"labels.text.stroke","stylers":[{"color":"#1b1b1b"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#373737"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c3c3c"}]},
  {"featureType":"road.highway.controlled_access","elementType":"geometry","stylers":[{"color":"#4e4e4e"}]},
  {"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
  {"featureType":"transit","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3d3d3d"}]}
]
''';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark != _isDark) {
      setState(() => _isDark = isDark);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // الموقع الافتراضي (الرياض)
    final defaultLocation = widget.initialLocation ?? Location(
      latitude: 24.7136,
      longitude: 46.6753,
      timestamp: DateTime.now(),
    );

    final initialCameraPosition = CameraPosition(
      target: LatLng(defaultLocation.latitude, defaultLocation.longitude),
      zoom: widget.initialZoom,
    );

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: initialCameraPosition,
          mapType: widget.mapType,
          style: _isDark ? _darkMapStyle : null,
          myLocationEnabled: widget.myLocationEnabled,
          myLocationButtonEnabled: widget.myLocationButtonEnabled,
          zoomControlsEnabled: widget.zoomControlsEnabled,
          markers: widget.markers ?? {},
          polylines: widget.polylines ?? {},
          circles: widget.circles ?? {},
          padding: widget.padding ?? EdgeInsets.zero,
          onMapCreated: (GoogleMapController controller) {
            _controller = controller;
            if (!_controllerCompleter.isCompleted) {
              _controllerCompleter.complete(controller);
            }
            
            // إخفاء loading indicator بعد تحميل الخريطة
            if (mounted) {
              setState(() {
                _isMapLoading = false;
              });
            }
            
            widget.onMapCreated?.call(controller);
            AppLogger.success('[MapWidget] تم تحميل الخريطة بنجاح');
          },
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onCameraMove: widget.onCameraMove,
          onCameraIdle: widget.onCameraIdle,
        ),
        
        // Loading indicator
        if (_isMapLoading)
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'جاري تحميل الخريطة...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// الانتقال إلى موقع محدد
  Future<void> animateToLocation(
    Location location, {
    double zoom = 15.0,
  }) async {
    final controller = await _controllerCompleter.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(location.latitude, location.longitude),
          zoom: zoom,
        ),
      ),
    );
  }

  /// تكبير الخريطة لعرض جميع العلامات
  Future<void> fitBounds(List<Location> locations) async {
    if (locations.isEmpty) return;

    final controller = await _controllerCompleter.future;
    
    // حساب الحدود
    double minLat = locations.first.latitude;
    double maxLat = locations.first.latitude;
    double minLng = locations.first.longitude;
    double maxLng = locations.first.longitude;

    for (final location in locations) {
      if (location.latitude < minLat) minLat = location.latitude;
      if (location.latitude > maxLat) maxLat = location.latitude;
      if (location.longitude < minLng) minLng = location.longitude;
      if (location.longitude > maxLng) maxLng = location.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }
}

/// Helper لإنشاء Marker
Marker createMarker({
  required String id,
  required Location location,
  required String title,
  String? snippet,
  BitmapDescriptor? icon,
  VoidCallback? onTap,
}) {
  return Marker(
    markerId: MarkerId(id),
    position: LatLng(location.latitude, location.longitude),
    infoWindow: InfoWindow(
      title: title,
      snippet: snippet,
    ),
    icon: icon ?? BitmapDescriptor.defaultMarker,
    onTap: onTap,
  );
}

/// Helper لإنشاء Polyline
Polyline createPolyline({
  required String id,
  required List<Location> points,
  Color color = Colors.blue,
  double width = 5.0,
  bool geodesic = true,
}) {
  return Polyline(
    polylineId: PolylineId(id),
    points: points.map((loc) => LatLng(loc.latitude, loc.longitude)).toList(),
    color: color,
    width: width.toInt(),
    geodesic: geodesic,
  );
}

/// Helper لإنشاء Circle
Circle createCircle({
  required String id,
  required Location center,
  required double radius,
  Color fillColor = Colors.blue,
  Color strokeColor = Colors.blue,
  double strokeWidth = 2.0,
}) {
  return Circle(
    circleId: CircleId(id),
    center: LatLng(center.latitude, center.longitude),
    radius: radius,
    fillColor: fillColor.withOpacity(0.2),
    strokeColor: strokeColor,
    strokeWidth: strokeWidth.toInt(),
  );
}

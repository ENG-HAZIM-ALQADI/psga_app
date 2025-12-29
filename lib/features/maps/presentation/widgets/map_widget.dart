import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// widget الخريطة القابل لإعادة الاستخدام
class MapWidget extends StatelessWidget {
  final LatLng initialPosition;
  final Set<Marker>? markers;
  final Set<Polyline>? polylines;
  final Function(GoogleMapController)? onMapCreated;
  final Function(LatLng)? onTap;
  final Function(CameraPosition)? onCameraMove;
  final bool showCurrentLocation;
  final bool isInteractive;
  final double? height;
  final MapType mapType;

  const MapWidget({
    super.key,
    required this.initialPosition,
    this.markers,
    this.polylines,
    this.onMapCreated,
    this.onTap,
    this.onCameraMove,
    this.showCurrentLocation = true,
    this.isInteractive = true,
    this.height,
    this.mapType = MapType.normal,
  });

  @override
  Widget build(BuildContext context) {
    final map = GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialPosition,
        zoom: 15,
      ),
      markers: markers ?? {},
      polylines: polylines ?? {},
      onMapCreated: onMapCreated,
      onTap: onTap,
      onCameraMove: onCameraMove,
      myLocationEnabled: showCurrentLocation,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
      mapType: mapType,
      rotateGesturesEnabled: isInteractive,
      scrollGesturesEnabled: isInteractive,
      tiltGesturesEnabled: isInteractive,
      zoomGesturesEnabled: isInteractive,
    );

    if (height != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: height,
          child: map,
        ),
      );
    }

    return map;
  }
}

/// خريطة مصغرة للمعاينة
class MiniMapWidget extends StatelessWidget {
  final LatLng location;
  final double height;
  final VoidCallback? onTap;

  const MiniMapWidget({
    super.key,
    required this.location,
    this.height = 150,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: location,
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('location'),
                    position: location,
                  ),
                },
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                rotateGesturesEnabled: false,
                scrollGesturesEnabled: false,
                tiltGesturesEnabled: false,
                zoomGesturesEnabled: false,
                liteModeEnabled: true,
              ),
              if (onTap != null)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.02),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

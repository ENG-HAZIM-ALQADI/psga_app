import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// رسم المسار على الخريطة
class RouteOverlay {
  /// إنشاء polyline للمسار المحدد
  static Polyline createRouteLine({
    required List<LatLng> points,
    Color color = const Color(0xFF2196F3),
    double width = 5,
    bool isActive = true,
    String id = 'route',
  }) {
    return Polyline(
      polylineId: PolylineId(id),
      points: points,
      color: isActive ? color : color.withOpacity(0.5),
      width: width.toInt(),
      patterns: isActive ? [] : [PatternItem.dash(20), PatternItem.gap(10)],
      jointType: JointType.round,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    );
  }

  /// إنشاء polyline للمسار الفعلي (تاريخ التتبع)
  static Polyline createTrackingLine({
    required List<LatLng> points,
    Color color = const Color(0xFF4CAF50),
    double width = 4,
    String id = 'tracking',
  }) {
    return Polyline(
      polylineId: PolylineId(id),
      points: points,
      color: color,
      width: width.toInt(),
      jointType: JointType.round,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    );
  }

  /// إنشاء polyline للانحراف
  static Polyline createDeviationLine({
    required LatLng currentPosition,
    required LatLng nearestRoutePoint,
    String id = 'deviation',
  }) {
    return Polyline(
      polylineId: PolylineId(id),
      points: [currentPosition, nearestRoutePoint],
      color: Colors.red,
      width: 3,
      patterns: [PatternItem.dash(10), PatternItem.gap(5)],
    );
  }
}

/// widget لعرض تفاصيل المسار
class RouteDetailsWidget extends StatelessWidget {
  final String routeName;
  final double distance;
  final Duration duration;
  final int waypointsCount;
  final VoidCallback? onStartTrip;
  final VoidCallback? onEdit;

  const RouteDetailsWidget({
    super.key,
    required this.routeName,
    required this.distance,
    required this.duration,
    this.waypointsCount = 0,
    this.onStartTrip,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  routeName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onEdit != null)
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.grey),
                  onPressed: onEdit,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoItem(
                icon: Icons.straighten,
                value: _formatDistance(distance),
                label: 'المسافة',
              ),
              const SizedBox(width: 24),
              _buildInfoItem(
                icon: Icons.timer,
                value: _formatDuration(duration),
                label: 'الوقت',
              ),
              if (waypointsCount > 0) ...[
                const SizedBox(width: 24),
                _buildInfoItem(
                  icon: Icons.location_on,
                  value: '$waypointsCount',
                  label: 'نقاط',
                ),
              ],
            ],
          ),
          if (onStartTrip != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onStartTrip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'بدء الرحلة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} م';
    }
    return '${(meters / 1000).toStringAsFixed(1)} كم';
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes} د';
    }
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '$hours س ${minutes > 0 ? '$minutes د' : ''}';
  }
}

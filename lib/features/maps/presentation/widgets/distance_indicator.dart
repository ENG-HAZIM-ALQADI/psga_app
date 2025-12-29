import 'package:flutter/material.dart';

/// widget لعرض المسافة والوقت
class DistanceIndicator extends StatelessWidget {
  final double distance;
  final Duration duration;
  final TravelType travelType;
  final bool showIcon;

  const DistanceIndicator({
    super.key,
    required this.distance,
    required this.duration,
    this.travelType = TravelType.driving,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIcon) ...[
          Icon(
            _getTravelIcon(),
            size: 18,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.straighten, size: 14, color: Colors.blue),
              const SizedBox(width: 4),
              Text(
                _formatDistance(),
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer, size: 14, color: Colors.green),
              const SizedBox(width: 4),
              Text(
                _formatDuration(),
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getTravelIcon() {
    switch (travelType) {
      case TravelType.walking:
        return Icons.directions_walk;
      case TravelType.cycling:
        return Icons.directions_bike;
      case TravelType.driving:
      default:
        return Icons.directions_car;
    }
  }

  String _formatDistance() {
    if (distance < 1000) {
      return '${distance.round()} متر';
    }
    return '${(distance / 1000).toStringAsFixed(1)} كم';
  }

  String _formatDuration() {
    if (duration.inSeconds == 0) {
      return '-';
    }
    if (duration.inMinutes < 1) {
      return '${duration.inSeconds} ث';
    }
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes} د';
    }
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (minutes == 0) {
      return '$hours س';
    }
    return '$hours س $minutes د';
  }
}

/// نوع وسيلة التنقل
enum TravelType {
  walking,
  cycling,
  driving,
}

/// widget لعرض المسافة الكبيرة
class LargeDistanceIndicator extends StatelessWidget {
  final double distance;
  final Duration duration;

  const LargeDistanceIndicator({
    super.key,
    required this.distance,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildItem(
            icon: Icons.straighten,
            value: _formatDistance(),
            label: 'المسافة',
            color: Colors.blue,
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey.shade300,
          ),
          _buildItem(
            icon: Icons.timer,
            value: _formatDuration(),
            label: 'الوقت المتوقع',
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _formatDistance() {
    if (distance < 1000) {
      return '${distance.round()} م';
    }
    return '${(distance / 1000).toStringAsFixed(1)} كم';
  }

  String _formatDuration() {
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes} دقيقة';
    }
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (minutes == 0) {
      return '$hours ساعة';
    }
    return '$hours س $minutes د';
  }
}

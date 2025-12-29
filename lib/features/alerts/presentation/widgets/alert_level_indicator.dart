import 'package:flutter/material.dart';
import '../../domain/entities/alert_entity.dart';

class AlertLevelIndicator extends StatelessWidget {
  final AlertLevel level;
  final double size;
  final bool showLabel;

  const AlertLevelIndicator({
    super.key,
    required this.level,
    this.size = 24,
    this.showLabel = true,
  });

  Color get _color {
    switch (level) {
      case AlertLevel.low:
        return Colors.green;
      case AlertLevel.medium:
        return Colors.orange;
      case AlertLevel.high:
        return Colors.deepOrange;
      case AlertLevel.critical:
        return Colors.red;
    }
  }

  String get _label {
    switch (level) {
      case AlertLevel.low:
        return 'منخفض';
      case AlertLevel.medium:
        return 'متوسط';
      case AlertLevel.high:
        return 'عالي';
      case AlertLevel.critical:
        return 'حرج';
    }
  }

  IconData get _icon {
    switch (level) {
      case AlertLevel.low:
        return Icons.info_outline;
      case AlertLevel.medium:
        return Icons.warning_amber;
      case AlertLevel.high:
        return Icons.error_outline;
      case AlertLevel.critical:
        return Icons.dangerous;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _icon,
            size: size,
            color: _color,
          ),
          if (showLabel) ...[
            const SizedBox(width: 6),
            Text(
              _label,
              style: TextStyle(
                color: _color,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AlertTypeIndicator extends StatelessWidget {
  final AlertType type;
  final double size;
  final bool showLabel;

  const AlertTypeIndicator({
    super.key,
    required this.type,
    this.size = 24,
    this.showLabel = true,
  });

  Color get _color {
    switch (type) {
      case AlertType.deviation:
        return Colors.orange;
      case AlertType.sos:
        return Colors.red;
      case AlertType.inactivity:
        return Colors.blue;
      case AlertType.lowBattery:
        return Colors.amber;
      case AlertType.noConnection:
        return Colors.grey;
    }
  }

  String get _label {
    switch (type) {
      case AlertType.deviation:
        return 'انحراف';
      case AlertType.sos:
        return 'طوارئ';
      case AlertType.inactivity:
        return 'عدم حركة';
      case AlertType.lowBattery:
        return 'بطارية';
      case AlertType.noConnection:
        return 'اتصال';
    }
  }

  IconData get _icon {
    switch (type) {
      case AlertType.deviation:
        return Icons.directions_off;
      case AlertType.sos:
        return Icons.emergency;
      case AlertType.inactivity:
        return Icons.access_time;
      case AlertType.lowBattery:
        return Icons.battery_alert;
      case AlertType.noConnection:
        return Icons.signal_wifi_off;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _icon,
            size: size,
            color: _color,
          ),
          if (showLabel) ...[
            const SizedBox(width: 6),
            Text(
              _label,
              style: TextStyle(
                color: _color,
                fontWeight: FontWeight.w500,
                fontSize: size * 0.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

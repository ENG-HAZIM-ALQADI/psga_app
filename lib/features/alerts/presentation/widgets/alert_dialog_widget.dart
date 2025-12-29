import 'package:flutter/material.dart';
import '../../domain/entities/alert_entity.dart';
import 'countdown_timer_widget.dart';

class AlertDialogWidget extends StatelessWidget {
  final AlertEntity alert;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback onAcknowledge;
  final VoidCallback onEscalate;

  const AlertDialogWidget({
    super.key,
    required this.alert,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.onAcknowledge,
    required this.onEscalate,
  });

  IconData get _alertIcon {
    switch (alert.type) {
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

  Color get _alertColor {
    switch (alert.level) {
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _alertColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _alertIcon,
                size: 48,
                color: _alertColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              alert.typeDisplayName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              alert.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            CountdownTimerWidget(
              seconds: remainingSeconds,
              totalSeconds: totalSeconds,
              size: 120,
            ),
            const SizedBox(height: 16),
            Text(
              'سيتم إبلاغ جهات الاتصال تلقائياً',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onEscalate,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('تصعيد فوري'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onAcknowledge,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('أنا بخير'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

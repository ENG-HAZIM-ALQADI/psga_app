import 'dart:async';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';

/// نافذة تنبيه مع عد تنازلي وزر "أنا بخير"
class AlertDialogWidget extends StatefulWidget {
  final AlertEntity alert;
  final int countdownSeconds;
  final VoidCallback onImOkPressed;
  final VoidCallback? onTimeout;

  const AlertDialogWidget({
    required this.alert,
    required this.onImOkPressed,
    this.countdownSeconds = 30,
    this.onTimeout,
    super.key,
  });

  @override
  State<AlertDialogWidget> createState() => _AlertDialogWidgetState();
}

class _AlertDialogWidgetState extends State<AlertDialogWidget>
    with SingleTickerProviderStateMixin {
  late int _remainingSeconds;
  Timer? _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.countdownSeconds;
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0) {
        _timer?.cancel();
        widget.onTimeout?.call();
        Navigator.of(context).pop();
      }
    });
  }

  Color get _alertColor {
    switch (widget.alert.severity) {
      case AlertSeverity.low:
        return AppColors.gold.withOpacity(0.6);
      case AlertSeverity.medium:
        return AppColors.gold;
      case AlertSeverity.high:
        return AppColors.red;
      case AlertSeverity.critical:
        return AppColors.red;
    }
  }

  IconData get _alertIcon {
    switch (widget.alert.type) {
      case AlertType.sos:
        return Icons.sos;
      case AlertType.deviation:
        return Icons.warning;
      case AlertType.checkpoint:
        return Icons.location_on;
      case AlertType.speedLimit:
        return Icons.speed;
      case AlertType.lowBattery:
        return Icons.battery_alert;
      case AlertType.noMovement:
        return Icons.not_accessible;
      case AlertType.geofence:
        return Icons.location_off;
      case AlertType.custom:
        return Icons.notifications_active;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _alertColor.withOpacity(0.1),
              _alertColor.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // أيقونة التنبيه
            ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.1).animate(_pulseController),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _alertColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _alertIcon,
                  size: 40,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // العنوان
            Text(
              widget.alert.title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _alertColor,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // الرسالة
            Text(
              widget.alert.message,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // العد التنازلي
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _alertColor,
                  width: 4,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$_remainingSeconds',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: _alertColor,
                      ),
                    ),
                    Text(
                      'ثانية',
                      style: TextStyle(
                        fontSize: 14,
                        color: _alertColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // التعليمات
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'سيتم إرسال التنبيه لجهات الاتصال إذا لم تضغط "أنا بخير"',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 24),

            // زر "أنا بخير"
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  _timer?.cancel();
                  widget.onImOkPressed();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'أنا بخير ✓',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // زر إرسال فوري
            TextButton(
              onPressed: () {
                _timer?.cancel();
                widget.onTimeout?.call();
                Navigator.of(context).pop();
              },
              child: Text(
                'إرسال التنبيه الآن',
                style: TextStyle(
                  color: _alertColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// دالة مساعدة لعرض نافذة التنبيه
Future<void> showAlertDialog(
  BuildContext context, {
  required AlertEntity alert,
  required VoidCallback onImOkPressed,
  VoidCallback? onTimeout,
  int countdownSeconds = 30,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialogWidget(
      alert: alert,
      onImOkPressed: onImOkPressed,
      onTimeout: onTimeout,
      countdownSeconds: countdownSeconds,
    ),
  );
}

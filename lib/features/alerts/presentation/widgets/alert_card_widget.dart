import 'package:flutter/material.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/core/utils/extensions.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';
import 'package:intl/intl.dart';

/// بطاقة عرض تنبيه
class AlertCardWidget extends StatelessWidget {
  final AlertEntity alert;
  final VoidCallback? onTap;
  final VoidCallback? onAcknowledge;
  final VoidCallback? onResolve;

  const AlertCardWidget({
    required this.alert,
    this.onTap,
    this.onAcknowledge,
    this.onResolve,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getSeverityColor(context, alert.severity).withOpacity(0.5),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الصف الأول: الأيقونة والعنوان والشارة
              Row(
                children: [
                  // الأيقونة
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getSeverityColor(context, alert.severity).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getTypeIcon(alert.type),
                      color: _getSeverityColor(context, alert.severity),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // العنوان
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _getTypeText(alert.type),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // شارة الشدة
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getSeverityColor(context, alert.severity),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getSeverityText(alert.severity),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // الرسالة
              Text(
                alert.message,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.grey,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // المعلومات
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(alert.triggeredAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.info_outline, size: 16, color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    _getStatusText(alert.status),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
                    ),
                  ),
                ],
              ),

              // الأزرار
              if (alert.status == AlertStatus.triggered ||
                  alert.status == AlertStatus.pending) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (onAcknowledge != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onAcknowledge,
                          icon: const Icon(Icons.check, size: 18),
                          label: Text(context.l10n.alertAcknowledged),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    if (onAcknowledge != null && onResolve != null)
                      const SizedBox(width: 8),
                    if (onResolve != null)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onResolve,
                          icon: const Icon(Icons.done_all, size: 18),
                          label: Text(context.l10n.alertCancelled),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.green,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getSeverityColor(BuildContext context, AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return Theme.of(context).colorScheme.primary;
      case AlertSeverity.medium:
        return AppColors.gold;
      case AlertSeverity.high:
        return AppColors.gold;
      case AlertSeverity.critical:
        return AppColors.red;
    }
  }

  IconData _getTypeIcon(AlertType type) {
    switch (type) {
      case AlertType.sos:
        return Icons.emergency;
      case AlertType.deviation:
        return Icons.wrong_location;
      case AlertType.checkpoint:
        return Icons.flag;
      case AlertType.speedLimit:
        return Icons.speed;
      case AlertType.lowBattery:
        return Icons.battery_alert;
      case AlertType.noMovement:
        return Icons.pause_circle;
      case AlertType.geofence:
        return Icons.location_off;
      case AlertType.custom:
        return Icons.info;
    }
  }

  String _getTypeText(AlertType type) {
    switch (type) {
      case AlertType.sos:
        return 'طوارئ SOS';
      case AlertType.deviation:
        return 'انحراف عن المسار';
      case AlertType.checkpoint:
        return 'نقطة تفتيش';
      case AlertType.speedLimit:
        return 'تجاوز السرعة';
      case AlertType.lowBattery:
        return 'بطارية منخفضة';
      case AlertType.noMovement:
        return 'عدم حركة';
      case AlertType.geofence:
        return 'خارج المنطقة';
      case AlertType.custom:
        return 'مخصص';
    }
  }

  String _getSeverityText(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return 'منخفض';
      case AlertSeverity.medium:
        return 'متوسط';
      case AlertSeverity.high:
        return 'عالي';
      case AlertSeverity.critical:
        return 'حرج';
    }
  }

  String _getStatusText(AlertStatus status) {
    switch (status) {
      case AlertStatus.triggered:
        return 'مُطلق';
      case AlertStatus.pending:
        return 'قيد الانتظار';
      case AlertStatus.acknowledged:
        return 'تم الإقرار';
      case AlertStatus.escalated:
        return 'تم التصعيد';
      case AlertStatus.resolved:
        return 'تم الحل';
      case AlertStatus.cancelled:
        return 'ملغي';
      case AlertStatus.ignored:
        return 'تم التجاهل';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} يوم';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }
}

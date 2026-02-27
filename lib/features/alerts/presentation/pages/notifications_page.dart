import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/core/constants/app_dimensions.dart';
import 'package:psga_app/core/utils/extensions.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';
import 'package:psga_app/features/alerts/presentation/bloc/alert/alert_bloc.dart';
import 'package:psga_app/features/alerts/presentation/bloc/alert/alert_event.dart';
import 'package:psga_app/features/alerts/presentation/bloc/alert/alert_state.dart';
import 'package:psga_app/shared/widgets/loading_widget.dart';
import 'package:psga_app/shared/widgets/empty_state_widget.dart';

/// صفحة الإشعارات - عرض جميع التنبيهات للمستخدم
class NotificationsPage extends StatefulWidget {
  final String userId;

  const NotificationsPage({
    required this.userId,
    super.key,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    AppLogger.info('[NotificationsPage] تحميل الإشعارات للمستخدم: ${widget.userId}');
    context.read<AlertBloc>().add(LoadActiveAlertsEvent(widget.userId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.notificationsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
            tooltip: context.l10n.refreshTooltip,
          ),
        ],
      ),
      body: BlocBuilder<AlertBloc, AlertState>(
        builder: (context, state) {
          if (state is AlertLoading) {
            return LoadingWidget(message: context.l10n.loadingNotifications);
          }

          if (state is AlertError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error.withOpacity(0.5),
                  ),
                  const SizedBox(height: AppDimensions.spacingMD),
                  Text(
                    state.message,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.spacingMD),
                  ElevatedButton.icon(
                    onPressed: _loadNotifications,
                    icon: const Icon(Icons.refresh),
                    label: Text(context.l10n.retry),
                  ),
                ],
              ),
            );
          }

          if (state is ActiveAlertsLoaded) {
            final alerts = state.alerts;

            if (alerts.isEmpty) {
              return EmptyStateWidget(
                icon: Icons.notifications_none,
                message: context.l10n.noNotifications,
                subtitle: context.l10n.noNotificationsSubtitle,
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                _loadNotifications();
              },
              child: ListView.separated(
                padding: const EdgeInsets.all(AppDimensions.paddingMD),
                itemCount: alerts.length,
                separatorBuilder: (context, index) => 
                  const SizedBox(height: AppDimensions.spacingSM),
                itemBuilder: (context, index) {
                  final alert = alerts[index];
                  return _NotificationCard(
                    alert: alert,
                    onTap: () => _showAlertDetails(context, alert),
                    onDismiss: () => _dismissAlert(alert),
                  );
                },
              ),
            );
          }

          return EmptyStateWidget(
            icon: Icons.notifications_none,
            message: context.l10n.noNotifications,
            subtitle: context.l10n.noNotificationsSubtitle,
          );
        },
      ),
    );
  }

  void _showAlertDetails(BuildContext context, AlertEntity alert) {
    AppLogger.info('[NotificationsPage] عرض تفاصيل التنبيه: ${alert.id}');
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getAlertIcon(alert.type),
              color: _getSeverityColor(context, alert.severity),
            ),
            const SizedBox(width: AppDimensions.spacingSM),
            Expanded(
              child: Text(
                alert.title,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow(
                icon: Icons.message,
                label: l10n.messageLabel,
                value: alert.message,
              ),
              const SizedBox(height: AppDimensions.spacingSM),
              _DetailRow(
                icon: Icons.schedule,
                label: l10n.timeLabel,
                value: _formatDateTime(alert.triggeredAt),
              ),
              const SizedBox(height: AppDimensions.spacingSM),
              _DetailRow(
                icon: Icons.priority_high,
                label: l10n.severityLabel,
                value: AlertEntity.getSeverityDescription(alert.severity),
              ),
              const SizedBox(height: AppDimensions.spacingSM),
              _DetailRow(
                icon: Icons.info,
                label: l10n.statusLabel,
                value: AlertEntity.getStatusDescription(alert.status),
              ),
              if (alert.location != null) ...[
                const SizedBox(height: AppDimensions.spacingSM),
                _DetailRow(
                  icon: Icons.location_on,
                  label: l10n.locationLabel,
                  value: '${alert.location!.latitude.toStringAsFixed(6)}, ${alert.location!.longitude.toStringAsFixed(6)}',
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (alert.status == AlertStatus.pending)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _acknowledgeAlert(alert);
              },
              child: Text(l10n.alertAcknowledged),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  void _acknowledgeAlert(AlertEntity alert) {
    AppLogger.info('[NotificationsPage] الإقرار بالتنبيه: ${alert.id}');
    context.read<AlertBloc>().add(
      AcknowledgeAlertEvent(
        alertId: alert.id,
        userId: widget.userId,
      ),
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.alertAcknowledged)),
    );
  }

  void _dismissAlert(AlertEntity alert) {
    AppLogger.info('[NotificationsPage] إخفاء التنبيه: ${alert.id}');
    // يمكن إضافة منطق لإخفاء التنبيه هنا
  }

  IconData _getAlertIcon(AlertType type) {
    switch (type) {
      case AlertType.deviation:
        return Icons.warning;
      case AlertType.sos:
        return Icons.emergency;
      case AlertType.checkpoint:
        return Icons.location_on;
      case AlertType.speedLimit:
        return Icons.speed;
      case AlertType.lowBattery:
        return Icons.battery_alert;
      case AlertType.noMovement:
        return Icons.motion_photos_off;
      case AlertType.geofence:
        return Icons.fence;
      case AlertType.custom:
        return Icons.notifications;
    }
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
        return Theme.of(context).colorScheme.error;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays == 1) {
      return 'أمس ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// بطاقة الإشعار
class _NotificationCard extends StatelessWidget {
  final AlertEntity alert;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.alert,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = alert.status == AlertStatus.pending;
    
    return Card(
      elevation: isUnread ? 4 : 2,
      color: isUnread 
        ? Theme.of(context).colorScheme.surface 
        : Theme.of(context).scaffoldBackgroundColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // أيقونة التنبيه
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getSeverityColor(context, alert.severity).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                ),
                child: Icon(
                  _getAlertIcon(alert.type),
                  color: _getSeverityColor(context, alert.severity),
                  size: 24,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSM),
              
              // محتوى التنبيه
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacingXS),
                    Text(
                      alert.message,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDimensions.spacingXS),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 12,
                          color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(alert.triggeredAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spacingSM),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getSeverityColor(context, alert.severity).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                          ),
                          child: Text(
                            AlertEntity.getSeverityDescription(alert.severity),
                            style: TextStyle(
                              fontSize: 11,
                              color: _getSeverityColor(context, alert.severity),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getAlertIcon(AlertType type) {
    switch (type) {
      case AlertType.deviation:
        return Icons.warning;
      case AlertType.sos:
        return Icons.emergency;
      case AlertType.checkpoint:
        return Icons.location_on;
      case AlertType.speedLimit:
        return Icons.speed;
      case AlertType.lowBattery:
        return Icons.battery_alert;
      case AlertType.noMovement:
        return Icons.motion_photos_off;
      case AlertType.geofence:
        return Icons.fence;
      case AlertType.custom:
        return Icons.notifications;
    }
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
        return Theme.of(context).colorScheme.error;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} د';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} س';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}

/// صف تفاصيل التنبيه
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary,
        ),
        const SizedBox(width: AppDimensions.spacingSM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

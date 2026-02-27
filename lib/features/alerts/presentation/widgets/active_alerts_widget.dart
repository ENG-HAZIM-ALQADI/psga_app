import 'package:flutter/material.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/utils/extensions.dart';
import 'package:psga_app/features/alerts/presentation/bloc/alert/alert_bloc.dart';
import 'package:psga_app/features/alerts/presentation/bloc/alert/alert_event.dart';
import 'package:psga_app/features/alerts/presentation/bloc/alert/alert_state.dart';
import 'package:psga_app/features/alerts/presentation/widgets/alert_card_widget.dart';

/// ويدجت عرض التنبيهات النشطة
class ActiveAlertsWidget extends StatefulWidget {
  final String userId;
  final bool showEmptyState;

  const ActiveAlertsWidget({
    required this.userId,
    this.showEmptyState = true,
    super.key,
  });

  @override
  State<ActiveAlertsWidget> createState() => _ActiveAlertsWidgetState();
}

class _ActiveAlertsWidgetState extends State<ActiveAlertsWidget> {
  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  void _loadAlerts() {
    context.read<AlertBloc>().add(LoadActiveAlertsEvent(widget.userId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AlertBloc, AlertState>(
      listener: (context, state) {
        if (state is AlertAcknowledged || state is AlertResolved) {
          _loadAlerts(); // إعادة تحميل بعد الإقرار أو الحل
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state is AlertAcknowledged
                    ? context.l10n.alertAcknowledged
                    : context.l10n.alertCancelled,
              ),
              backgroundColor: AppColors.green,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is AlertLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (state is ActiveAlertsLoaded) {
          final alerts = state.alerts;

          if (alerts.isEmpty) {
            if (!widget.showEmptyState) {
              return const SizedBox.shrink();
            }

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: AppColors.green.withOpacity(0.6),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.noActiveAlerts,
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.allAlertsProcessed,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _loadAlerts(),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return AlertCardWidget(
                  alert: alert,
                  onAcknowledge: () {
                    context.read<AlertBloc>().add(
                          AcknowledgeAlertEvent(
                            alertId: alert.id,
                            userId: widget.userId,
                          ),
                        );
                  },
                  onResolve: () {
                    _showResolveDialog(alert.id);
                  },
                  onTap: () {
                    _showAlertDetails(alert);
                  },
                );
              },
            ),
          );
        }

        if (state is AlertError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.red.withOpacity(0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'حدث خطأ',
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadAlerts,
                    icon: const Icon(Icons.refresh),
                    label: Text(context.l10n.retry),
                  ),
                ],
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  void _showResolveDialog(String alertId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.resolveAlert),
        content: Text(context.l10n.areYouSure),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<AlertBloc>().add(
                    ResolveAlertEvent(alertId),
                  );
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
            ),
            child: Text(context.l10n.resolveAlertConfirm),
          ),
        ],
      ),
    );
  }

  void _showAlertDetails(alert) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'تفاصيل التنبيه',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildDetailRow('العنوان', alert.title),
                _buildDetailRow('الرسالة', alert.message),
                _buildDetailRow('النوع', alert.type.toString()),
                _buildDetailRow('الشدة', alert.severity.toString()),
                _buildDetailRow('الحالة', alert.status.toString()),
                if (alert.location != null)
                  _buildDetailRow(
                    'الموقع',
                    '${alert.location!.latitude.toStringAsFixed(6)}, ${alert.location!.longitude.toStringAsFixed(6)}',
                  ),
                if (alert.metadata != null && alert.metadata!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'معلومات إضافية:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...alert.metadata!.entries.map(
                    (entry) => _buildDetailRow(entry.key, entry.value.toString()),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/alert_entity.dart';
import '../bloc/alert_bloc.dart';
import '../bloc/alert_event.dart';
import '../bloc/alert_state.dart';
import '../widgets/alert_level_indicator.dart';

class AlertHistoryPage extends StatefulWidget {
  const AlertHistoryPage({super.key});

  @override
  State<AlertHistoryPage> createState() => _AlertHistoryPageState();
}

class _AlertHistoryPageState extends State<AlertHistoryPage> {
  AlertType? _typeFilter;
  AlertStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  void _loadAlerts() {
    context.read<AlertBloc>().add(LoadAlertHistoryEvent(
      typeFilter: _typeFilter,
      statusFilter: _statusFilter,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل التنبيهات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: BlocBuilder<AlertBloc, AlertState>(
        builder: (context, state) {
          if (state is AlertLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is AlertError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadAlerts,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          if (state is AlertHistoryLoaded) {
            if (state.alerts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد تنبيهات سابقة',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => _loadAlerts(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.alerts.length,
                itemBuilder: (context, index) {
                  final alert = state.alerts[index];
                  return _buildAlertCard(alert);
                },
              ),
            );
          }

          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildAlertCard(AlertEntity alert) {
    final dateFormat = DateFormat('dd/MM/yyyy', 'ar');
    final timeFormat = DateFormat('HH:mm', 'ar');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showAlertDetails(alert),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AlertTypeIndicator(type: alert.type),
                  const SizedBox(width: 8),
                  AlertLevelIndicator(level: alert.level, showLabel: false),
                  const Spacer(),
                  _buildStatusBadge(alert.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                alert.message,
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(alert.triggeredAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    timeFormat.format(alert.triggeredAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (alert.sentToContacts.isNotEmpty) ...[
                    const Spacer(),
                    Icon(Icons.people, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '${alert.sentToContacts.length}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(AlertStatus status) {
    Color color;
    String label;

    switch (status) {
      case AlertStatus.pending:
        color = Colors.grey;
        label = 'انتظار';
        break;
      case AlertStatus.active:
        color = Colors.orange;
        label = 'نشط';
        break;
      case AlertStatus.acknowledged:
        color = Colors.green;
        label = 'تم الإقرار';
        break;
      case AlertStatus.escalated:
        color = Colors.red;
        label = 'تم التصعيد';
        break;
      case AlertStatus.resolved:
        color = Colors.blue;
        label = 'تم الحل';
        break;
      case AlertStatus.expired:
        color = Colors.grey;
        label = 'منتهي';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تصفية التنبيهات',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  const Text('نوع التنبيه:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('الكل'),
                        selected: _typeFilter == null,
                        onSelected: (_) {
                          setModalState(() => _typeFilter = null);
                        },
                      ),
                      ...AlertType.values.map((type) => FilterChip(
                        label: Text(_getTypeLabel(type)),
                        selected: _typeFilter == type,
                        onSelected: (_) {
                          setModalState(() => _typeFilter = type);
                        },
                      )),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {});
                        _loadAlerts();
                      },
                      child: const Text('تطبيق'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getTypeLabel(AlertType type) {
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

  void _showAlertDetails(AlertEntity alert) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    alert.typeDisplayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      AlertLevelIndicator(level: alert.level),
                      const SizedBox(width: 12),
                      _buildStatusBadge(alert.status),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDetailRow('الرسالة', alert.message),
                  _buildDetailRow(
                    'التاريخ والوقت',
                    DateFormat('dd/MM/yyyy HH:mm').format(alert.triggeredAt),
                  ),
                  if (alert.acknowledgedAt != null)
                    _buildDetailRow(
                      'تم الإقرار',
                      DateFormat('dd/MM/yyyy HH:mm').format(alert.acknowledgedAt!),
                    ),
                  if (alert.escalatedAt != null)
                    _buildDetailRow(
                      'تم التصعيد',
                      DateFormat('dd/MM/yyyy HH:mm').format(alert.escalatedAt!),
                    ),
                  _buildDetailRow(
                    'الموقع',
                    '${alert.location.latitude.toStringAsFixed(4)}, ${alert.location.longitude.toStringAsFixed(4)}',
                  ),
                  if (alert.sentToContacts.isNotEmpty)
                    _buildDetailRow(
                      'جهات الاتصال المُبلغة',
                      '${alert.sentToContacts.length} جهة',
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}

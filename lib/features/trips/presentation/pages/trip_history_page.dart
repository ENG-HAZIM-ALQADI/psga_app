// ============================================================================
// 📄 ملف: trip_history_page.dart
// 🏗️ الطبقة: Presentation (سجل الرحلات)
// 🎯 الوظيفة: صفحة تعرض سجل كامل الرحلات السابقة مع خيارات البحث والتصفية حسب التاريخ
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/routes.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../domain/entities/trip_entity.dart';
import '../bloc/trip_bloc.dart';
import '../bloc/trip_event.dart';
import '../bloc/trip_state.dart';
import '../widgets/trip_status_widget.dart';

/// 📌 صفحة سجل الرحلات
/// 💡 StatefulWidget للاحتفاظ بحالة التصفية (fromDate و toDate) محلياً
class TripHistoryPage extends StatefulWidget {
  final String userId;

  const TripHistoryPage({super.key, required this.userId});

  @override
  State<TripHistoryPage> createState() => _TripHistoryPageState();
}

class _TripHistoryPageState extends State<TripHistoryPage> {
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    context.read<TripBloc>().add(LoadTripHistory(
          userId: widget.userId,
          from: _fromDate,
          to: _toDate,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الرحلات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
        ],
      ),
      body: BlocBuilder<TripBloc, TripState>(
        builder: (context, state) {
          if (state is TripLoading) {
            return const LoadingWidget();
          }

          if (state is TripHistoryLoaded) {
            if (state.trips.isEmpty) {
              return _buildEmptyState(theme);
            }

            return RefreshIndicator(
              onRefresh: () async => _loadHistory(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: state.trips.length,
                itemBuilder: (context, index) {
                  final trip = state.trips[index];
                  return _buildTripCard(context, trip);
                },
              ),
            );
          }

          if (state is TripError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadHistory,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          return _buildEmptyState(theme);
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد رحلات سابقة',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر رحلاتك هنا بعد إكمالها',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, TripEntity trip) {
    final theme = Theme.of(context);
    final duration = trip.duration;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          AppLogger.info('[TripHistory] الانتقال لتفاصيل الرحلة: ${trip.id}', name: 'TripHistory');
          context.push(AppRoutes.tripDetails.replaceFirst(':id', trip.id), extra: trip);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      trip.routeName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TripStatusWidget(status: trip.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 8),
                  Text(_formatDateTime(trip.startTime)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStatChip(
                    icon: Icons.timer,
                    value: duration != null ? _formatDuration(duration) : '-',
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    icon: Icons.straighten,
                    value: '${trip.totalDistance.toStringAsFixed(1)} كم',
                  ),
                  if (trip.alertsTriggered > 0) ...[
                    const SizedBox(width: 8),
                    _buildStatChip(
                      icon: Icons.warning,
                      value: '${trip.alertsTriggered}',
                      color: Colors.orange,
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

  Widget _buildStatChip({
    required IconData icon,
    required String value,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'فلتر الرحلات',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text('من تاريخ'),
                subtitle: Text(_fromDate != null 
                    ? _formatDate(_fromDate!) 
                    : 'اختر تاريخ'),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _fromDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _fromDate = date);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text('إلى تاريخ'),
                subtitle: Text(_toDate != null 
                    ? _formatDate(_toDate!) 
                    : 'اختر تاريخ'),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _toDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _toDate = date);
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _fromDate = null;
                          _toDate = null;
                        });
                        Navigator.pop(context);
                        _loadHistory();
                      },
                      child: const Text('مسح الفلتر'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _loadHistory();
                      },
                      child: const Text('تطبيق'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} - ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}س ${duration.inMinutes % 60}د';
    }
    return '${duration.inMinutes} دقيقة';
  }
}

// ============================================================================
// 📄 ملف: trip_details_page.dart
// 🏗️ الطبقة: Presentation (تفاصيل الرحلة المنتهية)
// 🎯 الوظيفة: صفحة تعرض معلومات شاملة عن رحلة منتهية مع إحصائيات وانحرافات
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/routes.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../domain/entities/trip_entity.dart';
import '../bloc/trip_bloc.dart';
import '../bloc/trip_event.dart';
import '../bloc/trip_state.dart';
import '../widgets/trip_status_widget.dart';

/// 📌 صفحة تفاصيل الرحلة (StatelessWidget)
/// 💡 لا نحتاج StatefulWidget هنا - الحالة تُدار بواسطة BLoC
class TripDetailsPage extends StatelessWidget {
  final TripEntity trip;

  const TripDetailsPage({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<TripBloc, TripState>(
      listener: (context, state) {
        if (state is TripActive) {
          AppLogger.info('[TripDetails] تم بدء الرحلة المكررة بنجاح', name: 'TripDetails');
          context.push(AppRoutes.tripActive, extra: state.trip);
        } else if (state is TripError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل الرحلة'),
        ),
        body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 200,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 64,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'مسار الرحلة الفعلي',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
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
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TripStatusWidget(status: trip.status),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildStatsCard(theme),
                  const SizedBox(height: 16),
                  _buildTimeCard(theme),
                  if (trip.deviations.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildDeviationsCard(theme),
                  ],
                  if (trip.notes != null) ...[
                    const SizedBox(height: 16),
                    _buildNotesCard(theme),
                  ],
                  const SizedBox(height: 32),
                  CustomButton(
                    text: 'تكرار هذه الرحلة',
                    icon: Icons.replay,
                    onPressed: () => _repeatTrip(context),
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

  void _repeatTrip(BuildContext context) {
    AppLogger.info('[TripDetails] بدء تكرار الرحلة على المسار: ${trip.routeName}', name: 'TripDetails');
    
    final startLocation = trip.currentLocation ?? trip.startLocation;
    
    context.read<TripBloc>().add(StartTrip(
      routeId: trip.routeId,
      userId: trip.userId,
      startLocation: startLocation,
    ));
  }

  Widget _buildStatsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'إحصائيات الرحلة',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.straighten,
                    label: 'المسافة',
                    value: '${trip.totalDistance.toStringAsFixed(1)} كم',
                    theme: theme,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.speed,
                    label: 'متوسط السرعة',
                    value: '${trip.averageSpeed.toStringAsFixed(0)} كم/س',
                    theme: theme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.timer,
                    label: 'المدة',
                    value: trip.duration != null 
                        ? _formatDuration(trip.duration!) 
                        : '-',
                    theme: theme,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.warning_amber,
                    label: 'التنبيهات',
                    value: '${trip.alertsTriggered}',
                    theme: theme,
                    color: trip.alertsTriggered > 0 ? Colors.orange : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
    Color? color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color ?? theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'أوقات الرحلة',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildTimeRow(
              icon: Icons.play_arrow,
              iconColor: Colors.green,
              label: 'وقت البدء',
              value: _formatDateTime(trip.startTime),
            ),
            if (trip.endTime != null)
              _buildTimeRow(
                icon: Icons.stop,
                iconColor: Colors.red,
                label: 'وقت الانتهاء',
                value: _formatDateTime(trip.endTime!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Text(label),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDeviationsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'الانحرافات (${trip.deviations.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...trip.deviations.map((deviation) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: _getSeverityColor(deviation.severity).withOpacity(0.2),
                    child: Icon(
                      Icons.location_off,
                      color: _getSeverityColor(deviation.severity),
                    ),
                  ),
                  title: Text('انحراف ${deviation.distanceFromRoute.toStringAsFixed(0)} متر'),
                  subtitle: Text(_formatDateTime(deviation.detectedAt)),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.note),
                const SizedBox(width: 8),
                Text(
                  'ملاحظات',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(trip.notes!),
          ],
        ),
      ),
    );
  }

  Color _getSeverityColor(dynamic severity) {
    switch (severity.toString()) {
      case 'DeviationSeverity.low':
        return Colors.yellow.shade700;
      case 'DeviationSeverity.medium':
        return Colors.orange;
      case 'DeviationSeverity.high':
        return Colors.deepOrange;
      case 'DeviationSeverity.critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} - ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours} ساعة ${duration.inMinutes % 60} دقيقة';
    }
    return '${duration.inMinutes} دقيقة';
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';
import 'package:psga_app/features/trips/presentation/bloc/trip_bloc.dart';
import 'package:psga_app/features/trips/presentation/bloc/trip_state.dart';

/// عرض إحصائيات الرحلة
class TripStatsWidget extends StatelessWidget {
  final TripEntity trip;

  const TripStatsWidget({
    required this.trip,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TripBloc, TripState>(
      builder: (context, state) {
        // استخدام البيانات من TripStatsUpdated إذا كانت متاحة
        double currentSpeed = trip.currentSpeed ?? 0.0;
        double distanceTraveled = trip.distanceTraveled;
        Duration elapsed = trip.actualDuration;
        double remainingDistance = trip.route.estimatedDistance != null 
            ? (trip.route.estimatedDistance! / 1000 - trip.distanceTraveled)
            : 0.0;
        Duration? estimatedTime;

        if (state is TripStatsUpdated && state.trip.id == trip.id) {
          currentSpeed = state.currentSpeed;
          distanceTraveled = state.distanceTraveled;
          elapsed = state.elapsed;
          remainingDistance = state.remainingDistance;
          estimatedTime = state.estimatedTime;
        }

        final estimatedRemainingTime = estimatedTime != null
            ? estimatedTime.inMinutes
            : (currentSpeed > 0 
                ? (remainingDistance / currentSpeed * 60).round() 
                : 0);
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.statsLiveTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // القسم الأول: المعلومات الحية (بلون مميز)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.speed, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.statsLiveInfoTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLiveInfo(
                          context: context,
                          icon: Icons.speed_outlined,
                          label: AppLocalizations.of(context)!.statsCurrentSpeed,
                          value: '${currentSpeed.toStringAsFixed(1)} ${AppLocalizations.of(context)!.speedUnit}',
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildLiveInfo(
                          context: context,
                          icon: Icons.access_time,
                          label: AppLocalizations.of(context)!.statsElapsedTime,
                          value: _formatDuration(context, elapsed),
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLiveInfo(
                          context: context,
                          icon: Icons.straighten,
                          label: AppLocalizations.of(context)!.statsRemainingDistance,
                          value: remainingDistance > 0 
                              ? '${remainingDistance.toStringAsFixed(2)} ${AppLocalizations.of(context)!.distanceKmUnit}'
                              : AppLocalizations.of(context)!.statsArrived,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildLiveInfo(
                          context: context,
                          icon: Icons.timer_outlined,
                          label: AppLocalizations.of(context)!.statsRemainingTime,
                          value: estimatedRemainingTime > 0 
                              ? '$estimatedRemainingTime ${AppLocalizations.of(context)!.durationMinutes}'
                              : '--',
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),

            // الصف الأول: الإحصائيات العامة
            Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    context: context,
                    icon: Icons.straighten,
                    label: AppLocalizations.of(context)!.statsDistanceCovered,
                    value: '${distanceTraveled.toStringAsFixed(2)} ${AppLocalizations.of(context)!.distanceKmUnit}',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    context: context,
                    icon: Icons.speed,
                    label: AppLocalizations.of(context)!.statsAvgSpeed,
                    value: trip.averageSpeed != null
                        ? '${trip.averageSpeed!.toStringAsFixed(1)} ${AppLocalizations.of(context)!.speedUnit}'
                        : '-- ${AppLocalizations.of(context)!.speedUnit}',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // الصف الثاني
            Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    context: context,
                    icon: Icons.trending_up,
                    label: AppLocalizations.of(context)!.statsMaxSpeed,
                    value: trip.maxSpeed != null
                        ? '${trip.maxSpeed!.toStringAsFixed(1)} ${AppLocalizations.of(context)!.speedUnit}'
                        : '-- ${AppLocalizations.of(context)!.speedUnit}',
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    context: context,
                    icon: Icons.location_on,
                    label: AppLocalizations.of(context)!.statsTrackPoints,
                    value: '${trip.locationHistory.length}',
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // الصف الثالث
            Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    context: context,
                    icon: Icons.flag,
                    label: AppLocalizations.of(context)!.statsVisitedWaypoints,
                    value: '${trip.visitedWaypointIds.length}/${trip.route.waypoints.length}',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    context: context,
                    icon: Icons.location_off,
                    label: AppLocalizations.of(context)!.statsMissedWaypoints,
                    value: '${trip.missedWaypointIds.length}',
                    color: Colors.red,
                  ),
                ),
              ],
            ),

            // الانحرافات إذا وجدت
            if (trip.totalDeviations > 0) ...[
              const SizedBox(height: 12),
              _buildStatBox(
                context: context,
                icon: Icons.warning,
                label: AppLocalizations.of(context)!.statsTotalDeviations,
                value: '${trip.totalDeviations}',
                color: Colors.red,
                isFullWidth: true,
              ),
            ],

            // نسبة إكمال نقاط التفتيش
            if (trip.route.waypoints.any((w) => w.isCheckpoint)) ...[
              const SizedBox(height: 12),
              _buildProgressStat(
                context: context,
                label: AppLocalizations.of(context)!.statsCheckpoints,
                progress: trip.checkpointCompletion,
                icon: Icons.verified_user,
              ),
            ],
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildLiveInfo({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isFullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isFullWidth ? 20 : 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStat({
    required BuildContext context,
    required String label,
    required double progress,
    required IconData icon,
  }) {
    final percentage = (progress * 100).toInt();
    final color = progress >= 1.0 ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const Spacer(),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(BuildContext context, Duration duration) {
    final l10n = AppLocalizations.of(context)!;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return l10n.durationHoursMinutes(hours.toString(), minutes.toString());
    } else {
      return l10n.durationMinutesOnly(minutes.toString());
    }
  }
}

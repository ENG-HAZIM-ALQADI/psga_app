import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/core/utils/extensions.dart';
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';

/// بطاقة معلومات الرحلة
class TripInfoCard extends StatelessWidget {
  final TripEntity trip;

  const TripInfoCard({
    required this.trip,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // اسم المسار
            Row(
              children: [
                Icon(Icons.route, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.route.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // معلومات الوقت
            _buildInfoRow(
              context,
              icon: Icons.access_time,
              label: AppLocalizations.of(context)!.tripStartTime,
              value: trip.startTime.formatTime(),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              icon: Icons.timer,
              label: AppLocalizations.of(context)!.tripDuration,
              value: _formatDuration(context, trip.actualDuration),
            ),
            const SizedBox(height: 8),

            // معلومات المسافة
            _buildInfoRow(
              context,
              icon: Icons.straighten,
              label: AppLocalizations.of(context)!.tripDistanceCovered,
              value: '${trip.distanceTraveled.toStringAsFixed(2)} ${AppLocalizations.of(context)!.distanceKmUnit}',
            ),
            const SizedBox(height: 8),

            // السرعة
            if (trip.averageSpeed != null)
              _buildInfoRow(
                context,
                icon: Icons.speed,
                label: AppLocalizations.of(context)!.tripAvgSpeed,
                value: '${trip.averageSpeed!.toStringAsFixed(1)} ${AppLocalizations.of(context)!.speedUnit}',
              ),
            if (trip.maxSpeed != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                context,
                icon: Icons.trending_up,
                label: AppLocalizations.of(context)!.tripMaxSpeed,
                value: '${trip.maxSpeed!.toStringAsFixed(1)} ${AppLocalizations.of(context)!.speedUnit}',
              ),
            ],

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // معلومات النقاط
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(
                  context,
                  icon: Icons.flag,
                  label: AppLocalizations.of(context)!.tripVisitedPoints,
                  value: '${trip.visitedWaypointIds.length}',
                  color: AppColors.green,
                ),
                _buildStatColumn(
                  context,
                  icon: Icons.location_on,
                  label: AppLocalizations.of(context)!.tripRemainingPoints,
                  value: '${trip.remainingWaypoints}',
                  color: AppColors.gold,
                ),
                if (trip.totalDeviations > 0)
                  _buildStatColumn(
                    context,
                    icon: Icons.warning,
                    label: AppLocalizations.of(context)!.tripDeviations,
                    value: '${trip.totalDeviations}',
                    color: AppColors.red,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).textTheme.bodyMedium?.color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildStatColumn(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ],
    );
  }

  String _formatDuration(BuildContext context, Duration duration) {
    final l10n = AppLocalizations.of(context)!;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return l10n.durationHoursMinutes(hours.toString(), minutes.toString());
    } else if (minutes > 0) {
      return l10n.durationMinutesSeconds(minutes.toString(), seconds.toString());
    } else {
      return l10n.durationSecondsOnly(seconds.toString());
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';

/// عرض تقدم نقاط الطريق
class WaypointProgressWidget extends StatelessWidget {
  final TripEntity trip;

  const WaypointProgressWidget({
    required this.trip,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final waypoints = trip.route.waypoints;
    if (waypoints.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.waypointProgressTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '${trip.visitedWaypointIds.length} / ${waypoints.length}',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // شريط التقدم
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: trip.progress,
                minHeight: 8,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getProgressColor(trip.progress),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // النسبة المئوية
            Text(
              AppLocalizations.of(context)!.waypointCompleted((trip.progress * 100).toStringAsFixed(0)),
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),

            // قائمة النقاط
            ...waypoints.asMap().entries.map((entry) {
              final index = entry.key;
              final waypoint = entry.value;
              final isVisited = trip.visitedWaypointIds.contains(waypoint.id);
              final isCurrent = index == trip.currentWaypointIndex;
              final isMissed = trip.missedWaypointIds.contains(waypoint.id);

              return _buildWaypointItem(
                context: context,
                waypoint: waypoint,
                index: index,
                isVisited: isVisited,
                isCurrent: isCurrent,
                isMissed: isMissed,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildWaypointItem({
    required BuildContext context,
    required waypoint,
    required int index,
    required bool isVisited,
    required bool isCurrent,
    required bool isMissed,
  }) {
    Color iconColor;
    IconData iconData;

    if (isMissed) {
      iconColor = Colors.red;
      iconData = Icons.cancel;
    } else if (isVisited) {
      iconColor = Colors.green;
      iconData = Icons.check_circle;
    } else if (isCurrent) {
      iconColor = Colors.blue;
      iconData = Icons.location_on;
    } else {
      iconColor = Colors.grey;
      iconData = Icons.location_on_outlined;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // الأيقونة
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),

          // المعلومات
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${index + 1}. ${waypoint.name}',
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        decoration: isMissed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (waypoint.isCheckpoint) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.waypointCheckpointLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (waypoint.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    waypoint.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // الحالة
          if (isCurrent)
            Text(
              AppLocalizations.of(context)!.waypointCurrentLabel,
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            )
          else if (isMissed)
            Text(
              AppLocalizations.of(context)!.waypointMissedLabel,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            )
          else if (isVisited)
            const Icon(Icons.check, color: Colors.green, size: 18),
        ],
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress < 0.33) return Colors.red;
    if (progress < 0.66) return Colors.orange;
    return Colors.green;
  }
}

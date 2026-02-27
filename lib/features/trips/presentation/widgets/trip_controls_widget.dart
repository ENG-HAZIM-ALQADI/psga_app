import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';
import 'package:psga_app/features/trips/presentation/bloc/bloc.dart';

/// أزرار التحكم في الرحلة
class TripControlsWidget extends StatelessWidget {
  final TripEntity trip;

  const TripControlsWidget({
    required this.trip,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // الأزرار الرئيسية
            Row(
              children: [
                // زر الإيقاف/الاستئناف
                Expanded(
                  child: trip.isActive
                      ? ElevatedButton.icon(
                          onPressed: () => _onPause(context),
                          icon: const Icon(Icons.pause),
                          label: Text(AppLocalizations.of(context)!.pauseTrip),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: () => _onResume(context),
                          icon: const Icon(Icons.play_arrow),
                          label: Text(AppLocalizations.of(context)!.resumeTrip),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.green,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                ),
                const SizedBox(width: 12),

                // زر الإنهاء
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _onEnd(context),
                    icon: const Icon(Icons.stop),
                    label: Text(AppLocalizations.of(context)!.endTrip),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // زر SOS الطوارئ (بارز ومميز)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _onSOS(context),
                icon: const Icon(Icons.sos, size: 28),
                label: const Text(
                  '🆘 طوارئ - SOS',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 8,
                  shadowColor: AppColors.red,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // زر إلغاء الرحلة (زر منفصل بلون مميز)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _onCancel(context),
                icon: const Icon(Icons.cancel, size: 18),
                label: Text(AppLocalizations.of(context)!.cancelTrip),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).textTheme.bodyMedium?.color,
                  side: BorderSide(color: Theme.of(context).dividerColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // معلومات سريعة
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickStat(
                  context,
                  icon: Icons.straighten,
                  label: '${trip.distanceTraveled.toStringAsFixed(1)} كم',
                ),
                _buildQuickStat(
                  context,
                  icon: Icons.timer,
                  label: _formatDuration(trip.actualDuration),
                ),
                _buildQuickStat(
                  context,
                  icon: Icons.flag,
                  label: '${trip.visitedWaypointIds.length}/${trip.route.waypoints.length}',
                ),
                // ✅ إضافة ETA
                if (trip.calculateETA() != null)
                  _buildQuickStat(
                    context,
                    icon: Icons.schedule,
                    label: _formatDuration(trip.calculateETA()!),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                if (trip.totalDeviations > 0)
                  _buildQuickStat(
                    context,
                    icon: Icons.warning,
                    label: '${trip.totalDeviations}',
                    color: Theme.of(context).colorScheme.error,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? Theme.of(context).textTheme.bodyMedium?.color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color ?? Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _onPause(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.pauseTripTitle),
        content: Text(AppLocalizations.of(context)!.pauseTripContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<TripBloc>().add(PauseTripEvent(tripId: trip.id));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
            ),
            child: Text(AppLocalizations.of(context)!.pauseTrip),
          ),
        ],
      ),
    );
  }

  void _onResume(BuildContext context) {
    context.read<TripBloc>().add(ResumeTripEvent(tripId: trip.id));
  }

  void _onEnd(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.endTrip),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.endTripContent),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.tripDetails,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.tripSummaryDistance(trip.distanceTraveled.toStringAsFixed(2))),
            Text(AppLocalizations.of(context)!.tripSummaryDuration(_formatDuration(trip.actualDuration))),
            Text(AppLocalizations.of(context)!.tripSummaryWaypoints(trip.visitedWaypointIds.length.toString(), trip.route.waypoints.length.toString())),
            if (trip.totalDeviations > 0)
              Text(
                '• الانحرافات: ${trip.totalDeviations}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<TripBloc>().add(EndTripEvent(tripId: trip.id));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppLocalizations.of(context)!.endTrip),
          ),
        ],
      ),
    );
  }

  void _onCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.cancelTripTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.cancelTripContent),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سيتم حذف جميع بيانات الرحلة ولن يتم حفظها',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.back),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<TripBloc>().add(CancelTripEvent(tripId: trip.id));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[700],
            ),
            child: Text(AppLocalizations.of(context)!.cancelTrip),
          ),
        ],
      ),
    );
  }

  void _onSOS(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.red[50],
        title: Row(
          children: [
            Icon(Icons.sos, color: Colors.red[900], size: 32),
            const SizedBox(width: 12),
            const Text(
              '🆘 تأكيد الطوارئ',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'هل أنت متأكد من تفعيل طوارئ SOS؟',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.sendingAlert,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('• ${AppLocalizations.of(context)!.sosContactsList}'),
                  Text('• ${AppLocalizations.of(context)!.sosCurrentLocation}'),
                  Text('• ${AppLocalizations.of(context)!.sosTripInfo}'),
                  const SizedBox(height: 8),
                  Text(
                    '⚠️ استخدم هذا الزر فقط في حالات الطوارئ الفعلية',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red[900],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // تفعيل SOS
              context.read<TripBloc>().add(
                    TriggerSOSEvent(
                      tripId: trip.id,
                      currentLocation: trip.currentLocation ?? trip.route.waypoints.first.location,
                    ),
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[900],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              '🆘 تأكيد SOS',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}

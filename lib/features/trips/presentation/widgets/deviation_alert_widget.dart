import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/core/utils/extensions.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';
import 'package:psga_app/features/alerts/presentation/bloc/alert/alert_bloc.dart';
import 'package:psga_app/features/alerts/presentation/bloc/alert/alert_event.dart';
import 'package:psga_app/features/alerts/presentation/bloc/alert/alert_state.dart';
import 'package:psga_app/features/alerts/presentation/widgets/alert_dialog_widget.dart';
import 'package:psga_app/features/trips/domain/entities/deviation.dart';

/// عرض تنبيهات الانحرافات مع التكامل مع AlertBloc
class DeviationAlertWidget extends StatefulWidget {
  final List<Deviation> deviations;
  final String userId;
  final String? tripId;

  const DeviationAlertWidget({
    required this.deviations,
    required this.userId,
    this.tripId,
    super.key,
  });

  @override
  State<DeviationAlertWidget> createState() => _DeviationAlertWidgetState();
}

class _DeviationAlertWidgetState extends State<DeviationAlertWidget> {
  bool _hasTriggeredAlert = false;

  @override
  void didUpdateWidget(DeviationAlertWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // فحص الانحرافات الجديدة
    final activeDeviations = widget.deviations.where((d) => d.isActive).toList();
    
    if (activeDeviations.isNotEmpty && !_hasTriggeredAlert) {
      // إطلاق تنبيه للانحراف الأول
      final deviation = activeDeviations.first;
      
      // فقط إذا كان الانحراف جديد (لم يُرسل من قبل)
      if (deviation.severity == DeviationSeverity.high ||
          deviation.severity == DeviationSeverity.critical) {
        _triggerDeviationAlert(deviation);
        _hasTriggeredAlert = true;
      }
    } else if (activeDeviations.isEmpty) {
      _hasTriggeredAlert = false;
    }
  }

  void _triggerDeviationAlert(Deviation deviation) {
    AppLogger.info('[DeviationAlertWidget] إطلاق تنبيه انحراف: ${deviation.distanceFromRoute}m');

    // إطلاق تنبيه
    context.read<AlertBloc>().add(TriggerAlertEvent(
      userId: widget.userId,
      type: AlertType.deviation,
      title: 'انحراف عن المسار',
      message: 'أنت على بعد ${deviation.distanceFromRoute.toStringAsFixed(0)} متر من المسار المحدد',
      severity: _convertDeviationSeverity(deviation.severity),
      tripId: widget.tripId,
      location: deviation.deviationLocation,
      metadata: {
        'deviationType': deviation.type.toString(),
        'distance': deviation.distanceFromRoute,
        'duration': deviation.currentDuration.inSeconds,
      },
    ));
  }

  AlertSeverity _convertDeviationSeverity(DeviationSeverity severity) {
    switch (severity) {
      case DeviationSeverity.none:
      case DeviationSeverity.low:
        return AlertSeverity.low;
      case DeviationSeverity.medium:
        return AlertSeverity.medium;
      case DeviationSeverity.high:
        return AlertSeverity.high;
      case DeviationSeverity.critical:
        return AlertSeverity.critical;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AlertBloc, AlertState>(
      listener: (context, state) {
        if (state is AlertTriggered && state.alert.type == AlertType.deviation) {
          AppLogger.info('[DeviationAlertWidget] تنبيه تم إطلاقه - بدء التصعيد');
          
          // بدء التصعيد التلقائي
          context.read<AlertBloc>().add(StartEscalationEvent(
            alert: state.alert,
            userId: widget.userId,
          ));
        } else if (state is EscalationInProgress) {
          // عرض countdown dialog
          _showCountdownDialog(state);
        } else if (state is EscalationCancelled) {
          AppLogger.success('[DeviationAlertWidget] تم إلغاء التصعيد');
          Navigator.of(context, rootNavigator: true).pop();
        } else if (state is EscalationCompleted) {
          AppLogger.success('[DeviationAlertWidget] اكتمل التصعيد');
          Navigator.of(context, rootNavigator: true).pop();
          _showCompletionMessage();
        }
      },
      child: _buildDeviationCard(),
    );
  }

  void _showCountdownDialog(EscalationInProgress state) {
    // تحقق إذا كان Dialog مفتوح بالفعل
    if (ModalRoute.of(context)?.isCurrent != true) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialogWidget(
          alert: state.alert,
          countdownSeconds: state.totalSeconds,
          onImOkPressed: () {
            AppLogger.info('[DeviationAlertWidget] المستخدم ضغط "أنا بخير"');
            
            // إلغاء التصعيد
            context.read<AlertBloc>().add(CancelEscalationEvent(
              alertId: state.alert.id,
              userId: widget.userId,
            ));
          },
          onTimeout: () {
            AppLogger.info('[DeviationAlertWidget] انتهى الوقت - سيتم التصعيد');
            // التصعيد يحدث تلقائياً
          },
        ),
      ),
    );
  }

  void _showCompletionMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.allContactsNotified),
        backgroundColor: AppColors.gold,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildDeviationCard() {
    final activeDeviations = widget.deviations.where((d) => d.isActive).toList();

    if (activeDeviations.isEmpty && widget.deviations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.error.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان
            Row(
              children: [
                Icon(
                  Icons.warning,
                  color: Theme.of(context).colorScheme.error,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'الانحرافات',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.deviations.length}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onError,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            // الانحرافات النشطة
            if (activeDeviations.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error,
                      color: Theme.of(context).colorScheme.onError,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'انتباه! يوجد ${activeDeviations.length} انحراف نشط',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onError,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // قائمة الانحرافات
            ...widget.deviations.take(5).map((deviation) {
              return _buildDeviationItem(context, deviation);
            }),

            // عرض المزيد
            if (widget.deviations.length > 5) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => _showAllDeviations(context),
                  child: Text(
                    'عرض جميع الانحرافات (${widget.deviations.length})',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviationItem(BuildContext context, Deviation deviation) {
    final color = _getSeverityColor(deviation.severity);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الأيقونة
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getTypeIcon(deviation.type),
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // المعلومات
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        Deviation.getTypeDescription(deviation.type),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getSeverityLabel(deviation.severity),
                        style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'المسافة: ${deviation.distanceFromRoute.toStringAsFixed(0)} متر',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                if (!deviation.isResolved) ...[
                  const SizedBox(height: 4),
                  Text(
                    'المدة: ${_formatDuration(deviation.currentDuration)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // الحالة
          if (deviation.isResolved)
            const Icon(
              Icons.check_circle,
              color: AppColors.green,
              size: 18,
            )
          else
            Icon(
              Icons.emergency,
              color: color,
              size: 18,
            ),
        ],
      ),
    );
  }

  Color _getSeverityColor(DeviationSeverity severity) {
    switch (severity) {
      case DeviationSeverity.none:
        return AppColors.green;
      case DeviationSeverity.low:
        return AppColors.gold;
      case DeviationSeverity.medium:
        return AppColors.gold;
      case DeviationSeverity.high:
        return AppColors.red;
      case DeviationSeverity.critical:
        return AppColors.red;
    }
  }

  String _getSeverityLabel(DeviationSeverity severity) {
    switch (severity) {
      case DeviationSeverity.none:
        return 'لا يوجد';
      case DeviationSeverity.low:
        return 'منخفض';
      case DeviationSeverity.medium:
        return 'متوسط';
      case DeviationSeverity.high:
        return 'عالي';
      case DeviationSeverity.critical:
        return 'حرج';
    }
  }

  IconData _getTypeIcon(DeviationType type) {
    switch (type) {
      case DeviationType.minorDeviation:
        return Icons.warning_amber;
      case DeviationType.majorDeviation:
        return Icons.error;
      case DeviationType.wrongDirection:
        return Icons.wrong_location;
      case DeviationType.missedWaypoint:
        return Icons.location_off;
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);

    if (minutes > 0) {
      return '$minutes د $seconds ث';
    } else {
      return '$seconds ث';
    }
  }

  void _showAllDeviations(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // المقبض
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // العنوان
              Text(
                'جميع الانحرافات (${widget.deviations.length})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              const Divider(),

              // القائمة
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: widget.deviations.length,
                  itemBuilder: (context, index) {
                    return _buildDeviationItem(context, widget.deviations[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

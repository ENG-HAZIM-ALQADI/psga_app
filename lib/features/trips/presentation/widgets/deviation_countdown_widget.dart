import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/utils/extensions.dart';
import 'package:psga_app/features/trips/domain/entities/deviation.dart';
import 'package:psga_app/features/trips/presentation/bloc/trip_bloc.dart';
import 'package:psga_app/features/trips/presentation/bloc/trip_event.dart';
import 'package:psga_app/core/utils/logger.dart';

/// عرض العد التنازلي للانحراف كـ Dialog منبثق
/// Single Responsibility: مسؤول فقط عن عرض dialog التنبيه مع العد التنازلي
class DeviationCountdownWidget extends StatefulWidget {
  final Deviation deviation;
  final int secondsRemaining;
  final String tripId;

  const DeviationCountdownWidget({
    required this.deviation,
    required this.secondsRemaining,
    required this.tripId,
    super.key,
  });

  /// عرض Dialog التنبيه
  /// Dependency Inversion: يعتمد على abstraction (BuildContext) وليس implementation
  static void showDeviationAlert({
    required BuildContext context,
    required Deviation deviation,
    required int secondsRemaining,
    required String tripId,
  }) {
    AppLogger.info('[DeviationCountdownWidget] عرض نافذة التنبيه للانحراف');
    
    // تشغيل صوت واهتزاز
    _playAlertSound();
    _triggerVibration();
    
    showDialog(
      context: context,
      barrierDismissible: false, // لا يمكن إغلاقها بالضغط خارجها
      builder: (dialogContext) => DeviationCountdownWidget(
        deviation: deviation,
        secondsRemaining: secondsRemaining,
        tripId: tripId,
      ),
    );
  }

  /// تشغيل صوت التنبيه
  static void _playAlertSound() {
    try {
      // تشغيل صوت النظام للتنبيه
      SystemSound.play(SystemSoundType.alert);
      AppLogger.info('[DeviationCountdownWidget] تم تشغيل صوت التنبيه');
    } catch (e) {
      AppLogger.error('[DeviationCountdownWidget] فشل تشغيل الصوت: $e');
    }
  }

  /// تفعيل الاهتزاز
  static void _triggerVibration() {
    try {
      // اهتزاز متوسط الشدة
      HapticFeedback.mediumImpact();
      
      // اهتزاز إضافي بعد 500ms
      Future.delayed(const Duration(milliseconds: 500), () {
        HapticFeedback.mediumImpact();
      });
      
      // اهتزاز ثالث بعد 1000ms
      Future.delayed(const Duration(seconds: 1), () {
        HapticFeedback.mediumImpact();
      });
      
      AppLogger.info('[DeviationCountdownWidget] تم تفعيل الاهتزاز');
    } catch (e) {
      AppLogger.error('[DeviationCountdownWidget] فشل تفعيل الاهتزاز: $e');
    }
  }

  @override
  State<DeviationCountdownWidget> createState() => _DeviationCountdownWidgetState();
}

class _DeviationCountdownWidgetState extends State<DeviationCountdownWidget> {
  @override
  void initState() {
    super.initState();
    // تكرار الاهتزاز كل 5 ثوانٍ أثناء العد التنازلي
    _startPeriodicVibration();
  }

  void _startPeriodicVibration() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && widget.secondsRemaining > 0) {
        HapticFeedback.mediumImpact();
        _startPeriodicVibration(); // استمرار التكرار
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final percentage = widget.secondsRemaining / 30.0;
    final color = _getColorForSeverity(widget.deviation.severity);

    return PopScope(
      // منع الإغلاق بزر الرجوع
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 16,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color, width: 3),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // أيقونة التنبيه المتحركة
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.2),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: color,
                      size: 64,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // العنوان
              Text(
                '⚠️ تنبيه انحراف ${_getSeverityText(widget.deviation.severity)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                'تم كشف انحراف عن المسار المخطط',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 24),

              // العد التنازلي مع رسم متحرك
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(widget.secondsRemaining),
                      tween: Tween(begin: percentage + 0.033, end: percentage),
                      duration: const Duration(seconds: 1),
                      builder: (context, value, child) {
                        return CircularProgressIndicator(
                          value: value,
                          strokeWidth: 10,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        );
                      },
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '${widget.secondsRemaining}',
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          color: color,
                          shadows: [
                            Shadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'ثانية',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // المعلومات
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      Icons.straighten,
                      'المسافة عن المسار',
                      '${widget.deviation.distanceFromRoute.toStringAsFixed(0)} متر',
                      Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.access_time,
                      'مدة الانحراف',
                      '${widget.deviation.currentDuration.inMinutes} دقيقة',
                      Colors.blue,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // الرسالة التحذيرية
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red[700], size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'إذا لم تعد للمسار، سيتم إرسال تنبيه لجهات الاتصال',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.red[900],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // الأزرار
              Row(
                children: [
                  // زر أنا بخير
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        AppLogger.info('[DeviationCountdownWidget] المستخدم ضغط: أنا بخير');
                        Navigator.of(context).pop(); // إغلاق Dialog
                        context.read<TripBloc>().add(
                          DismissDeviationAlertEvent(tripId: widget.tripId),
                        );
                      },
                      icon: const Icon(Icons.check_circle, size: 24),
                      label: const Text(
                        'أنا بخير',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // زر SOS
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        AppLogger.warning('[DeviationCountdownWidget] المستخدم ضغط: SOS');
                        Navigator.of(context).pop(); // إغلاق Dialog
                        _showSOSConfirmation(context);
                      },
                      icon: const Icon(Icons.sos, size: 24),
                      label: const Text(
                        'SOS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
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

  /// بناء صف معلومات
  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSOSConfirmation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sos, color: Colors.red, size: 28),
            ),
            const SizedBox(width: 12),
            const Text(
              'تأكيد الطوارئ',
              style: TextStyle(fontSize: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'هل أنت متأكد من تفعيل طوارئ SOS؟',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'سيتم إرسال تنبيه فوري لجميع جهات الاتصال مع موقعك الحالي',
                      style: TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              AppLogger.info('[DeviationCountdownWidget] إلغاء SOS');
              Navigator.pop(dialogContext);
            },
            child: Text(context.l10n.cancel, style: const TextStyle(fontSize: 16)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              AppLogger.warning('[DeviationCountdownWidget] تأكيد SOS - إرسال التنبيه الفوري');
              Navigator.pop(dialogContext);
              // تفعيل SOS
              context.read<TripBloc>().add(
                TriggerSOSEvent(
                  tripId: widget.tripId,
                  currentLocation: widget.deviation.deviationLocation,
                ),
              );
            },
            icon: const Icon(Icons.sos, size: 22),
            label: const Text(
              'تأكيد SOS',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForSeverity(DeviationSeverity severity) {
    switch (severity) {
      case DeviationSeverity.none:
        return Colors.grey;
      case DeviationSeverity.low:
        return Colors.blue;
      case DeviationSeverity.medium:
        return Colors.orange;
      case DeviationSeverity.high:
        return Colors.deepOrange;
      case DeviationSeverity.critical:
        return Colors.red;
    }
  }

  String _getSeverityText(DeviationSeverity severity) {
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
}

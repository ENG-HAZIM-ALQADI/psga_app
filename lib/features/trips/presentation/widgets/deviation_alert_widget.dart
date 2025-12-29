// ============================================================================
// 📄 ملف: deviation_alert_widget.dart
// 🏗️ النوع: Custom Widget
// 🎯 الوظيفة: عنصر تحذير الانحراف عن المسار مع مؤقت تنازلي (Countdown Timer)
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/entities/deviation_entity.dart';

/// 📌 عنصر تحذير الانحراف (Deviation Alert Widget)
/// هذا Widget يعرض تنبيهاً للمستخدم عندما ينحرف عن المسار
/// ✨ المميزات:
/// - يعرض مستوى الخطورة (منخفض، متوسط، عالي، حرج)
/// - مؤقت تنازلي يُعد التنبيه التلقائي
/// - زر "أنا بخير" للتأكيد
/// - ألوان مختلفة حسب مستوى الخطورة
class DeviationAlertWidget extends StatefulWidget {
  final DeviationEntity deviation;      // 📊 بيانات الانحراف (المسافة، مستوى الخطورة)
  final VoidCallback? onDismiss;         // 🔘 الدالة عند إغلاق التنبيه
  final VoidCallback? onImOkay;          // ✅ الدالة عند الضغط "أنا بخير"
  final int countdownSeconds;            // ⏱️ عدد الثواني للمؤقت (افتراضي 30 ثانية)

  const DeviationAlertWidget({
    super.key,
    required this.deviation,
    this.onDismiss,
    this.onImOkay,
    this.countdownSeconds = 30,
  });

  @override
  State<DeviationAlertWidget> createState() => _DeviationAlertWidgetState();
}

/// 🏠 حالة عنصر تحذير الانحراف
class _DeviationAlertWidgetState extends State<DeviationAlertWidget> {
  /// ⏱️ متغير العد التنازلي (Countdown)
  /// استخدمنا late لأن قيمتها ستُعيّن في initState
  late int _remainingSeconds;
  
  /// ⏲️ متغير المؤقت الدوري (Periodic Timer)
  /// Timer.periodic: يعمل مرة كل ثانية (Duration(seconds: 1))
  Timer? _timer;

  @override
  void initState() {
    /// 🔧 تهيئة العد التنازلي وبدء المؤقت
    super.initState();
    _remainingSeconds = widget.countdownSeconds;  // ابدأ العد من 30 ثانية مثلاً
    _startTimer();  // شغل المؤقت الدوري
  }

  @override
  void dispose() {
    /// 🧹 تنظيف الموارد
    /// إغلاق المؤقت عند إغلاق الـ Widget لتجنب تسريب الذاكرة
    _timer?.cancel();
    super.dispose();
  }

  /// ⏲️ دالة بدء المؤقت الدوري
  void _startTimer() {
    /// Timer.periodic: ينفذ الكود كل X duration (هنا كل 1 ثانية)
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      /// 🔄 كل ثانية:
      if (_remainingSeconds > 0) {
        /// لم ننتهِ بعد، قلل 1 ثانية وأعد رسم الواجهة (setState)
        setState(() {
          _remainingSeconds--;
        });
      } else {
        /// انتهى العد التنازلي (وصلنا للصفر)
        timer.cancel();  // أوقف المؤقت
        /// 🚨 يمكن تشغيل إجراء تلقائي هنا (مثل إرسال SOS تلقائي)
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _getSeverityColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getSeverityColor(),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: _getSeverityColor(),
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getSeverityTitle(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getSeverityColor(),
                      ),
                    ),
                    Text(
                      'المسافة عن المسار: ${widget.deviation.distanceFromRoute.toStringAsFixed(0)} متر',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (widget.onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onDismiss,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$_remainingSeconds',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getSeverityColor(),
                      ),
                    ),
                    Text(
                      'ثانية للتنبيه التلقائي',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: widget.onImOkay,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('أنا بخير'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 🎨 دالة الحصول على لون الخطورة
  /// Switch/Case: تُرجع لوناً مختلفاً حسب مستوى الخطورة
  /// 💡 ألوان متدرجة من الفاتح (أصفر) إلى الداكن (أحمر)
  Color _getSeverityColor() {
    switch (widget.deviation.severity) {
      case DeviationSeverity.low:        // ⚠️ منخفض = أصفر
        return Colors.yellow.shade700;
      case DeviationSeverity.medium:     // ⚠️ متوسط = برتقالي
        return Colors.orange;
      case DeviationSeverity.high:       // ⚠️ عالي = برتقالي داكن
        return Colors.deepOrange;
      case DeviationSeverity.critical:   // 🔴 حرج = أحمر (خطر!)
        return Colors.red;
    }
  }

  /// 📝 دالة الحصول على عنوان الخطورة
  /// تُرجع نص وصفي بالعربية يخبر المستخدم عن مستوى الخطورة
  /// Switch/Case: يمر على جميع الحالات الممكنة (Enum)
  String _getSeverityTitle() {
    switch (widget.deviation.severity) {
      case DeviationSeverity.low:
        return 'انحراف طفيف عن المسار';        // 🟡 تحذير بسيط
      case DeviationSeverity.medium:
        return 'انحراف متوسط عن المسار';      // 🟠 تحذير متوسط
      case DeviationSeverity.high:
        return 'انحراف كبير عن المسار!';      // 🟠 تحذير قوي
      case DeviationSeverity.critical:
        return 'تحذير: انحراف حرج!';         // 🔴 تحذير خطير جداً
    }
  }
}

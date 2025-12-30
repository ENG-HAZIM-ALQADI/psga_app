// ============================================================================
// 📄 ملف: trip_stats_bar.dart
// 🏗️ النوع: Custom Widget (شريط الإحصائيات)
// 🎯 الوظيفة: عنصر يعرض معلومات الرحلة الحية (السرعة، المسافة، الوقت المنقضي)
// ============================================================================

import 'package:flutter/material.dart';
import '../../domain/entities/trip_entity.dart';

/// 📌 شريط إحصائيات الرحلة (Trip Stats Bar)
/// عنصر StatelessWidget يعرض 3 إحصائيات مهمة للرحلة النشطة في أسفل الشاشة
/// 📊 الإحصائيات:
/// - السرعة الحالية (من currentSpeed أو averageSpeed)
/// - المسافة المقطوعة الإجمالية
/// - الوقت المنقضي منذ بدء الرحلة
class TripStatsBar extends StatelessWidget {
  final TripEntity trip;          // 🏍️ بيانات الرحلة
  final double? currentSpeed;     // 🚗 السرعة الحالية (اختياري، أو استخدم averageSpeed)

  const TripStatsBar({
    super.key,
    required this.trip,
    this.currentSpeed,
  });

  @override
  Widget build(BuildContext context) {
    /// 🎨 نسق الألوان
    final theme = Theme.of(context);

    /// ⏱️ حساب الوقت المنقضي من بداية الرحلة إلى الآن
    /// DateTime.now().difference(): طرح وقتين للحصول على الفرق (Duration)
    final duration = DateTime.now().difference(trip.startTime);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              context,
              icon: Icons.speed,
              value: (currentSpeed ?? trip.averageSpeed).toStringAsFixed(0),
              unit: 'كم/س',
              label: 'السرعة',
            ),
            _buildDivider(context),
            _buildStatItem(
              context,
              icon: Icons.straighten,
              value: trip.totalDistance.toStringAsFixed(1),
              unit: 'كم',
              label: 'المسافة',
            ),
            _buildDivider(context),
            _buildStatItem(
              context,
              icon: Icons.timer,
              value: _formatDuration(duration),
              unit: '',
              label: 'الوقت',
            ),
          ],
        ),
      ),
    );
  }

  /// 📊 دالة بناء عنصر إحصائية واحدة
  /// كل إحصائية تتكون من: أيقونة + قيمة + وحدة + تسمية
  /// 💡 Reusable Component: نستخدمها 3 مرات للسرعة والمسافة والوقت
  Widget _buildStatItem(
      BuildContext context, {
        required IconData icon,     // 🎨 الأيقونة (مثل Icons.speed)
        required String value,      // 📈 القيمة الرقمية (مثل "85")
        required String unit,       // 📐 الوحدة (مثل "كم/س")
        required String label,      // 🏷️ التسمية (مثل "السرعة")
      }) {
    final theme = Theme.of(context);

    /// 📦 Column: ترتيب رأسي (أيقونة فوق الرقم فوق التسمية)
    return Column(
      mainAxisSize: MainAxisSize.min,  // 📐 الارتفاع بالحد الأدنى
      children: [
        /// 🎨 الأيقونة الملونة بألوان Theme
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        /// 📈 Row: ترتيب أفقي (قيمة + وحدة)
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,  // 📐 توازن الخط القاعدي
          children: [
            /// 📈 الرقم الكبير والعريض (مثل 85)
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            /// 📐 الوحدة الصغيرة بجانب الرقم (مثل "كم/س")
            /// 💡 isNotEmpty: عرض الوحدة فقط إذا كانت موجودة (الوقت بدون وحدة مثلاً)
            if (unit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2, right: 2),
                child: Text(
                  unit,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
        /// 🏷️ التسمية الصغيرة بلون فاتح (مثل "السرعة")
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// 📏 دالة بناء خط فاصل رأسي
  /// 💡 Divider: خط رمادي رقيق يفصل بين الإحصائيات
  Widget _buildDivider(BuildContext context) {
    /// 📦 Container: صندوق بسيط بحجم محدد
    return Container(
      height: 40,                  // 📏 الارتفاع (طول الخط)
      width: 1,                    // 📏 العرض (رقة الخط - 1 بكسل)
      color: Theme.of(context).dividerColor,  // 🎨 لون الخط الفاتح
    );
  }

  /// ⏱️ دالة تنسيق المدة الزمنية بتنسيق HH:MM:SS
  /// مثال: Duration(hours: 1, minutes: 5, seconds: 30) → "1:05:30"
  /// 💡 Format Conversion: تحويل Duration إلى نص مقروء
  String _formatDuration(Duration duration) {
    /// 📐 استخراج الساعات والدقائق والثواني
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;      // 📐 الدقائق بعد حساب الساعات
    final seconds = duration.inSeconds % 60;      // 📐 الثواني بعد حساب الدقائق

    /// ✅ إذا كانت هناك ساعات، اعرض الصيغة الكاملة HH:MM:SS
    if (hours > 0) {
      /// 💡 padLeft(2, '0'): أضف صفر على اليسار إذا كان الرقم 1 خانة فقط
      /// مثال: 5 → "05"
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    /// ✅ إذا أقل من ساعة، اعرض فقط MM:SS
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

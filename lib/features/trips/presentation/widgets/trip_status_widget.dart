// ============================================================================
// 📄 ملف: trip_status_widget.dart
// 🏗️ النوع: Custom Widget (عنصر حالة الرحلة)
// 🎯 الوظيفة: عنصر يعرض حالة الرحلة الحالية (نشطة، موقوفة، مكتملة، إلخ)
// ============================================================================

import 'package:flutter/material.dart';
import '../../domain/entities/trip_entity.dart';

/// 📌 عنصر حالة الرحلة (Trip Status Widget)
/// عنصر StatelessWidget يعرض حالة الرحلة في شكل Badge جميل وملون
/// 🎨 المميزات:
/// - 6 حالات مختلفة (نشطة، موقوفة، مكتملة، ملغاة، طوارئ، في الانتظار)
/// - ألوان مختلفة لكل حالة
/// - أيقونة تعبيرية لكل حالة
/// - خيار إظهار/إخفاء النص مع الأيقونة
class TripStatusWidget extends StatelessWidget {
  final TripStatus status;      // 🔴 حالة الرحلة (Enum)
  final bool showLabel;         // 🏷️ هل نعرض النص أم الأيقونة فقط

  const TripStatusWidget({
    super.key,
    required this.status,
    this.showLabel = true,      // افتراضياً نعرض النص أيضاً
  });

  @override
  Widget build(BuildContext context) {
    /// 🎨 Badge يعرض حالة الرحلة
    /// Container: يعطينا تحكماً كاملاً بـ Padding، BorderRadius، Color
    /// InkWell: نستطيع إضافة تفاعل عند الحاجة
    return Container(
      /// 🎨 Padding داخلي للشكل
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        /// 🎨 اللون يتغير حسب الحالة (باستخدام 20% opacity للحصول على لون فاتح)
        color: _getBackgroundColor(),
        /// 📐 حافة دائرية (تشبه Pill shape)
        borderRadius: BorderRadius.circular(16),
      ),
      /// 📦 Row: محتوى أفقي (أيقونة + نص)
      child: Row(
        mainAxisSize: MainAxisSize.min,    // 📐 الحد الأدنى من العرض المطلوب
        children: [
          /// 🎨 أيقونة الحالة
          Icon(
            _getIcon(),                    // أيقونة تختلف حسب الحالة
            size: 16,
            color: _getTextColor(),        // لون الأيقونة
          ),
          /// 📝 النص (اختياري - حسب showLabel)
          if (showLabel) ...[
            const SizedBox(width: 6),      // 🎨 مسافة بين الأيقونة والنص
            Text(
              _getLabel(),                 // نص الحالة بالعربية
              style: TextStyle(
                color: _getTextColor(),    // نفس لون الأيقونة
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 🎨 دالة الحصول على لون الخلفية
  /// لون فاتح (20% opacity) يتغير حسب حالة الرحلة
  /// 💡 withOpacity(0.2): تشفيف اللون لجعله فاتحاً
  Color _getBackgroundColor() {
    switch (status) {
      case TripStatus.active:       // 🟢 نشطة = أخضر فاتح
        return Colors.green.withOpacity(0.2);
      case TripStatus.paused:       // 🟠 موقوفة = برتقالي فاتح
        return Colors.orange.withOpacity(0.2);
      case TripStatus.completed:    // 🔵 مكتملة = أزرق فاتح
        return Colors.blue.withOpacity(0.2);
      case TripStatus.cancelled:    // ⚪ ملغاة = رمادي فاتح
        return Colors.grey.withOpacity(0.2);
      case TripStatus.emergency:    // 🔴 طوارئ = أحمر فاتح
        return Colors.red.withOpacity(0.2);
      case TripStatus.pending:      // 🟣 في الانتظار = بنفسجي فاتح
        return Colors.purple.withOpacity(0.2);
    }
  }

  /// 🎨 دالة الحصول على لون النص والأيقونة
  /// لون داكن (عميق) يتطابق مع لون الخلفية لكن أغمق
  /// 💡 تباين مهم: لون فاتح بالخلفية + لون داكن بالنص = قابل للقراءة
  Color _getTextColor() {
    switch (status) {
      case TripStatus.active:
        return Colors.green;        // 🟢 أخضر (عميق)
      case TripStatus.paused:
        return Colors.orange;       // 🟠 برتقالي (عميق)
      case TripStatus.completed:
        return Colors.blue;         // 🔵 أزرق (عميق)
      case TripStatus.cancelled:
        return Colors.grey;         // ⚪ رمادي (عميق)
      case TripStatus.emergency:
        return Colors.red;          // 🔴 أحمر (عميق)
      case TripStatus.pending:
        return Colors.purple;       // 🟣 بنفسجي (عميق)
    }
  }

  /// 🎨 دالة الحصول على الأيقونة التعبيرية
  /// كل حالة لها أيقونة تعبر عنها بشكل بديهي
  /// 💡 Icons: مكتبة Flutter لـ Material Design Icons
  IconData _getIcon() {
    switch (status) {
      case TripStatus.active:       // 🚗 في الطريق
        return Icons.directions_car;
      case TripStatus.paused:       // ⏸️ إيقاف مؤقت
        return Icons.pause_circle;
      case TripStatus.completed:    // ✅ اكتمل
        return Icons.check_circle;
      case TripStatus.cancelled:    // ❌ ملغى
        return Icons.cancel;
      case TripStatus.emergency:    // ⚠️ طوارئ
        return Icons.warning;
      case TripStatus.pending:      // ⏰ في الانتظار
        return Icons.schedule;
    }
  }

  /// 📝 دالة الحصول على النص/التسمية بالعربية
  /// نص يصف حالة الرحلة بكلمات مفهومة للمستخدم
  /// 💡 Localization: النصوص العربية تجعل الواجهة مناسبة للمستخدمين العرب
  String _getLabel() {
    switch (status) {
      case TripStatus.active:
        return 'نشطة';               // 🟢 الرحلة جارية الآن
      case TripStatus.paused:
        return 'متوقفة';             // ⏸️ الرحلة موقوفة مؤقتاً
      case TripStatus.completed:
        return 'مكتملة';             // ✅ الرحلة انتهت بنجاح
      case TripStatus.cancelled:
        return 'ملغاة';              // ❌ الرحلة تم إلغاؤها
      case TripStatus.emergency:
        return 'طوارئ';              // ⚠️ حالة طوارئ
      case TripStatus.pending:
        return 'في الانتظار';        // ⏰ لم تبدأ بعد
    }
  }
}

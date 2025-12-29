// ============================================================================
// 📄 ملف: route_card.dart
// 🏗️ النوع: Custom Widget (بطاقة المسار)
// 🎯 الوظيفة: عنصر يعرض معلومات المسار بشكل جميل وتفاعلي
// ============================================================================

import 'package:flutter/material.dart';
import '../../domain/entities/route_entity.dart';

/// 📌 بطاقة المسار (Route Card)
/// عنصر StatelessWidget لعرض معلومات المسار (الاسم، البداية، النهاية، المسافة، الوقت، عدد الاستخدامات)
/// 🎨 المميزات:
/// - تفاعل عند الضغط (onTap)
/// - تفاعل عند الضغط الطويل (onLongPress) لعرض خيارات إضافية
/// - زر المفضلة (Favorite) يعرض نجمة مملوءة أو فارغة
/// - عرض المعلومات في شكل "Chips" ملونة
class RouteCard extends StatelessWidget {
  final RouteEntity route;           // 📍 بيانات المسار المراد عرضها
  final VoidCallback? onTap;         // 🔘 تفاعل الضغط العادي
  final VoidCallback? onLongPress;   // 🔘 تفاعل الضغط الطويل
  final VoidCallback? onFavoriteToggle; // ⭐ تبديل المفضلة

  const RouteCard({
    super.key,
    required this.route,
    this.onTap,
    this.onLongPress,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    /// 🎨 الحصول على نسق الألوان من Context (Light/Dark Mode)
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.route,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            route.startPoint.name ?? 'نقطة البداية',
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.flag,
                          size: 14,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            route.endPoint.name ?? 'نقطة النهاية',
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildInfoChip(
                          icon: Icons.straighten,
                          label: '${route.estimatedDistance.toStringAsFixed(1)} كم',
                          theme: theme,
                        ),
                        const SizedBox(width: 8),
                        _buildInfoChip(
                          icon: Icons.access_time,
                          label: _formatDuration(route.estimatedDuration),
                          theme: theme,
                        ),
                        const SizedBox(width: 8),
                        _buildInfoChip(
                          icon: Icons.repeat,
                          label: '${route.usageCount}',
                          theme: theme,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  route.isFavorite ? Icons.star : Icons.star_border,
                  color: route.isFavorite ? Colors.amber : null,
                ),
                onPressed: onFavoriteToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🏷️ دالة بناء "Chip" المعلومات الصغير
  /// Chip: عنصر صغير يعرض معلومة واحدة (مسافة أو وقت مثلاً)
  /// 💡 Pattern: هذه الدالة تُستخدم لإعادة الاستخدام (DRY - Don't Repeat Yourself)
  Widget _buildInfoChip({
    required IconData icon,           // 🎨 الأيقونة (مثل Icons.straighten)
    required String label,            // 📝 النص (مثل "5.2 كم")
    required ThemeData theme,         // 🎨 نسق الألوان من Context
  }) {
    /// 📦 Container: صندوق بخلفية رمادية فاتحة وحافة دائرية صغيرة
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        /// 🎨 لون الخلفية الفاتح (يختلف حسب Light/Dark Mode)
        color: theme.colorScheme.surfaceContainerHighest,
        /// 📐 حافة دائرية بسيطة
        borderRadius: BorderRadius.circular(8),
      ),
      /// 📦 محتوى أفقي: أيقونة + مسافة + نص
      child: Row(
        mainAxisSize: MainAxisSize.min,  // 📐 عرض الـ Chip بأصغر حجم ممكن
        children: [
          Icon(icon, size: 12),           // 🎨 أيقونة صغيرة (12px)
          const SizedBox(width: 4),       // 🎨 مسافة صغيرة
          Text(label, style: theme.textTheme.labelSmall),  // 📝 نص صغير
        ],
      ),
    );
  }

  /// ⏱️ دالة تنسيق المدة الزمنية إلى نص قابل للقراءة
  /// مثال: Duration(minutes: 125) → "2 س 5 د"
  /// 💡 Formatting: تحويل البيانات الخام إلى نص يفهمه الإنسان
  String _formatDuration(Duration duration) {
    /// ✅ إذا كان هناك ساعات (> 0)
    if (duration.inHours > 0) {
      /// 📐 inMinutes % 60: الدقائق المتبقية بعد حساب الساعات
      /// مثال: 125 دقيقة = 2 ساعة و 5 دقائق
      return '${duration.inHours} س ${duration.inMinutes % 60} د';
    }
    /// ✅ إذا كانت أقل من ساعة، اعرض الدقائق فقط
    return '${duration.inMinutes} دقيقة';
  }
}

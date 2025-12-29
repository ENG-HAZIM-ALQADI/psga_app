import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📌 AuthHeader - رأس الصفحة (Widget)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف من هذا الـ Widget:
/// عرض العنوان والوصف في صفحات المصادقة بشكل موحد
///
/// الاستخدام:
/// - صفحة Login: "مرحباً بعودتك" + "سجل دخولك للمتابعة"
/// - صفحة Register: "إنشاء حساب" + "سجل معنا الآن"
/// - صفحة Forgot Password: "نسيت كلمة المرور؟"
///
/// الفوائد:
/// - إعادة الاستخدام (DRY Principle)
/// - تصميم موحد في جميع صفحات المصادقة
/// - سهولة تغيير التصميم من مكان واحد

class AuthHeader extends StatelessWidget {
  /// 🎯 العنوان الرئيسي
  /// مثل: "مرحباً بعودتك"
  final String title;

  /// 📝 الوصف الثانوي (اختياري)
  /// مثل: "سجل دخولك للمتابعة"
  final String? subtitle;

  /// 🔒 هل نعرض الشعار (الأيقونة)؟
  /// true = عرض الأيقونة الأمنية
  /// false = عدم العرض (صفحة بسيطة)
  final bool showLogo;

  const AuthHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showLogo) ...[
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.security,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppDimensions.marginL),
        ],
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppDimensions.marginS),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/constants/app_dimensions.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📌 SocialLoginButtons - أزرار تسجيل الدخول الاجتماعية (Widget)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف من هذا الـ Widget:
/// عرض أزرار تسجيل الدخول عبر Google و Apple
///
/// الاستخدام:
/// تسهيل عملية تسجيل الدخول للمستخدم:
/// - بدل إدخال Email و Password
/// - اضغط على Google أو Apple
/// - التطبيق يسحب بيانات حسابك مباشرة
///
/// الحالات:
/// - Google: دائماً متوفر
/// - Apple: اختياري (حسب showApple)
///
/// الفوائد:
/// - تسجيل دخول أسرع وأسهل
/// - أقل مشاكل أمنية (Google/Apple يتعاملون مع الأمان)
/// - تجربة مستخدم أفضل

class SocialLoginButtons extends StatelessWidget {
  /// 🔵 الدالة المُستدعاة عند الضغط على Google
  /// null = عرض رسالة "الميزة ستأتي قريباً"
  final VoidCallback? onGooglePressed;

  /// 🍎 الدالة المُستدعاة عند الضغط على Apple
  /// null = عرض رسالة "الميزة ستأتي قريباً"
  final VoidCallback? onApplePressed;

  /// 🍎 هل نعرض زر Apple؟
  /// true = عرض الزر (لـ iOS بشكل أساسي)
  /// false = إخفاء الزر (لـ Android مثلاً)
  final bool showApple;

  const SocialLoginButtons({
    super.key,
    this.onGooglePressed,
    this.onApplePressed,
    this.showApple = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingM),
              child: Text(
                'أو',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: AppDimensions.marginL),
        _SocialButton(
          onPressed: onGooglePressed,
          icon: Icons.g_mobiledata,
          label: 'تسجيل الدخول بـ Google',
          backgroundColor: Colors.white,
          textColor: Colors.black87,
          borderColor: Colors.grey.shade300,
        ),
        if (showApple) ...[
          const SizedBox(height: AppDimensions.marginM),
          _SocialButton(
            onPressed: onApplePressed,
            icon: Icons.apple,
            label: 'تسجيل الدخول بـ Apple',
            backgroundColor: Colors.black,
            textColor: Colors.white,
          ),
        ],
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;

  const _SocialButton({
    this.onPressed,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.buttonHeight,
      child: OutlinedButton.icon(
        onPressed: onPressed ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('سيتم تفعيل هذه الميزة قريباً')),
              );
            },
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          side: borderColor != null ? BorderSide(color: borderColor!) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          ),
        ),
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

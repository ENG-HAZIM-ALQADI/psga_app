import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📌 PasswordStrengthIndicator - مؤشر قوة كلمة المرور (Widget)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف من هذا الـ Widget:
/// إظهار مستوى قوة كلمة المرور بشكل مرئي للمستخدم
///
/// الفائدة:
/// - دليل بصري يساعد المستخدم على إنشاء كلمة قوية
/// - عرض شريط تقدم + نص توضيحي
/// - تغيير الألوان حسب القوة (أحمر → أخضر)
///
/// طريقة الحساب:
/// 1️⃣ التحقق من الطول (8 أحرف+)
/// 2️⃣ التحقق من وجود أرقام
/// 3️⃣ التحقق من وجود أحرف كبيرة
/// 4️⃣ التحقق من وجود رموز خاصة
///
/// النتيجة:
/// - ضعيفة: 1 معيار فقط
/// - متوسطة: 2 معيار
/// - قوية: 3 معايير
/// - قوية جداً: 4 معايير

/// 🔐 Enum: مستويات قوة كلمة المرور
enum PasswordStrength {
  /// ❌ ضعيفة جداً
  /// (أقل من 8 أحرف أو بدون معايير أمان)
  weak,

  /// ⚠️ متوسطة
  /// (تحتوي على معياري أمان)
  medium,

  /// ✅ قوية
  /// (تحتوي على ثلاثة معايير أمان)
  strong,

  /// 🟢 قوية جداً
  /// (تحتوي على جميع معايير الأمان)
  veryStrong,
}

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({
    super.key,
    required this.password,
  });

  PasswordStrength _calculateStrength() {
    if (password.isEmpty || password.length < 8) {
      return PasswordStrength.weak;
    }

    int score = 0;

    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;

    if (score <= 1) return PasswordStrength.weak;
    if (score == 2) return PasswordStrength.medium;
    if (score == 3) return PasswordStrength.strong;
    return PasswordStrength.veryStrong;
  }

  Color _getColor(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return AppColors.error;
      case PasswordStrength.medium:
        return AppColors.warning;
      case PasswordStrength.strong:
        return AppColors.success.withOpacity(0.7);
      case PasswordStrength.veryStrong:
        return AppColors.success;
    }
  }

  String _getText(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return 'ضعيفة';
      case PasswordStrength.medium:
        return 'متوسطة';
      case PasswordStrength.strong:
        return 'قوية';
      case PasswordStrength.veryStrong:
        return 'قوية جداً';
    }
  }

  double _getProgress(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return 0.25;
      case PasswordStrength.medium:
        return 0.5;
      case PasswordStrength.strong:
        return 0.75;
      case PasswordStrength.veryStrong:
        return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final strength = _calculateStrength();
    final color = _getColor(strength);
    final text = _getText(strength);
    final progress = _getProgress(strength);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppDimensions.marginS),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.marginS),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

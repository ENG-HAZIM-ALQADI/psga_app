import 'package:flutter/material.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/core/constants/app_dimensions.dart';
import 'package:psga_app/core/utils/validators.dart';

/// مؤشر قوة كلمة المرور
class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({
    required this.password,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) {
      return const SizedBox.shrink();
    }

    final strength = Validators.passwordStrength(password);
    final strengthData = _getStrengthData(strength);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppDimensions.spacingSM),
        
        // شريط القوة
        Row(
          children: List.generate(4, (index) {
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(
                  right: index < 3 ? AppDimensions.spacingXS : 0,
                ),
                decoration: BoxDecoration(
                  color: index < strength
                      ? strengthData.color
                      : AppColors.greyLight,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                ),
              ),
            );
          }),
        ),
        
        const SizedBox(height: AppDimensions.spacingSM),
        
        // نص القوة
        Text(
          strengthData.text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: strengthData.color,
                fontWeight: FontWeight.w600,
              ),
        ),
        
        // المتطلبات
        if (password.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.spacingSM),
          _buildRequirement(
            'على الأقل 8 أحرف',
            password.length >= 8,
          ),
          _buildRequirement(
            'يحتوي على حرف كبير',
            password.contains(RegExp(r'[A-Z]')),
          ),
          _buildRequirement(
            'يحتوي على رقم',
            password.contains(RegExp(r'[0-9]')),
          ),
          _buildRequirement(
            'يحتوي على رمز خاص (اختياري)',
            password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
          ),
        ],
      ],
    );
  }

  Widget _buildRequirement(String text, bool satisfied) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingXS),
      child: Row(
        children: [
          Icon(
            satisfied ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: satisfied ? AppColors.success : AppColors.grey,
          ),
          const SizedBox(width: AppDimensions.spacingXS),
          Text(
            text,
            style: TextStyle(
              fontSize: AppDimensions.fontXS,
              color: satisfied ? AppColors.success : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  _StrengthData _getStrengthData(int strength) {
    switch (strength) {
      case 0:
        return _StrengthData(
          text: 'ضعيف جداً',
          color: AppColors.error,
        );
      case 1:
        return _StrengthData(
          text: 'ضعيف',
          color: AppColors.errorLight,
        );
      case 2:
        return _StrengthData(
          text: 'متوسط',
          color: AppColors.warning,
        );
      case 3:
        return _StrengthData(
          text: 'قوي',
          color: AppColors.success,
        );
      case 4:
        return _StrengthData(
          text: 'قوي جداً',
          color: AppColors.successDark,
        );
      default:
        return _StrengthData(
          text: 'ضعيف',
          color: AppColors.error,
        );
    }
  }
}

class _StrengthData {
  final String text;
  final Color color;

  _StrengthData({
    required this.text,
    required this.color,
  });
}

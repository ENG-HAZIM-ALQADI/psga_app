import 'package:flutter/material.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/core/constants/app_dimensions.dart';
import 'package:psga_app/shared/widgets/custom_button.dart';

/// عرض حالة فارغة قابل لإعادة الاستخدام
class EmptyStateWidget extends StatelessWidget {
  final String message;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onAction;
  final String? actionText;

  const EmptyStateWidget({
    required this.message,
    super.key,
    this.subtitle,
    this.icon,
    this.onAction,
    this.actionText,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLG),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.inbox_outlined,
              size: AppDimensions.iconXXL * 1.5,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: AppDimensions.spacingLG),
            Text(
              message,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.darkTextPrimary,
                  ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppDimensions.spacingSM),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onAction != null && actionText != null) ...[
              const SizedBox(height: AppDimensions.spacingXL),
              CustomButton(
                text: actionText!,
                onPressed: onAction,
                width: 200,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:psga_app/core/constants/app_dimensions.dart';

/// زر مخصص قابل لإعادة الاستخدام
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final double? width;
  final double height;

  const CustomButton({
    required this.text,
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.width,
    this.height = AppDimensions.buttonHeightMD,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDisabled = onPressed == null || isLoading;

    if (isOutlined) {
      return SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: OutlinedButton(
          onPressed: isDisabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
            ),
            side: BorderSide(
              color: isDisabled
                  ? Theme.of(context).disabledColor
                  : backgroundColor ?? theme.colorScheme.primary,
            ),
          ),
          child: _buildContent(context),
        ),
      );
    }

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled
              ? Theme.of(context).disabledColor
              : backgroundColor ?? theme.colorScheme.primary,
          foregroundColor: textColor ?? Theme.of(context).colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          ),
          elevation: isDisabled ? 0 : AppDimensions.cardElevation,
        ),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: AppDimensions.iconSM),
          const SizedBox(width: AppDimensions.spacingSM),
          Text(
            text,
            style: TextStyle(
              fontSize: AppDimensions.fontMD,
              fontWeight: FontWeight.w600,
              color: isOutlined
                  ? (backgroundColor ?? Theme.of(context).colorScheme.primary)
                  : textColor,
            ),
          ),
        ],
      );
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: AppDimensions.fontMD,
        fontWeight: FontWeight.w600,
        color: isOutlined
            ? (backgroundColor ?? Theme.of(context).colorScheme.primary)
            : textColor,
      ),
    );
  }
}

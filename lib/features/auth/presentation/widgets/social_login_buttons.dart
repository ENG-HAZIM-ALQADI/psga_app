import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/core/constants/app_dimensions.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_event.dart';

/// أزرار تسجيل الدخول الاجتماعية
class SocialLoginButtons extends StatelessWidget {
  const SocialLoginButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Google Sign In (متاح لجميع المنصات)
        _SocialLoginButton(
          onPressed: () {
            context.read<AuthBloc>().add(const LoginWithGoogleRequested());
          },
          icon: Icons.g_mobiledata,
          label: 'تسجيل الدخول بواسطة Google',
          backgroundColor: AppColors.white,
          textColor: AppColors.textPrimary,
          borderColor: AppColors.border,
        ),

        const SizedBox(height: AppDimensions.spacingMD),

        // Apple Sign In (متاح فقط لـ iOS)
        if (Platform.isIOS)
          _SocialLoginButton(
            onPressed: () {
              context.read<AuthBloc>().add(const LoginWithAppleRequested());
            },
            icon: Icons.apple,
            label: 'تسجيل الدخول بواسطة Apple',
            backgroundColor: AppColors.black,
            textColor: AppColors.white,
          ),
      ],
    );
  }
}

/// زر تسجيل دخول اجتماعي مخصص
class _SocialLoginButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;

  const _SocialLoginButton({
    required this.onPressed,
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
      height: AppDimensions.buttonHeightMD,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(
            color: borderColor ?? backgroundColor,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: textColor,
            ),
            const SizedBox(width: AppDimensions.spacingSM),
            Text(
              label,
              style: TextStyle(
                fontSize: AppDimensions.fontMD,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

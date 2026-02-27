import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/core/constants/app_dimensions.dart';
import 'package:psga_app/core/utils/extensions.dart';
import 'package:psga_app/core/utils/validators.dart';
import 'package:psga_app/features/auth/domain/entities/user_entity.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:psga_app/features/auth/presentation/widgets/password_strength_indicator.dart';
import 'package:psga_app/shared/widgets/custom_button.dart';
import 'package:psga_app/shared/widgets/custom_text_field.dart';
import 'package:psga_app/shared/widgets/loading_widget.dart';

/// صفحة تغيير كلمة المرور
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.resetPassword),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            context.showErrorSnackBar(state.message);
          } else if (state is PasswordChanged) {
            // استخدام مفتاح l10n بدلاً من نص مباشر
            context.showSuccessSnackBar(l10n.passwordChanged);
            _currentPasswordController.clear();
            _newPasswordController.clear();
            _confirmPasswordController.clear();
          } else if (state is Unauthenticated) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          
          UserEntity? user;
          if (state is Authenticated) {
            user = state.user;
          } else if (state is ProfileUpdated) {
            user = state.user;
          }
          
          final bool hasPassword = user?.hasPassword ?? true;

          return LoadingOverlay(
            isLoading: isLoading,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.paddingLG),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // معلومات توضيحية
                    _buildInfoCard(hasPassword, l10n),

                    const SizedBox(height: AppDimensions.spacingXL),

                    // كلمة المرور الحالية - فقط إذا كان لديه كلمة مرور
                    if (hasPassword) ...[
                      CustomTextField(
                        controller: _currentPasswordController,
                        label: l10n.currentPasswordLabel,
                        hint: l10n.currentPasswordHint,
                        prefixIcon: const Icon(Icons.lock_outline),
                        obscureText: _obscureCurrentPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureCurrentPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureCurrentPassword = !_obscureCurrentPassword;
                            });
                          },
                        ),
                        validator: Validators.required,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppDimensions.spacingMD),
                    ],

                    // كلمة المرور الجديدة
                    CustomTextField(
                      controller: _newPasswordController,
                      label: l10n.newPasswordLabel,
                      hint: l10n.newPasswordHint,
                      prefixIcon: const Icon(Icons.lock),
                      obscureText: _obscureNewPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureNewPassword = !_obscureNewPassword;
                          });
                        },
                      ),
                      validator: Validators.password,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                    ),

                    const SizedBox(height: AppDimensions.spacingSM),

                    // مؤشر قوة كلمة المرور الجديدة
                    PasswordStrengthIndicator(
                      password: _newPasswordController.text,
                    ),

                    const SizedBox(height: AppDimensions.spacingMD),

                    // تأكيد كلمة المرور الجديدة
                    CustomTextField(
                      controller: _confirmPasswordController,
                      label: l10n.confirmNewPasswordLabel,
                      hint: l10n.confirmNewPasswordHint,
                      prefixIcon: const Icon(Icons.lock_outline),
                      obscureText: _obscureConfirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.confirmPasswordEmptyError;
                        }
                        if (value != _newPasswordController.text) {
                          return l10n.passwordMismatch;
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _changePassword(hasPassword, l10n),
                    ),

                    const SizedBox(height: AppDimensions.spacingXL),

                    // نصائح الأمان
                    _buildSecurityTips(l10n),

                    const SizedBox(height: AppDimensions.spacingXL),

                    // زر تغيير/إضافة كلمة المرور
                    CustomButton(
                      onPressed: () => _changePassword(hasPassword, l10n),
                      text: hasPassword ? l10n.changePasswordBtn : l10n.addPasswordBtn,
                      isLoading: isLoading,
                    ),

                    const SizedBox(height: AppDimensions.spacingMD),

                    // زر الإلغاء
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: isLoading ? null : () => Navigator.pop(context),
                        child: Text(l10n.cancel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(bool hasPassword, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMD),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.primary,
            size: 28,
          ),
          const SizedBox(width: AppDimensions.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasPassword ? l10n.importantInfo : l10n.addPasswordInfo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasPassword ? l10n.changePasswordInfo : l10n.addPasswordHint,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodyMedium?.color ??
                        AppColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityTips(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMD),
      decoration: BoxDecoration(
        color: AppColors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(
          color: AppColors.green.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                color: AppColors.green,
                size: 20,
              ),
              const SizedBox(width: AppDimensions.spacingSM),
              Text(
                l10n.securityTipsTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSM),
          _buildTip(l10n.securityTip1),
          _buildTip(l10n.securityTip2),
          _buildTip(l10n.securityTip3),
          _buildTip(l10n.securityTip4),
          _buildTip(l10n.securityTip5),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: AppColors.green,
            size: 16,
          ),
          const SizedBox(width: AppDimensions.spacingSM),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyMedium?.color ??
                    AppColors.darkTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _changePassword(bool hasPassword, AppLocalizations l10n) {
    if (_formKey.currentState!.validate()) {
      if (hasPassword &&
          _currentPasswordController.text == _newPasswordController.text) {
        context.showErrorSnackBar(l10n.passwordMustBeDifferent);
        return;
      }

      context.read<AuthBloc>().add(
            ChangePasswordRequested(
              currentPassword:
                  hasPassword ? _currentPasswordController.text : '',
              newPassword: _newPasswordController.text,
            ),
          );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/core/constants/app_dimensions.dart';
import 'package:psga_app/core/utils/extensions.dart';
import 'package:psga_app/core/utils/validators.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:psga_app/shared/widgets/custom_button.dart';
import 'package:psga_app/shared/widgets/custom_text_field.dart';
import 'package:psga_app/shared/widgets/loading_widget.dart';

/// شاشة نسيت كلمة المرور
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _sendResetLink() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
            ResetPasswordRequested(
              email: _emailController.text.trim(),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            context.showErrorSnackBar(state.message);
          } else if (state is AuthOperationSuccess) {
            setState(() {
              _emailSent = true;
            });
            context.showSuccessSnackBar(state.message);
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          final l10n = context.l10n;

          return LoadingOverlay(
            isLoading: isLoading,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingLG),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppDimensions.spacingXL),

                    // الأيقونة والعنوان
                    _buildHeader(l10n),

                    const SizedBox(height: AppDimensions.spacingXXL),

                    if (!_emailSent) ...[
                      // نموذج إدخال البريد الإلكتروني
                      _buildEmailForm(isLoading, l10n),
                    ] else ...[
                      // رسالة النجاح
                      _buildSuccessMessage(l10n),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Column(
      children: [
        // أيقونة
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
          ),
          child: Icon(
            Icons.lock_reset,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),

        const SizedBox(height: AppDimensions.spacingLG),

        // العنوان
        Text(
          l10n.forgotPassword,
          style: Theme.of(context).textTheme.displayMedium,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AppDimensions.spacingSM),

        // النص الفرعي
        Text(
          _emailSent
              ? 'تم إرسال رابط إعادة تعيين كلمة المرور'
              : 'لا تقلق، سنرسل لك رابط إعادة التعيين',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmailForm(bool isLoading, AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // حقل البريد الإلكتروني
          CustomTextField(
            controller: _emailController,
            label: l10n.email,
            hint: l10n.email,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined),
            validator: Validators.email,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _sendResetLink(),
          ),

          const SizedBox(height: AppDimensions.spacingXL),

          // زر الإرسال
          CustomButton(
            text: l10n.sendResetLink,
            onPressed: _sendResetLink,
            isLoading: isLoading,
          ),

          const SizedBox(height: AppDimensions.spacingMD),

          // رابط العودة لتسجيل الدخول
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(l10n.login),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // بطاقة رسالة النجاح
        Container(
          padding: const EdgeInsets.all(AppDimensions.paddingLG),
          decoration: BoxDecoration(
            color: AppColors.green.withOpacity(0.2).withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
            border: Border.all(
              color: AppColors.green.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.mark_email_read_outlined,
                size: 64,
                color: AppColors.green,
              ),
              const SizedBox(height: AppDimensions.spacingMD),
              Text(
                'تم إرسال البريد الإلكتروني!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.green,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingSM),
              Text(
                'تحقق من بريدك الإلكتروني ${_emailController.text}\nواتبع الرابط لإعادة تعيين كلمة المرور',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppDimensions.spacingXL),

        // زر إعادة الإرسال
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _emailSent = false;
            });
          },
          icon: const Icon(Icons.refresh),
          label: Text(AppLocalizations.of(context)!.reEnterEmail),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.paddingMD,
            ),
          ),
        ),

        const SizedBox(height: AppDimensions.spacingMD),

        // زر العودة
        CustomButton(
          text: l10n.login,
          onPressed: () {
            Navigator.pop(context);
          },
          isOutlined: true,
        ),

        const SizedBox(height: AppDimensions.spacingLG),

        // نصيحة
        Container(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2).withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppDimensions.spacingSM),
              Expanded(
                child: Text(
                  'إذا لم تجد البريد، تحقق من مجلد الرسائل غير المرغوب فيها (Spam)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

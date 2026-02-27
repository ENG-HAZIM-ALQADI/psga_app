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
import 'package:psga_app/features/auth/presentation/widgets/social_login_buttons.dart';
import 'package:psga_app/shared/widgets/custom_button.dart';
import 'package:psga_app/shared/widgets/custom_text_field.dart';
import 'package:psga_app/shared/widgets/loading_widget.dart';

/// شاشة تسجيل الدخول
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
            LoginRequested(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            context.showErrorSnackBar(state.message);
          } else if (state is Authenticated) {
            // التنقل إلى الصفحة الرئيسية بعد اكتمال البناء
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.showSuccessSnackBar('مرحباً ${state.user.name}!');
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/home',
                  (route) => false,
                );
              }
            });
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppDimensions.spacingXXL),

                      // الشعار والعنوان
                      _buildHeader(l10n),

                      const SizedBox(height: AppDimensions.spacingXXL),

                      // حقل البريد الإلكتروني
                      CustomTextField(
                        controller: _emailController,
                        label: l10n.email,
                        hint: l10n.email,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(Icons.email_outlined),
                        validator: Validators.email,
                        textInputAction: TextInputAction.next,
                      ),

                      const SizedBox(height: AppDimensions.spacingMD),

                      // حقل كلمة المرور
                      CustomTextField(
                        controller: _passwordController,
                        label: l10n.password,
                        hint: l10n.password,
                        obscureText: _obscurePassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.fieldRequired;
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _login(),
                      ),

                      const SizedBox(height: AppDimensions.spacingSM),

                      // نسيت كلمة المرور
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/forgot-password');
                          },
                          child: Text(l10n.forgotPassword),
                        ),
                      ),

                      const SizedBox(height: AppDimensions.spacingLG),

                      // زر تسجيل الدخول
                      CustomButton(
                        text: l10n.signIn,
                        onPressed: _login,
                        isLoading: isLoading,
                      ),

                      const SizedBox(height: AppDimensions.spacingXL),

                      // فاصل
                      _buildDivider(l10n),

                      const SizedBox(height: AppDimensions.spacingXL),

                      // أزرار التسجيل الاجتماعية
                      const SocialLoginButtons(),

                      const SizedBox(height: AppDimensions.spacingXL),

                      // رابط التسجيل
                      _buildSignUpLink(l10n),
                    ],
                  ),
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
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
          ),
          child: Icon(
            Icons.shield_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingLG),
        Text(
          l10n.welcome,
          style: Theme.of(context).textTheme.displayMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.spacingSM),
        Text(
          l10n.signIn,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDivider(AppLocalizations l10n) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
          child: Text(
            l10n.other,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary,
                ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildSignUpLink(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          l10n.dontHaveAccount,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        TextButton(
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/register');
          },
          child: Text(l10n.signUp),
        ),
      ],
    );
  }
}

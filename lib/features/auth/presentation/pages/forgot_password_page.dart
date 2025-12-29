import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/auth_header.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📌 ForgotPasswordPage - صفحة نسيان كلمة المرور (Presentation Layer)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف من هذا الملف:
/// مساعدة المستخدم الذي نسي كلمة المرور على استعادتها
///
/// الخطوات:
/// 1️⃣ المستخدم يدخل بريده الإلكتروني
/// 2️⃣ ننقر "إرسال رابط إعادة التعيين"
/// 3️⃣ Firebase يرسل البريد الإلكتروني
/// 4️⃣ الصفحة تعرض: "تحقق من بريدك الإلكتروني"
/// 5️⃣ المستخدم ينقر على الرابط في البريد
/// 6️⃣ يعيد تعيين كلمة المرور
/// 7️⃣ يسجل دخول جديد
///
/// حالات الصفحة:
/// - الأولية: حقل إدخال البريد
/// - بعد الإرسال: رسالة "تحقق من بريدك" + زر لإعادة الإرسال

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
  void initState() {
    super.initState();
    AppLogger.info('[ForgotPasswordPage] Initialized',
        name: 'ForgotPasswordPage');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      AppLogger.info('[ForgotPasswordPage] Reset password requested',
          name: 'ForgotPasswordPage');
      context.read<AuthBloc>().add(
            AuthResetPasswordRequested(email: _emailController.text.trim()),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نسيت كلمة المرور'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthPasswordResetSent) {
            AppLogger.success('[ForgotPasswordPage] Reset email sent',
                name: 'ForgotPasswordPage');
            setState(() {
              _emailSent = true;
            });
          } else if (state is AuthFailure) {
            AppLogger.error('[ForgotPasswordPage] Failed: ${state.message}',
                name: 'ForgotPasswordPage');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          if (_emailSent) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.paddingL),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        size: 80,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.marginL),
                    Text(
                      'تم إرسال الرابط!',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.marginM),
                    Text(
                      'تم إرسال رابط إعادة تعيين كلمة المرور إلى\n${_emailController.text}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.marginXL),
                    CustomButton(
                      text: 'العودة لتسجيل الدخول',
                      onPressed: () => context.pop(),
                    ),
                  ],
                ),
              ),
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppDimensions.marginXL),
                    const AuthHeader(
                      title: 'نسيت كلمة المرور؟',
                      subtitle:
                          'أدخل بريدك الإلكتروني وسنرسل لك رابط إعادة التعيين',
                    ),
                    const SizedBox(height: AppDimensions.marginXL),
                    CustomTextField(
                      controller: _emailController,
                      label: 'البريد الإلكتروني',
                      hint: 'example@email.com',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email_outlined,
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'البريد الإلكتروني مطلوب';
                        }
                        if (!value.contains('@')) {
                          return 'يرجى إدخال بريد إلكتروني صحيح';
                        }
                        return null;
                      },
                      onSubmitted: (_) => _onSubmit(),
                    ),
                    const SizedBox(height: AppDimensions.marginL),
                    CustomButton(
                      text: 'إرسال رابط إعادة التعيين',
                      onPressed: isLoading ? null : _onSubmit,
                      isLoading: isLoading,
                    ),
                    const SizedBox(height: AppDimensions.marginL),
                    Center(
                      child: TextButton(
                        onPressed: () => context.pop(),
                        child: const Text('العودة لتسجيل الدخول'),
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
}

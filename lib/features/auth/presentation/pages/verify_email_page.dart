import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/core/constants/app_dimensions.dart';
import 'package:psga_app/core/utils/extensions.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:psga_app/shared/widgets/custom_button.dart';
import 'package:psga_app/shared/widgets/loading_widget.dart';

/// شاشة التحقق من البريد الإلكتروني
class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _canResend = true;
  int _cooldownSeconds = 0;
  String? _cachedEmail; // تخزين البريد محلياً لعرضه حتى عند تغيّر الـ state

  @override
  void initState() {
    super.initState();
    // لا نُرسل تلقائياً — الرابط أُرسل بالفعل أثناء التسجيل
  }

  void _resendVerificationEmail() {
    if (!_canResend) return;

    context.read<AuthBloc>().add(const SendEmailVerificationRequested());

    // بدء العد التنازلي (60 ثانية)
    setState(() {
      _canResend = false;
      _cooldownSeconds = 60;
    });

    _startCooldown();
  }

  void _startCooldown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) {
          _canResend = true;
        } else {
          _startCooldown();
        }
      });
    });
  }

  void _checkVerificationAndContinue() {
    // إعادة تحميل حالة المستخدم للتحقق
    context.read<AuthBloc>().add(const AuthCheckRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            final msg = state.message.toLowerCase();
            final isTooMany = msg.contains('عدد كبير') || msg.contains('too-many');
            final isNetwork = msg.contains('شبكة') || msg.contains('اتصال') ||
                msg.contains('i/o') || msg.contains('connection');

            if (isTooMany) {
              // Firebase throttle — الرابط أُرسل مسبقاً
              context.showInfoSnackBar(
                  'رابط التحقق أُرسل بالفعل، تحقق من بريدك (أو مجلد Spam)');
            } else if (isNetwork) {
              context.showWarningSnackBar(
                  'تعذّر الإرسال، تحقق من اتصال الإنترنت وأعد المحاولة');
            } else {
              context.showErrorSnackBar(state.message);
            }
          } else if (state is EmailVerificationSent) {
            context.showSuccessSnackBar('✅ تم إرسال رابط التحقق، تحقق من بريدك الإلكتروني');
          } else if (state is Authenticated) {
            if (state.user.emailVerified) {
              // Navigate to home بعد اكتمال البناء
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  context.showSuccessSnackBar('تم التحقق من بريدك الإلكتروني!');
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/home',
                    (route) => false,
                  );
                }
              });
            } else {
              context.showInfoSnackBar('لم يتم التحقق من البريد بعد');
            }
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          final l10n = context.l10n;

          // تخزين البريد عند توفره لعرضه حتى أثناء التحميل
          if (state is Authenticated && state.user.email.isNotEmpty) {
            _cachedEmail = state.user.email;
          }

          return LoadingOverlay(
            isLoading: isLoading,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingLG),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppDimensions.spacingXXL),

                    // الأيقونة والعنوان
                    _buildHeader(_cachedEmail),

                    const SizedBox(height: AppDimensions.spacingXXL),

                    // الخطوات
                    _buildSteps(),

                    const SizedBox(height: AppDimensions.spacingXXL),

                    // زر إعادة الإرسال
                    CustomButton(
                      text: _canResend
                          ? 'إعادة إرسال رابط التحقق'
                          : 'إعادة الإرسال بعد $_cooldownSeconds ثانية',
                      onPressed: _canResend ? _resendVerificationEmail : null,
                      icon: Icons.email_outlined,
                      isOutlined: true,
                    ),

                    const SizedBox(height: AppDimensions.spacingMD),

                    // زر المتابعة
                    CustomButton(
                      text: 'قمت بالتحقق، المتابعة',
                      onPressed: _checkVerificationAndContinue,
                      icon: Icons.check_circle_outline,
                    ),

                    const SizedBox(height: AppDimensions.spacingMD),

                    // زر تخطي (مؤقت)
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/home',
                          (route) => false,
                        );
                      },
                      child: Text(context.l10n.skipForNow),
                    ),

                    const SizedBox(height: AppDimensions.spacingXL),

                    // نصيحة
                    _buildTip(),

                    const SizedBox(height: AppDimensions.spacingXL),

                    // زر تسجيل الخروج
                    OutlinedButton.icon(
                      onPressed: () {
                        context.read<AuthBloc>().add(const LogoutRequested());
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.logout),
                      label: Text(l10n.logout),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(color: Theme.of(context).colorScheme.error),
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

  Widget _buildHeader(String? email) {
    return Column(
      children: [
        // أيقونة
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          ),
          child: Icon(
            Icons.mark_email_unread_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),

        const SizedBox(height: AppDimensions.spacingLG),

        // العنوان
        Text(
          context.l10n.verifyEmail,
          style: Theme.of(context).textTheme.displayMedium,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AppDimensions.spacingSM),

        // النص الفرعي
        if (email != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingMD,
              vertical: AppDimensions.paddingSM,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
            ),
            child: Text(
              email,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              textAlign: TextAlign.center,
            ),
          ),

        const SizedBox(height: AppDimensions.spacingSM),

        Text(
          'أرسلنا رابط التحقق إلى بريدك الإلكتروني',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSteps() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLG),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'خطوات التحقق:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppDimensions.spacingMD),
          _buildStep(
            number: '1',
            text: 'افتح بريدك الإلكتروني',
            icon: Icons.email_outlined,
          ),
          const SizedBox(height: AppDimensions.spacingSM),
          _buildStep(
            number: '2',
            text: 'ابحث عن رسالة من PSGA',
            icon: Icons.search,
          ),
          const SizedBox(height: AppDimensions.spacingSM),
          _buildStep(
            number: '3',
            text: 'اضغط على رابط التحقق',
            icon: Icons.link,
          ),
          const SizedBox(height: AppDimensions.spacingSM),
          _buildStep(
            number: '4',
            text: 'ارجع واضغط "المتابعة"',
            icon: Icons.check_circle_outline,
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required String number,
    required String text,
    required IconData icon,
  }) {
    return Row(
      children: [
        // رقم الخطوة
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(width: AppDimensions.spacingSM),

        // أيقونة الخطوة
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),

        const SizedBox(width: AppDimensions.spacingSM),

        // نص الخطوة
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildTip() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMD),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.2).withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
        border: Border.all(
          color: AppColors.gold.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline,
            size: 24,
            color: AppColors.gold,
          ),
          const SizedBox(width: AppDimensions.spacingSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'نصيحة:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.gold,
                      ),
                ),
                const SizedBox(height: AppDimensions.spacingXS),
                Text(
                  'إذا لم تجد البريد، تحقق من:\n• مجلد الرسائل غير المرغوب فيها (Spam)\n• مجلد الترقيات (Promotions)\n• تأكد من صحة البريد الإلكتروني',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

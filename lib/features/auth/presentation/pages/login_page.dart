import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/routes.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/auth_header.dart';
import '../widgets/social_login_buttons.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📌 LoginPage - صفحة تسجيل الدخول (Presentation Layer)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف من هذا الملف:
/// عرض واجهة المستخدم لتسجيل الدخول
///
/// المسؤوليات:
/// 1️⃣ عرض نموذج الدخول (Email + Password)
/// 2️⃣ التحقق من المدخلات محلياً
/// 3️⃣ إرسال حدث للـ BLoC
/// 4️⃣ الاستماع لحالات BLoC وتحديث الواجهة
/// 5️⃣ عرض رسائل الخطأ أو التنقل للصفحة الرئيسية
///
/// تدفق البيانات:
/// - المستخدم يكتب البريد والكلمة
/// - ضغط الزر → _onLogin()
/// - التحقق من النموذج
/// - إرسال حدث AuthLoginRequested للـ BLoC
/// - BLoC يستدعي Use Case
/// - Use Case يستدعي Repository
/// - النتيجة تعود كـ State
/// - الواجهة تتحدث بناءً على State
///
/// الحالات:
/// - AuthLoading: عرض Spinner
/// - AuthSuccess: الانتقال لـ Home Page
/// - AuthFailure: عرض رسالة خطأ (SnackBar)

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  /// 🔑 مفتاح النموذج (Form Key)
  /// يُستخدم للتحقق من صحة بيانات النموذج قبل الإرسال
  /// مثال: _formKey.currentState?.validate()
  final _formKey = GlobalKey<FormState>();

  /// 📧 التحكم بـ حقل البريد الإلكتروني
  /// نحصل على القيمة المدخلة: _emailController.text
  final _emailController = TextEditingController();

  /// 🔐 التحكم بـ حقل كلمة المرور
  final _passwordController = TextEditingController();

  /// 👁️ هل إخفاء كلمة المرور؟
  /// true = نقاط (●●●)
  /// false = نص واضح
  bool _obscurePassword = true;

  /// 🔧 initState: يُستدعى عند إنشاء الـ Widget
  /// يُستخدم لـ:
  /// - تهيئة متغيرات
  /// - تسجيل الأحداث
  /// - بدء Timers
  @override
  void initState() {
    super.initState();
    AppLogger.info('[LoginPage] Initialized', name: 'LoginPage');
  }

  /// 🗑️ dispose: يُستدعى عند حذف الـ Widget
  /// مهم جداً: تنظيف الموارد
  /// إذا لم نفعل هذا:
  /// - تسريب الذاكرة (Memory Leak)
  /// - أخطاء عند إغلاق الصفحة
  @override
  void dispose() {
    /// تحرير التحكم بـ المدخلات
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 🔐 معالج الحدث: عند الضغط على زر تسجيل الدخول
  ///
  /// الخطوات:
  /// 1️⃣ التحقق من صحة النموذج
  /// 2️⃣ الحصول على القيم المدخلة
  /// 3️⃣ إرسال حدث للـ BLoC
  /// 4️⃣ البقية يتعامل معها BLoC + Use Case
  void _onLogin() {
    /// 1️⃣ التحقق من صحة النموذج
    /// _formKey.currentState?.validate()
    ///   → يستدعي Validators لكل حقل
    ///   → يرجع true إذا كانت جميع الحقول صحيحة
    /// ?? false = إذا كان currentState null، اعتبر الإجابة false
    if (_formKey.currentState?.validate() ?? false) {
      AppLogger.info('[LoginPage] Login form submitted', name: 'LoginPage');

      /// 2️⃣ إرسال الحدث للـ BLoC
      /// context.read<AuthBloc>() = الحصول على BLoC من السياق
      /// .add() = إضافة حدث جديد
      ///
      /// trim() = حذف المسافات الزائدة
      /// مثل: "  user@example.com  " → "user@example.com"
      context.read<AuthBloc>().add(
            AuthLoginRequested(
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
          if (state is AuthSuccess) {
            AppLogger.success(
                '[LoginPage] Login successful, navigating to home',
                name: 'LoginPage');
            context.go(AppRoutes.home);
          } else if (state is AuthFailure) {
            AppLogger.error('[LoginPage] Login failed: ${state.message}',
                name: 'LoginPage');
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
                      title: 'مرحباً بعودتك',
                      subtitle: 'سجل دخولك للمتابعة',
                    ),
                    const SizedBox(height: AppDimensions.marginXL),
                    CustomTextField(
                      controller: _emailController,
                      label: 'البريد الإلكتروني',
                      hint: 'example@email.com',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email_outlined,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'البريد الإلكتروني مطلوب';
                        }
                        if (!value.contains('@')) {
                          return 'يرجى إدخال بريد إلكتروني صحيح';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.marginM),
                    CustomTextField(
                      controller: _passwordController,
                      label: 'كلمة المرور',
                      hint: '********',
                      obscureText: _obscurePassword,
                      prefixIcon: Icons.lock_outlined,
                      textInputAction: TextInputAction.done,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'كلمة المرور مطلوبة';
                        }
                        if (value.length < 6) {
                          return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                        }
                        return null;
                      },
                      onSubmitted: (_) => _onLogin(),
                    ),
                    const SizedBox(height: AppDimensions.marginS),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: () => context.push(AppRoutes.forgotPassword),
                        child: const Text('نسيت كلمة المرور؟'),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.marginL),
                    CustomButton(
                      text: 'تسجيل الدخول',
                      onPressed: isLoading ? null : _onLogin,
                      isLoading: isLoading,
                    ),
                    const SizedBox(height: AppDimensions.marginL),
                    const SocialLoginButtons(),
                    const SizedBox(height: AppDimensions.marginXL),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('ليس لديك حساب؟'),
                        TextButton(
                          onPressed: () => context.push(AppRoutes.register),
                          child: const Text('إنشاء حساب جديد'),
                        ),
                      ],
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

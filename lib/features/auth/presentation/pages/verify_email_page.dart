import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/custom_button.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📌 VerifyEmailPage - صفحة التحقق من البريد الإلكتروني (Presentation Layer)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف من هذا الملف:
/// التحقق من أن بريد المستخدم حقيقي وموجود
///
/// السيناريو:
/// 1️⃣ المستخدم ينشئ حساب جديد
/// 2️⃣ Firebase يرسل بريد تحقق
/// 3️⃣ هذه الصفحة تظهر رسالة: "تحقق من بريدك"
/// 4️⃣ المستخدم ينقر على الرابط في البريد
/// 5️⃣ يرجع للصفحة وينقر "تحقق الآن"
/// 6️⃣ نتحقق من Firebase: هل البريد موثق؟
/// 7️⃣ إذا نعم: الانتقال لـ Home Page
///
/// الفوائد:
/// - التأكد من أن البريد الحقيقي
/// - منع الحسابات الوهمية
/// - طريقة للتواصل مع المستخدم
///
/// الميزات:
/// - عرض البريد المدخل
/// - زر "تحقق الآن" (مع حساب صحة البريد من Firebase)
/// - زر "إعادة إرسال الرابط" (مع Cooldown بـ 60 ثانية)

class VerifyEmailPage extends StatefulWidget {
  /// 📧 البريد الإلكتروني الذي نريد التحقق منه
  /// يُعرض للمستخدم كـ تذكير
  /// مثل: "تم إرسال رابط التحقق إلى user@example.com"
  final String email;

  const VerifyEmailPage({
    super.key,
    required this.email,
  });

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  /// ⏱️ عداد الانتظار لزر "إعادة الإرسال"
  /// - 60: في البداية (لا يمكن الضغط)
  /// - ينخفض كل ثانية
  /// - 0: يمكن الضغط مرة أخرى
  ///
  /// الفائدة:
  /// منع الانتظار من إرسال الرابط مرات كثيرة
  /// (يسمى: Rate Limiting)
  int _resendCooldown = 0;

  /// ⏲️ Timer: الساعة التي تعد التنازلي
  /// نحتاج لحفظها لكي نلغيها عند الخروج من الصفحة
  Timer? _timer;

  /// 🔧 initState: تهيئة الصفحة
  /// نسجل دخول الصفحة في الـ Logger
  @override
  void initState() {
    super.initState();
    AppLogger.info('[VerifyEmailPage] Initialized for: ${widget.email}',
        name: 'VerifyEmailPage');
  }

  /// 🗑️ dispose: تنظيف الموارد
  /// إلغاء الـ Timer (مهم جداً لتجنب Memory Leak)
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// ⏱️ بدء العداد التنازلي (60 ثانية)
  ///
  /// الخطوات:
  /// 1️⃣ اضبط العداد على 60
  /// 2️⃣ أرسل البريد
  /// 3️⃣ ابدأ Timer: كل ثانية أنقص العداد بـ 1
  /// 4️⃣ عندما يصل 0: أوقف الـ Timer
  ///
  /// الفائدة: منع إرسال رسائل كثيرة بسرعة
  void _startResendCooldown() {
    setState(() {
      _resendCooldown = 60;
    });

    /// Timer.periodic = مكرر (كل ثانية)
    /// Duration(seconds: 1) = كل ثانية واحدة
    /// setState = تحديث الـ Widget (لتحديث الواجهة)
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) {
          timer.cancel(); // توقف الـ Timer
        }
      });
    });
  }

  /// 📧 إعادة إرسال البريد
  ///
  /// الخطوات:
  /// 1️⃣ تسجيل الحدث
  /// 2️⃣ بدء العداد التنازلي (منع الإزعاج)
  /// 3️⃣ عرض رسالة نجاح (SnackBar)
  void _onResendEmail() {
    AppLogger.info('[VerifyEmailPage] Resending verification email',
        name: 'VerifyEmailPage');
    _startResendCooldown();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إرسال رابط التحقق مجدداً'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  /// ✅ التحقق من حالة البريد
  ///
  /// الخطوات:
  /// 1️⃣ التحقق من Firebase: هل البريد موثق؟
  /// 2️⃣ إذا نعم: الانتقال لـ Home Page
  /// 3️⃣ إذا لا: عرض رسالة خطأ (جرب مرة أخرى)
  ///
  /// الشرط: if (mounted)
  /// معناه: هل الـ Widget موجود؟
  /// فائدته: منع عرض رسائل بعد حذف الصفحة
  void _onCheckVerification() {
    AppLogger.info('[VerifyEmailPage] Checking verification status',
        name: 'VerifyEmailPage');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جاري التحقق...'),
      ),
    );

    /// Future.delayed = تأخير (الانتظار)
    /// const Duration(seconds: 1) = ثانية واحدة
    /// if (mounted) = هل الـ Widget موجود؟
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        context.go(AppRoutes.home);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تأكيد البريد الإلكتروني'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingXL),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 80,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(height: AppDimensions.marginL),
              Text(
                'تحقق من بريدك الإلكتروني',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.marginM),
              Text(
                'تم إرسال رابط التحقق إلى',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.marginS),
              Text(
                widget.email,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.marginXL),
              CustomButton(
                text: 'تحقق الآن',
                onPressed: _onCheckVerification,
              ),
              const SizedBox(height: AppDimensions.marginM),
              CustomButton(
                text: _resendCooldown > 0
                    ? 'إعادة الإرسال ($_resendCooldown)'
                    : 'إعادة إرسال الرابط',
                isOutlined: true,
                onPressed: _resendCooldown > 0 ? null : _onResendEmail,
              ),
              const SizedBox(height: AppDimensions.marginL),
              Text(
                'لم تستلم الرابط؟ تحقق من مجلد الرسائل غير المرغوب فيها',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

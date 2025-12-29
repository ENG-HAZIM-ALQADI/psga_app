import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/validators.dart';
import '../repositories/auth_repository.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📌 ResetPasswordUseCase - إعادة تعيين كلمة المرور (Domain Layer)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف من هذا الملف:
/// إرسال رابط إعادة تعيين كلمة المرور للمستخدم
///
/// الخطوات:
/// 1️⃣ التحقق من صحة البريد الإلكتروني
/// 2️⃣ إرسال رابط التعيين للبريد
/// 3️⃣ المستخدم ينقر على الرابط
/// 4️⃣ المستخدم يدخل كلمة مرور جديدة
///
/// ملاحظة:
/// - هذا Use Case فقط يرسل البريد
/// - لا يغيير كلمة المرور (ذلك يتم عبر رابط البريد)
/// - النتيجة: void (لا توجد بيانات للإرجاع)

class ResetPasswordUseCase {
  /// 🔗 Repository: واجهة تجريدية
  final AuthRepository repository;

  ResetPasswordUseCase(this.repository);

  /// 🔹 الدالة الرئيسية: call(email)
  /// email: البريد الإلكتروني الذي سيُرسل إليه الرابط
  /// النتيجة: Either<Failure, void>
  ///   - Left (فشل): البريد غير صحيح أو خطأ إرسال
  ///   - Right (نجاح): تم الإرسال بنجاح
  Future<Either<Failure, void>> call(String email) async {
    AppLogger.info('[ResetPasswordUseCase] Starting password reset for: $email',
        name: 'ResetPasswordUseCase');

    /// 1️⃣ التحقق من صحة البريد
    /// البريد يجب أن يكون:
    /// - صيغة صحيحة (مثل: user@example.com)
    /// - موجود في قاعدة البيانات (Firebase سيتحقق)
    final emailError = Validators.validateEmail(email);
    if (emailError != null) {
      AppLogger.error(
          '[ResetPasswordUseCase] Email validation failed: $emailError',
          name: 'ResetPasswordUseCase');

      /// إرجاع فشل التحقق فوراً
      return Left(ValidationFailure(message: emailError));
    }

    /// 2️⃣ استدعاء Repository لإرسال البريد
    /// Repository سيتعامل مع:
    /// - البحث عن البريد في Firebase
    /// - توليد رابط آمن
    /// - إرسال البريد الإلكتروني
    final result = await repository.resetPassword(email);

    /// 3️⃣ تسجيل النتيجة
    result.fold(
      (failure) => AppLogger.error(
          '[ResetPasswordUseCase] Reset password failed: ${failure.message}',
          name: 'ResetPasswordUseCase'),
      (_) => AppLogger.success(
          '[ResetPasswordUseCase] Reset password email sent successfully',
          name: 'ResetPasswordUseCase'),
    );

    /// 4️⃣ إرجاع النتيجة
    /// BLoC سيستقبل هذه النتيجة:
    /// - إذا نجح: emit(AuthPasswordResetSent) → عرض رسالة "تحقق من بريدك"
    /// - إذا فشل: emit(AuthFailure) → عرض رسالة خطأ
    return result;
  }
}

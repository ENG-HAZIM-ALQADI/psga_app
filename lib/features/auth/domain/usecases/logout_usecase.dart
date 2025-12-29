import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../repositories/auth_repository.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📌 LogoutUseCase - منطق تسجيل الخروج (Domain Layer)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف من هذا الملف:
/// تمثيل حالة استخدام واحدة: "تسجيل الخروج"
///
/// ماذا يفعل تسجيل الخروج؟
/// 1️⃣ حذف Token من Firebase
/// 2️⃣ حذف بيانات المستخدم من Hive (محلياً)
/// 3️⃣ إرسال إشارة لـ UI لتنقل لـ Login Page
///
/// ملاحظة:
/// - لا توجد معاملات (Parameters) - نحن نعرف من هو المستخدم من Context
/// - النتيجة: void (لا نحتاج بيانات، فقط نجاح/فشل)
///
/// استخدام الحالة:
/// - عند ضغط "تسجيل الخروج" من القائمة
/// - عند حذف الحساب
/// - عند مشاكل أمنية

class LogoutUseCase {
  /// 🔗 Repository: واجهة تجريدية للخروج
  final AuthRepository repository;

  LogoutUseCase(this.repository);

  /// 🔹 الدالة الرئيسية: call()
  /// - لا توجد معاملات
  /// - النتيجة: Either<Failure, void>
  ///   - Left (فشل)
  ///   - Right (نجاح) = void (قيمة فارغة)
  Future<Either<Failure, void>> call() async {
    AppLogger.info('[LogoutUseCase] Starting logout process',
        name: 'LogoutUseCase');

    /// ⏳ انتظر نتيجة تسجيل الخروج من Repository
    /// Repository سيتعامل مع:
    /// - Firebase Signout
    /// - حذف البيانات المحلية (Hive)
    /// - تنظيف جميع الموارد
    final result = await repository.logout();

    /// 📊 تسجيل النتيجة
    /// fold: معالجة الحالتين (فشل أو نجاح)
    /// (_) = ignore the result (لا نحتاج القيمة، هي void فارغة)
    result.fold(
      (failure) => AppLogger.error(
          '[LogoutUseCase] Logout failed: ${failure.message}',
          name: 'LogoutUseCase'),
      (_) => AppLogger.success('[LogoutUseCase] Logout successful',
          name: 'LogoutUseCase'),
    );

    /// ✅ إرجاع النتيجة
    /// BLoC سيستقبل هذه النتيجة ويصدر AuthUnauthenticated state
    return result;
  }
}

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📌 GetCurrentUserUseCase - الحصول على المستخدم الحالي (Domain Layer)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف من هذا الملف:
/// جلب بيانات المستخدم المسجل دخول حالياً
///
/// الحالات:
/// 1️⃣ هناك مستخدم مسجل دخول → Right(UserEntity)
/// 2️⃣ لا يوجد مستخدم مسجل دخول → Left(Failure)
/// 3️⃣ Token انتهت صلاحيته → Left(Failure)
///
/// متى يُستخدم؟
/// - عند بدء التطبيق (التحقق من حالة المصادقة)
/// - تحديث بيانات المستخدم الحالي
/// - التحقق من صلاحية الجلسة
///
/// الفرق عن LoginUseCase:
/// LoginUseCase: يحتاج email + password (تسجيل دخول جديد)
/// GetCurrentUserUseCase: لا يحتاج معاملات (فقط جلب البيانات الموجودة)

class GetCurrentUserUseCase {
  /// 🔗 Repository: واجهة تجريدية للحصول على المستخدم
  final AuthRepository repository;

  GetCurrentUserUseCase(this.repository);

  /// 🔹 الدالة الرئيسية: call()
  /// - لا توجد معاملات
  /// - النتيجة: Either<Failure, UserEntity>
  ///   - Left (فشل): لا يوجد مستخدم أو Token انتهى
  ///   - Right (نجاح): بيانات المستخدم
  Future<Either<Failure, UserEntity>> call() async {
    AppLogger.info('[GetCurrentUserUseCase] Getting current user',
        name: 'GetCurrentUserUseCase');

    /// 🔍 استدعاء Repository للحصول على المستخدم
    /// Repository سيتحقق من:
    /// 1. هل يوجد Token في Hive؟
    /// 2. هل Token صحيح في Firebase؟
    /// 3. جلب بيانات المستخدم الكاملة
    final result = await repository.getCurrentUser();

    /// 📊 تسجيل النتيجة
    result.fold(
      (failure) => AppLogger.error(
          '[GetCurrentUserUseCase] Failed to get current user: ${failure.message}',
          name: 'GetCurrentUserUseCase'),
      (user) => AppLogger.success(
          '[GetCurrentUserUseCase] Current user retrieved: ${user.email}',
          name: 'GetCurrentUserUseCase'),
    );

    /// ✅ إرجاع النتيجة
    /// BLoC سيستقبل هذه النتيجة:
    /// - إذا نجح: emit(AuthSuccess) → عرض Home Page
    /// - إذا فشل: emit(AuthUnauthenticated) → عرض Login Page
    return result;
  }
}

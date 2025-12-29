import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/validators.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📌 RegisterUseCase - منطق إنشاء حساب جديد (Domain Layer)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف من هذا الملف:
/// تمثيل حالة استخدام واحدة: "إنشاء حساب جديد"
/// - التحقق من صحة جميع البيانات (اسم، بريد، كلمة المرور وتأكيدها)
/// - استدعاء Repository
/// - إرجاع النتيجة
///
/// الفرق عن LoginUseCase:
/// LoginUseCase: يحتاج بريد + كلمة فقط
/// RegisterUseCase: يحتاج اسم + بريد + كلمة + تأكيد الكلمة
///
/// Clean Architecture Principle:
/// Business Logic منفصل عن:
/// - UI Details
/// - Firebase Implementation
/// - Database Details

class RegisterUseCase {
  /// 🔗 Repository هي واجهة تجريدية
  /// لا نعرف التطبيق الفعلي (Firebase أم Mock)
  final AuthRepository repository;

  RegisterUseCase(this.repository);

  /// 🔹 الدالة الرئيسية: call()
  /// params: معاملات إنشاء الحساب (اسم، بريد، كلمة، تأكيد)
  /// Either<Failure, UserEntity>:
  ///   - Left (فشل): إذا فشل، نرجع Failure
  ///   - Right (نجاح): إذا نجح، نرجع UserEntity
  Future<Either<Failure, UserEntity>> call(RegisterParams params) async {
    AppLogger.info('[RegisterUseCase] Starting registration process',
        name: 'RegisterUseCase');

    /// 1️⃣ التحقق من صحة الاسم
    /// الاسم يجب أن يكون:
    /// - غير فارغ
    /// - بطول معقول (ليس جداً قصير أو طويل)
    final nameError = Validators.validateName(params.name);
    if (nameError != null) {
      AppLogger.error('[RegisterUseCase] Name validation failed: $nameError',
          name: 'RegisterUseCase');

      /// إرجاع فشل التحقق
      return Left(ValidationFailure(message: nameError));
    }

    /// 2️⃣ التحقق من صحة البريد الإلكتروني
    /// البريد يجب أن يكون:
    /// - صيغة صحيحة (مثل: user@example.com)
    /// - فريداً (لا يوجد حساب آخر بهذا البريد)
    final emailError = Validators.validateEmail(params.email);
    if (emailError != null) {
      AppLogger.error('[RegisterUseCase] Email validation failed: $emailError',
          name: 'RegisterUseCase');
      return Left(ValidationFailure(message: emailError));
    }

    /// 3️⃣ التحقق من قوة كلمة المرور
    /// كلمة المرور يجب أن تحتوي على:
    /// - أحرف كبيرة (A-Z)
    /// - أحرف صغيرة (a-z)
    /// - أرقام (0-9)
    /// - رموز خاصة (!@#$...)
    /// - بطول أكثر من 8 أحرف
    ///
    /// ملاحظة: validatePassword أقسى من validatePasswordSimple
    final passwordError = Validators.validatePassword(params.password);
    if (passwordError != null) {
      AppLogger.error(
          '[RegisterUseCase] Password validation failed: $passwordError',
          name: 'RegisterUseCase');
      return Left(ValidationFailure(message: passwordError));
    }

    /// 4️⃣ التحقق من تطابق الكلمة وتأكيدها
    /// يجب أن تكون الكلمة المدخلة مساوية لتأكيد الكلمة
    /// مثل:
    /// password = "MyPass123!"
    /// confirmPassword = "MyPass123!" ✅
    ///
    /// لو كانت مختلفة:
    /// password = "MyPass123!"
    /// confirmPassword = "MyPass456!" ❌
    final confirmError = Validators.validateConfirmPassword(
      params.confirmPassword,
      params.password,
    );
    if (confirmError != null) {
      AppLogger.error(
          '[RegisterUseCase] Confirm password validation failed: $confirmError',
          name: 'RegisterUseCase');
      return Left(ValidationFailure(message: confirmError));
    }

    /// 5️⃣ استدعاء Repository للتسجيل الفعلي
    /// Repository سيتعامل مع:
    /// - إنشاء حساب Firebase
    /// - حفظ البيانات محلياً (Hive)
    /// - إرسال بريد التحقق
    /// - إدارة المزامنة
    final result = await repository.register(
      params.name,
      params.email,
      params.password,
    );

    /// 6️⃣ تسجيل النتيجة
    /// fold: معالجة الحالتين (فشل أو نجاح)
    result.fold(
      (failure) => AppLogger.error(
          '[RegisterUseCase] Registration failed: ${failure.message}',
          name: 'RegisterUseCase'),
      (user) => AppLogger.success(
          '[RegisterUseCase] Registration successful for: ${user.email}',
          name: 'RegisterUseCase'),
    );

    /// 7️⃣ إرجاع النتيجة
    /// BLoC سيستقبل هذه النتيجة ويصدر State مناسب
    return result;
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 📌 RegisterParams - معاملات إنشاء الحساب
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف: تمرير جميع بيانات التسجيل في object واحد
/// بدل تمرير 4 parameters منفصلة
///
/// الفائدة:
/// - وضوح أكثر
/// - سهولة إضافة parameters جديدة لاحقاً
/// - قابلية الاختبار
class RegisterParams extends Equatable {
  /// 👤 اسم المستخدم الكامل
  /// مثل: "أحمد محمد علي"
  final String name;

  /// 📧 البريد الإلكتروني
  /// مثل: "ahmed@example.com"
  final String email;

  /// 🔐 كلمة المرور (الأولى)
  /// مثل: "MySecurePass123!"
  final String password;

  /// 🔐 تأكيد كلمة المرور
  /// يجب أن تكون مساوية لـ password
  /// مثل: "MySecurePass123!"
  final String confirmPassword;

  const RegisterParams({
    required this.name,
    required this.email,
    required this.password,
    required this.confirmPassword,
  });

  /// props: الخصائص المستخدمة للمقارنة (Equatable)
  @override
  List<Object?> get props => [name, email, password, confirmPassword];
}

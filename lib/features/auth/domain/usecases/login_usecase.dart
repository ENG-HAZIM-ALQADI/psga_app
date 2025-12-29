import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/validators.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📌 LoginUseCase - منطق تسجيل الدخول (Domain Layer)
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// الهدف من هذا الملف:
/// - تمثيل حالة استخدام واحدة: "تسجيل الدخول"
/// - هذا الملف في Domain Layer (بعيد عن Firebase و UI)
/// - مسؤول عن:
///   1. التحقق من صحة البيانات (email، password)
///   2. استدعاء Repository (واجهة تجريدية)
///   3. إرجاع النتيجة: إما نجاح (Right) أو فشل (Left)
/// 
/// Clean Architecture Principle:
/// نفصل Business Logic عن:
/// - UI Details (BLoC يتعامل معها)
/// - Data Sources (Repository يتعامل معه)
/// - Framework Dependencies (Flutter, Firebase)
/// 
/// هذا يجعل الكود قابلاً للاختبار والصيانة
///
class LoginUseCase {
  /// Repository هي واجهة تجريدية (Abstract Class)
  /// لا نعرف إذا تأتي البيانات من Firebase أم Mock
  /// هذا يسمى "Dependency Inversion Principle"
  final AuthRepository repository;

  LoginUseCase(this.repository);

  /// 🔹 الدالة الرئيسية: call()
  /// params: معاملات تسجيل الدخول (email و password)
  /// Either<Failure, UserEntity>:
  ///   - Left (فشل): إذا حدث خطأ، نرجع Failure object
  ///   - Right (نجاح): إذا نجح، نرجع UserEntity
  /// 
  /// await: انتظر استدعاء Repository (قد يكون بطيء)
  Future<Either<Failure, UserEntity>> call(LoginParams params) async {
    AppLogger.info('[LoginUseCase] Starting login process', name: 'LoginUseCase');

    /// 1️⃣ التحقق من صحة البريد الإلكتروني
    /// Validators.validateEmail(): دالة تتحقق من صيغة البريد
    /// إذا كان هناك خطأ، تُرجع رسالة خطأ (نص)
    final emailError = Validators.validateEmail(params.email);
    if (emailError != null) {
      AppLogger.error('[LoginUseCase] Email validation failed: $emailError', name: 'LoginUseCase');
      /// إرجاع Left() = فشل بـ ValidationFailure
      return Left(ValidationFailure(message: emailError));
    }

    /// 2️⃣ التحقق من صحة كلمة المرور
    final passwordError = Validators.validatePasswordSimple(params.password);
    if (passwordError != null) {
      AppLogger.error('[LoginUseCase] Password validation failed: $passwordError', name: 'LoginUseCase');
      return Left(ValidationFailure(message: passwordError));
    }

    /// 3️⃣ استدعاء Repository للعملية الفعلية
    /// repository.login() هي طريقة تجريدية (Abstract)
    /// قد يكون تطبيقها Firebase أو Mock
    /// await = انتظر النتيجة من الإنترنت (قد تأخذ وقتاً)
    final result = await repository.login(params.email, params.password);
    
    /// 4️⃣ تسجيل النتيجة
    result.fold(
      (failure) => AppLogger.error('[LoginUseCase] Login failed: ${failure.message}', name: 'LoginUseCase'),
      (user) => AppLogger.success('[LoginUseCase] Login successful for: ${user.email}', name: 'LoginUseCase'),
    );

    /// 5️⃣ إرجاع النتيجة كما هي
    /// BLoC سيتعامل معها وسيصدر states مناسبة
    return result;
  }
}

class LoginParams extends Equatable {
  final String email;
  final String password;

  const LoginParams({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

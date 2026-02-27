import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/core/utils/validators.dart';
import 'package:psga_app/features/auth/domain/entities/user_entity.dart';
import 'package:psga_app/features/auth/domain/repositories/auth_repository.dart';

/// حالة استخدام التسجيل
class RegisterUseCase {
  final AuthRepository repository;

  RegisterUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call({
    required String email,
    required String password,
    required String name,
  }) async {
    AppLogger.info('[RegisterUseCase] محاولة التسجيل: $email');

    // التحقق من الاسم
    if (name.trim().isEmpty) {
      AppLogger.warning('[RegisterUseCase] الاسم فارغ');
      return const Left(ValidationFailure('Name is required'));
    }

    if (name.trim().length < 2) {
      AppLogger.warning('[RegisterUseCase] الاسم قصير جداً');
      return const Left(ValidationFailure('Name must be at least 2 characters'));
    }

    // التحقق من البريد الإلكتروني
    if (email.trim().isEmpty) {
      AppLogger.warning('[RegisterUseCase] البريد الإلكتروني فارغ');
      return const Left(ValidationFailure('Email is required'));
    }

    final emailValidation = Validators.email(email.trim());
    if (emailValidation != null) {
      AppLogger.warning('[RegisterUseCase] البريد الإلكتروني غير صحيح');
      return Left(ValidationFailure(emailValidation));
    }

    // التحقق من كلمة المرور
    final passwordValidation = Validators.password(password);
    if (passwordValidation != null) {
      AppLogger.warning('[RegisterUseCase] كلمة المرور غير صالحة');
      return Left(ValidationFailure(passwordValidation));
    }

    // استدعاء المستودع
    AppLogger.info('[RegisterUseCase] جاري التسجيل...');
    final result = await repository.register(
      email: email.trim().toLowerCase(),
      password: password,
      name: name.trim(),
    );

    result.fold(
      (failure) => AppLogger.error('[RegisterUseCase] فشل التسجيل', failure.message),
      (user) => AppLogger.success('[RegisterUseCase] تم التسجيل بنجاح: ${user.email}'),
    );

    return result;
  }
}

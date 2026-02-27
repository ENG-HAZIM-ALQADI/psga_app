import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/auth/domain/entities/user_entity.dart';
import 'package:psga_app/features/auth/domain/repositories/auth_repository.dart';

/// حالة استخدام تسجيل الدخول
class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call({
    required String email,
    required String password,
  }) async {
    AppLogger.info('[LoginUseCase] محاولة تسجيل الدخول: $email');

    // التحقق من المدخلات
    if (email.trim().isEmpty) {
      AppLogger.warning('[LoginUseCase] البريد الإلكتروني فارغ');
      return const Left(ValidationFailure('Email is required'));
    }

    if (password.isEmpty) {
      AppLogger.warning('[LoginUseCase] كلمة المرور فارغة');
      return const Left(ValidationFailure('Password is required'));
    }

    if (password.length < 8) {
      AppLogger.warning('[LoginUseCase] كلمة المرور قصيرة جداً');
      return const Left(ValidationFailure('Password must be at least 8 characters'));
    }

    // استدعاء المستودع
    AppLogger.info('[LoginUseCase] جاري تسجيل الدخول...');
    final result = await repository.login(
      email: email.trim().toLowerCase(),
      password: password,
    );

    result.fold(
      (failure) => AppLogger.error('[LoginUseCase] فشل تسجيل الدخول', failure.message),
      (user) => AppLogger.success('[LoginUseCase] تم تسجيل الدخول بنجاح: ${user.email}'),
    );

    return result;
  }
}

import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/auth/domain/entities/user_entity.dart';
import 'package:psga_app/features/auth/domain/repositories/auth_repository.dart';

/// حالة استخدام تسجيل الدخول بواسطة Apple
class LoginWithAppleUseCase {
  final AuthRepository repository;

  LoginWithAppleUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call() async {
    AppLogger.info('[LoginWithAppleUseCase] محاولة تسجيل الدخول بواسطة Apple');

    final result = await repository.loginWithApple();

    result.fold(
      (failure) => AppLogger.error('[LoginWithAppleUseCase] فشل تسجيل الدخول', failure.message),
      (user) => AppLogger.success('[LoginWithAppleUseCase] تم تسجيل الدخول بنجاح: ${user.email}'),
    );

    return result;
  }
}

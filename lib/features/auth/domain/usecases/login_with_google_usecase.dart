import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/auth/domain/entities/user_entity.dart';
import 'package:psga_app/features/auth/domain/repositories/auth_repository.dart';

/// حالة استخدام تسجيل الدخول بواسطة Google
class LoginWithGoogleUseCase {
  final AuthRepository repository;

  LoginWithGoogleUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call() async {
    AppLogger.info('[LoginWithGoogleUseCase] محاولة تسجيل الدخول بواسطة Google');

    final result = await repository.loginWithGoogle();

    result.fold(
      (failure) => AppLogger.error('[LoginWithGoogleUseCase] فشل تسجيل الدخول', failure.message),
      (user) => AppLogger.success('[LoginWithGoogleUseCase] تم تسجيل الدخول بنجاح: ${user.email}'),
    );

    return result;
  }
}

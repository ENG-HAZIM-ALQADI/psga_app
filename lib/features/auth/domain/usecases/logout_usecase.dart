import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/auth/domain/repositories/auth_repository.dart';

/// حالة استخدام تسجيل الخروج
class LogoutUseCase {
  final AuthRepository repository;

  LogoutUseCase(this.repository);

  Future<Either<Failure, void>> call() async {
    AppLogger.info('[LogoutUseCase] محاولة تسجيل الخروج');

    final result = await repository.logout();

    result.fold(
      (failure) => AppLogger.error('[LogoutUseCase] فشل تسجيل الخروج', failure.message),
      (_) => AppLogger.success('[LogoutUseCase] تم تسجيل الخروج بنجاح'),
    );

    return result;
  }
}

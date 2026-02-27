import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/auth/domain/repositories/auth_repository.dart';

/// حالة استخدام حذف الحساب
class DeleteAccountUseCase {
  final AuthRepository repository;

  DeleteAccountUseCase(this.repository);

  Future<Either<Failure, void>> call() async {
    AppLogger.info('[DeleteAccountUseCase] محاولة حذف الحساب');

    final result = await repository.deleteAccount();

    result.fold(
      (failure) => AppLogger.error('[DeleteAccountUseCase] فشل حذف الحساب', failure.message),
      (_) => AppLogger.success('[DeleteAccountUseCase] تم حذف الحساب بنجاح'),
    );

    return result;
  }
}

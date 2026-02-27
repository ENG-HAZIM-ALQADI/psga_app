import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/auth/domain/repositories/auth_repository.dart';

/// حالة استخدام إرسال التحقق من البريد الإلكتروني
class SendEmailVerificationUseCase {
  final AuthRepository repository;

  SendEmailVerificationUseCase(this.repository);

  Future<Either<Failure, void>> call() async {
    AppLogger.info('[SendEmailVerificationUseCase] محاولة إرسال رابط التحقق');

    final result = await repository.sendEmailVerification();

    result.fold(
      (failure) => AppLogger.error('[SendEmailVerificationUseCase] فشل إرسال الرابط', failure.message),
      (_) => AppLogger.success('[SendEmailVerificationUseCase] تم إرسال رابط التحقق بنجاح'),
    );

    return result;
  }
}

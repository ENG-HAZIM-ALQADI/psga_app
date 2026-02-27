import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/core/utils/validators.dart';
import 'package:psga_app/features/auth/domain/repositories/auth_repository.dart';

/// حالة استخدام إعادة تعيين كلمة المرور
class ResetPasswordUseCase {
  final AuthRepository repository;

  ResetPasswordUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String email,
  }) async {
    AppLogger.info('[ResetPasswordUseCase] محاولة إعادة تعيين كلمة المرور: $email');

    // التحقق من البريد الإلكتروني
    if (email.trim().isEmpty) {
      AppLogger.warning('[ResetPasswordUseCase] البريد الإلكتروني فارغ');
      return const Left(ValidationFailure('Email is required'));
    }

    final emailValidation = Validators.email(email.trim());
    if (emailValidation != null) {
      AppLogger.warning('[ResetPasswordUseCase] البريد الإلكتروني غير صحيح');
      return Left(ValidationFailure(emailValidation));
    }

    // استدعاء المستودع
    AppLogger.info('[ResetPasswordUseCase] جاري إرسال رابط إعادة التعيين...');
    final result = await repository.resetPassword(
      email: email.trim().toLowerCase(),
    );

    result.fold(
      (failure) => AppLogger.error('[ResetPasswordUseCase] فشل إرسال الرابط', failure.message),
      (_) => AppLogger.success('[ResetPasswordUseCase] تم إرسال رابط إعادة التعيين بنجاح'),
    );

    return result;
  }
}

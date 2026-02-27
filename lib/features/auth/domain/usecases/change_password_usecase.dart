import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/core/utils/validators.dart';
import 'package:psga_app/features/auth/domain/repositories/auth_repository.dart';

/// حالة استخدام تغيير كلمة المرور
class ChangePasswordUseCase {
  final AuthRepository repository;

  ChangePasswordUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String currentPassword,
    required String newPassword,
  }) async {
    AppLogger.info('[ChangePasswordUseCase] محاولة تغيير/إضافة كلمة المرور');

    // إذا كانت كلمة المرور الحالية فارغة، فهذا يعني إضافة كلمة مرور جديدة
    final bool isAddingPassword = currentPassword.isEmpty;

    // التحقق من كلمة المرور الجديدة
    final passwordValidation = Validators.password(newPassword);
    if (passwordValidation != null) {
      AppLogger.warning('[ChangePasswordUseCase] كلمة المرور الجديدة غير صالحة');
      return Left(ValidationFailure(passwordValidation));
    }

    // التحقق من أن كلمة المرور الجديدة مختلفة (فقط عند التغيير وليس الإضافة)
    if (!isAddingPassword && currentPassword == newPassword) {
      AppLogger.warning('[ChangePasswordUseCase] كلمة المرور الجديدة مطابقة للحالية');
      return const Left(ValidationFailure('New password must be different'));
    }

    // استدعاء المستودع
    AppLogger.info(
      isAddingPassword 
          ? '[ChangePasswordUseCase] جاري إضافة كلمة المرور...'
          : '[ChangePasswordUseCase] جاري تغيير كلمة المرور...'
    );
    final result = await repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

    result.fold(
      (failure) => AppLogger.error('[ChangePasswordUseCase] فشل تغيير/إضافة كلمة المرور', failure.message),
      (_) => AppLogger.success(
        isAddingPassword
            ? '[ChangePasswordUseCase] تم إضافة كلمة المرور بنجاح'
            : '[ChangePasswordUseCase] تم تغيير كلمة المرور بنجاح'
      ),
    );

    return result;
  }
}

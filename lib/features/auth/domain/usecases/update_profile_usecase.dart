import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/auth/domain/entities/user_entity.dart';
import 'package:psga_app/features/auth/domain/repositories/auth_repository.dart';

/// حالة استخدام تحديث الملف الشخصي
class UpdateProfileUseCase {
  final AuthRepository repository;

  UpdateProfileUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call({
    String? name,
    String? photoUrl,
    String? phoneNumber,
  }) async {
    AppLogger.info('[UpdateProfileUseCase] محاولة تحديث الملف الشخصي');

    // التحقق من وجود بيانات للتحديث
    if (name == null && photoUrl == null && phoneNumber == null) {
      AppLogger.warning('[UpdateProfileUseCase] لا توجد بيانات للتحديث');
      return const Left(ValidationFailure('No data to update'));
    }

    // التحقق من الاسم
    if (name != null && name.trim().length < 2) {
      AppLogger.warning('[UpdateProfileUseCase] الاسم قصير جداً');
      return const Left(ValidationFailure('Name must be at least 2 characters'));
    }

    // استدعاء المستودع
    AppLogger.info('[UpdateProfileUseCase] جاري تحديث الملف الشخصي...');
    final result = await repository.updateProfile(
      name: name?.trim(),
      photoUrl: photoUrl?.trim(),
      phoneNumber: phoneNumber?.trim(),
    );

    result.fold(
      (failure) => AppLogger.error('[UpdateProfileUseCase] فشل التحديث', failure.message),
      (user) => AppLogger.success('[UpdateProfileUseCase] تم التحديث بنجاح'),
    );

    return result;
  }
}

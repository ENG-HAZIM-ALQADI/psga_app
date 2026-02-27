import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/auth/domain/entities/user_entity.dart';
import 'package:psga_app/features/auth/domain/repositories/auth_repository.dart';

/// حالة استخدام الحصول على المستخدم الحالي
class GetCurrentUserUseCase {
  final AuthRepository repository;

  GetCurrentUserUseCase(this.repository);

  Future<Either<Failure, UserEntity?>> call() async {
    AppLogger.info('[GetCurrentUserUseCase] جاري الحصول على المستخدم الحالي');

    final result = await repository.getCurrentUser();

    result.fold(
      (failure) => AppLogger.error('[GetCurrentUserUseCase] فشل في الحصول على المستخدم', failure.message),
      (user) {
        if (user != null) {
          AppLogger.success('[GetCurrentUserUseCase] تم العثور على المستخدم: ${user.email}');
        } else {
          AppLogger.info('[GetCurrentUserUseCase] لا يوجد مستخدم مسجل دخول');
        }
      },
    );

    return result;
  }
}

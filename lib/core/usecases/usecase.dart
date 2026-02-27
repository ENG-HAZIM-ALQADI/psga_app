import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';

/// Base class لجميع Use Cases
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

/// للاستخدام بدون معاملات
class NoParams {
  const NoParams();
}

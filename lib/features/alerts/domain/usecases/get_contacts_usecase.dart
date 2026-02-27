import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/alerts/domain/entities/contact_entity.dart';
import 'package:psga_app/features/alerts/domain/repositories/contacts_repository.dart';

/// معاملات الحصول على جهات الاتصال
class GetContactsParams extends Equatable {
  final String userId;

  const GetContactsParams({required this.userId});

  @override
  List<Object> get props => [userId];
}

/// حالة استخدام: جلب جهات الاتصال
/// 
/// Single Responsibility: مسؤول فقط عن جلب قائمة جهات الاتصال للمستخدم
class GetContactsUseCase implements UseCase<List<ContactEntity>, GetContactsParams> {
  final ContactsRepository repository;

  GetContactsUseCase(this.repository);

  @override
  Future<Either<Failure, List<ContactEntity>>> call(GetContactsParams params) async {
    try {
      AppLogger.info('[GetContactsUseCase] جاري جلب جهات الاتصال للمستخدم: ${params.userId}');
      
      final result = await repository.getContacts(params.userId);
      
      result.fold(
        (failure) => AppLogger.error('[GetContactsUseCase] فشل جلب جهات الاتصال: ${failure.message}'),
        (contacts) => AppLogger.success('[GetContactsUseCase] تم جلب ${contacts.length} جهة اتصال'),
      );
      
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[GetContactsUseCase] خطأ غير متوقع في جلب جهات الاتصال', e, stackTrace);
      return Left(ServerFailure('فشل جلب جهات الاتصال: ${e.toString()}'));
    }
  }
}

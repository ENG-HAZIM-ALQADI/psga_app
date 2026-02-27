import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/alerts/domain/entities/contact_entity.dart';
import 'package:psga_app/features/alerts/domain/repositories/contacts_repository.dart';

// ========== إضافة جهة اتصال ==========

/// حالة استخدام: إضافة جهة اتصال جديدة
/// 
/// Single Responsibility: مسؤول فقط عن إضافة جهات الاتصال مع التحقق من الصحة
class AddContactUseCase implements UseCase<ContactEntity, ContactEntity> {
  final ContactsRepository repository;

  AddContactUseCase(this.repository);

  @override
  Future<Either<Failure, ContactEntity>> call(ContactEntity contact) async {
    try {
      AppLogger.info('[AddContactUseCase] جاري إضافة جهة اتصال: ${contact.name}');
      
      // التحقق من صحة البيانات
      if (!contact.isValid) {
        AppLogger.warning('[AddContactUseCase] بيانات جهة الاتصال غير صالحة');
        return const Left(ValidationFailure('بيانات جهة الاتصال غير صالحة'));
      }
      
      final result = await repository.addContact(contact);
      
      result.fold(
        (failure) => AppLogger.error('[AddContactUseCase] فشل إضافة جهة الاتصال: ${failure.message}'),
        (success) => AppLogger.success('[AddContactUseCase] تمت إضافة جهة الاتصال بنجاح'),
      );
      
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[AddContactUseCase] خطأ غير متوقع في إضافة جهة الاتصال', e, stackTrace);
      return Left(ServerFailure('فشل إضافة جهة الاتصال: ${e.toString()}'));
    }
  }
}

// ========== تحديث جهة اتصال ==========

/// حالة استخدام: تحديث بيانات جهة اتصال موجودة
/// 
/// Single Responsibility: مسؤول فقط عن تحديث جهات الاتصال
class UpdateContactUseCase implements UseCase<ContactEntity, ContactEntity> {
  final ContactsRepository repository;

  UpdateContactUseCase(this.repository);

  @override
  Future<Either<Failure, ContactEntity>> call(ContactEntity contact) async {
    try {
      AppLogger.info('[UpdateContactUseCase] جاري تحديث جهة اتصال: ${contact.id}');
      
      // التحقق من صحة البيانات
      if (!contact.isValid) {
        AppLogger.warning('[UpdateContactUseCase] بيانات جهة الاتصال غير صالحة');
        return const Left(ValidationFailure('بيانات جهة الاتصال غير صالحة'));
      }
      
      final result = await repository.updateContact(contact);
      
      result.fold(
        (failure) => AppLogger.error('[UpdateContactUseCase] فشل تحديث جهة الاتصال: ${failure.message}'),
        (success) => AppLogger.success('[UpdateContactUseCase] تم تحديث جهة الاتصال بنجاح'),
      );
      
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[UpdateContactUseCase] خطأ غير متوقع في تحديث جهة الاتصال', e, stackTrace);
      return Left(ServerFailure('فشل تحديث جهة الاتصال: ${e.toString()}'));
    }
  }
}

// ========== حذف جهة اتصال ==========

/// حالة استخدام: حذف جهة اتصال
/// 
/// Single Responsibility: مسؤول فقط عن حذف جهات الاتصال
class DeleteContactUseCase implements UseCase<void, String> {
  final ContactsRepository repository;

  DeleteContactUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(String contactId) async {
    try {
      AppLogger.info('[DeleteContactUseCase] جاري حذف جهة اتصال: $contactId');
      
      final result = await repository.deleteContact(contactId);
      
      result.fold(
        (failure) => AppLogger.error('[DeleteContactUseCase] فشل حذف جهة الاتصال: ${failure.message}'),
        (_) => AppLogger.success('[DeleteContactUseCase] تم حذف جهة الاتصال بنجاح'),
      );
      
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[DeleteContactUseCase] خطأ غير متوقع في حذف جهة الاتصال', e, stackTrace);
      return Left(ServerFailure('فشل حذف جهة الاتصال: ${e.toString()}'));
    }
  }
}

// ========== جلب جهات الطوارئ ==========

/// حالة استخدام: جلب جهات الاتصال للطوارئ
/// 
/// Single Responsibility: مسؤول فقط عن جلب جهات الطوارئ
class GetEmergencyContactsUseCase implements UseCase<List<ContactEntity>, String> {
  final ContactsRepository repository;

  GetEmergencyContactsUseCase(this.repository);

  @override
  Future<Either<Failure, List<ContactEntity>>> call(String userId) async {
    try {
      AppLogger.info('[GetEmergencyContactsUseCase] جاري جلب جهات الطوارئ للمستخدم: $userId');
      
      final result = await repository.getEmergencyContacts(userId);
      
      result.fold(
        (failure) => AppLogger.error('[GetEmergencyContactsUseCase] فشل جلب جهات الطوارئ: ${failure.message}'),
        (contacts) => AppLogger.success('[GetEmergencyContactsUseCase] تم جلب ${contacts.length} جهة طوارئ'),
      );
      
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[GetEmergencyContactsUseCase] خطأ غير متوقع في جلب جهات الطوارئ', e, stackTrace);
      return Left(ServerFailure('فشل جلب جهات الطوارئ: ${e.toString()}'));
    }
  }
}

// ========== تعيين جهة اتصال أساسية ==========

/// حالة استخدام: تعيين جهة اتصال كأساسية
/// 
/// Single Responsibility: مسؤول فقط عن تعيين جهة الاتصال الأساسية
class SetPrimaryContactUseCase implements UseCase<ContactEntity, SetPrimaryContactParams> {
  final ContactsRepository repository;

  SetPrimaryContactUseCase(this.repository);

  @override
  Future<Either<Failure, ContactEntity>> call(SetPrimaryContactParams params) async {
    try {
      AppLogger.info('[SetPrimaryContactUseCase] جاري تعيين جهة اتصال أساسية: ${params.contactId}');
      
      final result = await repository.setPrimaryContact(
        userId: params.userId,
        contactId: params.contactId,
      );
      
      result.fold(
        (failure) => AppLogger.error('[SetPrimaryContactUseCase] فشل تعيين جهة الاتصال: ${failure.message}'),
        (contact) => AppLogger.success('[SetPrimaryContactUseCase] تم تعيين جهة الاتصال الأساسية بنجاح'),
      );
      
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[SetPrimaryContactUseCase] خطأ غير متوقع في تعيين جهة الاتصال', e, stackTrace);
      return Left(ServerFailure('فشل تعيين جهة الاتصال: ${e.toString()}'));
    }
  }
}

/// معاملات تعيين جهة الاتصال الأساسية
class SetPrimaryContactParams {
  final String userId;
  final String contactId;

  const SetPrimaryContactParams({
    required this.userId,
    required this.contactId,
  });
}


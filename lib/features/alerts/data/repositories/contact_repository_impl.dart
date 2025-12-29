import 'package:dartz/dartz.dart';
import '../../../../config/app_config.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/services/sync/sync_manager.dart';
import '../../../../core/services/sync/sync_item.dart';
import '../../domain/entities/contact_entity.dart';
import '../../domain/repositories/contact_repository.dart';
import '../datasources/contact_local_datasource.dart';
import '../datasources/contact_remote_datasource.dart';
import '../models/contact_model.dart';

/// Repository لجهات الاتصال - يدير البيانات المحلية والبعيدة
/// - يحفظ محلياً أولاً (Hive)
/// - يضيف إلى قائمة المزامنة
/// - يُزامن مع Firebase تلقائياً
class ContactRepositoryImpl implements ContactRepository {
  final ContactLocalDataSource localDataSource;
  final ContactRemoteDataSource remoteDataSource;
  late final bool useMock;
  final SyncManager _syncManager = SyncManager.instance;

  ContactRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    bool? useMock,
  }) {
    this.useMock = useMock ?? AppConfig.enableFirebase == false;
  }

  @override
  Future<Either<Failure, ContactEntity>> addContact(ContactEntity contact) async {
    try {
      final contactModel = ContactModel.fromEntity(contact);
      
      if (useMock) {
        final result = await localDataSource.addContact(contactModel);
        
        final syncItem = SyncItem(
          createdAt: DateTime.now(),
          id: contact.id,
          type: SyncItemType.contact,
          action: SyncAction.create,
          data: contactModel.toJson(),
          localId: contact.id,
        );
        await _syncManager.addToQueue(syncItem);
        
        AppLogger.info('[ContactRepo] تمت إضافة جهة الاتصال (Mock): ${contact.name}');
        return Right(result);
      } else {
        // التحقق من وجود معرف المستخدم
        if (contactModel.userId.isEmpty) {
          final currentUser = await _syncManager.getCurrentUserId();
          if (currentUser != null) {
            final updatedContact = ContactModel(
              id: contactModel.id,
              userId: currentUser,
              name: contactModel.name,
              phoneNumber: contactModel.phoneNumber,
              relationship: contactModel.relationship,
              email: contactModel.email,
              fcmToken: contactModel.fcmToken,
              isEmergencyContact: contactModel.isEmergencyContact,
              priority: contactModel.priority,
              canViewLiveLocation: contactModel.canViewLiveLocation,
              isVerified: contactModel.isVerified,
              createdAt: contactModel.createdAt,
            );
            await localDataSource.addContact(updatedContact);
            
            final syncItem = SyncItem(
              createdAt: DateTime.now(),
              id: contact.id,
              type: SyncItemType.contact,
              action: SyncAction.create,
              data: updatedContact.toJson(),
              localId: contact.id,
            );
            await _syncManager.addToQueue(syncItem);
            
            AppLogger.info('[ContactRepo] تمت إضافة جهة الاتصال بنجاح (مع UID مسترجع): ${contact.name}');
            return Right(updatedContact);
          }
          return const Left(ServerFailure(message: 'معرف المستخدم مفقود ولا يمكن استرجاعه'));
        }
        
        // الحفظ محلياً أولاً لضمان عدم ضياع البيانات
        await localDataSource.addContact(contactModel);
        
        final syncItem = SyncItem(
          createdAt: DateTime.now(),
          id: contact.id,
          type: SyncItemType.contact,
          action: SyncAction.create,
          data: contactModel.toJson(), // سيبقى الـ ID في الـ data لضمان وصوله لـ Firestore
          localId: contact.id,
        );
        
        // المزامنة مع Firestore
        await _syncManager.addToQueue(syncItem);
        
        AppLogger.info('[ContactRepo] تمت إضافة جهة الاتصال بنجاح: ${contact.name}');
        return Right(contactModel);
      }
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'فشل في إضافة جهة الاتصال: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateContact(ContactEntity contact) async {
    try {
      final contactModel = ContactModel.fromEntity(contact);
      
      if (useMock) {
        await localDataSource.updateContact(contactModel);
      } else {
        await remoteDataSource.updateContact(contactModel);
        await localDataSource.updateContact(contactModel);
      }
      
      final syncItem = SyncItem(
        createdAt: DateTime.now(),
        id: contact.id,
        type: SyncItemType.contact,
        action: SyncAction.update,
        data: contactModel.toJson(),
        localId: contact.id,
      );
      await _syncManager.addToQueue(syncItem);
      
      AppLogger.info('[ContactRepo] تم تحديث جهة الاتصال: ${contact.name}');
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'فشل في تحديث جهة الاتصال: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteContact(String contactId) async {
    try {
      if (useMock) {
        await localDataSource.deleteContact(contactId);
      } else {
        await remoteDataSource.deleteContact(contactId);
        await localDataSource.deleteContact(contactId);
      }
      
      final syncItem = SyncItem(
        createdAt: DateTime.now(),
        id: contactId,
        type: SyncItemType.contact,
        action: SyncAction.delete,
        data: {'id': contactId},
        localId: contactId,
      );
      await _syncManager.addToQueue(syncItem);
      
      AppLogger.info('[ContactRepo] تم حذف جهة الاتصال: $contactId');
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'فشل في حذف جهة الاتصال: $e'));
    }
  }

  @override
  Future<Either<Failure, List<ContactEntity>>> getContacts(String userId) async {
    try {
      // ✅ نمط Offline-First: جلب محلي أولاً
      var contacts = await localDataSource.getContacts(userId);
      
      // إذا كانت القائمة فارغة، جلب من Firebase وحفظ محلياً
      if (contacts.isEmpty && !useMock) {
        AppLogger.info('[ContactRepo] 📥 جلب جهات الاتصال من Firebase...');
        contacts = await remoteDataSource.getContacts(userId);
        
        // ✅ حفظ البيانات المجلوبة محلياً
        for (var contact in contacts) {
          final contactModel = ContactModel.fromEntity(contact);
          await localDataSource.addContact(contactModel);
          AppLogger.info('[ContactRepo] 💾 تم حفظ: ${contact.name}');
        }
        AppLogger.success('[ContactRepo] ✅ تم حفظ ${contacts.length} جهة اتصال محلياً');
      }
      
      AppLogger.info('[ContactRepo] تم جلب ${contacts.length} جهة اتصال');
      return Right(contacts);
    } catch (e) {
      AppLogger.error('[ContactRepo] ❌ خطأ في جلب جهات الاتصال: $e');
      return Left(ServerFailure(message: 'فشل في جلب جهات الاتصال: $e'));
    }
  }

  @override
  Future<Either<Failure, ContactEntity?>> getEmergencyContact(String userId) async {
    try {
      final contact = useMock
          ? await localDataSource.getEmergencyContact(userId)
          : await remoteDataSource.getEmergencyContact(userId);
      return Right(contact);
    } catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب جهة الطوارئ: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> verifyContact(String contactId) async {
    try {
      if (useMock) {
        await localDataSource.verifyContact(contactId);
      } else {
        await remoteDataSource.verifyContact(contactId);
        await localDataSource.verifyContact(contactId);
      }
      
      AppLogger.success('[ContactRepo] تم التحقق من جهة الاتصال: $contactId');
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'فشل في التحقق من جهة الاتصال: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> setEmergencyContact(String contactId) async {
    try {
      if (useMock) {
        await localDataSource.setEmergencyContact(contactId);
      } else {
        await remoteDataSource.setEmergencyContact(contactId);
        await localDataSource.setEmergencyContact(contactId);
      }
      
      AppLogger.info('[ContactRepo] تم تعيين جهة الطوارئ الرئيسية: $contactId');
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'فشل في تعيين جهة الطوارئ: $e'));
    }
  }
}

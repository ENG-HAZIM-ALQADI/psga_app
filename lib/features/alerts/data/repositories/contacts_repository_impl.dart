import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/repositories/base_offline_repository.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/alerts/data/models/contact_model.dart';
import 'package:psga_app/features/alerts/domain/entities/contact_entity.dart';
import 'package:psga_app/features/alerts/domain/repositories/contacts_repository.dart';

/// تنفيذ مستودع جهات الاتصال
class ContactsRepositoryImpl 
    extends BaseOfflineRepository<ContactEntity, ContactModel>
    implements ContactsRepository {
  
  final FirebaseFirestore _firestore;

  ContactsRepositoryImpl({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  // ==================== BaseOfflineRepository Implementation ====================

  @override
  String get boxName => 'contacts';

  @override
  String get collectionName => 'contacts';

  @override
  ContactModel toModel(ContactEntity entity) => ContactModel.fromEntity(entity);

  @override
  ContactEntity toEntity(ContactModel model) => model.toEntity();

  @override
  Map<String, dynamic> toJson(ContactModel model) => model.toJson();

  @override
  ContactModel fromJson(Map<String, dynamic> json) => ContactModel.fromJson(json);

  @override
  String getId(ContactEntity entity) => entity.id;

  @override
  Future<Either<Failure, ContactEntity?>> fetchFromServer(String id) async {
    try {
      AppLogger.info('[ContactsRepository] جلب جهة اتصال من السيرفر: $id');
      
      final doc = await _firestore.collection('contacts').doc(id).get();
      
      if (!doc.exists) {
        AppLogger.info('[ContactsRepository] جهة الاتصال غير موجودة: $id');
        return const Right(null);
      }

      final model = ContactModel.fromJson(doc.data()!);
      final entity = model.toEntity();
      
      // حفظ محلياً
      await saveLocal(entity);
      
      AppLogger.success('[ContactsRepository] تم جلب جهة الاتصال من السيرفر');
      return Right(entity);
    } catch (e, stackTrace) {
      AppLogger.error('[ContactsRepository] فشل جلب جهة الاتصال', e, stackTrace);
      return Left(ServerFailure('فشل جلب جهة الاتصال: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<ContactEntity>>> fetchAllFromServer() async {
    // ✅ يجب تمرير userId - استخدم getContacts بدلاً من هذه الدالة
    AppLogger.warning('[ContactsRepository] fetchAllFromServer بدون userId - استخدم getContacts');
    return const Right([]);
  }

  // ==================== ContactsRepository Implementation ====================

  @override
  Future<Either<Failure, ContactEntity>> addContact(ContactEntity contact) async {
    try {
      AppLogger.info('[ContactsRepository] إضافة جهة اتصال: ${contact.name}');

      // التحقق من صحة البيانات
      if (!contact.isValid) {
        AppLogger.warning('[ContactsRepository] بيانات غير صالحة');
        return const Left(ValidationFailure('بيانات جهة الاتصال غير صالحة'));
      }

      // حفظ باستخدام Offline-First
      return await save(contact);
    } catch (e, stackTrace) {
      AppLogger.error('[ContactsRepository] فشل إضافة جهة اتصال', e, stackTrace);
      return Left(ServerFailure('فشل إضافة جهة الاتصال: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ContactEntity>> updateContact(ContactEntity contact) async {
    try {
      AppLogger.info('[ContactsRepository] تحديث جهة اتصال: ${contact.id}');

      // التحقق من الوجود
      if (!existsLocal(contact.id)) {
        AppLogger.warning('[ContactsRepository] جهة الاتصال غير موجودة');
        return const Left(NotFoundFailure('جهة الاتصال غير موجودة'));
      }

      // تحديث باستخدام Offline-First
      return await update(contact);
    } catch (e, stackTrace) {
      AppLogger.error('[ContactsRepository] فشل تحديث جهة اتصال', e, stackTrace);
      return Left(ServerFailure('فشل التحديث: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteContact(String contactId) async {
    try {
      AppLogger.info('[ContactsRepository] حذف جهة اتصال: $contactId');
      
      // جلب جهة الاتصال أولاً للحصول على userId
      final contactResult = await getLocal(contactId);
      
      String? userId;
      contactResult.fold(
        (failure) {
          AppLogger.warning('[ContactsRepository] لم يتم العثور على userId محلياً');
        },
        (contact) {
          if (contact != null) {
            userId = contact.userId;
          }
        },
      );
      
      // حذف مع تمرير userId كبيانات إضافية
      return await delete(
        contactId,
        additionalData: userId != null ? {'userId': userId} : null,
      );
    } catch (e, stackTrace) {
      AppLogger.error('[ContactsRepository] فشل حذف جهة اتصال', e, stackTrace);
      return Left(ServerFailure('فشل الحذف: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<ContactEntity>>> getContacts(String userId) async {
    try {
      AppLogger.info('[ContactsRepository] جلب جهات اتصال المستخدم: $userId');

      // محاولة الجلب المحلي أولاً
      final localResult = await getAllLocal();

      return localResult.fold(
        (failure) {
          // فشل المحلي، جرب السيرفر
          if (connectivityService.isConnected) {
            return _fetchUserContactsFromServer(userId);
          }
          return Left(failure);
        },
        (allContacts) {
          // تصفية حسب userId
          final userContacts = allContacts
              .where((contact) => contact.userId == userId)
              .toList();

          // إذا كان فارغاً ومتصل، جرب السيرفر
          if (userContacts.isEmpty && connectivityService.isConnected) {
            return _fetchUserContactsFromServer(userId);
          }

          // ترتيب حسب الأولوية
          userContacts.sort((a, b) => a.priority.compareTo(b.priority));

          AppLogger.info('[ContactsRepository] تم جلب ${userContacts.length} جهة اتصال');
          return Right(userContacts);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[ContactsRepository] فشل جلب جهات الاتصال', e, stackTrace);
      return Left(CacheFailure('فشل الجلب: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ContactEntity?>> getContact(String contactId) async {
    try {
      return await get(contactId);
    } catch (e, stackTrace) {
      AppLogger.error('[ContactsRepository] فشل جلب جهة الاتصال', e, stackTrace);
      return Left(CacheFailure('فشل الجلب: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<ContactEntity>>> getEmergencyContacts(String userId) async {
    try {
      AppLogger.info('[ContactsRepository] جلب جهات الاتصال الطارئة');

      final contactsResult = await getContacts(userId);

      return contactsResult.fold(
        (failure) => Left(failure),
        (contacts) {
          final emergencyContacts = contacts
              .where((contact) => contact.isPrimary)
              .toList();

          // ترتيب حسب الأولوية
          emergencyContacts.sort((a, b) => a.priority.compareTo(b.priority));

          AppLogger.info('[ContactsRepository] تم جلب ${emergencyContacts.length} جهة طوارئ');
          return Right(emergencyContacts);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[ContactsRepository] فشل جلب جهات الطوارئ', e, stackTrace);
      return Left(CacheFailure('فشل الجلب: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ContactEntity>> setPrimaryContact({
    required String userId,
    required String contactId,
  }) async {
    try {
      AppLogger.info('[ContactsRepository] تعيين جهة اتصال أساسية: $contactId');

      // الحصول على جهة الاتصال
      final contactResult = await getContact(contactId);

      return contactResult.fold(
        (failure) => Left(failure),
        (contact) async {
          if (contact == null) {
            return const Left(NotFoundFailure('جهة الاتصال غير موجودة'));
          }

          // تحديث لتكون primary
          final updatedContact = ContactModel.fromEntity(contact).copyWith(
            isPrimary: true,
            priority: 1, // أعلى أولوية
            updatedAt: DateTime.now(),
          );

          return await updateContact(updatedContact);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[ContactsRepository] فشل تعيين جهة اتصال أساسية', e, stackTrace);
      return Left(ServerFailure('فشل التعيين: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<ContactEntity>>> reorderContacts({
    required String userId,
    required List<String> contactIds,
  }) async {
    try {
      AppLogger.info('[ContactsRepository] إعادة ترتيب ${contactIds.length} جهة اتصال');

      final List<ContactEntity> updatedContacts = [];

      for (int i = 0; i < contactIds.length; i++) {
        final contactResult = await getContact(contactIds[i]);

        await contactResult.fold(
          (failure) => Future.value(),
          (contact) async {
            if (contact != null) {
              final updated = ContactModel.fromEntity(contact).copyWith(
                priority: i + 1,
                updatedAt: DateTime.now(),
              );

              final result = await updateContact(updated);
              result.fold(
                (failure) => null,
                (updated) => updatedContacts.add(updated),
              );
            }
          },
        );
      }

      AppLogger.success('[ContactsRepository] تم إعادة ترتيب ${updatedContacts.length} جهة');
      return Right(updatedContacts);
    } catch (e, stackTrace) {
      AppLogger.error('[ContactsRepository] فشل إعادة الترتيب', e, stackTrace);
      return Left(ServerFailure('فشل إعادة الترتيب: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<ContactEntity>>> searchContacts({
    required String userId,
    required String query,
  }) async {
    try {
      AppLogger.info('[ContactsRepository] البحث عن: $query');

      final contactsResult = await getContacts(userId);

      return contactsResult.fold(
        (failure) => Left(failure),
        (contacts) {
          final searchQuery = query.toLowerCase();
          final results = contacts.where((contact) {
            return contact.name.toLowerCase().contains(searchQuery) ||
                   contact.phoneNumber.contains(query) ||
                   (contact.email?.toLowerCase().contains(searchQuery) ?? false);
          }).toList();

          AppLogger.info('[ContactsRepository] نتائج البحث: ${results.length}');
          return Right(results);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[ContactsRepository] فشل البحث', e, stackTrace);
      return Left(CacheFailure('فشل البحث: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> verifyPhoneNumber(String phoneNumber) async {
    try {
      // تنظيف الرقم
      final cleaned = phoneNumber.replaceAll(RegExp(r'[\s-]'), '');
      
      // التحقق من الصيغة
      final isValid = RegExp(r'^[+]?[0-9]{10,15}$').hasMatch(cleaned);
      
      AppLogger.info('[ContactsRepository] التحقق من رقم: $phoneNumber → $isValid');
      return Right(isValid);
    } catch (e, stackTrace) {
      AppLogger.error('[ContactsRepository] فشل التحقق', e, stackTrace);
      return Left(ValidationFailure('فشل التحقق: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<ContactEntity>>> importFromDevice(String userId) async {
    try {
      AppLogger.info('[ContactsRepository] استيراد من الجهاز');

      // TODO: تنفيذ الاستيراد من contacts plugin
      // final contacts = await FlutterContacts.getContacts(
      //   withProperties: true,
      // );

      // في الوقت الحالي، نرجع قائمة فارغة
      AppLogger.warning('[ContactsRepository] استيراد من الجهاز غير متاح حالياً');
      return const Right([]);
    } catch (e, stackTrace) {
      AppLogger.error('[ContactsRepository] فشل الاستيراد', e, stackTrace);
      return Left(ServerFailure('فشل الاستيراد: ${e.toString()}'));
    }
  }

  // ==================== Helper Methods ====================

  /// جلب جهات اتصال المستخدم من السيرفر
  Future<Either<Failure, List<ContactEntity>>> _fetchUserContactsFromServer(
    String userId,
  ) async {
    try {
      AppLogger.info('[ContactsRepository] جلب جهات اتصال $userId من Firestore');
      
      final allEntities = <ContactEntity>[];
      
      // 1. جلب من subcollection: /users/{userId}/contacts
      try {
        final subcollectionSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('contacts')
            .get();
        
        if (subcollectionSnapshot.docs.isNotEmpty) {
          AppLogger.info('[ContactsRepository] وُجد ${subcollectionSnapshot.docs.length} جهة اتصال في subcollection');
          
          final subcollectionModels = subcollectionSnapshot.docs
              .map((doc) => ContactModel.fromJson(doc.data()))
              .toList();
          
          allEntities.addAll(subcollectionModels.map((m) => m.toEntity()));
        }
      } catch (e) {
        AppLogger.warning('[ContactsRepository] فشل جلب من subcollection: $e');
      }
      
      // 2. جلب من legacy collection: /contacts
      try {
        final legacySnapshot = await _firestore
            .collection('contacts')
            .where('userId', isEqualTo: userId)
            .get();
        
        if (legacySnapshot.docs.isNotEmpty) {
          AppLogger.info('[ContactsRepository] وُجد ${legacySnapshot.docs.length} جهة اتصال في legacy collection');
          
          final legacyModels = legacySnapshot.docs
              .map((doc) => ContactModel.fromJson(doc.data()))
              .toList();
          
          // تجنب التكرار
          for (final entity in legacyModels.map((m) => m.toEntity())) {
            if (!allEntities.any((e) => e.id == entity.id)) {
              allEntities.add(entity);
            }
          }
        }
      } catch (e) {
        AppLogger.warning('[ContactsRepository] فشل جلب من legacy collection: $e');
      }
      
      if (allEntities.isEmpty) {
        AppLogger.info('[ContactsRepository] لا توجد جهات اتصال للمستخدم $userId');
        return const Right([]);
      }

      // حفظ محلياً
      await saveAllLocal(allEntities);

      // ترتيب حسب الأولوية
      allEntities.sort((a, b) => a.priority.compareTo(b.priority));

      AppLogger.success('[ContactsRepository] تم جلب ${allEntities.length} جهة اتصال من Firestore');
      return Right(allEntities);
    } catch (e, stackTrace) {
      AppLogger.error('[ContactsRepository] فشل جلب جهات الاتصال من Firebase', e, stackTrace);
      return Left(ServerFailure('فشل الجلب: ${e.toString()}'));
    }
  }
}

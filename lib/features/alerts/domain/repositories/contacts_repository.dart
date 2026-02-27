import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/features/alerts/domain/entities/contact_entity.dart';

/// مستودع جهات الاتصال الموثوقة
abstract class ContactsRepository {
  /// إضافة جهة اتصال
  Future<Either<Failure, ContactEntity>> addContact(ContactEntity contact);

  /// تحديث جهة اتصال
  Future<Either<Failure, ContactEntity>> updateContact(ContactEntity contact);

  /// حذف جهة اتصال
  Future<Either<Failure, void>> deleteContact(String contactId);

  /// الحصول على جميع جهات الاتصال للمستخدم
  Future<Either<Failure, List<ContactEntity>>> getContacts(String userId);

  /// الحصول على جهة اتصال واحدة
  Future<Either<Failure, ContactEntity?>> getContact(String contactId);

  /// الحصول على جهات الاتصال الطارئة (isPrimary = true)
  Future<Either<Failure, List<ContactEntity>>> getEmergencyContacts(String userId);

  /// تعيين جهة اتصال كأساسية
  Future<Either<Failure, ContactEntity>> setPrimaryContact({
    required String userId,
    required String contactId,
  });

  /// إعادة ترتيب الأولويات
  Future<Either<Failure, List<ContactEntity>>> reorderContacts({
    required String userId,
    required List<String> contactIds, // مرتبة حسب الأولوية
  });

  /// البحث عن جهات اتصال
  Future<Either<Failure, List<ContactEntity>>> searchContacts({
    required String userId,
    required String query,
  });

  /// التحقق من رقم الهاتف
  Future<Either<Failure, bool>> verifyPhoneNumber(String phoneNumber);

  /// استيراد من جهات اتصال الجهاز
  Future<Either<Failure, List<ContactEntity>>> importFromDevice(String userId);
}

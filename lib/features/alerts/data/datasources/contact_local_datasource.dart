import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/services/storage/hive_boxes.dart';
import '../models/contact_model.dart';

abstract class ContactLocalDataSource {
  Future<ContactModel> addContact(ContactModel contact);
  Future<void> updateContact(ContactModel contact);
  Future<void> deleteContact(String contactId);
  Future<List<ContactModel>> getContacts(String userId);
  Future<ContactModel?> getEmergencyContact(String userId);
  Future<void> verifyContact(String contactId);
  Future<void> setEmergencyContact(String contactId);
}

/// تنفيذ local datasource للاتصالات (Mock - بيانات من الذاكرة)
class MockContactLocalDataSource implements ContactLocalDataSource {
  final List<ContactModel> _contacts = [];

  @override
  Future<ContactModel> addContact(ContactModel contact) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _contacts.add(contact);
    return contact;
  }

  @override
  Future<void> updateContact(ContactModel contact) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final index = _contacts.indexWhere((c) => c.id == contact.id);
    if (index != -1) {
      _contacts[index] = contact;
    }
  }

  @override
  Future<void> deleteContact(String contactId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _contacts.removeWhere((c) => c.id == contactId);
  }

  @override
  Future<List<ContactModel>> getContacts(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _contacts.toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  @override
  Future<ContactModel?> getEmergencyContact(String userId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return _contacts.firstWhere((c) => c.isEmergencyContact);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> verifyContact(String contactId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final index = _contacts.indexWhere((c) => c.id == contactId);
    if (index != -1) {
      final contact = _contacts[index];
      _contacts[index] = ContactModel(
        id: contact.id,
        userId: contact.userId,
        name: contact.name,
        phoneNumber: contact.phoneNumber,
        email: contact.email,
        fcmToken: contact.fcmToken,
        relationship: contact.relationship,
        isEmergencyContact: contact.isEmergencyContact,
        priority: contact.priority,
        canViewLiveLocation: contact.canViewLiveLocation,
        isVerified: true,
        createdAt: contact.createdAt,
      );
    }
  }

  @override
  Future<void> setEmergencyContact(String contactId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    for (int i = 0; i < _contacts.length; i++) {
      final contact = _contacts[i];
      _contacts[i] = ContactModel(
        id: contact.id,
        userId: contact.userId,
        name: contact.name,
        phoneNumber: contact.phoneNumber,
        email: contact.email,
        fcmToken: contact.fcmToken,
        relationship: contact.relationship,
        isEmergencyContact: contact.id == contactId,
        priority: contact.priority,
        canViewLiveLocation: contact.canViewLiveLocation,
        isVerified: contact.isVerified,
        createdAt: contact.createdAt,
      );
    }
  }
}

/// تنفيذ local datasource للاتصالات (Hive)
/// - يحفظ البيانات محلياً في Hive
/// - يضمن عدم فقدان البيانات عند إعادة التشغيل
class HiveContactLocalDataSource implements ContactLocalDataSource {
  @override
  Future<ContactModel> addContact(ContactModel contact) async {
    try {
      final box = Hive.box<ContactModel>(HiveBoxes.contacts);
      await box.put(contact.id, contact);
      debugPrint('💾 [ContactDS] تمت إضافة جهة اتصال في Hive: ${contact.name}');
      return contact;
    } catch (e) {
      debugPrint('💾 [ContactDS] ❌ خطأ في إضافة جهة اتصال: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateContact(ContactModel contact) async {
    try {
      final box = Hive.box<ContactModel>(HiveBoxes.contacts);
      await box.put(contact.id, contact);
      debugPrint('💾 [ContactDS] تم تحديث جهة اتصال في Hive: ${contact.name}');
    } catch (e) {
      debugPrint('💾 [ContactDS] ❌ خطأ في تحديث جهة اتصال: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteContact(String contactId) async {
    try {
      final box = Hive.box<ContactModel>(HiveBoxes.contacts);
      await box.delete(contactId);
      debugPrint('💾 [ContactDS] تم حذف جهة اتصال من Hive: $contactId');
    } catch (e) {
      debugPrint('💾 [ContactDS] ❌ خطأ في حذف جهة اتصال: $e');
      rethrow;
    }
  }

  @override
  Future<List<ContactModel>> getContacts(String userId) async {
    try {
      final box = Hive.box<ContactModel>(HiveBoxes.contacts);
      final contacts = box.values
          .where((c) => c.userId == userId)
          .toList()
        ..sort((a, b) => a.priority.compareTo(b.priority));
      debugPrint('💾 [ContactDS] تم جلب ${contacts.length} جهة اتصال من Hive');
      return contacts;
    } catch (e) {
      debugPrint('💾 [ContactDS] ❌ خطأ في جلب جهات الاتصال: $e');
      return [];
    }
  }

  @override
  Future<ContactModel?> getEmergencyContact(String userId) async {
    try {
      final box = Hive.box<ContactModel>(HiveBoxes.contacts);
      final contact = box.values
          .where((c) => c.userId == userId && c.isEmergencyContact)
          .firstOrNull;
      return contact;
    } catch (e) {
      debugPrint('💾 [ContactDS] ❌ خطأ في جلب جهة الطوارئ: $e');
      return null;
    }
  }

  @override
  Future<void> verifyContact(String contactId) async {
    try {
      final box = Hive.box<ContactModel>(HiveBoxes.contacts);
      final contact = box.get(contactId);
      if (contact != null) {
        final updated = ContactModel(
          id: contact.id,
          userId: contact.userId,
          name: contact.name,
          phoneNumber: contact.phoneNumber,
          email: contact.email,
          fcmToken: contact.fcmToken,
          relationship: contact.relationship,
          isEmergencyContact: contact.isEmergencyContact,
          priority: contact.priority,
          canViewLiveLocation: contact.canViewLiveLocation,
          isVerified: true,
          createdAt: contact.createdAt,
        );
        await box.put(contactId, updated);
        debugPrint('💾 [ContactDS] تم التحقق من جهة اتصال: $contactId');
      }
    } catch (e) {
      debugPrint('💾 [ContactDS] ❌ خطأ في التحقق: $e');
      rethrow;
    }
  }

  @override
  Future<void> setEmergencyContact(String contactId) async {
    try {
      final box = Hive.box<ContactModel>(HiveBoxes.contacts);
      for (final key in box.keys) {
        final contact = box.get(key);
        if (contact != null) {
          final updated = ContactModel(
            id: contact.id,
            userId: contact.userId,
            name: contact.name,
            phoneNumber: contact.phoneNumber,
            email: contact.email,
            fcmToken: contact.fcmToken,
            relationship: contact.relationship,
            isEmergencyContact: contact.id == contactId,
            priority: contact.priority,
            canViewLiveLocation: contact.canViewLiveLocation,
            isVerified: contact.isVerified,
            createdAt: contact.createdAt,
          );
          await box.put(key, updated);
        }
      }
      debugPrint('💾 [ContactDS] تم تعيين جهة الطوارئ: $contactId');
    } catch (e) {
      debugPrint('💾 [ContactDS] ❌ خطأ في تعيين جهة الطوارئ: $e');
      rethrow;
    }
  }
}

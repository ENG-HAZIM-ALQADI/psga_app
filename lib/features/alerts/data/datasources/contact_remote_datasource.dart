import '../models/contact_model.dart';

abstract class ContactRemoteDataSource {
  Future<ContactModel> addContact(ContactModel contact);
  Future<void> updateContact(ContactModel contact);
  Future<void> deleteContact(String contactId);
  Future<List<ContactModel>> getContacts(String userId);
  Future<ContactModel?> getEmergencyContact(String userId);
  Future<void> verifyContact(String contactId);
  Future<void> setEmergencyContact(String contactId);
}

class MockContactRemoteDataSource implements ContactRemoteDataSource {
  final Map<String, ContactModel> _contacts = {};

  @override
  Future<ContactModel> addContact(ContactModel contact) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _contacts[contact.id] = contact;
    return contact;
  }

  @override
  Future<void> updateContact(ContactModel contact) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _contacts[contact.id] = contact;
  }

  @override
  Future<void> deleteContact(String contactId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _contacts.remove(contactId);
  }

  @override
  Future<List<ContactModel>> getContacts(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _contacts.values.where((c) => c.userId == userId).toList();
  }

  @override
  Future<ContactModel?> getEmergencyContact(String userId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return _contacts.values.firstWhere(
        (c) => c.userId == userId && c.isEmergencyContact,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> verifyContact(String contactId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (_contacts.containsKey(contactId)) {
      final contact = _contacts[contactId]!;
      _contacts[contactId] = ContactModel(
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
    for (final key in _contacts.keys) {
      final contact = _contacts[key]!;
      _contacts[key] = ContactModel(
        id: contact.id,
        userId: contact.userId,
        name: contact.name,
        phoneNumber: contact.phoneNumber,
        email: contact.email,
        fcmToken: contact.fcmToken,
        relationship: contact.relationship,
        isEmergencyContact: key == contactId,
        priority: contact.priority,
        canViewLiveLocation: contact.canViewLiveLocation,
        isVerified: contact.isVerified,
        createdAt: contact.createdAt,
      );
    }
  }
}

class FirebaseContactRemoteDataSource implements ContactRemoteDataSource {
  @override
  Future<ContactModel> addContact(ContactModel contact) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return contact;
  }

  @override
  Future<void> updateContact(ContactModel contact) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<void> deleteContact(String contactId) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<List<ContactModel>> getContacts(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [];
  }

  @override
  Future<ContactModel?> getEmergencyContact(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return null;
  }

  @override
  Future<void> verifyContact(String contactId) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<void> setEmergencyContact(String contactId) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }
}

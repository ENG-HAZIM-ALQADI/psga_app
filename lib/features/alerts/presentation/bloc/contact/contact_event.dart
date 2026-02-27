import 'package:equatable/equatable.dart';
import 'package:psga_app/features/alerts/domain/entities/contact_entity.dart';

abstract class ContactEvent extends Equatable {
  const ContactEvent();
  
  @override
  List<Object?> get props => [];
}

class LoadContactsEvent extends ContactEvent {
  final String userId;

  const LoadContactsEvent(this.userId);

  @override
  List<Object> get props => [userId];
}

class LoadEmergencyContactsEvent extends ContactEvent {
  final String userId;

  const LoadEmergencyContactsEvent(this.userId);

  @override
  List<Object> get props => [userId];
}

class AddContactEvent extends ContactEvent {
  final ContactEntity contact;

  const AddContactEvent(this.contact);

  @override
  List<Object> get props => [contact];
}

class UpdateContactEvent extends ContactEvent {
  final ContactEntity contact;

  const UpdateContactEvent(this.contact);

  @override
  List<Object> get props => [contact];
}

class DeleteContactEvent extends ContactEvent {
  final String contactId;

  const DeleteContactEvent(this.contactId);

  @override
  List<Object> get props => [contactId];
}

class SearchContactsEvent extends ContactEvent {
  final String userId;
  final String query;

  const SearchContactsEvent({
    required this.userId,
    required this.query,
  });

  @override
  List<Object> get props => [userId, query];
}

class ReorderContactsEvent extends ContactEvent {
  final String userId;
  final List<String> contactIds;

  const ReorderContactsEvent({
    required this.userId,
    required this.contactIds,
  });

  @override
  List<Object> get props => [userId, contactIds];
}

class SetPrimaryContactEvent extends ContactEvent {
  final String userId;
  final String contactId;

  const SetPrimaryContactEvent({
    required this.userId,
    required this.contactId,
  });

  @override
  List<Object> get props => [userId, contactId];
}

/// التحقق من وجود جهات اتصال للمستخدم
class CheckContactsExistEvent extends ContactEvent {
  final String userId;

  const CheckContactsExistEvent({required this.userId});

  @override
  List<Object> get props => [userId];
}

class VerifyPhoneNumberEvent extends ContactEvent {
  final String phoneNumber;

  const VerifyPhoneNumberEvent(this.phoneNumber);

  @override
  List<Object> get props => [phoneNumber];
}

class ImportContactsFromDeviceEvent extends ContactEvent {
  final String userId;

  const ImportContactsFromDeviceEvent(this.userId);

  @override
  List<Object> get props => [userId];
}


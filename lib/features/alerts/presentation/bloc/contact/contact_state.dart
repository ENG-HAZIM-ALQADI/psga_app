import 'package:equatable/equatable.dart';
import 'package:psga_app/features/alerts/domain/entities/contact_entity.dart';

abstract class ContactState extends Equatable {
  const ContactState();
  
  @override
  List<Object?> get props => [];
}

class ContactInitial extends ContactState {}

class ContactLoading extends ContactState {}

class ContactsLoaded extends ContactState {
  final List<ContactEntity> contacts;

  const ContactsLoaded(this.contacts);

  @override
  List<Object> get props => [contacts];
}

class EmergencyContactsLoaded extends ContactState {
  final List<ContactEntity> contacts;

  const EmergencyContactsLoaded(this.contacts);

  @override
  List<Object> get props => [contacts];
}

class ContactSearchResults extends ContactState {
  final List<ContactEntity> results;
  final String query;

  const ContactSearchResults({
    required this.results,
    required this.query,
  });

  @override
  List<Object> get props => [results, query];
}

class ContactAdded extends ContactState {
  final ContactEntity contact;

  const ContactAdded(this.contact);

  @override
  List<Object> get props => [contact];
}

class ContactUpdated extends ContactState {
  final ContactEntity contact;

  const ContactUpdated(this.contact);

  @override
  List<Object> get props => [contact];
}

class ContactDeleted extends ContactState {
  final String contactId;

  const ContactDeleted(this.contactId);

  @override
  List<Object> get props => [contactId];
}

class ContactsReordered extends ContactState {
  final List<ContactEntity> contacts;

  const ContactsReordered(this.contacts);

  @override
  List<Object> get props => [contacts];
}

class PrimaryContactSet extends ContactState {
  final ContactEntity contact;

  const PrimaryContactSet(this.contact);

  @override
  List<Object> get props => [contact];
}

class PhoneNumberVerified extends ContactState {
  final bool isValid;
  final String phoneNumber;

  const PhoneNumberVerified({
    required this.isValid,
    required this.phoneNumber,
  });

  @override
  List<Object> get props => [isValid, phoneNumber];
}

class ContactsImported extends ContactState {
  final List<ContactEntity> contacts;

  const ContactsImported(this.contacts);

  @override
  List<Object> get props => [contacts];
}

class ContactError extends ContactState {
  final String message;

  const ContactError(this.message);

  @override
  List<Object> get props => [message];
}

/// حالة فحص وجود جهات اتصال
class ContactsExistCheckState extends ContactState {
  final bool hasContacts;
  final int contactCount;

  const ContactsExistCheckState({
    required this.hasContacts,
    required this.contactCount,
  });

  @override
  List<Object> get props => [hasContacts, contactCount];
}


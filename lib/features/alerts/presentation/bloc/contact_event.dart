import 'package:equatable/equatable.dart';
import '../../domain/entities/contact_entity.dart';

abstract class ContactEvent extends Equatable {
  const ContactEvent();

  @override
  List<Object?> get props => [];
}

class LoadContactsEvent extends ContactEvent {
  final String userId;
  
  const LoadContactsEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

class AddContactEvent extends ContactEvent {
  final ContactEntity contact;

  const AddContactEvent(this.contact);

  @override
  List<Object?> get props => [contact];
}

class UpdateContactEvent extends ContactEvent {
  final ContactEntity contact;

  const UpdateContactEvent(this.contact);

  @override
  List<Object?> get props => [contact];
}

class DeleteContactEvent extends ContactEvent {
  final String contactId;

  const DeleteContactEvent(this.contactId);

  @override
  List<Object?> get props => [contactId];
}

class VerifyContactEvent extends ContactEvent {
  final String contactId;

  const VerifyContactEvent(this.contactId);

  @override
  List<Object?> get props => [contactId];
}

class SetEmergencyContactEvent extends ContactEvent {
  final String contactId;

  const SetEmergencyContactEvent(this.contactId);

  @override
  List<Object?> get props => [contactId];
}

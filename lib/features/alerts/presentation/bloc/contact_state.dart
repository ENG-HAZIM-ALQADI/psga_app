import 'package:equatable/equatable.dart';
import '../../domain/entities/contact_entity.dart';

abstract class ContactState extends Equatable {
  const ContactState();

  @override
  List<Object?> get props => [];
}

class ContactsInitial extends ContactState {
  const ContactsInitial();
}

class ContactsLoading extends ContactState {
  const ContactsLoading();
}

class ContactsLoaded extends ContactState {
  final List<ContactEntity> contacts;

  const ContactsLoaded(this.contacts);

  ContactEntity? get emergencyContact {
    try {
      return contacts.firstWhere((c) => c.isEmergencyContact);
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [contacts];
}

class ContactOperationSuccess extends ContactState {
  final String message;

  const ContactOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class ContactsError extends ContactState {
  final String message;

  const ContactsError(this.message);

  @override
  List<Object?> get props => [message];
}

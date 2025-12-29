import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/repositories/contact_repository.dart';
import 'contact_event.dart';
import 'contact_state.dart';

class ContactBloc extends Bloc<ContactEvent, ContactState> {
  final ContactRepository contactRepository;
  String? _currentUserId;

  ContactBloc({required this.contactRepository}) : super(const ContactsInitial()) {
    on<LoadContactsEvent>(_onLoadContacts);
    on<AddContactEvent>(_onAddContact);
    on<UpdateContactEvent>(_onUpdateContact);
    on<DeleteContactEvent>(_onDeleteContact);
    on<VerifyContactEvent>(_onVerifyContact);
    on<SetEmergencyContactEvent>(_onSetEmergencyContact);
  }

  Future<void> _onLoadContacts(
    LoadContactsEvent event,
    Emitter<ContactState> emit,
  ) async {
    _currentUserId = event.userId;
    if (state is! ContactsLoaded) {
      emit(const ContactsLoading());
    }

    final result = await contactRepository.getContacts(event.userId);

    result.fold(
      (failure) => emit(ContactsError(failure.message)),
      (contacts) {
        AppLogger.info('[Contacts] تم تحميل ${contacts.length} جهة اتصال');
        emit(ContactsLoaded(contacts));
      },
    );
  }

  Future<void> _onAddContact(
    AddContactEvent event,
    Emitter<ContactState> emit,
  ) async {
    final result = await contactRepository.addContact(event.contact);

    result.fold(
      (failure) => emit(ContactsError(failure.message)),
      (contact) {
        AppLogger.success('[Contacts] تمت إضافة جهة الاتصال: ${contact.name}');
        // ✅ إعادة تحميل البيانات أولاً قبل عرض رسالة النجاح
        if (_currentUserId != null) {
          add(LoadContactsEvent(_currentUserId!));
        }
        // عرض رسالة النجاح بعد إعادة التحميل
        emit(ContactOperationSuccess('تمت إضافة ${contact.name} بنجاح'));
      },
    );
  }

  Future<void> _onUpdateContact(
    UpdateContactEvent event,
    Emitter<ContactState> emit,
  ) async {
    final result = await contactRepository.updateContact(event.contact);

    result.fold(
      (failure) => emit(ContactsError(failure.message)),
      (_) {
        AppLogger.info('[Contacts] تم تحديث جهة الاتصال: ${event.contact.name}');
        emit(ContactOperationSuccess('تم تحديث ${event.contact.name} بنجاح'));
        if (_currentUserId != null) {
          add(LoadContactsEvent(_currentUserId!));
        }
      },
    );
  }

  Future<void> _onDeleteContact(
    DeleteContactEvent event,
    Emitter<ContactState> emit,
  ) async {
    final result = await contactRepository.deleteContact(event.contactId);

    result.fold(
      (failure) => emit(ContactsError(failure.message)),
      (_) {
        AppLogger.info('[Contacts] تم حذف جهة الاتصال');
        emit(const ContactOperationSuccess('تم حذف جهة الاتصال بنجاح'));
        if (_currentUserId != null) {
          add(LoadContactsEvent(_currentUserId!));
        }
      },
    );
  }

  Future<void> _onVerifyContact(
    VerifyContactEvent event,
    Emitter<ContactState> emit,
  ) async {
    final result = await contactRepository.verifyContact(event.contactId);

    result.fold(
      (failure) => emit(ContactsError(failure.message)),
      (_) {
        AppLogger.success('[Contacts] تم التحقق من جهة الاتصال');
        emit(const ContactOperationSuccess('تم التحقق من جهة الاتصال بنجاح'));
        if (_currentUserId != null) {
          add(LoadContactsEvent(_currentUserId!));
        }
      },
    );
  }

  Future<void> _onSetEmergencyContact(
    SetEmergencyContactEvent event,
    Emitter<ContactState> emit,
  ) async {
    final result = await contactRepository.setEmergencyContact(event.contactId);

    result.fold(
      (failure) => emit(ContactsError(failure.message)),
      (_) {
        AppLogger.info('[Contacts] تم تعيين جهة الطوارئ الرئيسية');
        emit(const ContactOperationSuccess('تم تعيين جهة الطوارئ الرئيسية'));
        if (_currentUserId != null) {
          add(LoadContactsEvent(_currentUserId!));
        }
      },
    );
  }
}

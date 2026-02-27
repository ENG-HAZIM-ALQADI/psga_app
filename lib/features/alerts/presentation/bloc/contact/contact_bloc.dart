import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/alerts/domain/usecases/manage_contacts_usecase.dart';
import 'package:psga_app/features/alerts/domain/usecases/get_contacts_usecase.dart';
import 'package:psga_app/features/alerts/presentation/bloc/contact/contact_event.dart';
import 'package:psga_app/features/alerts/presentation/bloc/contact/contact_state.dart';

class ContactBloc extends Bloc<ContactEvent, ContactState> {
  final AddContactUseCase addContactUseCase;
  final UpdateContactUseCase updateContactUseCase;
  final DeleteContactUseCase deleteContactUseCase;
  final GetContactsUseCase getContactsUseCase;
  final GetEmergencyContactsUseCase getEmergencyContactsUseCase;
  final SetPrimaryContactUseCase setPrimaryContactUseCase;

  ContactBloc({
    required this.addContactUseCase,
    required this.updateContactUseCase,
    required this.deleteContactUseCase,
    required this.getContactsUseCase,
    required this.getEmergencyContactsUseCase,
    required this.setPrimaryContactUseCase,
  }) : super(ContactInitial()) {
    on<LoadContactsEvent>(_onLoadContacts);
    on<LoadEmergencyContactsEvent>(_onLoadEmergencyContacts);
    on<AddContactEvent>(_onAddContact);
    on<UpdateContactEvent>(_onUpdateContact);
    on<DeleteContactEvent>(_onDeleteContact);
    on<SearchContactsEvent>(_onSearchContacts);
    on<SetPrimaryContactEvent>(_onSetPrimaryContact);
    on<CheckContactsExistEvent>(_onCheckContactsExist);
  }

  Future<void> _onLoadContacts(
    LoadContactsEvent event,
    Emitter<ContactState> emit,
  ) async {
    try {
      emit(ContactLoading());

      AppLogger.info('[ContactBloc] جاري تحميل جهات الاتصال');
      final result = await getContactsUseCase(GetContactsParams(userId: event.userId));

      result.fold(
        (failure) {
          AppLogger.error('[ContactBloc] فشل تحميل جهات الاتصال: ${failure.message}');
          emit(ContactError(failure.message));
        },
        (contacts) {
          AppLogger.success('[ContactBloc] تم تحميل ${contacts.length} جهة اتصال');
          emit(ContactsLoaded(contacts));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[ContactBloc] خطأ في جلب جهات الاتصال', e, stackTrace);
      emit(const ContactError('contactsLoadFailed'));
    }
  }

  Future<void> _onLoadEmergencyContacts(
    LoadEmergencyContactsEvent event,
    Emitter<ContactState> emit,
  ) async {
    try {
      emit(ContactLoading());

      AppLogger.info('[ContactBloc] جاري تحميل جهات الطوارئ');
      final result = await getEmergencyContactsUseCase(event.userId);

      result.fold(
        (failure) {
          AppLogger.error('[ContactBloc] فشل تحميل جهات الطوارئ: ${failure.message}');
          emit(ContactError(failure.message));
        },
        (contacts) {
          AppLogger.success('[ContactBloc] تم تحميل ${contacts.length} جهة طوارئ');
          emit(EmergencyContactsLoaded(contacts));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[ContactBloc] خطأ في جلب جهات الطوارئ', e, stackTrace);
      emit(const ContactError('emergencyContactsLoadFailed'));
    }
  }

  Future<void> _onAddContact(
    AddContactEvent event,
    Emitter<ContactState> emit,
  ) async {
    try {
      emit(ContactLoading());

      AppLogger.info('[ContactBloc] جاري إضافة جهة اتصال: ${event.contact.name}');
      final result = await addContactUseCase(event.contact);

      result.fold(
        (failure) {
          AppLogger.error('[ContactBloc] فشل إضافة جهة الاتصال: ${failure.message}');
          emit(ContactError(failure.message));
        },
        (contact) {
          AppLogger.success('[ContactBloc] تمت إضافة جهة الاتصال بنجاح');
          emit(ContactAdded(contact));
          // إعادة تحميل القائمة
          add(LoadContactsEvent(contact.userId));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[ContactBloc] خطأ في إضافة جهة اتصال', e, stackTrace);
      emit(const ContactError('contactAddFailed'));
    }
  }

  Future<void> _onUpdateContact(
    UpdateContactEvent event,
    Emitter<ContactState> emit,
  ) async {
    try {
      emit(ContactLoading());

      AppLogger.info('[ContactBloc] جاري تحديث جهة الاتصال: ${event.contact.id}');
      final result = await updateContactUseCase(event.contact);

      result.fold(
        (failure) {
          AppLogger.error('[ContactBloc] فشل تحديث جهة الاتصال: ${failure.message}');
          emit(ContactError(failure.message));
        },
        (contact) {
          AppLogger.success('[ContactBloc] تم تحديث جهة الاتصال بنجاح');
          emit(ContactUpdated(contact));
          // إعادة تحميل القائمة
          add(LoadContactsEvent(contact.userId));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[ContactBloc] خطأ في تحديث جهة اتصال', e, stackTrace);
      emit(const ContactError('contactUpdateFailed'));
    }
  }

  Future<void> _onDeleteContact(
    DeleteContactEvent event,
    Emitter<ContactState> emit,
  ) async {
    try {
      emit(ContactLoading());

      AppLogger.info('[ContactBloc] جاري حذف جهة الاتصال: ${event.contactId}');
      final result = await deleteContactUseCase(event.contactId);

      result.fold(
        (failure) {
          AppLogger.error('[ContactBloc] فشل حذف جهة الاتصال: ${failure.message}');
          emit(ContactError(failure.message));
        },
        (_) {
          AppLogger.success('[ContactBloc] تم حذف جهة الاتصال بنجاح');
          emit(ContactDeleted(event.contactId));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[ContactBloc] خطأ في حذف جهة اتصال', e, stackTrace);
      emit(const ContactError('contactDeleteFailed'));
    }
  }

  Future<void> _onSearchContacts(
    SearchContactsEvent event,
    Emitter<ContactState> emit,
  ) async {
    try {
      AppLogger.info('[ContactBloc] البحث عن: ${event.query}');

      // إذا كان البحث فارغاً، نحمل الكل
      if (event.query.trim().isEmpty) {
        add(LoadContactsEvent(event.userId));
        return;
      }

      emit(ContactLoading());

      // جلب جميع جهات الاتصال أولاً
      final result = await getContactsUseCase(GetContactsParams(userId: event.userId));

      result.fold(
        (failure) {
          AppLogger.error('[ContactBloc] فشل البحث: ${failure.message}');
          emit(ContactError(failure.message));
        },
        (contacts) {
          // تصفية النتائج محلياً
          final query = event.query.toLowerCase();
          final results = contacts.where((contact) {
            return contact.name.toLowerCase().contains(query) ||
                   contact.phoneNumber.contains(event.query) ||
                   (contact.email?.toLowerCase().contains(query) ?? false);
          }).toList();

          AppLogger.info('[ContactBloc] نتائج البحث: ${results.length}');
          emit(ContactSearchResults(results: results, query: event.query));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[ContactBloc] خطأ في البحث', e, stackTrace);
      emit(const ContactError('contactSearchFailed'));
    }
  }

  Future<void> _onSetPrimaryContact(
    SetPrimaryContactEvent event,
    Emitter<ContactState> emit,
  ) async {
    try {
      emit(ContactLoading());

      AppLogger.info('[ContactBloc] تعيين جهة اتصال أساسية: ${event.contactId}');
      final result = await setPrimaryContactUseCase(
        SetPrimaryContactParams(
          userId: event.userId,
          contactId: event.contactId,
        ),
      );

      result.fold(
        (failure) {
          AppLogger.error('[ContactBloc] فشل تعيين جهة أساسية: ${failure.message}');
          emit(ContactError(failure.message));
        },
        (contact) {
          AppLogger.success('[ContactBloc] تم تعيين جهة الاتصال كأساسية');
          emit(PrimaryContactSet(contact));
          // إعادة تحميل القائمة
          add(LoadContactsEvent(event.userId));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[ContactBloc] خطأ في تعيين جهة أساسية', e, stackTrace);
      emit(const ContactError('setPrimaryContactFailed'));
    }
  }

  /// التحقق من وجود جهات اتصال للمستخدم
  /// Single Responsibility: مسؤول فقط عن فحص وجود جهات اتصال
  /// يُصدر ContactsExistCheckState ثم يُعيد ContactsLoaded لحماية واجهة المستخدم
  Future<void> _onCheckContactsExist(
    CheckContactsExistEvent event,
    Emitter<ContactState> emit,
  ) async {
    try {
      AppLogger.info('[ContactBloc] جاري التحقق من وجود جهات اتصال للمستخدم: ${event.userId}');
      
      final result = await getContactsUseCase(GetContactsParams(userId: event.userId));

      result.fold(
        (failure) {
          AppLogger.error('[ContactBloc] فشل التحقق من جهات الاتصال: ${failure.message}');
          emit(const ContactsExistCheckState(
            hasContacts: false,
            contactCount: 0,
          ));
          // إعادة حالة آمنة لحماية صفحة جهات الاتصال من الاختفاء
          emit(const ContactsLoaded([]));
        },
        (contacts) {
          final hasContacts = contacts.isNotEmpty;
          AppLogger.info('[ContactBloc] ${hasContacts ? "يوجد" : "لا يوجد"} جهات اتصال - العدد: ${contacts.length}');
          
          // إصدار حالة الفحص أولاً ليستقبلها المستمع في route_detail_page
          emit(ContactsExistCheckState(
            hasContacts: hasContacts,
            contactCount: contacts.length,
          ));
          // إعادة ContactsLoaded لحماية صفحة جهات الاتصال من الاختفاء
          emit(ContactsLoaded(contacts));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[ContactBloc] خطأ في التحقق من جهات الاتصال', e, stackTrace);
      emit(const ContactsExistCheckState(
        hasContacts: false,
        contactCount: 0,
      ));
      emit(const ContactsLoaded([]));
    }
  }
}


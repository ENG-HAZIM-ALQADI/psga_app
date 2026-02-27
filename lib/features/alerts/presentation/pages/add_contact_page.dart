import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/features/alerts/domain/entities/contact_entity.dart';
import 'package:psga_app/features/alerts/presentation/bloc/contact/contact_bloc.dart';
import 'package:psga_app/features/alerts/presentation/bloc/contact/contact_event.dart';
import 'package:psga_app/features/alerts/presentation/bloc/contact/contact_state.dart';
import 'package:psga_app/features/alerts/presentation/widgets/contact_form_widget.dart';

/// صفحة إضافة أو تعديل جهة اتصال
class AddContactPage extends StatefulWidget {
  final String userId;
  final ContactEntity? contact; // null = إضافة جديد، وإلا تعديل

  const AddContactPage({
    required this.userId,
    this.contact,
    super.key,
  });

  @override
  State<AddContactPage> createState() => _AddContactPageState();
}

class _AddContactPageState extends State<AddContactPage> {
  bool get _isEditing => widget.contact != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? AppLocalizations.of(context)!.editContact : AppLocalizations.of(context)!.addContact),
      ),
      body: BlocConsumer<ContactBloc, ContactState>(
        listener: (context, state) {
          if (state is ContactAdded) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.contactAdded),
                backgroundColor: AppColors.green,
              ),
            );
            Navigator.pop(context, true);
          } else if (state is ContactUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.contactUpdated),
                backgroundColor: AppColors.green,
              ),
            );
            Navigator.pop(context, true);
          } else if (state is ContactError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          } else if (state is PhoneNumberVerified) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.isValid 
                    ? '✓ رقم الهاتف صحيح' 
                    : '✗ رقم الهاتف غير صحيح',
                ),
                backgroundColor: state.isValid ? AppColors.green : AppColors.gold,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        builder: (context, state) {
          // عرض مؤشر التحميل
          if (state is ContactLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context)!.saving),
                ],
              ),
            );
          }

          // عرض النموذج
          return ContactFormWidget(
            contact: widget.contact,
            onSave: (contact) {
              if (_isEditing) {
                // تعديل جهة اتصال موجودة
                context.read<ContactBloc>().add(
                  UpdateContactEvent(contact),
                );
              } else {
                // إضافة جهة اتصال جديدة
                final newContact = contact.copyWith(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  userId: widget.userId,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                
                context.read<ContactBloc>().add(
                  AddContactEvent(newContact),
                );
              }
            },
            onCancel: () {
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }
}

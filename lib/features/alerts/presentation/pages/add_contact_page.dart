import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../domain/entities/contact_entity.dart';
import '../bloc/contact_bloc.dart';
import '../bloc/contact_event.dart';
import '../bloc/contact_state.dart';

class AddContactPage extends StatefulWidget {
  final ContactEntity? contact;

  const AddContactPage({super.key, this.contact});

  @override
  State<AddContactPage> createState() => _AddContactPageState();
}

class _AddContactPageState extends State<AddContactPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  
  String _relationship = 'friend';
  bool _isEmergencyContact = false;
  bool _canViewLiveLocation = false;
  bool _isLoading = false;

  bool get _isEditing => widget.contact != null;

  final List<Map<String, String>> _relationships = [
    {'value': 'father', 'label': 'أب'},
    {'value': 'mother', 'label': 'أم'},
    {'value': 'spouse', 'label': 'زوج/زوجة'},
    {'value': 'brother', 'label': 'أخ'},
    {'value': 'sister', 'label': 'أخت'},
    {'value': 'friend', 'label': 'صديق'},
    {'value': 'other', 'label': 'أخرى'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.contact != null) {
      _nameController.text = widget.contact!.name;
      _phoneController.text = widget.contact!.phoneNumber;
      _emailController.text = widget.contact!.email ?? '';
      _relationship = widget.contact!.relationship;
      _isEmergencyContact = widget.contact!.isEmergencyContact;
      _canViewLiveLocation = widget.contact!.canViewLiveLocation;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل جهة الاتصال' : 'إضافة جهة اتصال'),
      ),
      body: BlocListener<ContactBloc, ContactState>(
        listener: (context, state) {
          if (state is ContactOperationSuccess) {
            context.pop();
          } else if (state is ContactsError) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CustomTextField(
                controller: _nameController,
                label: 'الاسم',
                prefixIcon: Icons.person,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال الاسم';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _phoneController,
                label: 'رقم الهاتف',
                prefixIcon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال رقم الهاتف';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _emailController,
                label: 'البريد الإلكتروني (اختياري)',
                prefixIcon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _relationship,
                decoration: InputDecoration(
                  labelText: 'العلاقة',
                  prefixIcon: const Icon(Icons.people),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _relationships.map((r) {
                  return DropdownMenuItem(
                    value: r['value'],
                    child: Text(r['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _relationship = value!);
                },
              ),
              const SizedBox(height: 24),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('جهة طوارئ رئيسية'),
                      subtitle: const Text(
                        'سيتم إبلاغ هذه الجهة أولاً عند الطوارئ',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _isEmergencyContact,
                      onChanged: (value) {
                        setState(() => _isEmergencyContact = value);
                      },
                      secondary: Icon(
                        Icons.star,
                        color: _isEmergencyContact ? Colors.amber : Colors.grey,
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('يمكنه رؤية موقعي المباشر'),
                      subtitle: const Text(
                        'السماح لهذه الجهة بمتابعة موقعك',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _canViewLiveLocation,
                      onChanged: (value) {
                        setState(() => _canViewLiveLocation = value);
                      },
                      secondary: Icon(
                        Icons.location_on,
                        color: _canViewLiveLocation ? Colors.blue : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              CustomButton(
                text: _isEditing ? 'حفظ التغييرات' : 'إضافة',
                isLoading: _isLoading,
                onPressed: _submit,
              ),
              if (_isEditing && widget.contact?.isVerified != true) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    context.read<ContactBloc>().add(
                      VerifyContactEvent(widget.contact!.id),
                    );
                  },
                  icon: const Icon(Icons.verified),
                  label: const Text('التحقق من الرقم'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authState = context.read<AuthBloc>().state;
    String userId = 'current_user';
    if (authState is AuthSuccess) {
      userId = authState.user.id;
    }

    final contact = ContactEntity(
      id: widget.contact?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      name: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      relationship: _relationship,
      isEmergencyContact: _isEmergencyContact,
      canViewLiveLocation: _canViewLiveLocation,
      isVerified: widget.contact?.isVerified ?? false,
      priority: widget.contact?.priority ?? 0,
      createdAt: widget.contact?.createdAt ?? DateTime.now(),
    );

    if (_isEditing) {
      context.read<ContactBloc>().add(UpdateContactEvent(contact));
    } else {
      context.read<ContactBloc>().add(AddContactEvent(contact));
    }
  }
}

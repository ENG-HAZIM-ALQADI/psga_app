import 'package:flutter/material.dart';
import 'package:psga_app/core/utils/extensions.dart';
import 'package:psga_app/core/utils/phone_validator.dart';
import 'package:psga_app/features/alerts/domain/entities/contact_entity.dart';
import 'package:psga_app/features/alerts/presentation/widgets/contact_type_selector.dart';

/// نموذج إضافة/تعديل جهة اتصال
class ContactFormWidget extends StatefulWidget {
  final Function(ContactEntity) onSave;
  final ContactEntity? contact; // null = إضافة جديد
  final VoidCallback? onCancel;

  const ContactFormWidget({
    required this.onSave,
    this.contact,
    this.onCancel,
    super.key,
  });

  @override
  State<ContactFormWidget> createState() => _ContactFormWidgetState();
}

class _ContactFormWidgetState extends State<ContactFormWidget> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  
  late ContactType _selectedType;
  late bool _isPrimary;
  late bool _receivesSMS;
  late bool _receivesEmail;
  late bool _receivesPushNotification;
  late bool _allowLocationTracking;

  @override
  void initState() {
    super.initState();
    
    _nameController = TextEditingController(text: widget.contact?.name ?? '');
    _phoneController = TextEditingController(text: widget.contact?.phoneNumber ?? '');
    _emailController = TextEditingController(text: widget.contact?.email ?? '');
    
    _selectedType = widget.contact?.type ?? ContactType.family;
    _isPrimary = widget.contact?.isPrimary ?? false;
    _receivesSMS = widget.contact?.receivesSMS ?? true;
    _receivesEmail = widget.contact?.receivesEmail ?? false;
    _receivesPushNotification = widget.contact?.receivesPushNotification ?? false;
    _allowLocationTracking = widget.contact?.allowLocationTracking ?? false;
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
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // الاسم
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: context.l10n.fullNameLabel,
              hintText: context.l10n.fullNameHint,
              prefixIcon: const Icon(Icons.person),
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return context.l10n.nameRequired;
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // رقم الهاتف
          TextFormField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: context.l10n.phoneNumber,
              hintText: '+966501234567',
              prefixIcon: const Icon(Icons.phone),
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            validator: PhoneValidator.validate,
          ),

          const SizedBox(height: 16),

          // البريد الإلكتروني
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: context.l10n.emailOptionalLabel,
              hintText: 'example@email.com',
              prefixIcon: const Icon(Icons.email),
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                    .hasMatch(value)) {
                  return context.l10n.emailInvalid;
                }
              }
              return null;
            },
          ),

          const SizedBox(height: 24),

          // نوع العلاقة
          ContactTypeSelector(
            selectedType: _selectedType,
            onChanged: (type) {
              setState(() {
                _selectedType = type;
              });
            },
          ),

          const SizedBox(height: 24),

          // جهة اتصال أساسية
          SwitchListTile(
            title: Text(context.l10n.primaryContact),
            subtitle: Text(context.l10n.primaryContactHint),
            value: _isPrimary,
            onChanged: (value) {
              setState(() {
                _isPrimary = value;
              });
            },
            secondary: const Icon(Icons.star),
          ),

          const Divider(),

          // إعدادات الإشعارات
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              context.l10n.notificationSettings,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          CheckboxListTile(
            title: Text(context.l10n.receiveSms),
            subtitle: Text(context.l10n.receiveSmsHint),
            value: _receivesSMS,
            onChanged: (value) {
              setState(() {
                _receivesSMS = value ?? true;
              });
            },
            secondary: const Icon(Icons.sms),
          ),

          CheckboxListTile(
            title: Text(context.l10n.receiveNotifications),
            subtitle: Text(context.l10n.receiveNotificationsHint),
            value: _receivesPushNotification,
            onChanged: (value) {
              setState(() {
                _receivesPushNotification = value ?? false;
              });
            },
            secondary: const Icon(Icons.notifications),
          ),

          CheckboxListTile(
            title: Text(context.l10n.receiveEmail),
            subtitle: Text(context.l10n.receiveEmailHint),
            value: _receivesEmail,
            onChanged: _emailController.text.trim().isEmpty
                ? null
                : (value) {
                    setState(() {
                      _receivesEmail = value ?? false;
                    });
                  },
            secondary: const Icon(Icons.email_outlined),
          ),

          const Divider(),

          // السماح برؤية الموقع
          SwitchListTile(
            title: Text(context.l10n.allowLocationSharing),
            subtitle: Text(context.l10n.allowLocationSharingHint),
            value: _allowLocationTracking,
            onChanged: (value) {
              setState(() {
                _allowLocationTracking = value;
              });
            },
            secondary: const Icon(Icons.location_on),
          ),

          const SizedBox(height: 24),

          // أزرار الحفظ والإلغاء
          Row(
            children: [
              if (widget.onCancel != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    child: Text(context.l10n.cancel),
                  ),
                ),
              if (widget.onCancel != null) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _handleSave,
                  child: Text(widget.contact == null ? context.l10n.addContact : context.l10n.saveChanges),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // تنسيق رقم الهاتف
    final formattedPhone = PhoneValidator.format(_phoneController.text.trim());

    final contact = ContactEntity(
      id: widget.contact?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      userId: widget.contact?.userId ?? '', // سيتم تعيينه من الخارج
      name: _nameController.text.trim(),
      phoneNumber: formattedPhone,
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      type: _selectedType,
      isPrimary: _isPrimary,
      receivesSMS: _receivesSMS,
      receivesEmail: _receivesEmail,
      receivesPushNotification: _receivesPushNotification,
      allowLocationTracking: _allowLocationTracking,
      createdAt: widget.contact?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    widget.onSave(contact);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/core/utils/extensions.dart';
import 'package:psga_app/core/utils/phone_validator.dart';
import 'package:psga_app/features/alerts/domain/entities/contact_entity.dart';
import 'package:url_launcher/url_launcher.dart';
// [تم الحذف]: لم نعد بحاجة لاستيراد primary_contact_badge.dart

/// بطاقة عرض جهة اتصال
class ContactCardWidget extends StatelessWidget {
  final ContactEntity contact;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const ContactCardWidget({
    required this.contact,
    this.onEdit,
    this.onDelete,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الصف الأول: الاسم والشارة
              Row(
                children: [
                  // الأيقونة
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: _getTypeColor(context, contact.type).withOpacity(0.2),
                    child: Icon(
                      _getTypeIcon(contact.type),
                      color: _getTypeColor(context, contact.type),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // الاسم والنوع
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                contact.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // [تم التعديل]: استخدام الدالة المدمجة بدلاً من الويجت الخارجية
                            _buildPrimaryBadge(contact.isPrimary),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              _getTypeText(context, contact.type),
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
                              ),
                            ),
                            // إضافة شارة Emergency إذا كان نوع طوارئ
                            if (contact.type == ContactType.emergency) ...[
                              const SizedBox(width: 8),
                              _buildEmergencyBadge(), // تم فصل هذا الكود في دالة لترتيب الكود
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // أزرار الإجراءات
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'edit' && onEdit != null) {
                        onEdit!();
                      } else if (value == 'delete' && onDelete != null) {
                        onDelete!();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit, size: 20),
                            const SizedBox(width: 8),
                            Text(context.l10n.edit),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete, size: 20, color: AppColors.red),
                            const SizedBox(width: 8),
                            Text(context.l10n.delete, style: const TextStyle(color: AppColors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // معلومات الاتصال
              _buildContactInfo(
                  context,
                  Icons.phone,
                  PhoneValidator.formatForDisplay(contact.phoneNumber),
                      () {
                    _makePhoneCall(contact.phoneNumber);
                  }
              ),

              if (contact.email != null && contact.email!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildContactInfo(context, Icons.email, contact.email!, null),
              ],

              const SizedBox(height: 12),

              // التفضيلات
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (contact.receivesSMS)
                    _buildChip(Icons.sms, 'SMS', Theme.of(context).colorScheme.primary),
                  if (contact.receivesEmail)
                    _buildChip(Icons.email, 'Email', AppColors.green),
                  if (contact.receivesPushNotification)
                    _buildChip(Icons.notifications, 'Push', AppColors.gold),
                ],
              ),

              // زر الاتصال السريع
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _makePhoneCall(contact.phoneNumber),
                  icon: const Icon(Icons.phone, size: 20),
                  label: Text(context.l10n.callEmergency),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getTypeColor(context, contact.type),
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // الدوال المساعدة (Helper Widgets & Methods)
  // ---------------------------------------------------------------------------

  /// [تم الدمج]: دالة بناء شارة جهة الاتصال الأساسية
  /// تم نقل المنطق من ملف primary_contact_badge.dart إلى هنا
  Widget _buildPrimaryBadge(bool isPrimary) {
    if (!isPrimary) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withOpacity(0.8), width: 1),
      ),
      child: Builder(
        builder: (context) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context)!.contactTypePrimary,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// دالة مساعدة لبناء شارة الطوارئ (تم فصلها لتنظيف الكود الأساسي)
  Widget _buildEmergencyBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.red.withOpacity(0.6),
          width: 1,
        ),
      ),
      child: Builder(
        builder: (context) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emergency,
              size: 12,
              color: AppColors.red,
            ),
            const SizedBox(width: 2),
            Text(
              AppLocalizations.of(context)!.contactTypeEmergency,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfo(BuildContext context, IconData icon, String text, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.grey,
              ),
            ),
          ),
          if (onTap != null)
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(BuildContext context, ContactType type) {
    switch (type) {
      case ContactType.emergency:
        return AppColors.red;
      case ContactType.family:
        return Theme.of(context).colorScheme.primary;
      case ContactType.friend:
        return AppColors.green;
      case ContactType.colleague:
        return AppColors.gold;
      case ContactType.security:
        return Theme.of(context).colorScheme.secondary;
      case ContactType.other:
        return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    }
  }

  IconData _getTypeIcon(ContactType type) {
    switch (type) {
      case ContactType.emergency:
        return Icons.emergency;
      case ContactType.family:
        return Icons.family_restroom;
      case ContactType.friend:
        return Icons.people;
      case ContactType.colleague:
        return Icons.work;
      case ContactType.security:
        return Icons.security;
      case ContactType.other:
        return Icons.person;
    }
  }

  String _getTypeText(BuildContext context, ContactType type) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case ContactType.emergency:
        return l10n.contactTypeEmergency;
      case ContactType.family:
        return l10n.contactTypeFamily;
      case ContactType.friend:
        return l10n.contactTypeFriend;
      case ContactType.colleague:
        return l10n.contactTypeColleague;
      case ContactType.security:
        return l10n.contactTypeSecurity;
      case ContactType.other:
        return l10n.contactTypeOther;
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }
}
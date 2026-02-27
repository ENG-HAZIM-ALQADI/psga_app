import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:psga_app/features/alerts/domain/entities/contact_entity.dart';

/// محدد نوع جهة الاتصال
class ContactTypeSelector extends StatelessWidget {
  final ContactType selectedType;
  final Function(ContactType) onChanged;

  const ContactTypeSelector({
    required this.selectedType,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n          = AppLocalizations.of(context)!;
    final colorScheme   = Theme.of(context).colorScheme;
    final isDark        = Theme.of(context).brightness == Brightness.dark;
    final unselectedBg  = isDark ? colorScheme.surfaceContainerHighest : Colors.grey[200]!;
    final unselectedFg  = colorScheme.onSurface.withOpacity(0.75);

    // خريطة الترجمة لأنواع الاتصال
    final typeLabels = {
      ContactType.family:    l10n.contactTypeFamily,
      ContactType.friend:    l10n.contactTypeFriend,
      ContactType.colleague: l10n.contactTypeColleague,
      ContactType.security:  l10n.contactTypeSecurity,
      ContactType.emergency: l10n.contactTypeEmergency,
      ContactType.other:     l10n.contactTypeOther,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.relationship,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ContactType.values.map((type) {
            final isSelected = type == selectedType;

            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getTypeIcon(type),
                    size: 18,
                    color: isSelected ? Colors.white : unselectedFg,
                  ),
                  const SizedBox(width: 6),
                  Text(typeLabels[type] ?? type.name),
                ],
              ),
              selected: isSelected,
              onSelected: (_) => onChanged(type),
              selectedColor: colorScheme.primary,
              backgroundColor: unselectedBg,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : unselectedFg,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? colorScheme.primary : colorScheme.outline.withOpacity(0.4),
                width: 1,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _getTypeIcon(ContactType type) {
    switch (type) {
      case ContactType.family:
        return Icons.family_restroom;
      case ContactType.friend:
        return Icons.people;
      case ContactType.colleague:
        return Icons.work;
      case ContactType.security:
        return Icons.security;
      case ContactType.emergency:
        return Icons.emergency;
      case ContactType.other:
        return Icons.person;
    }
  }
}

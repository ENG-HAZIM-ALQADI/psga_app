import 'package:flutter/material.dart';
import '../../domain/entities/contact_entity.dart';

class ContactCard extends StatelessWidget {
  final ContactEntity contact;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onCall;

  const ContactCard({
    super.key,
    required this.contact,
    this.onTap,
    this.onDelete,
    this.onCall,
  });

  IconData get _relationshipIcon {
    switch (contact.relationship) {
      case 'father':
      case 'mother':
        return Icons.family_restroom;
      case 'spouse':
        return Icons.favorite;
      case 'brother':
      case 'sister':
        return Icons.people;
      case 'friend':
        return Icons.person;
      default:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: contact.isEmergencyContact
                    ? Colors.red.shade100
                    : Colors.blue.shade100,
                child: Icon(
                  _relationshipIcon,
                  color: contact.isEmergencyContact
                      ? Colors.red.shade700
                      : Colors.blue.shade700,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            contact.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (contact.isEmergencyContact)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 14,
                                  color: Colors.red.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'طوارئ',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contact.phoneNumber,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          contact.displayRelationship,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                        if (contact.isVerified) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.verified,
                            size: 16,
                            color: Colors.green.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'متحقق',
                            style: TextStyle(
                              color: Colors.green.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (onCall != null)
                IconButton(
                  onPressed: onCall,
                  icon: const Icon(Icons.call),
                  color: Colors.green,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

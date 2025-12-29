import 'package:equatable/equatable.dart';

class ContactEntity extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String phoneNumber;
  final String? email;
  final String? fcmToken;
  final String relationship;
  final bool isEmergencyContact;
  final int priority;
  final bool canViewLiveLocation;
  final bool isVerified;
  final DateTime createdAt;

  const ContactEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.phoneNumber,
    this.email,
    this.fcmToken,
    required this.relationship,
    this.isEmergencyContact = false,
    this.priority = 0,
    this.canViewLiveLocation = false,
    this.isVerified = false,
    required this.createdAt,
  });

  ContactEntity copyWith({
    String? id,
    String? userId,
    String? name,
    String? phoneNumber,
    String? email,
    String? fcmToken,
    String? relationship,
    bool? isEmergencyContact,
    int? priority,
    bool? canViewLiveLocation,
    bool? isVerified,
    DateTime? createdAt,
  }) {
    return ContactEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      fcmToken: fcmToken ?? this.fcmToken,
      relationship: relationship ?? this.relationship,
      isEmergencyContact: isEmergencyContact ?? this.isEmergencyContact,
      priority: priority ?? this.priority,
      canViewLiveLocation: canViewLiveLocation ?? this.canViewLiveLocation,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get displayRelationship {
    switch (relationship) {
      case 'father':
        return 'أب';
      case 'mother':
        return 'أم';
      case 'spouse':
        return 'زوج/زوجة';
      case 'brother':
        return 'أخ';
      case 'sister':
        return 'أخت';
      case 'friend':
        return 'صديق';
      case 'other':
        return 'أخرى';
      default:
        return relationship;
    }
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        phoneNumber,
        email,
        fcmToken,
        relationship,
        isEmergencyContact,
        priority,
        canViewLiveLocation,
        isVerified,
        createdAt,
      ];
}

import '../../domain/entities/contact_entity.dart';

class ContactModel extends ContactEntity {
  const ContactModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.phoneNumber,
    super.email,
    super.fcmToken,
    required super.relationship,
    super.isEmergencyContact,
    super.priority,
    super.canViewLiveLocation,
    super.isVerified,
    required super.createdAt,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      phoneNumber: json['phoneNumber'] as String,
      email: json['email'] as String?,
      fcmToken: json['fcmToken'] as String?,
      relationship: json['relationship'] as String,
      isEmergencyContact: json['isEmergencyContact'] as bool? ?? false,
      priority: json['priority'] as int? ?? 0,
      canViewLiveLocation: json['canViewLiveLocation'] as bool? ?? false,
      isVerified: json['isVerified'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'fcmToken': fcmToken,
      'relationship': relationship,
      'isEmergencyContact': isEmergencyContact,
      'priority': priority,
      'canViewLiveLocation': canViewLiveLocation,
      'isVerified': isVerified,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ContactModel.fromFirestore(Map<String, dynamic> doc, String docId) {
    return ContactModel.fromJson({...doc, 'id': docId});
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    return json;
  }

  factory ContactModel.fromEntity(ContactEntity entity) {
    return ContactModel(
      id: entity.id,
      userId: entity.userId,
      name: entity.name,
      phoneNumber: entity.phoneNumber,
      email: entity.email,
      fcmToken: entity.fcmToken,
      relationship: entity.relationship,
      isEmergencyContact: entity.isEmergencyContact,
      priority: entity.priority,
      canViewLiveLocation: entity.canViewLiveLocation,
      isVerified: entity.isVerified,
      createdAt: entity.createdAt,
    );
  }
}

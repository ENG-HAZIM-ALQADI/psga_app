import 'package:psga_app/features/alerts/domain/entities/contact_entity.dart';

/// نموذج جهة الاتصال
class ContactModel extends ContactEntity {
  const ContactModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.phoneNumber,
    required super.type,
    required super.createdAt,
    super.email,
    super.isPrimary,
    super.receivesSMS,
    super.receivesEmail,
    super.receivesPushNotification,
    super.priority,
    super.fcmToken,
    super.allowLocationTracking,
    super.updatedAt,
  });

  /// من JSON
  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      phoneNumber: json['phoneNumber'] as String,
      email: json['email'] as String?,
      type: ContactType.values.firstWhere(
        (e) => e.toString() == 'ContactType.${json['type']}',
      ),
      isPrimary: json['isPrimary'] as bool? ?? false,
      receivesSMS: json['receivesSMS'] as bool? ?? true,
      receivesEmail: json['receivesEmail'] as bool? ?? false,
      receivesPushNotification: json['receivesPushNotification'] as bool? ?? false,
      priority: json['priority'] as int? ?? 999,
      fcmToken: json['fcmToken'] as String?,
      allowLocationTracking: json['allowLocationTracking'] as bool? ?? false,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: json['updatedAt'] != null
          ? _parseDateTime(json['updatedAt'])
          : null,
    );
  }

  /// إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'type': type.toString().split('.').last,
      'isPrimary': isPrimary,
      'receivesSMS': receivesSMS,
      'receivesEmail': receivesEmail,
      'receivesPushNotification': receivesPushNotification,
      'priority': priority,
      'fcmToken': fcmToken,
      'allowLocationTracking': allowLocationTracking,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// من Entity
  factory ContactModel.fromEntity(ContactEntity entity) {
    return ContactModel(
      id: entity.id,
      userId: entity.userId,
      name: entity.name,
      phoneNumber: entity.phoneNumber,
      type: entity.type,
      createdAt: entity.createdAt,
      email: entity.email,
      isPrimary: entity.isPrimary,
      receivesSMS: entity.receivesSMS,
      receivesEmail: entity.receivesEmail,
      receivesPushNotification: entity.receivesPushNotification,
      priority: entity.priority,
      fcmToken: entity.fcmToken,
      allowLocationTracking: entity.allowLocationTracking,
      updatedAt: entity.updatedAt,
    );
  }

  /// إلى Entity
  ContactEntity toEntity() => this;

  /// نسخ مع تعديلات (override من parent)
  @override
  ContactModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? phoneNumber,
    String? email,
    ContactType? type,
    bool? isPrimary,
    bool? receivesSMS,
    bool? receivesEmail,
    bool? receivesPushNotification,
    int? priority,
    String? fcmToken,
    bool? allowLocationTracking,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContactModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isPrimary: isPrimary ?? this.isPrimary,
      receivesSMS: receivesSMS ?? this.receivesSMS,
      receivesEmail: receivesEmail ?? this.receivesEmail,
      receivesPushNotification: receivesPushNotification ?? this.receivesPushNotification,
      priority: priority ?? this.priority,
      fcmToken: fcmToken ?? this.fcmToken,
      allowLocationTracking: allowLocationTracking ?? this.allowLocationTracking,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// تحويل DateTime من String أو Firestore Timestamp
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.parse(value);
    if (value is Map) {
      final seconds = value['_seconds'] as int? ?? value['seconds'] as int? ?? 0;
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
    try { return (value as dynamic).toDate() as DateTime; } catch (_) { return DateTime.now(); }
  }
}

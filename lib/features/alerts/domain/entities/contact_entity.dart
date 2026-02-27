import 'package:equatable/equatable.dart';

/// نوع جهة الاتصال
enum ContactType {
  family,    // عائلة
  friend,    // صديق
  colleague, // زميل
  security,  // أمن
  emergency, // طوارئ
  other,     // أخرى
}

/// كيان جهة الاتصال
class ContactEntity extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String phoneNumber;
  final String? email;
  final ContactType type;
  final bool isPrimary;
  final bool receivesSMS;
  final bool receivesEmail;
  final bool receivesPushNotification;
  final int priority; // 1 = أعلى أولوية
  final String? fcmToken; // FCM token للإشعارات
  final bool allowLocationTracking; // السماح برؤية الموقع المباشر
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ContactEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.phoneNumber,
    required this.type,
    required this.createdAt,
    this.email,
    this.isPrimary = false,
    this.receivesSMS = true,
    this.receivesEmail = false,
    this.receivesPushNotification = false,
    this.priority = 999,
    this.fcmToken,
    this.allowLocationTracking = false,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        phoneNumber,
        email,
        type,
        isPrimary,
        receivesSMS,
        receivesEmail,
        receivesPushNotification,
        priority,
        fcmToken,
        allowLocationTracking,
        createdAt,
        updatedAt,
      ];

  /// هل جهة الاتصال صالحة؟
  bool get isValid {
    return name.isNotEmpty && 
           phoneNumber.isNotEmpty &&
           _isValidPhone(phoneNumber);
  }

  /// هل يمكن الاتصال بـ SMS؟
  bool get canSendSMS => receivesSMS && _isValidPhone(phoneNumber);

  /// هل يمكن الاتصال بـ Email؟
  bool get canSendEmail => receivesEmail && email != null && _isValidEmail(email!);

  /// التحقق من صحة رقم الهاتف
  bool _isValidPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s-]'), '');
    return RegExp(r'^[+]?[0-9]{10,15}$').hasMatch(cleaned);
  }

  /// التحقق من صحة البريد الإلكتروني
  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  /// نسخ مع تعديلات
  ContactEntity copyWith({
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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContactEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      email: email ?? this.email,
      isPrimary: isPrimary ?? this.isPrimary,
      receivesSMS: receivesSMS ?? this.receivesSMS,
      receivesEmail: receivesEmail ?? this.receivesEmail,
      receivesPushNotification: receivesPushNotification ?? this.receivesPushNotification,
      priority: priority ?? this.priority,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// الحصول على وصف النوع
  static String getTypeDescription(ContactType type) {
    switch (type) {
      case ContactType.family:
        return 'عائلة';
      case ContactType.friend:
        return 'صديق';
      case ContactType.colleague:
        return 'زميل';
      case ContactType.security:
        return 'أمن';
      case ContactType.emergency:
        return 'طوارئ';
      case ContactType.other:
        return 'أخرى';
    }
  }
}

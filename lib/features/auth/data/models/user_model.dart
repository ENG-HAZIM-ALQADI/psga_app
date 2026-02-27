import 'package:psga_app/features/auth/domain/entities/user_entity.dart';

/// نموذج المستخدم (يمتد من Entity)
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.name,
    required super.emailVerified,
    required super.createdAt,
    super.photoUrl,
    super.phoneNumber,
    super.lastLoginAt,
    super.loginProvider,
  });

  /// من JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      photoUrl: json['photoUrl'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      emailVerified: json['emailVerified'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'] as String)
          : null,
      loginProvider: json['loginProvider'] as String?,
    );
  }

  /// إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'phoneNumber': phoneNumber,
      'emailVerified': emailVerified,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'loginProvider': loginProvider,
    };
  }

  /// من Firebase User
  factory UserModel.fromFirebaseUser(dynamic firebaseUser) {
    // استخراج loginProvider من providerData
    String? provider;
    if (firebaseUser.providerData != null && firebaseUser.providerData.isNotEmpty) {
      provider = firebaseUser.providerData.first.providerId as String?;
    }
    
    return UserModel(
      id: firebaseUser.uid as String,
      email: firebaseUser.email as String,
      name: firebaseUser.displayName as String? ?? '',
      photoUrl: firebaseUser.photoURL as String?,
      phoneNumber: firebaseUser.phoneNumber as String?,
      emailVerified: firebaseUser.emailVerified as bool? ?? false,
      createdAt: firebaseUser.metadata?.creationTime ?? DateTime.now(),
      lastLoginAt: firebaseUser.metadata?.lastSignInTime,
      loginProvider: provider,
    );
  }

  /// من Entity
  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      id: entity.id,
      email: entity.email,
      name: entity.name,
      photoUrl: entity.photoUrl,
      phoneNumber: entity.phoneNumber,
      emailVerified: entity.emailVerified,
      createdAt: entity.createdAt,
      lastLoginAt: entity.lastLoginAt,
      loginProvider: entity.loginProvider,
    );
  }

  /// نسخ مع تعديل
  @override
  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? photoUrl,
    String? phoneNumber,
    bool? emailVerified,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    String? loginProvider,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      emailVerified: emailVerified ?? this.emailVerified,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      loginProvider: loginProvider ?? this.loginProvider,
    );
  }
}

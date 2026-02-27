import 'package:equatable/equatable.dart';

/// كيان المستخدم النقي
class UserEntity extends Equatable {
  final String id;
  final String email;
  final String name;
  final String? photoUrl;
  final String? phoneNumber;
  final bool emailVerified;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final String? loginProvider; // 'password', 'google.com', 'apple.com'

  const UserEntity({
    required this.id,
    required this.email,
    required this.name,
    required this.emailVerified,
    required this.createdAt,
    this.photoUrl,
    this.phoneNumber,
    this.lastLoginAt,
    this.loginProvider,
  });
  
  /// هل المستخدم مسجل بواسطة حساب Google أو Apple؟
  bool get isOAuthUser => loginProvider == 'google.com' || loginProvider == 'apple.com';
  
  /// هل المستخدم لديه كلمة مرور؟
  bool get hasPassword => loginProvider == 'password' || (loginProvider != null && loginProvider!.contains('password'));

  /// نسخ مع تعديل بعض الحقول
  UserEntity copyWith({
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
    return UserEntity(
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

  @override
  List<Object?> get props => [
        id,
        email,
        name,
        photoUrl,
        phoneNumber,
        emailVerified,
        createdAt,
        lastLoginAt,
        loginProvider,
      ];

  @override
  String toString() {
    return 'UserEntity(id: $id, email: $email, name: $name, emailVerified: $emailVerified, loginProvider: $loginProvider)';
  }
}

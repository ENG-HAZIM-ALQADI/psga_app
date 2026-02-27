import 'dart:io';
import 'package:equatable/equatable.dart';

/// أحداث المصادقة
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// التحقق من حالة المصادقة
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

/// تسجيل الدخول
class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginRequested({
    required this.email,
    required this.password,
  });

  @override
  List<Object> get props => [email, password];
}

/// تسجيل حساب جديد
class RegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String name;

  const RegisterRequested({
    required this.email,
    required this.password,
    required this.name,
  });

  @override
  List<Object> get props => [email, password, name];
}

/// تسجيل الخروج
class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}

/// إعادة تعيين كلمة المرور
class ResetPasswordRequested extends AuthEvent {
  final String email;

  const ResetPasswordRequested({required this.email});

  @override
  List<Object> get props => [email];
}

/// إرسال رابط التحقق من البريد
class SendEmailVerificationRequested extends AuthEvent {
  const SendEmailVerificationRequested();
}

/// تحديث الملف الشخصي
class UpdateProfileRequested extends AuthEvent {
  final String? name;
  final String? photoUrl;
  final String? phoneNumber;

  const UpdateProfileRequested({
    this.name,
    this.photoUrl,
    this.phoneNumber,
  });

  @override
  List<Object?> get props => [name, photoUrl, phoneNumber];
}

/// رفع صورة الملف الشخصي
class UploadProfilePhotoRequested extends AuthEvent {
  final File imageFile;

  const UploadProfilePhotoRequested({required this.imageFile});

  @override
  List<Object> get props => [imageFile];
}

/// تغيير كلمة المرور
class ChangePasswordRequested extends AuthEvent {
  final String currentPassword;
  final String newPassword;

  const ChangePasswordRequested({
    required this.currentPassword,
    required this.newPassword,
  });

  @override
  List<Object> get props => [currentPassword, newPassword];
}

/// حذف الحساب
class DeleteAccountRequested extends AuthEvent {
  const DeleteAccountRequested();
}

/// تسجيل الدخول بواسطة Google
class LoginWithGoogleRequested extends AuthEvent {
  const LoginWithGoogleRequested();
}

/// تسجيل الدخول بواسطة Apple
class LoginWithAppleRequested extends AuthEvent {
  const LoginWithAppleRequested();
}

/// الاستماع لتغييرات حالة المصادقة
class AuthStateChangeRequested extends AuthEvent {
  const AuthStateChangeRequested();
}

/// تحديث تقدم رفع الصورة
class UploadProgressUpdated extends AuthEvent {
  final double progress;

  const UploadProgressUpdated(this.progress);

  @override
  List<Object> get props => [progress];
}

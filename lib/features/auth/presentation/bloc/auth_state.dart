import 'package:equatable/equatable.dart';
import 'package:psga_app/features/auth/domain/entities/user_entity.dart';

/// حالات المصادقة
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// الحالة الأولية
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// جاري التحميل
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// مصادق (مسجل دخول)
class Authenticated extends AuthState {
  final UserEntity user;

  const Authenticated(this.user);

  @override
  List<Object> get props => [user];
}

/// غير مصادق (غير مسجل دخول)
class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// خطأ في المصادقة
class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object> get props => [message];
}

/// نجحت عملية (لكن المستخدم غير مسجل دخول)
/// مثل: إرسال رابط إعادة تعيين كلمة المرور
class AuthOperationSuccess extends AuthState {
  final String message;

  const AuthOperationSuccess(this.message);

  @override
  List<Object> get props => [message];
}

/// تم تحديث الملف الشخصي
class ProfileUpdated extends AuthState {
  final UserEntity user;

  const ProfileUpdated(this.user);

  @override
  List<Object> get props => [user];
}

/// تم إرسال رابط التحقق
class EmailVerificationSent extends AuthState {
  const EmailVerificationSent();
}

/// جاري رفع صورة الملف الشخصي
class UploadingPhoto extends AuthState {
  final double progress; // 0.0 to 1.0

  const UploadingPhoto(this.progress);

  @override
  List<Object> get props => [progress];
}

/// تم تغيير كلمة المرور - يتطلب تسجيل خروج
class PasswordChanged extends AuthState {
  const PasswordChanged();
}

import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/features/auth/domain/entities/user_entity.dart';

/// عقد مستودع المصادقة
abstract class AuthRepository {
  /// تسجيل الدخول
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  });

  /// تسجيل حساب جديد
  Future<Either<Failure, UserEntity>> register({
    required String email,
    required String password,
    required String name,
  });

  /// تسجيل الخروج
  Future<Either<Failure, void>> logout();

  /// الحصول على المستخدم الحالي
  Future<Either<Failure, UserEntity?>> getCurrentUser();

  /// إعادة تعيين كلمة المرور
  Future<Either<Failure, void>> resetPassword({
    required String email,
  });

  /// إرسال رابط التحقق من البريد الإلكتروني
  Future<Either<Failure, void>> sendEmailVerification();

  /// تحديث الملف الشخصي
  Future<Either<Failure, UserEntity>> updateProfile({
    String? name,
    String? photoUrl,
    String? phoneNumber,
  });

  /// رفع صورة الملف الشخصي
  Future<Either<Failure, UserEntity>> uploadProfilePhoto(File imageFile);

  /// تغيير كلمة المرور
  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// حذف الحساب
  Future<Either<Failure, void>> deleteAccount();

  /// تسجيل الدخول بواسطة Google
  Future<Either<Failure, UserEntity>> loginWithGoogle();

  /// تسجيل الدخول بواسطة Apple
  Future<Either<Failure, UserEntity>> loginWithApple();

  /// الاستماع لتغييرات حالة المصادقة
  Stream<UserEntity?> get authStateChanges;
  
  /// الاستماع لتقدم رفع الصورة
  Stream<double> get uploadProgress;
}

import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/exceptions.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:psga_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:psga_app/features/auth/domain/entities/user_entity.dart';
import 'package:psga_app/features/auth/domain/repositories/auth_repository.dart';

/// تنفيذ مستودع المصادقة
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  }) async {
    try {
      AppLogger.info('[AuthRepository] محاولة تسجيل الدخول');

      // تسجيل الدخول عبر Firebase
      final user = await remoteDataSource.login(
        email: email,
        password: password,
      );

      // حفظ المستخدم محلياً
      await localDataSource.cacheUser(user);

      AppLogger.success('[AuthRepository] تم تسجيل الدخول بنجاح');
      return Right(user);
    } on AuthException catch (e) {
      AppLogger.error('[AuthRepository] خطأ في المصادقة', e.message);
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      AppLogger.error('[AuthRepository] خطأ في الشبكة', e.message);
      return Left(NetworkFailure(e.message));
    } catch (e) {
      AppLogger.error('[AuthRepository] خطأ غير متوقع', e);
      return const Left(UnknownFailure('حدث خطأ غير متوقع'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      AppLogger.info('[AuthRepository] محاولة التسجيل');

      // التسجيل عبر Firebase
      final user = await remoteDataSource.register(
        email: email,
        password: password,
        name: name,
      );

      // حفظ المستخدم محلياً
      await localDataSource.cacheUser(user);

      AppLogger.success('[AuthRepository] تم التسجيل بنجاح');
      return Right(user);
    } on AuthException catch (e) {
      AppLogger.error('[AuthRepository] خطأ في المصادقة', e.message);
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      AppLogger.error('[AuthRepository] خطأ في الشبكة', e.message);
      return Left(NetworkFailure(e.message));
    } catch (e) {
      AppLogger.error('[AuthRepository] خطأ غير متوقع', e);
      return const Left(UnknownFailure('حدث خطأ غير متوقع'));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      AppLogger.info('[AuthRepository] محاولة تسجيل الخروج');

      // تسجيل الخروج من Firebase
      await remoteDataSource.logout();

      // حذف المستخدم من Cache المحلي
      await localDataSource.clearCache();

      AppLogger.success('[AuthRepository] تم تسجيل الخروج بنجاح');
      return const Right(null);
    } on AuthException catch (e) {
      AppLogger.error('[AuthRepository] خطأ في المصادقة', e.message);
      return Left(AuthFailure(e.message));
    } catch (e) {
      AppLogger.error('[AuthRepository] خطأ غير متوقع', e);
      return const Left(UnknownFailure('حدث خطأ غير متوقع'));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    try {
      AppLogger.info('[AuthRepository] جاري الحصول على المستخدم الحالي');

      // محاولة الحصول على المستخدم من Firebase
      final remoteUser = await remoteDataSource.getCurrentUser();

      if (remoteUser != null) {
        // حفظ/تحديث المستخدم محلياً
        await localDataSource.cacheUser(remoteUser);
        AppLogger.success('[AuthRepository] تم الحصول على المستخدم من Firebase');
        return Right(remoteUser);
      }

      // إذا لم يوجد في Firebase، جرب Cache المحلي
      final cachedUser = await localDataSource.getCachedUser();
      if (cachedUser != null) {
        AppLogger.info('[AuthRepository] تم الحصول على المستخدم من Cache');
        return Right(cachedUser);
      }

      AppLogger.info('[AuthRepository] لا يوجد مستخدم مسجل دخول');
      return const Right(null);
    } on AuthException catch (e) {
      AppLogger.error('[AuthRepository] خطأ في المصادقة', e.message);
      return Left(AuthFailure(e.message));
    } on CacheException catch (e) {
      AppLogger.error('[AuthRepository] خطأ في Cache', e.message);
      // في حالة خطأ Cache، نرجع null
      return const Right(null);
    } catch (e) {
      AppLogger.error('[AuthRepository] خطأ غير متوقع', e);
      return const Left(UnknownFailure('حدث خطأ غير متوقع'));
    }
  }

  @override
  Future<Either<Failure, void>> resetPassword({
    required String email,
  }) async {
    try {
      AppLogger.info('[AuthRepository] محاولة إعادة تعيين كلمة المرور');

      await remoteDataSource.resetPassword(email: email);

      AppLogger.success('[AuthRepository] تم إرسال رابط إعادة التعيين بنجاح');
      return const Right(null);
    } on AuthException catch (e) {
      AppLogger.error('[AuthRepository] خطأ في المصادقة', e.message);
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      AppLogger.error('[AuthRepository] خطأ في الشبكة', e.message);
      return Left(NetworkFailure(e.message));
    } catch (e) {
      AppLogger.error('[AuthRepository] خطأ غير متوقع', e);
      return const Left(UnknownFailure('حدث خطأ غير متوقع'));
    }
  }

  @override
  Future<Either<Failure, void>> sendEmailVerification() async {
    try {
      AppLogger.info('[AuthRepository] محاولة إرسال رابط التحقق');

      await remoteDataSource.sendEmailVerification();

      AppLogger.success('[AuthRepository] تم إرسال رابط التحقق بنجاح');
      return const Right(null);
    } on AuthException catch (e) {
      AppLogger.error('[AuthRepository] خطأ في المصادقة', e.message);
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      AppLogger.error('[AuthRepository] خطأ في الشبكة', e.message);
      return Left(NetworkFailure(e.message));
    } catch (e) {
      AppLogger.error('[AuthRepository] خطأ غير متوقع', e);
      return const Left(UnknownFailure('حدث خطأ غير متوقع'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> updateProfile({
    String? name,
    String? photoUrl,
    String? phoneNumber,
  }) async {
    try {
      AppLogger.info('[AuthRepository] محاولة تحديث الملف الشخصي');

      final user = await remoteDataSource.updateProfile(
        name: name,
        photoUrl: photoUrl,
        phoneNumber: phoneNumber,
      );

      // تحديث Cache المحلي
      await localDataSource.cacheUser(user);

      AppLogger.success('[AuthRepository] تم تحديث الملف الشخصي بنجاح');
      return Right(user);
    } on AuthException catch (e) {
      AppLogger.error('[AuthRepository] خطأ في المصادقة', e.message);
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      AppLogger.error('[AuthRepository] خطأ في الشبكة', e.message);
      return Left(NetworkFailure(e.message));
    } catch (e) {
      AppLogger.error('[AuthRepository] خطأ غير متوقع', e);
      return const Left(UnknownFailure('حدث خطأ غير متوقع'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> uploadProfilePhoto(File imageFile) async {
    try {
      AppLogger.info('[AuthRepository] محاولة رفع صورة الملف الشخصي');

      final user = await remoteDataSource.uploadProfilePhoto(imageFile);

      // تحديث Cache المحلي
      await localDataSource.cacheUser(user);

      AppLogger.success('[AuthRepository] تم رفع الصورة بنجاح');
      return Right(user);
    } on StorageException catch (e) {
      AppLogger.error('[AuthRepository] خطأ في التخزين', e.message);
      return Left(StorageFailure(e.message));
    } on AuthException catch (e) {
      AppLogger.error('[AuthRepository] خطأ في المصادقة', e.message);
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      AppLogger.error('[AuthRepository] خطأ في الشبكة', e.message);
      return Left(NetworkFailure(e.message));
    } catch (e) {
      AppLogger.error('[AuthRepository] خطأ غير متوقع', e);
      return const Left(UnknownFailure('حدث خطأ غير متوقع'));
    }
  }

  @override
  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      AppLogger.info('[AuthRepository] محاولة تغيير كلمة المرور');

      await remoteDataSource.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      AppLogger.success('[AuthRepository] تم تغيير كلمة المرور بنجاح');
      return const Right(null);
    } on AuthException catch (e) {
      AppLogger.error('[AuthRepository] خطأ في المصادقة', e.message);
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      AppLogger.error('[AuthRepository] خطأ في الشبكة', e.message);
      return Left(NetworkFailure(e.message));
    } catch (e) {
      AppLogger.error('[AuthRepository] خطأ غير متوقع', e);
      return const Left(UnknownFailure('حدث خطأ غير متوقع'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAccount() async {
    try {
      AppLogger.info('[AuthRepository] محاولة حذف الحساب');

      // حذف من Firebase (المستخدم وجميع بياناته)
      await remoteDataSource.deleteAccount();

      // حذف جميع البيانات من Cache المحلي
      await localDataSource.clearAllData();

      AppLogger.success('[AuthRepository] تم حذف الحساب وجميع البيانات بنجاح');
      return const Right(null);
    } on AuthException catch (e) {
      AppLogger.error('[AuthRepository] خطأ في المصادقة', e.message);
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      AppLogger.error('[AuthRepository] خطأ في الشبكة', e.message);
      return Left(NetworkFailure(e.message));
    } catch (e) {
      AppLogger.error('[AuthRepository] خطأ غير متوقع', e);
      return const Left(UnknownFailure('حدث خطأ غير متوقع'));
    }
  }

  @override
  Stream<UserEntity?> get authStateChanges {
    return remoteDataSource.authStateChanges.map((user) {
      if (user != null) {
        // حفظ المستخدم محلياً عند التغيير
        localDataSource.cacheUser(user);
      } else {
        // حذف Cache عند تسجيل الخروج
        localDataSource.clearCache();
      }
      return user;
    });
  }
  
  @override
  Stream<double> get uploadProgress {
    return remoteDataSource.uploadProgress;
  }

  @override
  Future<Either<Failure, UserEntity>> loginWithGoogle() async {
    try {
      AppLogger.info('[AuthRepository] محاولة تسجيل الدخول بواسطة Google');

      final user = await remoteDataSource.loginWithGoogle();

      // حفظ المستخدم محلياً
      await localDataSource.cacheUser(user);

      AppLogger.success('[AuthRepository] تم تسجيل الدخول بواسطة Google بنجاح');
      return Right(user);
    } on AuthException catch (e) {
      AppLogger.error('[AuthRepository] خطأ في المصادقة', e.message);
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      AppLogger.error('[AuthRepository] خطأ في الشبكة', e.message);
      return Left(NetworkFailure(e.message));
    } catch (e) {
      AppLogger.error('[AuthRepository] خطأ غير متوقع', e);
      return const Left(UnknownFailure('حدث خطأ غير متوقع'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> loginWithApple() async {
    try {
      AppLogger.info('[AuthRepository] محاولة تسجيل الدخول بواسطة Apple');

      final user = await remoteDataSource.loginWithApple();

      // حفظ المستخدم محلياً
      await localDataSource.cacheUser(user);

      AppLogger.success('[AuthRepository] تم تسجيل الدخول بواسطة Apple بنجاح');
      return Right(user);
    } on AuthException catch (e) {
      AppLogger.error('[AuthRepository] خطأ في المصادقة', e.message);
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      AppLogger.error('[AuthRepository] خطأ في الشبكة', e.message);
      return Left(NetworkFailure(e.message));
    } catch (e) {
      AppLogger.error('[AuthRepository] خطأ غير متوقع', e);
      return const Left(UnknownFailure('حدث خطأ غير متوقع'));
    }
  }
}

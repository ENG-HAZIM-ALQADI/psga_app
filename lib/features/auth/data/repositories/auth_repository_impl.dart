import 'package:flutter/foundation.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/services/sync/sync_manager.dart';
import '../../../../core/services/sync/sync_item.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📌 AuthRepositoryImpl - تطبيق Repository (Data Layer)
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// الهدف من هذا الملف (Data Layer):
/// هذا ملف الجسر بين Domain Layer و Data Sources
/// مسؤوليته:
/// 1. استقبال طلب من Use Case عبر واجهة AuthRepository
/// 2. اختيار: هل نأخذ البيانات من الإنترنت (Firebase) أم من التخزين (Hive)؟
/// 3. معالجة الأخطاء وتحويلها لـ Failures
/// 4. تحويل Models لـ Entities قبل الإرجاع
/// 5. إدارة المزامنة (Sync)
/// 
/// الفرق بين المستويات:
/// Domain Layer: "ما هو الشيء الذي نريده؟" (AuthRepository = واجهة)
/// Data Layer: "كيف نحصل على الشيء الذي نريده؟" (AuthRepositoryImpl = التطبيق)
/// 
/// التسلسل:
/// BLoC → UseCase → AuthRepository (Interface) → AuthRepositoryImpl → DataSources
///
class AuthRepositoryImpl implements AuthRepository {
  /// remoteDataSource: يتعامل مع Firebase (بيانات من السحابة)
  final AuthRemoteDataSource remoteDataSource;
  
  /// localDataSource: يتعامل مع Hive (بيانات محلية)
  final AuthLocalDataSource localDataSource;
  
  /// مدير المزامنة: يعالج قائمة الانتظار للمزامنة
  final SyncManager _syncManager = SyncManager.instance;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, UserEntity>> login(String email, String password) async {
    AppLogger.info('[AuthRepositoryImpl] Login attempt for: $email', name: 'AuthRepositoryImpl');
    
    /// try-catch: نحاول تسجيل الدخول ونتعامل مع الأخطاء
    try {
      /// 1️⃣ استدعاء remoteDataSource (Firebase Auth)
      /// loginWithEmailAndPassword هي دالة async قد تأخذ وقتاً
      /// await = انتظر النتيجة
      /// النتيجة: UserModel (مع JSON serialization)
      final user = await remoteDataSource.loginWithEmailAndPassword(email, password);
      
      /// 2️⃣ حفظ البيانات محلياً في Hive
      /// لماذا؟ لأننا نريد الـ Offline-First
      /// إذا انقطع الإنترنت لاحقاً، يمكننا استخدام البيانات المحفوظة
      await localDataSource.cacheUser(user);
      
      /// 3️⃣ إضافة عملية المزامنة إلى قائمة الانتظار
      /// SyncItem: تمثيل العملية المراد مزامنتها
      /// سيتم محاولة مزامنتها لاحقاً (حتى لو انقطع الاتصال)
      final syncItem = SyncItem(
        createdAt: DateTime.now(),
        id: user.id,
        type: SyncItemType.user,        // نوع البيانات: مستخدم
        action: SyncAction.update,       // نوع العملية: تحديث
        data: user.toJson(),             // البيانات المراد مزامنتها
        localId: user.id,
      );
      await _syncManager.addToQueue(syncItem);
      
      AppLogger.success('[AuthRepositoryImpl] Login successful', name: 'AuthRepositoryImpl');
      
      /// 4️⃣ بدء مزامنة فورية
      /// جلب جميع البيانات المتعلقة بالمستخدم من Firebase
      _syncManager.fullSync();
      
      /// 5️⃣ تحويل UserModel لـ UserEntity قبل الإرجاع
      /// لماذا؟ لأن Domain Layer لا يعرف عن Firebase Annotations
      /// UserEntity نسخة نقية بدون database details
      /// Right() = النجاح في dartz
      return Right(user.toEntity());
      
    /// معالجة استثناءات المصادقة (Firebase Auth errors)
    } on AuthException catch (e) {
      AppLogger.error('[AuthRepositoryImpl] Login failed: ${e.message}', name: 'AuthRepositoryImpl');
      /// تحويل AuthException لـ AuthFailure (من Domain Layer)
      return Left(AuthFailure(message: e.message));
      
    /// معالجة أي خطأ غير متوقع
    } catch (e) {
      AppLogger.error('[AuthRepositoryImpl] Unexpected error: $e', name: 'AuthRepositoryImpl');
      /// تحويل الخطأ العام لـ UnknownFailure
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> register(
    String name,
    String email,
    String password,
  ) async {
    AppLogger.info('[AuthRepositoryImpl] 🔵 بدء التسجيل: $email', name: 'AuthRepositoryImpl');
    debugPrint('🔵 [AuthRepositoryImpl] بدء عملية التسجيل...');
    
    try {
      AppLogger.info('[AuthRepositoryImpl] 🔵 استدعاء Firebase Auth...', name: 'AuthRepositoryImpl');
      debugPrint('🔵 [AuthRepositoryImpl] استدعاء Firebase Auth');
      
      final user = await remoteDataSource.registerWithEmailAndPassword(name, email, password);
      AppLogger.success('[AuthRepositoryImpl] ✅ تم الحصول على UserModel: ${user.email}', name: 'AuthRepositoryImpl');
      debugPrint('✅ [AuthRepositoryImpl] تم الحصول على بيانات المستخدم من Firebase');
      
      AppLogger.info('[AuthRepositoryImpl] 🔵 جاري حفظ المستخدم محلياً في Hive...', name: 'AuthRepositoryImpl');
      debugPrint('💾 [AuthRepositoryImpl] حفظ محلي: بيانات المستخدم في Hive');
      await localDataSource.cacheUser(user);
      AppLogger.success('[AuthRepositoryImpl] ✅ تم حفظ المستخدم محلياً بنجاح', name: 'AuthRepositoryImpl');
      debugPrint('✅ [AuthRepositoryImpl] نجح الحفظ المحلي');
      
      AppLogger.info('[AuthRepositoryImpl] 🔵 جاري إضافة البيانات إلى قائمة المزامنة...', name: 'AuthRepositoryImpl');
      debugPrint('📤 [AuthRepositoryImpl] إضافة إلى قائمة المزامنة مع Firestore');
      
      final syncItem = SyncItem(
        createdAt: DateTime.now(),
        id: user.id,
        type: SyncItemType.user,
        action: SyncAction.create,
        data: user.toJson(),
        localId: user.id,
      );
      await _syncManager.addToQueue(syncItem);
      
      AppLogger.success('[AuthRepositoryImpl] ✅ تم إضافة المستخدم إلى قائمة المزامنة', name: 'AuthRepositoryImpl');
      debugPrint('✅ [AuthRepositoryImpl] سيتم مزامنة البيانات مع Firestore قريباً...');
      
      AppLogger.success('[AuthRepositoryImpl] ✅ تم التسجيل بنجاح (محلي + مُخطط للمزامنة)', name: 'AuthRepositoryImpl');
      return Right(user.toEntity());
    } on AuthException catch (e) {
      AppLogger.error('[AuthRepositoryImpl] ❌ فشل التسجيل: ${e.message}', name: 'AuthRepositoryImpl');
      debugPrint('❌ [AuthRepositoryImpl] خطأ: ${e.message}');
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      AppLogger.error('[AuthRepositoryImpl] ❌ خطأ غير متوقع: $e', name: 'AuthRepositoryImpl');
      debugPrint('❌ [AuthRepositoryImpl] خطأ: $e');
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    AppLogger.info('[AuthRepositoryImpl] Logout attempt', name: 'AuthRepositoryImpl');
    
    try {
      await remoteDataSource.logout();
      await localDataSource.clearCachedUser();
      AppLogger.success('[AuthRepositoryImpl] Logout successful', name: 'AuthRepositoryImpl');
      return const Right(null);
    } on AuthException catch (e) {
      AppLogger.error('[AuthRepositoryImpl] Logout failed: ${e.message}', name: 'AuthRepositoryImpl');
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      AppLogger.error('[AuthRepositoryImpl] Unexpected error: $e', name: 'AuthRepositoryImpl');
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> resetPassword(String email) async {
    AppLogger.info('[AuthRepositoryImpl] Reset password for: $email', name: 'AuthRepositoryImpl');
    
    try {
      await remoteDataSource.resetPassword(email);
      AppLogger.success('[AuthRepositoryImpl] Reset password email sent', name: 'AuthRepositoryImpl');
      return const Right(null);
    } on AuthException catch (e) {
      AppLogger.error('[AuthRepositoryImpl] Reset password failed: ${e.message}', name: 'AuthRepositoryImpl');
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      AppLogger.error('[AuthRepositoryImpl] Unexpected error: $e', name: 'AuthRepositoryImpl');
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    AppLogger.info('[AuthRepositoryImpl] Getting current user', name: 'AuthRepositoryImpl');
    
    try {
      final user = await remoteDataSource.getCurrentUser();
      if (user != null) {
        await localDataSource.cacheUser(user);
        return Right(user.toEntity());
      }
      
      final cachedUser = await localDataSource.getCachedUser();
      if (cachedUser != null) {
        return Right(cachedUser.toEntity());
      }
      
      return const Left(AuthFailure(message: 'لا يوجد مستخدم مسجل'));
    } catch (e) {
      AppLogger.error('[AuthRepositoryImpl] Error getting current user: $e', name: 'AuthRepositoryImpl');
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> sendEmailVerification() async {
    AppLogger.info('[AuthRepositoryImpl] Sending email verification', name: 'AuthRepositoryImpl');
    
    try {
      await remoteDataSource.sendEmailVerification();
      AppLogger.success('[AuthRepositoryImpl] Email verification sent', name: 'AuthRepositoryImpl');
      return const Right(null);
    } on AuthException catch (e) {
      AppLogger.error('[AuthRepositoryImpl] Email verification failed: ${e.message}', name: 'AuthRepositoryImpl');
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      AppLogger.error('[AuthRepositoryImpl] Unexpected error: $e', name: 'AuthRepositoryImpl');
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> verifyPhoneNumber(String phoneNumber) async {
    AppLogger.info('[AuthRepositoryImpl] Verifying phone number: $phoneNumber', name: 'AuthRepositoryImpl');
    AppLogger.warning('[AuthRepositoryImpl] Phone verification not implemented yet', name: 'AuthRepositoryImpl');
    return const Right(null);
  }

  @override
  Stream<UserEntity?> get authStateChanges {
    return remoteDataSource.authStateChanges.map(
      (user) => user?.toEntity(),
    );
  }
}

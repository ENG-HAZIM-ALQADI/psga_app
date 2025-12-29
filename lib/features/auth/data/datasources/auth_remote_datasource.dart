import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../models/user_model.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📌 AuthRemoteDataSource - واجهة مصادر البيانات البعيدة (Data Layer)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف من هذا الملف:
/// تعريف العقد (Contract) لمصادر البيانات البعيدة (Firebase)
///
/// ما هي Remote DataSource؟
/// - معالج الاتصال بـ Firebase
/// - لا تتعامل مع البيانات المحلية (Hive)
/// - تتعامل فقط مع الإنترنت والسحابة
///
/// الفرق بين Abstract و Implementation:
/// AuthRemoteDataSource (Abstract) = الواجهة (العقد)
/// FirebaseAuthRemoteDataSource = التطبيق (Firebase)
/// MockAuthRemoteDataSource = التطبيق الوهمي (للاختبار)
///
/// Dependency Inversion:
/// بدل Repository يستدعي Firebase مباشرة
/// Repository يستدعي واجهة (AuthRemoteDataSource)
/// والتطبيق قد يكون Firebase أو Mock حسب الحاجة

abstract class AuthRemoteDataSource {
  /// 🔐 تسجيل الدخول بـ Email و Password
  /// يرسل الطلب لـ Firebase
  /// النتيجة: UserModel أو Exception
  Future<UserModel> loginWithEmailAndPassword(String email, String password);

  /// 📝 إنشاء حساب جديد
  /// يرسل الطلب لـ Firebase
  /// النتيجة: UserModel جديد
  Future<UserModel> registerWithEmailAndPassword(
      String name, String email, String password);

  /// 🚪 تسجيل الخروج
  /// حذف الجلسة من Firebase
  Future<void> logout();

  /// 🔑 إرسال رابط إعادة تعيين كلمة المرور
  /// Firebase يرسل البريد الإلكتروني
  Future<void> resetPassword(String email);

  /// 👤 الحصول على المستخدم الحالي
  /// يرجع null إذا لا يوجد مستخدم
  Future<UserModel?> getCurrentUser();

  /// 📧 إرسال بريد التحقق من البريد الإلكتروني
  Future<void> sendEmailVerification();

  /// 🔄 Stream: مراقبة تغييرات حالة المصادقة
  /// Firebase يراقب وأي تغيير يُصدر قيمة جديدة
  Stream<UserModel?> get authStateChanges;
}

class FirebaseAuthRemoteDataSource implements AuthRemoteDataSource {
  final FirebaseAuth _firebaseAuth;

  FirebaseAuthRemoteDataSource({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  @override
  Future<UserModel> loginWithEmailAndPassword(
      String email, String password) async {
    AppLogger.info('[Firebase Auth] جاري تسجيل الدخول...',
        name: 'FirebaseAuthRemoteDataSource');

    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw const AuthException(message: 'فشل تسجيل الدخول');
      }

      final userModel = UserModel.fromFirebaseUser(user);
      AppLogger.success('[Firebase Auth] تم تسجيل الدخول بنجاح',
          name: 'FirebaseAuthRemoteDataSource');
      return userModel;
    } on FirebaseException catch (e) {
      AppLogger.error('[Firebase Auth] خطأ: ${e.code}',
          name: 'FirebaseAuthRemoteDataSource');
      throw AuthException(message: _getArabicErrorMessage(e.code));
    } catch (e) {
      AppLogger.error('[Firebase Auth] خطأ غير متوقع: $e',
          name: 'FirebaseAuthRemoteDataSource');
      throw AuthException(message: 'حدث خطأ غير متوقع: $e');
    }
  }

  @override
  Future<UserModel> registerWithEmailAndPassword(
    String name,
    String email,
    String password,
  ) async {
    AppLogger.info('[Firebase Auth] جاري إنشاء حساب جديد...',
        name: 'FirebaseAuthRemoteDataSource');

    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw const AuthException(message: 'فشل إنشاء الحساب');
      }

      await user.updateDisplayName(name);
      await user.sendEmailVerification();

      final updatedUser = _firebaseAuth.currentUser;
      final userModel = UserModel.fromFirebaseUser(updatedUser!);

      AppLogger.success('[Firebase Auth] تم إنشاء الحساب بنجاح',
          name: 'FirebaseAuthRemoteDataSource');
      return userModel;
    } on FirebaseException catch (e) {
      AppLogger.error('[Firebase Auth] خطأ: ${e.code}',
          name: 'FirebaseAuthRemoteDataSource');
      throw AuthException(message: _getArabicErrorMessage(e.code));
    } catch (e) {
      AppLogger.error('[Firebase Auth] خطأ غير متوقع: $e',
          name: 'FirebaseAuthRemoteDataSource');
      throw AuthException(message: 'حدث خطأ غير متوقع: $e');
    }
  }

  @override
  Future<void> logout() async {
    AppLogger.info('[Firebase Auth] جاري تسجيل الخروج...',
        name: 'FirebaseAuthRemoteDataSource');

    try {
      await _firebaseAuth.signOut();
      AppLogger.success('[Firebase Auth] تم تسجيل الخروج بنجاح',
          name: 'FirebaseAuthRemoteDataSource');
    } catch (e) {
      AppLogger.error('[Firebase Auth] خطأ في تسجيل الخروج: $e',
          name: 'FirebaseAuthRemoteDataSource');
      throw const AuthException(message: 'فشل تسجيل الخروج');
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    AppLogger.info('[Firebase Auth] جاري إرسال رابط إعادة التعيين...',
        name: 'FirebaseAuthRemoteDataSource');

    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      AppLogger.success('[Firebase Auth] تم إرسال رابط إعادة التعيين',
          name: 'FirebaseAuthRemoteDataSource');
    } on FirebaseException catch (e) {
      AppLogger.error('[Firebase Auth] خطأ: ${e.code}',
          name: 'FirebaseAuthRemoteDataSource');
      throw AuthException(message: _getArabicErrorMessage(e.code));
    } catch (e) {
      AppLogger.error('[Firebase Auth] خطأ غير متوقع: $e',
          name: 'FirebaseAuthRemoteDataSource');
      throw const AuthException(message: 'حدث خطأ غير متوقع');
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    AppLogger.info('[Firebase Auth] جاري جلب المستخدم الحالي...',
        name: 'FirebaseAuthRemoteDataSource');

    final user = _firebaseAuth.currentUser;
    if (user != null) {
      return UserModel.fromFirebaseUser(user);
    }
    return null;
  }

  @override
  Future<void> sendEmailVerification() async {
    AppLogger.info('[Firebase Auth] جاري إرسال بريد التحقق...',
        name: 'FirebaseAuthRemoteDataSource');

    try {
      final user = _firebaseAuth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        AppLogger.success('[Firebase Auth] تم إرسال بريد التحقق',
            name: 'FirebaseAuthRemoteDataSource');
      }
    } catch (e) {
      AppLogger.error('[Firebase Auth] خطأ في إرسال بريد التحقق: $e',
          name: 'FirebaseAuthRemoteDataSource');
      throw const AuthException(message: 'فشل إرسال بريد التحقق');
    }
  }

  @override
  Stream<UserModel?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map((user) {
      if (user != null) {
        return UserModel.fromFirebaseUser(user);
      }
      return null;
    });
  }

  String _getArabicErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'لم يتم العثور على حساب بهذا البريد الإلكتروني';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة';
      case 'email-already-in-use':
        return 'هذا البريد الإلكتروني مسجل بالفعل';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة';
      case 'user-disabled':
        return 'هذا الحساب معطل';
      case 'too-many-requests':
        return 'محاولات كثيرة جداً، يرجى المحاولة لاحقاً';
      case 'operation-not-allowed':
        return 'هذه العملية غير مسموحة';
      case 'network-request-failed':
        return 'فشل الاتصال بالإنترنت';
      case 'invalid-credential':
        return 'بيانات الاعتماد غير صالحة';
      case 'account-exists-with-different-credential':
        return 'يوجد حساب بهذا البريد مع طريقة تسجيل مختلفة';
      default:
        return 'حدث خطأ غير متوقع ($code)';
    }
  }
}

class MockAuthRemoteDataSource implements AuthRemoteDataSource {
  UserModel? _currentUser;
  final _authStateController = StreamController<UserModel?>.broadcast();

  @override
  Future<UserModel> loginWithEmailAndPassword(
      String email, String password) async {
    AppLogger.info('[Mock Auth] جاري تسجيل الدخول...',
        name: 'MockAuthRemoteDataSource');

    await Future.delayed(const Duration(milliseconds: 500));

    if (password.length < 6) {
      throw const AuthException(message: 'كلمة المرور غير صحيحة');
    }

    final user = UserModel(
      id: 'mock_user_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      displayName: email.split('@').first,
      isEmailVerified: true,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );

    _currentUser = user;
    _authStateController.add(user);

    AppLogger.success('[Mock Auth] تم تسجيل الدخول بنجاح',
        name: 'MockAuthRemoteDataSource');
    return user;
  }

  @override
  Future<UserModel> registerWithEmailAndPassword(
    String name,
    String email,
    String password,
  ) async {
    AppLogger.info('[Mock Auth] جاري إنشاء حساب جديد...',
        name: 'MockAuthRemoteDataSource');

    await Future.delayed(const Duration(milliseconds: 500));

    final user = UserModel(
      id: 'mock_user_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      displayName: name,
      isEmailVerified: false,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );

    _currentUser = user;
    _authStateController.add(user);

    AppLogger.success('[Mock Auth] تم إنشاء الحساب بنجاح',
        name: 'MockAuthRemoteDataSource');
    return user;
  }

  @override
  Future<void> logout() async {
    AppLogger.info('[Mock Auth] جاري تسجيل الخروج...',
        name: 'MockAuthRemoteDataSource');

    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = null;
    _authStateController.add(null);
    AppLogger.success('[Mock Auth] تم تسجيل الخروج بنجاح',
        name: 'MockAuthRemoteDataSource');
  }

  @override
  Future<void> resetPassword(String email) async {
    AppLogger.info('[Mock Auth] جاري إرسال رابط إعادة التعيين...',
        name: 'MockAuthRemoteDataSource');

    await Future.delayed(const Duration(milliseconds: 500));
    AppLogger.success('[Mock Auth] تم إرسال رابط إعادة التعيين',
        name: 'MockAuthRemoteDataSource');
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    AppLogger.info('[Mock Auth] جاري جلب المستخدم الحالي...',
        name: 'MockAuthRemoteDataSource');
    return _currentUser;
  }

  @override
  Future<void> sendEmailVerification() async {
    AppLogger.info('[Mock Auth] جاري إرسال بريد التحقق...',
        name: 'MockAuthRemoteDataSource');
    await Future.delayed(const Duration(milliseconds: 500));
    AppLogger.success('[Mock Auth] تم إرسال بريد التحقق',
        name: 'MockAuthRemoteDataSource');
  }

  @override
  Stream<UserModel?> get authStateChanges => _authStateController.stream;
}

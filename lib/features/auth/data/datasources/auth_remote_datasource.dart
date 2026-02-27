import 'dart:io';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:psga_app/core/errors/exceptions.dart' hide FirebaseException;
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/auth/data/models/user_model.dart';

/// مصدر البيانات البعيد للمصادقة (Firebase)
abstract class AuthRemoteDataSource {
  /// تسجيل الدخول
  Future<UserModel> login({
    required String email,
    required String password,
  });

  /// تسجيل حساب جديد
  Future<UserModel> register({
    required String email,
    required String password,
    required String name,
  });

  /// تسجيل الخروج
  Future<void> logout();

  /// الحصول على المستخدم الحالي
  Future<UserModel?> getCurrentUser();

  /// إعادة تعيين كلمة المرور
  Future<void> resetPassword({required String email});

  /// إرسال رابط التحقق من البريد الإلكتروني
  Future<void> sendEmailVerification();

  /// تحديث الملف الشخصي
  Future<UserModel> updateProfile({
    String? name,
    String? photoUrl,
    String? phoneNumber,
  });

  /// رفع صورة الملف الشخصي
  Future<UserModel> uploadProfilePhoto(File imageFile);

  /// Stream لمراقبة تقدم رفع الصورة
  Stream<double> get uploadProgress;

  /// تغيير كلمة المرور
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// حذف الحساب
  Future<void> deleteAccount();

  /// تسجيل الدخول بواسطة Google
  Future<UserModel> loginWithGoogle();

  /// تسجيل الدخول بواسطة Apple
  Future<UserModel> loginWithApple();

  /// الاستماع لتغييرات حالة المصادقة
  Stream<UserModel?> get authStateChanges;
}

/// تنفيذ مصدر البيانات البعيد
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth firebaseAuth;
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  
  // StreamController لمراقبة تقدم الرفع
  final StreamController<double> _uploadProgressController = StreamController<double>.broadcast();

  AuthRemoteDataSourceImpl({
    required this.firebaseAuth,
    required this.firestore,
    required this.storage,
  });
  
  @override
  Stream<double> get uploadProgress => _uploadProgressController.stream;

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      AppLogger.info('[AuthRemoteDataSource] جاري تسجيل الدخول في Firebase: $email');

      final userCredential = await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw AuthException('تسجيل الدخول فشل - لم يتم إرجاع مستخدم');
      }

      // تحديث آخر تسجيل دخول في Firestore
      await _updateLastLogin(userCredential.user!.uid);

      // جلب البيانات الكاملة من Firestore
      final userDoc = await firestore.collection('users').doc(userCredential.user!.uid).get();
      if (!userDoc.exists) {
        throw AuthException('المستخدم غير موجود في قاعدة البيانات');
      }

      final userData = userDoc.data()!;
      final user = UserModel.fromJson(userData);

      AppLogger.success('[AuthRemoteDataSource] تم تسجيل الدخول بنجاح');
      return user;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('[AuthRemoteDataSource] خطأ Firebase Auth', e.message);
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      AppLogger.error('[AuthRemoteDataSource] خطأ غير متوقع', e);
      throw AuthException('حدث خطأ أثناء تسجيل الدخول');
    }
  }

  @override
  Future<UserModel> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      AppLogger.info('[AuthRemoteDataSource] جاري التسجيل في Firebase: $email');

      final userCredential = await firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw AuthException('التسجيل فشل - لم يتم إرجاع مستخدم');
      }

      AppLogger.success('[AuthRemoteDataSource] تم إنشاء حساب Firebase: ${userCredential.user!.uid}');

      // تحديث الاسم
      await userCredential.user!.updateDisplayName(name);
      await userCredential.user!.reload();

      AppLogger.info('[AuthRemoteDataSource] تم تحديث الاسم: $name');

      final updatedUser = firebaseAuth.currentUser;
      if (updatedUser == null) {
        throw AuthException('فشل في تحديث المستخدم');
      }

      final user = UserModel.fromFirebaseUser(updatedUser);

      AppLogger.info('[AuthRemoteDataSource] جاري حفظ البيانات في Firestore');

      // حفظ بيانات المستخدم في Firestore
      await _saveUserToFirestore(user);

      AppLogger.success('[AuthRemoteDataSource] تم حفظ البيانات في Firestore');

      // إرسال رابط التحقق بعد حفظ البيانات في Firestore
      try {
        AppLogger.info('[AuthRemoteDataSource] جاري إرسال رابط التحقق بعد التسجيل...');
        // انتظار قصير للتأكد من استقرار Firebase Auth
        await Future.delayed(const Duration(milliseconds: 500));
        await sendEmailVerification();
        AppLogger.success('[AuthRemoteDataSource] تم إرسال رابط التحقق');
      } catch (e) {
        AppLogger.warning('[AuthRemoteDataSource] فشل إرسال رابط التحقق: $e');
        // لا نوقف العملية إذا فشل الإرسال
      }

      AppLogger.success('[AuthRemoteDataSource] تم التسجيل بنجاح');
      return user;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('[AuthRemoteDataSource] خطأ Firebase Auth', e.message);
      throw _handleFirebaseAuthException(e);
    } catch (e, stackTrace) {
      AppLogger.error('[AuthRemoteDataSource] خطأ غير متوقع', e, stackTrace);
      throw AuthException('حدث خطأ أثناء التسجيل: ${e.toString()}');
    }
  }

  @override
  Future<void> logout() async {
    try {
      AppLogger.info('[AuthRemoteDataSource] جاري تسجيل الخروج من Firebase');
      await firebaseAuth.signOut();
      AppLogger.success('[AuthRemoteDataSource] تم تسجيل الخروج بنجاح');
    } catch (e) {
      AppLogger.error('[AuthRemoteDataSource] خطأ أثناء تسجيل الخروج', e);
      throw AuthException('حدث خطأ أثناء تسجيل الخروج');
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final firebaseUser = firebaseAuth.currentUser;
      
      if (firebaseUser == null) {
        AppLogger.info('[AuthRemoteDataSource] لا يوجد مستخدم مسجل دخول');
        return null;
      }

      // إعادة تحميل المستخدم من Firebase Auth للحصول على emailVerified الحقيقي
      await firebaseUser.reload();
      final freshFirebaseUser = firebaseAuth.currentUser;
      if (freshFirebaseUser == null) return null;

      // جلب البيانات الإضافية من Firestore (loginProvider، phoneNumber، إلخ)
      try {
        final userDoc = await firestore.collection('users').doc(freshFirebaseUser.uid).get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          // بناء UserModel من Firestore مع تجاوز emailVerified بقيمة Firebase Auth الحقيقية
          final userModel = UserModel.fromJson(userData).copyWith(
            emailVerified: freshFirebaseUser.emailVerified,
          );
          AppLogger.info('[AuthRemoteDataSource] تم جلب المستخدم - emailVerified: ${freshFirebaseUser.emailVerified}');

          // تحديث emailVerified في Firestore إذا تغيّر (المستخدم أكمل التحقق)
          final storedVerified = userData['emailVerified'] as bool? ?? false;
          if (freshFirebaseUser.emailVerified && !storedVerified) {
            AppLogger.info('[AuthRemoteDataSource] تحديث emailVerified في Firestore');
            await firestore.collection('users').doc(freshFirebaseUser.uid).update({
              'emailVerified': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          return userModel;
        }
      } catch (e) {
        AppLogger.warning('[AuthRemoteDataSource] فشل جلب البيانات من Firestore، استخدام Firebase Auth', e);
      }

      // Fallback: استخدام Firebase Auth فقط
      return UserModel.fromFirebaseUser(freshFirebaseUser);
    } catch (e) {
      AppLogger.error('[AuthRemoteDataSource] خطأ في الحصول على المستخدم', e);
      throw AuthException('حدث خطأ في الحصول على المستخدم');
    }
  }

  @override
  Future<void> resetPassword({required String email}) async {
    try {
      AppLogger.info('[AuthRemoteDataSource] جاري إرسال رابط إعادة تعيين كلمة المرور: $email');
      await firebaseAuth.sendPasswordResetEmail(email: email);
      AppLogger.success('[AuthRemoteDataSource] تم إرسال الرابط بنجاح');
    } on FirebaseAuthException catch (e) {
      AppLogger.error('[AuthRemoteDataSource] خطأ Firebase Auth', e.message);
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      AppLogger.error('[AuthRemoteDataSource] خطأ غير متوقع', e);
      throw AuthException('حدث خطأ أثناء إرسال رابط إعادة التعيين');
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      final user = firebaseAuth.currentUser;
      if (user == null) {
        throw AuthException('لا يوجد مستخدم مسجل دخول');
      }

      // إعادة تحميل للتأكد من الحالة الفعلية
      await user.reload();
      final freshUser = firebaseAuth.currentUser;

      if (freshUser == null) {
        throw AuthException('لا يوجد مستخدم مسجل دخول');
      }

      if (freshUser.emailVerified) {
        AppLogger.info('[AuthRemoteDataSource] البريد الإلكتروني مُحقق بالفعل');
        return;
      }

      AppLogger.info('[AuthRemoteDataSource] جاري إرسال رابط التحقق للبريد: ${freshUser.email}');

      // إرسال بريد التحقق القياسي (بدون ActionCodeSettings لتجنب مشاكل Dynamic Links)
      await freshUser.sendEmailVerification();

      AppLogger.success('[AuthRemoteDataSource] تم إرسال رابط التحقق بنجاح');
    } on FirebaseAuthException catch (e) {
      AppLogger.error('[AuthRemoteDataSource] خطأ Firebase Auth', e.message);
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      AppLogger.error('[AuthRemoteDataSource] خطأ غير متوقع في إرسال رابط التحقق', e);
      throw AuthException('حدث خطأ أثناء إرسال رابط التحقق');
    }
  }

  @override
  Future<UserModel> updateProfile({
    String? name,
    String? photoUrl,
    String? phoneNumber,
  }) async {
    try {
      final user = firebaseAuth.currentUser;
      if (user == null) {
        throw AuthException('لا يوجد مستخدم مسجل دخول');
      }

      AppLogger.info('[AuthRemoteDataSource] جاري تحديث الملف الشخصي');

      // تحديث في Firebase Auth
      if (name != null) {
        await user.updateDisplayName(name);
      }

      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }

      // تحديث في Firestore
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (name != null) updateData['name'] = name;
      if (photoUrl != null) updateData['photoUrl'] = photoUrl;
      if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;
      
      await firestore.collection('users').doc(user.uid).update(updateData);

      // جلب البيانات المحدثة من Firestore (للحصول على phoneNumber وباقي الحقول)
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        throw AuthException('المستخدم غير موجود في قاعدة البيانات');
      }

      final userData = userDoc.data()!;
      final userModel = UserModel.fromJson(userData);

      AppLogger.success('[AuthRemoteDataSource] تم تحديث الملف الشخصي بنجاح');
      return userModel;
    } catch (e) {
      AppLogger.error('[AuthRemoteDataSource] خطأ في تحديث الملف الشخصي', e);
      throw AuthException('حدث خطأ في تحديث الملف الشخصي');
    }
  }

  @override
  Future<UserModel> uploadProfilePhoto(File imageFile) async {
    try {
      final user = firebaseAuth.currentUser;
      if (user == null) {
        throw AuthException('لا يوجد مستخدم مسجل دخول');
      }

      AppLogger.info('[AuthRemoteDataSource] جاري رفع صورة الملف الشخصي');
      
      // بدء التحميل - 0%
      _uploadProgressController.add(0.0);

      // 1. حذف الصورة القديمة من Storage إذا كانت موجودة
      if (user.photoURL != null && user.photoURL!.contains('profile_images')) {
        try {
          AppLogger.info('[AuthRemoteDataSource] حذف الصورة القديمة...');
          final oldPhotoRef = storage.refFromURL(user.photoURL!);
          await oldPhotoRef.delete();
          AppLogger.success('[AuthRemoteDataSource] تم حذف الصورة القديمة');
        } catch (e) {
          AppLogger.warning('[AuthRemoteDataSource] فشل حذف الصورة القديمة (قد لا تكون موجودة)', e);
        }
      }
      
      _uploadProgressController.add(0.1); // 10% - حذف الصورة القديمة

      // 2. رفع الصورة الجديدة
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${user.uid}_$timestamp.jpg';
      final storageRef = storage.ref().child('profile_images/${user.uid}/$fileName');

      AppLogger.info('[AuthRemoteDataSource] رفع الصورة إلى: profile_images/${user.uid}/$fileName');
      
      // رفع مع metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedBy': user.uid,
          'uploadedAt': timestamp.toString(),
        },
      );
      
      final uploadTask = storageRef.putFile(imageFile, metadata);
      
      // الاستماع للتقدم وإرساله للـ Stream
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.totalBytes > 0) {
          final progress = 0.1 + (snapshot.bytesTransferred / snapshot.totalBytes) * 0.8; // 10% to 90%
          _uploadProgressController.add(progress);
          AppLogger.info('[AuthRemoteDataSource] تقدم الرفع: ${(progress * 100).toStringAsFixed(1)}%');
        }
      });
      
      // انتظار اكتمال الرفع
      final snapshot = await uploadTask;
      
      _uploadProgressController.add(0.9); // 90% - اكتمل الرفع

      // 3. الحصول على رابط التحميل
      final downloadUrl = await snapshot.ref.getDownloadURL();
      AppLogger.success('[AuthRemoteDataSource] تم رفع الصورة بنجاح: $downloadUrl');

      // 4. تحديث الملف الشخصي
      await user.updatePhotoURL(downloadUrl);
      await user.reload();
      
      final updatedUser = firebaseAuth.currentUser;
      if (updatedUser == null) {
        throw AuthException('فشل في تحديث المستخدم');
      }

      final userModel = UserModel.fromFirebaseUser(updatedUser);

      // 5. تحديث في Firestore
      await firestore.collection('users').doc(userModel.id).update({
        'photoUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _uploadProgressController.add(1.0); // 100% - اكتمل كل شيء
      AppLogger.success('[AuthRemoteDataSource] تم تحديث الملف الشخصي مع الصورة الجديدة');
      return userModel;
    } on FirebaseException catch (e) {
      _uploadProgressController.add(0.0); // إعادة تعيين عند الخطأ
      AppLogger.error('[AuthRemoteDataSource] خطأ Firebase', e.message);
      throw StorageException('فشل رفع الصورة: ${e.message}');
    } catch (e) {
      _uploadProgressController.add(0.0); // إعادة تعيين عند الخطأ
      AppLogger.error('[AuthRemoteDataSource] خطأ في رفع الصورة', e);
      throw StorageException('حدث خطأ في رفع الصورة');
    }
  }

  @override
  Stream<UserModel?> get authStateChanges {
    return firebaseAuth.authStateChanges().map((firebaseUser) {
      if (firebaseUser == null) {
        return null;
      }
      return UserModel.fromFirebaseUser(firebaseUser);
    });
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = firebaseAuth.currentUser;
      if (user == null || user.email == null) {
        throw AuthException('لا يوجد مستخدم مسجل دخول');
      }

      // تحديد ما إذا كان المستخدم يضيف كلمة مرور أم يغيرها
      final bool isAddingPassword = currentPassword.isEmpty;
      
      AppLogger.info(
        isAddingPassword
            ? '[AuthRemoteDataSource] جاري إضافة كلمة مرور للحساب'
            : '[AuthRemoteDataSource] جاري تغيير كلمة المرور'
      );

      // إذا كان لديه كلمة مرور حالية، يجب إعادة المصادقة
      if (!isAddingPassword) {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);
      }

      // تحديث/إضافة كلمة المرور
      await user.updatePassword(newPassword);
      
      // تحديث loginProvider في Firestore ليشمل password
      await firestore.collection('users').doc(user.uid).update({
        'loginProvider': 'password',
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      AppLogger.success(
        isAddingPassword
            ? '[AuthRemoteDataSource] تم إضافة كلمة المرور بنجاح'
            : '[AuthRemoteDataSource] تم تغيير كلمة المرور بنجاح'
      );
    } on FirebaseAuthException catch (e) {
      AppLogger.error('[AuthRemoteDataSource] خطأ Firebase Auth', e.message);
      
      if (e.code == 'wrong-password') {
        throw AuthException('كلمة المرور الحالية غير صحيحة');
      } else if (e.code == 'requires-recent-login') {
        throw AuthException('يرجى تسجيل الدخول مرة أخرى لتغيير كلمة المرور');
      } else if (e.code == 'weak-password') {
        throw AuthException('كلمة المرور ضعيفة جداً');
      }
      
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      AppLogger.error('[AuthRemoteDataSource] خطأ غير متوقع', e);
      throw AuthException('حدث خطأ أثناء تغيير/إضافة كلمة المرور');
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final user = firebaseAuth.currentUser;
      if (user == null) {
        throw AuthException('لا يوجد مستخدم مسجل دخول');
      }

      AppLogger.info('[AuthRemoteDataSource] جاري حذف الحساب: ${user.uid}');

      // حذف بيانات المستخدم من Firestore أولاً
      await _deleteUserDataFromFirestore(user.uid);

      // حذف الحساب من Firebase Auth
      await user.delete();

      AppLogger.success('[AuthRemoteDataSource] تم حذف الحساب بنجاح');
    } on FirebaseAuthException catch (e) {
      AppLogger.error('[AuthRemoteDataSource] خطأ Firebase Auth', e.message);
      
      if (e.code == 'requires-recent-login') {
        throw AuthException('يرجى تسجيل الدخول مرة أخرى لحذف الحساب');
      }
      
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      AppLogger.error('[AuthRemoteDataSource] خطأ غير متوقع', e);
      throw AuthException('حدث خطأ أثناء حذف الحساب');
    }
  }

  @override
  Future<UserModel> loginWithGoogle() async {
    try {
      AppLogger.info('[AuthRemoteDataSource] جاري تسجيل الدخول بواسطة Google');

      // بدء عملية تسجيل الدخول
      final GoogleSignIn googleSignIn = GoogleSignIn();
      
      // ✅ إزالة signOut() لتجنب Concurrent operations
      // فقط تحقق من الحساب الحالي
      final currentUser = googleSignIn.currentUser;
      if (currentUser != null) {
        AppLogger.info('[AuthRemoteDataSource] يوجد حساب محفوظ: ${currentUser.email}');
      }
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        AppLogger.info('[AuthRemoteDataSource] تم إلغاء تسجيل الدخول بواسطة Google');
        throw AuthException('تم إلغاء تسجيل الدخول بواسطة Google');
      }

      AppLogger.info('[AuthRemoteDataSource] تم اختيار حساب Google: ${googleUser.email}');

      // الحصول على بيانات المصادقة
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw AuthException('فشل الحصول على بيانات المصادقة من Google');
      }

      AppLogger.info('[AuthRemoteDataSource] تم الحصول على tokens من Google');

      // إنشاء Credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // تسجيل الدخول في Firebase
      final userCredential = await firebaseAuth.signInWithCredential(credential);

      if (userCredential.user == null) {
        throw AuthException('فشل تسجيل الدخول في Firebase');
      }

      AppLogger.success('[AuthRemoteDataSource] تم تسجيل الدخول في Firebase: ${userCredential.user!.uid}');

      final user = UserModel.fromFirebaseUser(userCredential.user!);

      // حفظ بيانات المستخدم في Firestore (أو تحديثها)
      await _saveUserToFirestore(user);
      await _updateLastLogin(user.id);

      // جلب البيانات المحدثة من Firestore (للحصول على loginProvider الصحيح)
      final userDoc = await firestore.collection('users').doc(user.id).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final updatedUser = UserModel.fromJson(userData);
        AppLogger.success('[AuthRemoteDataSource] تم تسجيل الدخول بواسطة Google بنجاح');
        return updatedUser;
      }

      AppLogger.success('[AuthRemoteDataSource] تم تسجيل الدخول بواسطة Google بنجاح');
      return user;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('[AuthRemoteDataSource] خطأ Firebase Auth', e.message);
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      AppLogger.error('[AuthRemoteDataSource] خطأ غير متوقع', e);
      
      // معالجة خاصة لأخطاء Google Sign In
      final errorMessage = e.toString();
      if (errorMessage.contains('PlatformException') || errorMessage.contains('sign_in')) {
        throw AuthException('فشل الاتصال بـ Google. تأكد من إعدادات SHA-1');
      } else if (errorMessage.contains('network')) {
        throw NetworkException('لا يوجد اتصال بالإنترنت');
      }
      
      throw AuthException('حدث خطأ أثناء تسجيل الدخول بواسطة Google: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> loginWithApple() async {
    try {
      AppLogger.info('[AuthRemoteDataSource] جاري تسجيل الدخول بواسطة Apple');

      // بدء عملية تسجيل الدخول
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // إنشاء OAuth Credential
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // تسجيل الدخول في Firebase
      final userCredential = await firebaseAuth.signInWithCredential(oauthCredential);

      if (userCredential.user == null) {
        throw AuthException('فشل تسجيل الدخول بواسطة Apple');
      }

      // تحديث الاسم إذا كان متوفراً من Apple
      if (appleCredential.givenName != null || appleCredential.familyName != null) {
        final fullName = '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'.trim();
        if (fullName.isNotEmpty) {
          await userCredential.user!.updateDisplayName(fullName);
          await userCredential.user!.reload();
        }
      }

      final updatedUser = firebaseAuth.currentUser;
      if (updatedUser == null) {
        throw AuthException('فشل في تحديث المستخدم');
      }

      final user = UserModel.fromFirebaseUser(updatedUser);

      // حفظ بيانات المستخدم في Firestore
      await _saveUserToFirestore(user);
      await _updateLastLogin(user.id);

      AppLogger.success('[AuthRemoteDataSource] تم تسجيل الدخول بواسطة Apple بنجاح');
      return user;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('[AuthRemoteDataSource] خطأ Firebase Auth', e.message);
      throw _handleFirebaseAuthException(e);
    } on SignInWithAppleAuthorizationException catch (e) {
      AppLogger.error('[AuthRemoteDataSource] خطأ Apple Sign In', e.message);
      
      if (e.code == AuthorizationErrorCode.canceled) {
        throw AuthException('تم إلغاء تسجيل الدخول بواسطة Apple');
      }
      
      throw AuthException('حدث خطأ أثناء تسجيل الدخول بواسطة Apple');
    } catch (e) {
      AppLogger.error('[AuthRemoteDataSource] خطأ غير متوقع', e);
      throw AuthException('حدث خطأ أثناء تسجيل الدخول بواسطة Apple');
    }
  }

  /// حذف بيانات المستخدم من Firestore
  Future<void> _deleteUserDataFromFirestore(String userId) async {
    try {
      AppLogger.info('[AuthRemoteDataSource] بدء حذف جميع بيانات المستخدم: $userId');

      // ──────────────────────────────────────────────────────────
      // حذف subcollections أولاً (Firestore لا يحذفها تلقائياً)
      // ──────────────────────────────────────────────────────────
      
      // حذف /users/{userId}/routes
      try {
        final subRoutesSnap = await firestore
            .collection('users').doc(userId).collection('routes').get();
        for (var doc in subRoutesSnap.docs) { await doc.reference.delete(); }
        AppLogger.info('[AuthRemoteDataSource] ✅ تم حذف ${subRoutesSnap.docs.length} مسار من subcollection');
      } catch (e) {
        AppLogger.warning('[AuthRemoteDataSource] فشل حذف subcollection routes: $e');
      }
      
      // حذف /users/{userId}/contacts
      try {
        final subContactsSnap = await firestore
            .collection('users').doc(userId).collection('contacts').get();
        for (var doc in subContactsSnap.docs) { await doc.reference.delete(); }
        AppLogger.info('[AuthRemoteDataSource] ✅ تم حذف ${subContactsSnap.docs.length} جهة اتصال من subcollection');
      } catch (e) {
        AppLogger.warning('[AuthRemoteDataSource] فشل حذف subcollection contacts: $e');
      }
      
      // حذف /users/{userId}/trips
      try {
        final subTripsSnap = await firestore
            .collection('users').doc(userId).collection('trips').get();
        for (var doc in subTripsSnap.docs) { await doc.reference.delete(); }
        AppLogger.info('[AuthRemoteDataSource] ✅ تم حذف ${subTripsSnap.docs.length} رحلة من subcollection');
      } catch (e) {
        AppLogger.warning('[AuthRemoteDataSource] فشل حذف subcollection trips: $e');
      }
      
      // حذف /users/{userId}/alerts
      try {
        final subAlertsSnap = await firestore
            .collection('users').doc(userId).collection('alerts').get();
        for (var doc in subAlertsSnap.docs) { await doc.reference.delete(); }
        AppLogger.info('[AuthRemoteDataSource] ✅ تم حذف ${subAlertsSnap.docs.length} تنبيه من subcollection');
      } catch (e) {
        AppLogger.warning('[AuthRemoteDataSource] فشل حذف subcollection alerts: $e');
      }
      
      // حذف /users/{userId}/alert_configs
      try {
        final subConfigsSnap = await firestore
            .collection('users').doc(userId).collection('alert_configs').get();
        for (var doc in subConfigsSnap.docs) { await doc.reference.delete(); }
        AppLogger.info('[AuthRemoteDataSource] ✅ تم حذف إعدادات التنبيهات من subcollection');
      } catch (e) {
        AppLogger.warning('[AuthRemoteDataSource] فشل حذف subcollection alert_configs: $e');
      }

      // ──────────────────────────────────────────────────────────
      // حذف وثيقة المستخدم الرئيسية (بعد subcollections)
      // ──────────────────────────────────────────────────────────
      await firestore.collection('users').doc(userId).delete();
      AppLogger.info('[AuthRemoteDataSource] ✅ تم حذف وثيقة المستخدم');

      // ──────────────────────────────────────────────────────────
      // حذف legacy collections
      // ──────────────────────────────────────────────────────────
      
      // حذف جميع الرحلات من legacy
      final tripsSnapshot = await firestore
          .collection('trips')
          .where('userId', isEqualTo: userId)
          .get();
      for (var doc in tripsSnapshot.docs) { await doc.reference.delete(); }
      AppLogger.info('[AuthRemoteDataSource] ✅ تم حذف ${tripsSnapshot.docs.length} رحلة من legacy');

      // حذف جميع المسارات من legacy
      final routesSnapshot = await firestore
          .collection('routes')
          .where('userId', isEqualTo: userId)
          .get();
      for (var doc in routesSnapshot.docs) { await doc.reference.delete(); }
      AppLogger.info('[AuthRemoteDataSource] ✅ تم حذف ${routesSnapshot.docs.length} مسار من legacy');

      // حذف جميع التنبيهات من legacy
      final alertsSnapshot = await firestore
          .collection('alerts')
          .where('userId', isEqualTo: userId)
          .get();
      for (var doc in alertsSnapshot.docs) { await doc.reference.delete(); }
      AppLogger.info('[AuthRemoteDataSource] ✅ تم حذف ${alertsSnapshot.docs.length} تنبيه من legacy');

      // حذف جهات الاتصال من legacy
      final contactsSnapshot = await firestore
          .collection('contacts')
          .where('userId', isEqualTo: userId)
          .get();
      for (var doc in contactsSnapshot.docs) { await doc.reference.delete(); }
      AppLogger.info('[AuthRemoteDataSource] ✅ تم حذف ${contactsSnapshot.docs.length} جهة اتصال من legacy');

      // حذف إعدادات التنبيهات
      try {
        await firestore.collection('alert_configs').doc('${userId}_config').delete();
        AppLogger.info('[AuthRemoteDataSource] ✅ تم حذف إعدادات التنبيهات');
      } catch (e) {
        // تجاهل خطأ الصلاحيات - قد لا يكون لدى المستخدم إعدادات
        AppLogger.warning('[AuthRemoteDataSource] تخطي حذف إعدادات التنبيهات (قد تكون غير موجودة)', e);
      }

      // حذف صور الملف الشخصي من Storage
      try {
        final storageRef = storage.ref().child('profile_images/$userId');
        final listResult = await storageRef.listAll();
        for (var item in listResult.items) {
          await item.delete();
        }
        AppLogger.info('[AuthRemoteDataSource] ✅ تم حذف ${listResult.items.length} صورة من Storage');
      } catch (e) {
        AppLogger.warning('[AuthRemoteDataSource] فشل حذف الصور من Storage', e);
      }

      AppLogger.success('[AuthRemoteDataSource] ✅ تم حذف جميع بيانات المستخدم من Firestore بنجاح');
    } catch (e, stackTrace) {
      AppLogger.error('[AuthRemoteDataSource] فشل حذف البيانات من Firestore', e, stackTrace);
      // نستمر في حذف الحساب حتى لو فشل حذف البيانات
    }
  }

  /// حفظ بيانات المستخدم في Firestore
  Future<void> _saveUserToFirestore(UserModel user) async {
    try {
      AppLogger.info('[AuthRemoteDataSource] جاري حفظ المستخدم في Firestore: ${user.id}');
      
      final data = user.toJson();
      AppLogger.info('[AuthRemoteDataSource] بيانات المستخدم: $data');
      
      await firestore.collection('users').doc(user.id).set(
        data,
        SetOptions(merge: true), // merge لتحديث البيانات الموجودة فقط
      );
      
      AppLogger.success('[AuthRemoteDataSource] ✅ تم حفظ المستخدم في Firestore بنجاح');
    } catch (e, stackTrace) {
      AppLogger.error('[AuthRemoteDataSource] ❌ فشل حفظ المستخدم في Firestore', e, stackTrace);
      // نرمي Exception لأن هذه عملية مهمة
      throw Exception('فشل حفظ البيانات في Firestore: ${e.toString()}');
    }
  }

  /// تحديث آخر تسجيل دخول
  Future<void> _updateLastLogin(String userId) async {
    try {
      await firestore.collection('users').doc(userId).update({
        'lastLoginAt': DateTime.now().toIso8601String(),
      });
      AppLogger.info('[AuthRemoteDataSource] تم تحديث آخر تسجيل دخول');
    } catch (e) {
      AppLogger.warning('[AuthRemoteDataSource] فشل تحديث آخر تسجيل دخول', e);
      // لا نرمي exception هنا
    }
  }

  /// معالجة استثناءات Firebase Auth
  Exception _handleFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return AuthException('لا يوجد مستخدم بهذا البريد الإلكتروني');
      case 'wrong-password':
        return AuthException('كلمة المرور غير صحيحة');
      case 'email-already-in-use':
        return AuthException('البريد الإلكتروني مستخدم بالفعل');
      case 'invalid-email':
        return AuthException('البريد الإلكتروني غير صحيح');
      case 'weak-password':
        return AuthException('كلمة المرور ضعيفة جداً');
      case 'user-disabled':
        return AuthException('هذا الحساب معطل');
      case 'too-many-requests':
        return AuthException('عدد كبير من المحاولات. يرجى المحاولة لاحقاً');
      case 'operation-not-allowed':
        return AuthException('هذه العملية غير مسموحة');
      case 'network-request-failed':
        return NetworkException('فشل الاتصال بالشبكة');
      case 'invalid-credential':
        return AuthException('بيانات الدخول غير صحيحة');
      case 'account-exists-with-different-credential':
        return AuthException('البريد الإلكتروني مرتبط بطريقة تسجيل دخول أخرى');
      case 'credential-already-in-use':
        return AuthException('هذه البيانات مرتبطة بحساب آخر');
      default:
        // تجنب عرض رسائل تقنية خام للمستخدم
        final message = e.message ?? '';
        final isNetworkError = message.contains('I/O error') ||
            message.contains('Connection reset') ||
            message.contains('network');
        if (isNetworkError) {
          return NetworkException('فشل الاتصال بالشبكة. تحقق من الإنترنت');
        }
        return AuthException('حدث خطأ غير متوقع. يرجى المحاولة لاحقاً');
    }
  }
}

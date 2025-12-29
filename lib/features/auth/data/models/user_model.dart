import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../domain/entities/user_entity.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📌 UserModel - نموذج المستخدم (Data Layer)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف من هذا الملف:
/// تمثيل المستخدم في Data Layer مع القدرة على التسلسل (JSON)
/// 
/// الفرق بين UserEntity و UserModel:
/// 
/// UserEntity (Domain Layer):
/// - نقي، بدون annotations
/// - لا يعرف عن Firebase
/// - يستخدم في الأعمال المنطقية
/// 
/// UserModel (Data Layer): ← هنا
/// - يرث من UserEntity (نفس البيانات)
/// - يضيف factory methods للتحويل:
///   - fromJson(): JSON → UserModel (من Hive أو Firebase)
///   - toJson(): UserModel → JSON (للحفظ)
///   - fromEntity(): UserEntity → UserModel (من Domain)
///   - toEntity(): UserModel → UserEntity (للـ Domain)
///   - fromFirebaseUser(): Firebase User → UserModel
/// 
/// المبدأ:
/// **Adapter Pattern**
/// Model = محول بين تمثيلات مختلفة
///
/// التسلسل:
/// Firebase User Object
///   ↓ fromFirebaseUser()
/// UserModel
///   ↓ toJson()
/// {id: "...", email: "...", ...} (JSON)
///   ↓ حفظ في Hive
/// Hive Storage
///   ↓ fromJson()
/// UserModel
///   ↓ toEntity()
/// UserEntity ← تُرسل للـ Domain & UI
///

/// 🔹 UserModel يرث من UserEntity
/// معناه: UserModel = UserEntity + factory methods
/// يمكن استخدام UserModel في أي مكان يتوقع UserEntity
/// (لكننا نحولها بـ toEntity() قبل الإرسال للـ Domain)
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.displayName,
    super.phoneNumber,
    super.photoUrl,
    required super.isEmailVerified,
    required super.createdAt,
    super.lastLoginAt,
  });

  /// 🔧 factory: تحويل JSON → UserModel
  /// يستقبل: Map من JSON (من Firebase Firestore أو Hive)
  /// يعيد: UserModel
  /// 
  /// مثال JSON:
  /// ```json
  /// {
  ///   "id": "abc123",
  ///   "email": "user@example.com",
  ///   "displayName": "Ahmed Ali",
  ///   "createdAt": "2024-01-15T10:30:00.000Z",
  ///   "isEmailVerified": true
  /// }
  /// ```
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String?,
      photoUrl: json['photoUrl'] as String?,
      isEmailVerified: json['isEmailVerified'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'] as String)
          : null,
    );
  }

  /// 🔧 toJson: تحويل UserModel → JSON
  /// يستقبل: this (UserModel)
  /// يعيد: Map<String, dynamic>
  /// 
  /// الاستخدام:
  /// ```
  /// final json = userModel.toJson();
  /// // إرسل للـ Firebase
  /// // أو احفظ في Hive
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'isEmailVerified': isEmailVerified,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  /// 🔧 factory: تحويل UserEntity → UserModel
  /// يستقبل: UserEntity (من Domain Layer)
  /// يعيد: UserModel (Data Layer)
  /// 
  /// الحالة: نحتاج حفظ بيانات من Domain في Data Layer
  /// ```
  /// final entity = UserEntity(...);
  /// final model = UserModel.fromEntity(entity);
  /// await repository.save(model);
  /// ```
  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      id: entity.id,
      email: entity.email,
      displayName: entity.displayName,
      phoneNumber: entity.phoneNumber,
      photoUrl: entity.photoUrl,
      isEmailVerified: entity.isEmailVerified,
      createdAt: entity.createdAt,
      lastLoginAt: entity.lastLoginAt,
    );
  }

  /// 🔧 toEntity: تحويل UserModel → UserEntity
  /// يستقبل: this (UserModel)
  /// يعيد: UserEntity
  /// 
  /// الحالة: جلبنا بيانات من Firebase/Hive، والآن نرسلها للـ Domain
  /// ```
  /// final model = UserModel.fromJson(json);
  /// final entity = model.toEntity();
  /// // أرسل entity للـ Domain/Presentation
  /// ```
  UserEntity toEntity() {
    return UserEntity(
      id: id,
      email: email,
      displayName: displayName,
      phoneNumber: phoneNumber,
      photoUrl: photoUrl,
      isEmailVerified: isEmailVerified,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
    );
  }

  /// 🔧 factory: تحويل Firebase User → UserModel
  /// يستقبل: firebase_auth.User (من Firebase Authentication)
  /// يعيد: UserModel
  /// 
  /// متى يُستخدم؟
  /// بعد تسجيل دخول أو تسجيل ناجح
  /// Firebase يعطينا User object
  /// نحتاج تحويله لـ UserModel
  /// 
  /// مثال:
  /// ```
  /// final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
  ///   email: email,
  ///   password: password,
  /// );
  /// final user = userCredential.user!; // Firebase User
  /// final model = UserModel.fromFirebaseUser(user); // → UserModel
  /// ```
  factory UserModel.fromFirebaseUser(firebase_auth.User user) {
    return UserModel(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? '',
      phoneNumber: user.phoneNumber,
      photoUrl: user.photoURL,
      isEmailVerified: user.emailVerified,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      lastLoginAt: user.metadata.lastSignInTime,
    );
  }

  /// 🔧 factory: إنشاء مستخدم فارغ
  /// يُستخدم كـ placeholder
  factory UserModel.empty() {
    return UserModel(
      id: '',
      email: '',
      displayName: '',
      phoneNumber: null,
      photoUrl: null,
      isEmailVerified: false,
      createdAt: DateTime.now(),
      lastLoginAt: null,
    );
  }
}

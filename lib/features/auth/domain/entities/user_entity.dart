import 'package:equatable/equatable.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📌 UserEntity - كيان المستخدم (Domain Layer)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف من هذا الملف:
/// تمثيل المستخدم في Domain Layer
/// 
/// ما هو Entity؟
/// Entity = نسخة "نقية" من البيانات بدون:
/// - Firebase Annotations (@HiveField, @JsonSerializable)
/// - Database Details
/// - Framework Dependencies
/// 
/// الفرق بين Entity و Model:
/// 
/// Entity (Domain Layer):
/// - نقي، بدون annotations
/// - مستقل عن Firebase و Hive
/// - يستخدم في Domain و Presentation
/// 
/// Model (Data Layer):
/// - يحتوي على @JsonSerializable و @HiveField
/// - يحتوي على factory methods (fromJson, fromEntity)
/// - يستخدم فقط في Data Layer
/// 
/// المبدأ:
/// **Separation of Concerns**
/// Domain لا يعرف عن Firebase أو Hive
/// هذا يجعل الكود نظيفاً وقابلاً للصيانة
///
/// التسلسل:
/// ```
/// Firebase/Hive (JSON)
///   ↓
/// UserModel.fromJson() → UserModel
///   ↓
/// model.toEntity() → UserEntity ← هنا الآن
///   ↓
/// Domain Layer & UI
/// ```
///
/// Equatable:
/// مكتبة تساعد على المقارنة بين Objects
/// بدونها: 
///   user1 == user2 → false (حتى لو نفس البيانات)
/// معها:
///   user1 == user2 → true (إذا كانت nفس البيانات)

class UserEntity extends Equatable {
  /// 🆔 معرف فريد للمستخدم
  /// Firebase يولده تلقائياً (مثل: "abc123xyz789")
  final String id;
  
  /// 📧 البريد الإلكتروني
  /// يجب أن يكون فريداً (لا يمكن تسجيل حسابين بنفس البريد)
  final String email;
  
  /// 👤 اسم المستخدم الذي يعرضه
  /// يظهر في:
  /// - Profile Page
  /// - الرسائل ("مرحباً، أحمد!")
  /// - الإشعارات
  final String displayName;
  
  /// 📱 رقم الهاتف (اختياري)
  /// قد يكون null إذا لم يضيفه المستخدم
  final String? phoneNumber;
  
  /// 📷 رابط صورة الملف الشخصي (اختياري)
  /// عادة صورة من Google Cloud Storage أو Firebase Storage
  /// مثل: "https://storage.googleapis.com/..."
  final String? photoUrl;
  
  /// ✅ هل تم التحقق من البريد الإلكتروني؟
  /// - false: المستخدم الجديد (لم يتحقق من البريد)
  /// - true: تم التحقق (نقر على رابط التحقق)
  /// 
  /// ملاحظة:
  /// بعض الميزات قد تحتاج التحقق من البريد
  /// (مثل: تغيير كلمة المرور)
  final bool isEmailVerified;
  
  /// 📅 تاريخ إنشاء الحساب
  /// مثل: 2024-01-15 10:30:00
  /// يُستخدم في:
  /// - حساب كم يوم المستخدم معنا
  /// - الترتيب التاريخي في السجلات
  final DateTime createdAt;
  
  /// 🕐 آخر مرة سجل الدخول
  /// - null: لم يسجل دخول بعد (حساب جديد لم يُستخدم)
  /// - DateTime: تاريخ ووقت آخر دخول
  /// 
  /// يُستخدم في:
  /// - معرفة النشاط (هل المستخدم نشط؟)
  /// - احتساب عدم النشاط (حذف البيانات بعد 6 أشهر)
  final DateTime? lastLoginAt;

  const UserEntity({
    required this.id,
    required this.email,
    required this.displayName,
    this.phoneNumber,
    this.photoUrl,
    required this.isEmailVerified,
    required this.createdAt,
    this.lastLoginAt,
  });

  /// 🔍 هل المستخدم فارغ؟
  /// يُستخدم للتحقق السريع
  /// ```
  /// if (user.isEmpty) {
  ///   // لا يوجد مستخدم
  /// }
  /// ```
  bool get isEmpty => id.isEmpty;
  
  /// 🔍 هل المستخدم موجود؟
  /// العكس من isEmpty
  bool get isNotEmpty => !isEmpty;

  /// 🔧 factory: إنشاء مستخدم فارغ
  /// يُستخدم كـ placeholder عندما لا يوجد مستخدم
  /// ```
  /// UserEntity emptyUser = UserEntity.empty();
  /// ```
  factory UserEntity.empty() {
    return UserEntity(
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

  /// 🔧 copyWith: نسخ المستخدم مع تعديل بعض الحقول
  /// مفيد عندما نريد تحديث حقل واحد فقط
  /// 
  /// مثال:
  /// ```
  /// final updatedUser = user.copyWith(
  ///   displayName: 'Ahmed Ali',
  ///   photoUrl: 'https://...',
  /// );
  /// ```
  UserEntity copyWith({
    String? id,
    String? email,
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
    bool? isEmailVerified,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return UserEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  /// 🔍 props: الخصائص المستخدمة للمقارنة (Equatable)
  /// بدون هذا:
  /// ```
  /// user1 == user2  // false (حتى لو نفس البيانات)
  /// ```
  /// معه:
  /// ```
  /// user1 == user2  // true (إذا كانت props متساوية)
  /// ```
  @override
  List<Object?> get props => [
        id,
        email,
        displayName,
        phoneNumber,
        photoUrl,
        isEmailVerified,
        createdAt,
        lastLoginAt,
      ];
}

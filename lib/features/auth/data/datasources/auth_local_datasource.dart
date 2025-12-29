import '../../../../core/services/storage/local_storage_service.dart';
import '../../../../core/utils/logger.dart';
import '../models/user_model.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📌 AuthLocalDataSource - التخزين المحلي (Data Layer)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف من هذا الملف:
/// التعامل مع التخزين المحلي (Hive) لبيانات المستخدم
/// 
/// ماذا يحفظ؟
/// - بيانات المستخدم الحالي (ID، الاسم، البريد)
/// - Token (للمصادقة اللاحقة)
/// 
/// لماذا نحتاج تخزين محلي؟
/// 1️⃣ Offline-First: التطبيق يعمل بدون إنترنت
/// 2️⃣ تجنب الطلبات المتكررة: لا حاجة لـ API كل مرة
/// 3️⃣ السرعة: Hive أسرع بكثير من Firebase
/// 4️⃣ أمان: بيانات حساسة محفوظة محلياً بأمان
///
/// العمل مع Repository:
/// ```
/// AuthRepositoryImpl
///   ├─ remoteDataSource (Firebase)
///   └─ localDataSource (Hive) ← هنا الآن
/// ```
/// 
/// التسلسل:
/// User Action
///   ↓
/// BLoC
///   ↓
/// Repository
///   ├─ localDataSource.cacheUser() ← احفظ محلياً فوراً
///   └─ remoteDataSource.login() ← نزامن مع Firebase (خلفية)

class AuthLocalDataSource {
  /// 💾 خدمة التخزين المحلي (Hive)
  final LocalStorageService _storageService = LocalStorageService.instance;
  
  /// 🔄 ذاكرة تخزين مؤقتة (Cache)
  /// نحتفظ بـ آخر user في الذاكرة
  /// لتجنب قراءة Hive كل مرة
  /// 
  /// الفائدة:
  /// - أسرع بكثير من قراءة Hive
  /// - كفاءة البطارية أفضل
  UserModel? _cachedUser;

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 💾 cacheUser - حفظ بيانات المستخدم محلياً
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// الهدف: حفظ بيانات المستخدم في:
  /// 1️⃣ الذاكرة (_cachedUser)
  /// 2️⃣ Hive (قاعدة البيانات المحلية)
  ///
  /// الاستخدام:
  /// ```
  /// // بعد تسجيل دخول ناجح
  /// final user = await firebaseAuth.signIn(...);
  /// await localDataSource.cacheUser(user);
  /// ```
  ///
  /// ماذا يحفظ؟
  /// - ID المستخدم
  /// - البريد الإلكتروني
  /// - الاسم والصورة
  /// - آخر وقت دخول

  Future<void> cacheUser(UserModel user) async {
    AppLogger.info('[AuthLocalDataSource] 🔵 جاري حفظ المستخدم: ${user.email}', name: 'AuthLocalDataSource');
    
    // 1️⃣ حفظ في الذاكرة (سريع جداً)
    _cachedUser = user;
    
    try {
      // 2️⃣ حفظ في Hive (قاعدة البيانات المحلية)
      await _storageService.saveUser(user);
      AppLogger.success('[AuthLocalDataSource] ✅ تم حفظ المستخدم في Hive: ${user.email}', name: 'AuthLocalDataSource');
    } catch (e) {
      AppLogger.error('[AuthLocalDataSource] ❌ فشل حفظ المستخدم في Hive: $e', name: 'AuthLocalDataSource');
      rethrow;  // رمِ الخطأ للـ Repository
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 📖 getCachedUser - جلب بيانات المستخدم المحفوظة
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// الهدف: جلب المستخدم الحالي من:
  /// 1️⃣ الذاكرة أولاً (سريع جداً)
  /// 2️⃣ Hive إذا لم يكن في الذاكرة
  ///
  /// الاستخدام:
  /// ```
  /// // عند فتح التطبيق
  /// final user = await localDataSource.getCachedUser();
  /// if (user != null) {
  ///   // المستخدم مسجل دخول بالفعل
  /// } else {
  ///   // لا يوجد مستخدم، عرض Login Page
  /// }
  /// ```
  ///
  /// العملية:
  /// 1️⃣ تحقق: هل البيانات في الذاكرة؟
  /// 2️⃣ إذا نعم: أرجع فوراً
  /// 3️⃣ إذا لا: ابحث في Hive
  /// 4️⃣ إذا موجود: احفظ في الذاكرة ثم أرجع
  /// 5️⃣ إذا غير موجود: أرجع null

  Future<UserModel?> getCachedUser() async {
    AppLogger.info('[AuthLocalDataSource] Getting cached user', name: 'AuthLocalDataSource');
    
    // 1️⃣ تحقق الذاكرة أولاً
    if (_cachedUser != null) {
      return _cachedUser;
    }
    
    try {
      // 2️⃣ ابحث في Hive
      final storedUser = await _storageService.getUser();
      
      if (storedUser != null) {
        // 3️⃣ احفظ في الذاكرة للمرات القادمة (سرعة)
        _cachedUser = storedUser;
        AppLogger.success('[AuthLocalDataSource] User loaded from Hive storage', name: 'AuthLocalDataSource');
        return storedUser;
      }
    } catch (e) {
      AppLogger.error('[AuthLocalDataSource] Failed to load user from Hive: $e', name: 'AuthLocalDataSource');
    }
    
    // 4️⃣ لا يوجد مستخدم
    return null;
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🗑️ clearCachedUser - حذف بيانات المستخدم
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// الهدف: حذف بيانات المستخدم من:
  /// 1️⃣ الذاكرة
  /// 2️⃣ Hive
  ///
  /// متى يتم استدعاؤها؟
  /// - عند تسجيل الخروج (Logout)
  /// - عند حذف الحساب
  /// - عند مشاكل أمنية
  ///
  /// الاستخدام:
  /// ```
  /// // عند الضغط على "تسجيل الخروج"
  /// await localDataSource.clearCachedUser();
  /// // الآن لا يوجد بيانات محفوظة
  /// ```

  Future<void> clearCachedUser() async {
    AppLogger.info('[AuthLocalDataSource] Clearing cached user', name: 'AuthLocalDataSource');
    
    // 1️⃣ امسح من الذاكرة
    _cachedUser = null;
    
    try {
      // 2️⃣ امسح من Hive
      await _storageService.delete('users_box', 'current_user');
      AppLogger.success('[AuthLocalDataSource] User cleared from Hive storage', name: 'AuthLocalDataSource');
    } catch (e) {
      AppLogger.error('[AuthLocalDataSource] Failed to clear user from Hive: $e', name: 'AuthLocalDataSource');
    }
  }

  /// 🔍 hasUser - هل يوجد مستخدم محفوظ؟
  /// 
  /// الاستخدام السريع:
  /// ```
  /// if (localDataSource.hasUser) {
  ///   // هناك مستخدم
  /// } else {
  ///   // لا يوجد مستخدم
  /// }
  /// ```
  bool get hasUser => _cachedUser != null;
}

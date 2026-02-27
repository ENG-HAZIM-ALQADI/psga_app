import 'package:psga_app/core/storage/local_storage_service.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/auth/data/models/user_model.dart';

/// مصدر البيانات المحلي للمصادقة
abstract class AuthLocalDataSource {
  /// حفظ المستخدم محلياً
  Future<void> cacheUser(UserModel user);

  /// الحصول على المستخدم المحفوظ
  Future<UserModel?> getCachedUser();

  /// حذف المستخدم المحفوظ
  Future<void> clearCache();

  /// حذف جميع البيانات المحلية
  Future<void> clearAllData();

  /// التحقق من وجود مستخدم محفوظ
  Future<bool> hasCache();
}

/// تنفيذ مصدر البيانات المحلي
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final LocalStorageService _localStorage;

  AuthLocalDataSourceImpl(this._localStorage);

  @override
  Future<void> cacheUser(UserModel user) async {
    try {
      AppLogger.info('[AuthLocalDataSource] جاري حفظ المستخدم محلياً: ${user.email}');
      await _localStorage.saveUser(user);
      AppLogger.success('[AuthLocalDataSource] تم حفظ المستخدم بنجاح');
    } catch (e, stackTrace) {
      AppLogger.error('[AuthLocalDataSource] فشل حفظ المستخدم', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<UserModel?> getCachedUser() async {
    try {
      AppLogger.info('[AuthLocalDataSource] جاري الحصول على المستخدم المحفوظ');
      final user = _localStorage.getUser();
      
      if (user == null) {
        AppLogger.info('[AuthLocalDataSource] لا يوجد مستخدم محفوظ');
      } else {
        AppLogger.success('[AuthLocalDataSource] تم العثور على المستخدم: ${user.email}');
      }
      
      return user;
    } catch (e, stackTrace) {
      AppLogger.error('[AuthLocalDataSource] خطأ في الحصول على المستخدم', e, stackTrace);
      return null;
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      AppLogger.info('[AuthLocalDataSource] جاري حذف المستخدم المحفوظ');
      await _localStorage.deleteUser();
      AppLogger.success('[AuthLocalDataSource] تم حذف المستخدم بنجاح');
    } catch (e, stackTrace) {
      AppLogger.error('[AuthLocalDataSource] فشل حذف المستخدم', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> clearAllData() async {
    try {
      AppLogger.info('[AuthLocalDataSource] جاري حذف جميع البيانات المحلية');
      await _localStorage.clearAllData();
      AppLogger.success('[AuthLocalDataSource] تم حذف جميع البيانات بنجاح');
    } catch (e, stackTrace) {
      AppLogger.error('[AuthLocalDataSource] فشل حذف جميع البيانات', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<bool> hasCache() async {
    try {
      final hasUser = _localStorage.hasUser();
      AppLogger.info('[AuthLocalDataSource] يوجد مستخدم محفوظ: $hasUser');
      return hasUser;
    } catch (e, stackTrace) {
      AppLogger.error('[AuthLocalDataSource] خطأ في التحقق من وجود مستخدم', e, stackTrace);
      return false;
    }
  }
}

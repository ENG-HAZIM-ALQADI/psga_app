import '../../../../core/services/storage/hive_boxes.dart';
import '../../../../core/services/storage/local_storage_service.dart';
import '../models/route_model.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 💾 RouteLocalDataSource - واجهة التخزين المحلي للمسارات (Data Layer)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف: تعريف العمليات الأساسية لتخزين المسارات محلياً
///
/// لماذا نحتاج المسارات محلياً؟
/// - ✅ سريع جداً (بدون إنترنت)
/// - ✅ المستخدم يريد المسارات المحفوظة دائماً
/// - ✅ تخفيض استهلاك البيانات (استخدام النسخة المحفوظة)

abstract class RouteLocalDataSource {
  /// ➕ حفظ مسار جديد
  Future<void> saveRoute(RouteModel route);

  /// 📖 جلب مسار بمعرفه
  Future<RouteModel?> getRoute(String id);

  /// 📖 جلب جميع المسارات المحفوظة
  Future<List<RouteModel>> getAllRoutes();

  /// 🗑️ حذف مسار
  Future<void> deleteRoute(String id);

  /// ✏️ تحديث مسار موجود
  Future<void> updateRoute(RouteModel route);

  /// 🧹 حذف جميع البيانات
  Future<void> clearAll();
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 📦 HiveRouteLocalDataSource - استخدام Hive Database الحقيقي
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Hive = قاعدة بيانات محلية سريعة وآمنة
/// - يحفظ البيانات في ملفات على الجهاز
/// - يمكن تشفير البيانات
/// - سريع جداً (في-الذاكرة + persistent)
///
/// الاستخدام:
/// هذا الـ DataSource في الإنتاج (الاستخدام الفعلي)

class HiveRouteLocalDataSource implements RouteLocalDataSource {
  /// 🔗 الاعتماد: خدمة التخزين المحلي
  /// LocalStorageService يتعامل مع جميع عمليات Hive
  final LocalStorageService _storageService = LocalStorageService.instance;

  /// ➕ حفظ مسار جديد
  /// يُفوض العملية لـ LocalStorageService
  @override
  Future<void> saveRoute(RouteModel route) async {
    await _storageService.saveRoute(route);
  }

  /// 📖 جلب مسار بمعرفه
  @override
  Future<RouteModel?> getRoute(String id) async {
    return await _storageService.getRoute(id);
  }

  /// 📖 جلب جميع المسارات
  /// ملاحظة: تُسترجع الجميع (قد نحتاج تصفية بعدها)
  @override
  Future<List<RouteModel>> getAllRoutes() async {
    return await _storageService.getRoutes();
  }

  /// 🗑️ حذف مسار
  @override
  Future<void> deleteRoute(String id) async {
    await _storageService.deleteRoute(id);
  }

  /// ✏️ تحديث مسار
  /// (في Hive: التحديث = حفظ بنفس المعرف)
  @override
  Future<void> updateRoute(RouteModel route) async {
    await _storageService.saveRoute(route);
  }

  /// 🧹 حذف جميع البيانات من صندوق المسارات
  @override
  Future<void> clearAll() async {
    await _storageService.deleteAll(HiveBoxes.routes);
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🧪 MockRouteLocalDataSource - نسخة وهمية للاختبار
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الاستخدام:
/// - اختبار وحدات (Unit Tests)
/// - التطوير السريع بدون Hive
/// - محاكاة قاعدة بيانات بدون التعقيد

class MockRouteLocalDataSource implements RouteLocalDataSource {
  /// 💾 Storage في الذاكرة
  /// Key = معرف المسار
  /// Value = بيانات المسار
  final Map<String, RouteModel> _routes = {};

  /// ➕ حفظ مسار جديد
  /// محاكاة: تأخير صغير (كأنه database)
  @override
  Future<void> saveRoute(RouteModel route) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _routes[route.id] = route;
  }

  /// 📖 جلب مسار بمعرفه
  @override
  Future<RouteModel?> getRoute(String id) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _routes[id];
  }

  /// 📖 جلب جميع المسارات
  @override
  Future<List<RouteModel>> getAllRoutes() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _routes.values.toList();
  }

  /// 🗑️ حذف مسار
  @override
  Future<void> deleteRoute(String id) async {
    await Future.delayed(const Duration(milliseconds: 50));
    _routes.remove(id);
  }

  /// ✏️ تحديث مسار
  @override
  Future<void> updateRoute(RouteModel route) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _routes[route.id] = route;
  }

  /// 🧹 حذف جميع البيانات
  @override
  Future<void> clearAll() async {
    _routes.clear();
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// تدفق البيانات في Repository:
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// ```
/// RouteRepository.getRoute(id)
///   ↓ (يستخدم)
/// RouteLocalDataSource (abstract)
///   ↓ (حسب الإعداد)
///   ├─ HiveRouteLocalDataSource (إنتاج)
///   │  └─ Hive Database
///   │
///   └─ MockRouteLocalDataSource (اختبار)
///      └─ Map في RAM
/// ```
/// ═══════════════════════════════════════════════════════════════════════════

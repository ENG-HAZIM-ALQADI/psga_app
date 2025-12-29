import '../models/route_model.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// ☁️ RouteRemoteDataSource - واجهة البيانات البعيدة للمسارات
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف: تعريف العمليات للمسارات في الخادم (Firebase)
///
/// الاستخدام:
/// - مزامنة المسارات عبر الأجهزة
/// - نسخ احتياطية آمنة
/// - مشاركة المسارات مع المستخدمين الآخرين

abstract class RouteRemoteDataSource {
  /// ➕ حفظ مسار جديد على الخادم
  Future<void> saveRoute(RouteModel route);

  /// 📖 جلب مسار من الخادم
  Future<RouteModel?> getRoute(String id);

  /// 📖 جلب جميع مسارات المستخدم من الخادم
  Future<List<RouteModel>> getUserRoutes(String userId);

  /// 🗑️ حذف مسار من الخادم
  Future<void> deleteRoute(String id);

  /// ✏️ تحديث مسار على الخادم
  Future<void> updateRoute(RouteModel route);
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🧪 MockRouteRemoteDataSource - نسخة وهمية للاختبار
/// ═══════════════════════════════════════════════════════════════════════════

class MockRouteRemoteDataSource implements RouteRemoteDataSource {
  /// 💾 محاكاة الخادم
  final Map<String, RouteModel> _routes = {};

  @override
  Future<void> saveRoute(RouteModel route) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _routes[route.id] = route;
  }

  @override
  Future<RouteModel?> getRoute(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _routes[id];
  }

  @override
  Future<List<RouteModel>> getUserRoutes(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _routes.values
        .where((route) => route.userId == userId)
        .toList();
  }

  @override
  Future<void> deleteRoute(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _routes.remove(id);
  }

  @override
  Future<void> updateRoute(RouteModel route) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _routes[route.id] = route;
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🔥 FirebaseRouteRemoteDataSource - تطبيق Firebase الفعلي
/// ═══════════════════════════════════════════════════════════════════════════

class FirebaseRouteRemoteDataSource implements RouteRemoteDataSource {
  @override
  Future<void> saveRoute(RouteModel route) async {
    /// TODO: تطبيق Firebase Firestore
    /// await FirebaseFirestore.instance
    ///   .collection('routes')
    ///   .doc(route.id)
    ///   .set(route.toFirestore());
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<RouteModel?> getRoute(String id) async {
    /// TODO: تطبيق Firebase
    await Future.delayed(const Duration(milliseconds: 200));
    return null;
  }

  @override
  Future<List<RouteModel>> getUserRoutes(String userId) async {
    /// TODO: تطبيق Firebase مع where clause
    /// return FirebaseFirestore.instance
    ///   .collection('routes')
    ///   .where('userId', isEqualTo: userId)
    ///   .get()
    ///   .then((snapshot) => snapshot.docs
    ///     .map((doc) => RouteModel.fromFirestore(doc.data(), doc.id))
    ///     .toList());
    await Future.delayed(const Duration(milliseconds: 300));
    return [];
  }

  @override
  Future<void> deleteRoute(String id) async {
    /// TODO: تطبيق Firebase
    /// await FirebaseFirestore.instance
    ///   .collection('routes')
    ///   .doc(id)
    ///   .delete();
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<void> updateRoute(RouteModel route) async {
    /// TODO: تطبيق Firebase
    /// await FirebaseFirestore.instance
    ///   .collection('routes')
    ///   .doc(route.id)
    ///   .update(route.toFirestore());
    await Future.delayed(const Duration(milliseconds: 300));
  }
}

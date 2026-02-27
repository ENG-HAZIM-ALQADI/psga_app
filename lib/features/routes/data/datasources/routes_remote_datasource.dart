import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/routes/data/models/route_model.dart';

abstract class RoutesRemoteDataSource {
  Future<RouteModel> createRoute(RouteModel route);
  Future<List<RouteModel>> getUserRoutes(String userId);
  Future<RouteModel> getRoute(String routeId);
  Future<RouteModel> updateRoute(RouteModel route);
  Future<void> deleteRoute(String routeId);
  Future<RouteModel> toggleFavorite(String routeId, bool currentStatus);
}

class RoutesRemoteDataSourceImpl implements RoutesRemoteDataSource {
  final FirebaseFirestore firestore;
  
  RoutesRemoteDataSourceImpl({required this.firestore});
  
  CollectionReference get _collection => firestore.collection('routes');

  @override
  Future<RouteModel> createRoute(RouteModel route) async {
    try {
      AppLogger.info('[RoutesRemoteDataSource] إنشاء مسار: ${route.name}');
      await _collection.doc(route.id).set(route.toJson());
      AppLogger.success('[RoutesRemoteDataSource] تم إنشاء المسار بنجاح');
      return route;
    } catch (e, stackTrace) {
      AppLogger.error('[RoutesRemoteDataSource] فشل إنشاء المسار', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<RouteModel>> getUserRoutes(String userId) async {
    try {
      AppLogger.info('[RoutesRemoteDataSource] جلب مسارات: $userId');
      
      final allModels = <RouteModel>[];
      
      // ✅ 1. جلب من subcollection: /users/{userId}/routes (الطريقة الجديدة)
      try {
        final subcollectionSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('routes')
            .orderBy('updatedAt', descending: true)
            .get();
        
        if (subcollectionSnapshot.docs.isNotEmpty) {
          AppLogger.info('[RoutesRemoteDataSource] وُجد ${subcollectionSnapshot.docs.length} مسار في subcollection');
          
          final subcollectionModels = subcollectionSnapshot.docs
              .map((doc) => RouteModel.fromJson({...doc.data(), 'id': doc.id}))
              .toList();
          
          allModels.addAll(subcollectionModels);
        }
      } catch (e) {
        AppLogger.warning('[RoutesRemoteDataSource] فشل جلب من subcollection', e);
        // نتابع للـ legacy collection
      }
      
      // ✅ 2. جلب من legacy collection: /routes (للتوافق مع البيانات القديمة)
      try {
        final legacySnapshot = await _collection
            .where('userId', isEqualTo: userId)
            .orderBy('updatedAt', descending: true)
            .get();
        
        if (legacySnapshot.docs.isNotEmpty) {
          AppLogger.info('[RoutesRemoteDataSource] وُجد ${legacySnapshot.docs.length} مسار في legacy collection');
          
          final legacyModels = legacySnapshot.docs
              .map((doc) => RouteModel.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
              .toList();
          
          // ✅ تجنب التكرار - إضافة فقط المسارات غير الموجودة
          for (final model in legacyModels) {
            if (!allModels.any((m) => m.id == model.id)) {
              allModels.add(model);
            }
          }
        }
      } catch (e) {
        AppLogger.warning('[RoutesRemoteDataSource] فشل جلب من legacy collection', e);
      }
      
      AppLogger.success('[RoutesRemoteDataSource] تم جلب ${allModels.length} مسار');
      return allModels;
    } catch (e, stackTrace) {
      AppLogger.error('[RoutesRemoteDataSource] فشل جلب المسارات', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<RouteModel> getRoute(String routeId) async {
    try {
      final doc = await _collection.doc(routeId).get();
      if (!doc.exists) throw Exception('المسار غير موجود');
      return RouteModel.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id});
    } catch (e) {
      AppLogger.error('[RoutesRemoteDataSource] فشل جلب المسار', e);
      rethrow;
    }
  }

  @override
  Future<RouteModel> updateRoute(RouteModel route) async {
    try {
      AppLogger.info('[RoutesRemoteDataSource] تحديث مسار: ${route.id}');
      await _collection.doc(route.id).update(route.toJson());
      AppLogger.success('[RoutesRemoteDataSource] تم التحديث بنجاح');
      return route;
    } catch (e) {
      AppLogger.error('[RoutesRemoteDataSource] فشل التحديث', e);
      rethrow;
    }
  }

  @override
  Future<void> deleteRoute(String routeId) async {
    try {
      AppLogger.info('[RoutesRemoteDataSource] حذف مسار: $routeId');
      await _collection.doc(routeId).delete();
      AppLogger.success('[RoutesRemoteDataSource] تم الحذف بنجاح');
    } catch (e) {
      AppLogger.error('[RoutesRemoteDataSource] فشل الحذف', e);
      rethrow;
    }
  }

  @override
  Future<RouteModel> toggleFavorite(String routeId, bool currentStatus) async {
    try {
      await _collection.doc(routeId).update({'isFavorite': !currentStatus});
      final updatedRoute = await getRoute(routeId);
      return updatedRoute;
    } catch (e) {
      AppLogger.error('[RoutesRemoteDataSource] فشل تحديث المفضلة', e);
      rethrow;
    }
  }
}

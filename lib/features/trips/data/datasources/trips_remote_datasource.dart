import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:psga_app/core/errors/exceptions.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/trips/data/models/deviation_model.dart';
import 'package:psga_app/features/trips/data/models/trip_model.dart';

/// مصدر بيانات الرحلات من Firestore
abstract class TripsRemoteDataSource {
  Future<TripModel> startTrip({
    required String userId,
    required String routeId,
  });
  
  Future<TripModel> updateTrip(TripModel trip);
  
  Future<TripModel?> getActiveTrip(String userId);
  
  Future<List<TripModel>> getTripHistory({
    required String userId,
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
  });
  
  Future<TripModel> getTripById(String tripId);
  
  Future<List<DeviationModel>> getTripDeviations(String tripId);
  
  Future<void> deleteTrip(String tripId);
}

/// تنفيذ مصدر بيانات الرحلات من Firestore
class TripsRemoteDataSourceImpl implements TripsRemoteDataSource {
  final firestore.FirebaseFirestore _firestore;

  TripsRemoteDataSourceImpl({required firestore.FirebaseFirestore firestore})
      : _firestore = firestore;

  @override
  Future<TripModel> startTrip({
    required String userId,
    required String routeId,
  }) async {
    try {
      AppLogger.info('[TripsRemote] بدء رحلة جديدة');

      // الحصول على المسار - نحاول legacy أولاً ثم subcollection
      AppLogger.info('[TripsRemote] جلب بيانات المسار: $routeId');
      var routeDoc = await _firestore.collection('routes').doc(routeId).get();
      
      if (!routeDoc.exists) {
        // fallback: البحث في subcollection users/{userId}/routes
        AppLogger.warning('[TripsRemote] المسار غير موجود في legacy، نحاول subcollection');
        routeDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('routes')
            .doc(routeId)
            .get();
      }
      
      if (!routeDoc.exists) {
        AppLogger.error('[TripsRemote] المسار غير موجود في أي مكان: $routeId');
        throw ServerException('المسار غير موجود');
      }

      // إنشاء الرحلة
      final tripRef = _firestore.collection('trips').doc();
      final now = DateTime.now();

      final tripData = {
        'id': tripRef.id,
        'userId': userId,
        'routeId': routeId,
        'route': routeDoc.data(),
        'status': 'active',
        'startTime': now.toIso8601String(),
        'endTime': null,
        'pausedAt': null,
        'totalPausedDuration': 0,
        'distanceTraveled': 0.0,
        'locationHistory': [],
        'visitedWaypointIds': [],
        'missedWaypointIds': [],
        'currentWaypointIndex': 0,
        'deviations': [],
        'currentDeviation': null,
        'totalDeviations': 0,
        'averageSpeed': null,
        'maxSpeed': null,
        'currentLocation': null,
        'lastKnownLocation': null,
        'createdAt': firestore.FieldValue.serverTimestamp(),
        'updatedAt': firestore.FieldValue.serverTimestamp(),
      };

      await tripRef.set(tripData);

      AppLogger.success('[TripsRemote] تم بدء الرحلة: ${tripRef.id}');
      return TripModel.fromJson({...tripData, 'id': tripRef.id});
    } on firestore.FirebaseException catch (e) {
      AppLogger.error('[TripsRemote] خطأ Firebase', e);
      throw ServerException(e.message ?? 'فشل بدء الرحلة');
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRemote] خطأ غير متوقع', e, stackTrace);
      throw ServerException('فشل بدء الرحلة');
    }
  }

  @override
  Future<TripModel> updateTrip(TripModel trip) async {
    try {
      AppLogger.info('[TripsRemote] تحديث رحلة: ${trip.id}');

      final tripRef = _firestore.collection('trips').doc(trip.id);
      final tripData = trip.toJson();
      tripData['updatedAt'] = firestore.FieldValue.serverTimestamp();

      await tripRef.update(tripData);

      AppLogger.success('[TripsRemote] تم تحديث الرحلة');
      return trip;
    } on firestore.FirebaseException catch (e) {
      AppLogger.error('[TripsRemote] خطأ Firebase', e);
      throw ServerException(e.message ?? 'فشل تحديث الرحلة');
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRemote] خطأ غير متوقع', e, stackTrace);
      throw ServerException('فشل تحديث الرحلة');
    }
  }

  @override
  Future<TripModel?> getActiveTrip(String userId) async {
    try {
      AppLogger.info('[TripsRemote] جلب الرحلة النشطة');

      final snapshot = await _firestore
          .collection('trips')
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: ['active', 'paused'])
          .orderBy('startTime', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;
      return TripModel.fromJson({...doc.data(), 'id': doc.id});
    } on firestore.FirebaseException catch (e) {
      AppLogger.error('[TripsRemote] خطأ Firebase', e);
      throw ServerException(e.message ?? 'فشل جلب الرحلة');
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRemote] خطأ غير متوقع', e, stackTrace);
      throw ServerException('فشل جلب الرحلة');
    }
  }

  @override
  Future<List<TripModel>> getTripHistory({
    required String userId,
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      AppLogger.info('[TripsRemote] جلب سجل الرحلات');

      var query = _firestore
          .collection('trips')
          .where('userId', isEqualTo: userId)
          .orderBy('startTime', descending: true);

      if (startDate != null) {
        query = query.where('startTime',
            isGreaterThanOrEqualTo: startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.where('startTime',
            isLessThanOrEqualTo: endDate.toIso8601String());
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => TripModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } on firestore.FirebaseException catch (e) {
      AppLogger.error('[TripsRemote] خطأ Firebase', e);
      throw ServerException(e.message ?? 'فشل جلب السجل');
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRemote] خطأ غير متوقع', e, stackTrace);
      throw ServerException('فشل جلب السجل');
    }
  }

  @override
  Future<TripModel> getTripById(String tripId) async {
    try {
      AppLogger.info('[TripsRemote] جلب تفاصيل رحلة: $tripId');

      // محاولة legacy أولاً
      var doc = await _firestore.collection('trips').doc(tripId).get();

      if (!doc.exists) {
        // fallback: البحث في subcollection users/{userId}/trips
        // نبحث في جميع المستخدمين لأننا لا نعرف userId هنا
        AppLogger.warning('[TripsRemote] الرحلة غير موجودة في legacy: $tripId');
        throw ServerException('الرحلة غير موجودة');
      }

      return TripModel.fromJson({...doc.data()!, 'id': doc.id});
    } on firestore.FirebaseException catch (e) {
      AppLogger.error('[TripsRemote] خطأ Firebase', e);
      throw ServerException(e.message ?? 'فشل جلب التفاصيل');
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRemote] خطأ غير متوقع', e, stackTrace);
      throw ServerException('فشل جلب التفاصيل');
    }
  }

  @override
  Future<List<DeviationModel>> getTripDeviations(String tripId) async {
    try {
      AppLogger.info('[TripsRemote] جلب انحرافات الرحلة: $tripId');

      final trip = await getTripById(tripId);
      return trip.deviations.map((d) => DeviationModel.fromEntity(d)).toList();
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRemote] خطأ في جلب الانحرافات', e, stackTrace);
      throw ServerException('فشل جلب الانحرافات');
    }
  }

  @override
  Future<void> deleteTrip(String tripId) async {
    try {
      AppLogger.info('[TripsRemote] حذف رحلة: $tripId');

      await _firestore.collection('trips').doc(tripId).delete();

      AppLogger.success('[TripsRemote] تم حذف الرحلة');
    } on firestore.FirebaseException catch (e) {
      AppLogger.error('[TripsRemote] خطأ Firebase', e);
      throw ServerException(e.message ?? 'فشل حذف الرحلة');
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRemote] خطأ غير متوقع', e, stackTrace);
      throw ServerException('فشل حذف الرحلة');
    }
  }
}

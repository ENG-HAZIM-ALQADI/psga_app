import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/repositories/base_offline_repository.dart';
import 'package:psga_app/core/services/connectivity_service.dart';
import 'package:psga_app/core/storage/hive_service.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart';
import 'package:psga_app/features/routes/data/models/route_model.dart';
import 'package:psga_app/features/trips/data/models/trip_model.dart';
import 'package:psga_app/features/trips/data/datasources/trips_local_datasource.dart';
import 'package:psga_app/features/trips/data/datasources/trips_remote_datasource.dart';
import 'package:psga_app/features/trips/domain/entities/deviation.dart';
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';
import 'package:psga_app/features/trips/domain/entities/trip_settings_entity.dart';
import 'package:psga_app/features/trips/data/models/trip_settings_model.dart';
import 'package:psga_app/features/trips/domain/repositories/trips_repository.dart';
import 'package:psga_app/core/services/sync_service.dart';

class TripsRepositoryImpl 
    extends BaseOfflineRepository<TripEntity, TripModel>
    implements TripsRepository {
  
  final TripsLocalDataSource localDataSource;
  final TripsRemoteDataSource remoteDataSource;
  
  @override
  final ConnectivityService connectivityService;
  final FirebaseFirestore _firestore;
  final HiveService _hive = HiveService.instance;

  TripsRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.connectivityService,
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  // ==================== BaseOfflineRepository Implementation ====================

  @override
  String get boxName => 'trips';

  @override
  String get collectionName => 'trips';

  @override
  TripModel toModel(TripEntity entity) => TripModel.fromEntity(entity);

  @override
  TripEntity toEntity(TripModel model) => model.toEntity();

  @override
  Map<String, dynamic> toJson(TripModel model) => model.toJson();

  @override
  TripModel fromJson(Map<String, dynamic> json) => TripModel.fromJson(json);

  @override
  String getId(TripEntity entity) => entity.id;

  @override
  Future<Either<Failure, TripEntity?>> fetchFromServer(String id) async {
    try {
      final doc = await _firestore.collection('trips').doc(id).get();
      
      if (!doc.exists) return const Right(null);

      final model = TripModel.fromJson(doc.data()!);
      await saveLocal(model.toEntity());
      
      return Right(model.toEntity());
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRepository] فشل جلب الرحلة', e, stackTrace);
      return Left(ServerFailure('فشل جلب الرحلة: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<TripEntity>>> fetchAllFromServer() async {
    try {
      final snapshot = await _firestore.collection('trips').get();
      
      final entities = snapshot.docs
          .map((doc) => TripModel.fromJson(doc.data()).toEntity())
          .toList();
      
      await saveAllLocal(entities);
      
      return Right(entities);
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRepository] فشل جلب الرحلات', e, stackTrace);
      return Left(ServerFailure('فشل جلب الرحلات: ${e.toString()}'));
    }
  }

  // ==================== Helper: Get Route ====================

  Future<Either<Failure, RouteEntity>> _getRoute(String routeId) async {
    try {
      AppLogger.info('[TripsRepository] جلب المسار: $routeId');
      
      // محاولة جلب من routes box في Hive (استخدام RouteModel كنوع)
      try {
        final box = _hive.getTypedBox<RouteModel>('routes');
        final routeModel = box.get(routeId);
        if (routeModel != null) {
          AppLogger.success('[TripsRepository] تم جلب المسار من Hive');
          return Right(routeModel.toEntity());
        }
      } catch (e) {
        AppLogger.warning('[TripsRepository] المسار غير موجود في Hive: $e');
      }
      
      // إذا لم يوجد، جلب من Firestore
      AppLogger.info('[TripsRepository] جاري جلب المسار من Firestore');
      final doc = await _firestore.collection('routes').doc(routeId).get();
      if (!doc.exists) {
        AppLogger.warning('[TripsRepository] المسار غير موجود في Firestore');
        return const Left(NotFoundFailure('المسار غير موجود'));
      }
      
      // استخدام RouteModel للتحويل الصحيح
      final data = doc.data()!;
      final routeModel = RouteModel.fromJson(data);
      final routeEntity = routeModel.toEntity();
      
      // حفظ في Hive للمرات القادمة
      try {
        final box = _hive.getTypedBox<RouteModel>('routes');
        await box.put(routeId, routeModel);
        AppLogger.info('[TripsRepository] تم حفظ المسار في Hive');
      } catch (e) {
        AppLogger.warning('[TripsRepository] فشل حفظ المسار في Hive: $e');
      }
      
      AppLogger.success('[TripsRepository] تم جلب المسار بنجاح من Firestore');
      return Right(routeEntity);
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRepository] فشل جلب المسار', e, stackTrace);
      return Left(ServerFailure('فشل جلب المسار: ${e.toString()}'));
    }
  }

  // ==================== Trips Management ====================

  @override
  @override
  Future<Either<Failure, TripEntity>> startTrip({
    required String userId,
    required String routeId,
    dynamic modifiedRoute, // المسار المعدل (اختياري)
  }) async {
    try {
      AppLogger.info('[TripsRepository] بدء رحلة جديدة: route=$routeId');
      
      // استخدام المسار المعدل إذا تم تمريره، وإلا جلب المسار الأصلي
      RouteEntity route;
      if (modifiedRoute != null) {
        AppLogger.info('[TripsRepository] استخدام المسار المعدل للرحلة');
        route = modifiedRoute as RouteEntity;
      } else {
        AppLogger.info('[TripsRepository] جلب المسار الأصلي');
        final routeResult = await _getRoute(routeId);
        
        // استخدام fold مباشرة للتحقق من النتيجة
        RouteEntity? fetchedRoute;
        final failure = routeResult.fold(
          (fail) => fail,
          (r) {
            fetchedRoute = r;
            return null;
          },
        );
        
        // إذا كان هناك فشل، نرجعه
        if (failure != null) {
          return Left(failure);
        }
        
        // إذا لم يتم جلب المسار، نرجع خطأ
        if (fetchedRoute == null) {
          return const Left(NotFoundFailure('فشل في جلب المسار'));
        }
        
        route = fetchedRoute!;
      }
      
      final trip = TripEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        routeId: routeId,
        route: route,
        status: TripStatus.active,
        startTime: DateTime.now(),
        locationHistory: const [],
        deviations: const [],
      );
      
      return save(trip);
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRepository] فشل بدء الرحلة', e, stackTrace);
      return Left(ServerFailure('فشل بدء الرحلة: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, TripEntity>> endTrip(String tripId) async {
    try {
      AppLogger.info('[TripsRepository] إنهاء رحلة: $tripId');
      
      final tripResult = await get(tripId);
      
      return tripResult.fold(
        (failure) => Left(failure),
        (trip) async {
          if (trip == null) {
            return const Left(NotFoundFailure('الرحلة غير موجودة'));
          }
          
          final updatedTrip = trip.copyWith(
            status: TripStatus.completed,
            endTime: DateTime.now(),
          );
          
          return update(updatedTrip);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRepository] فشل إنهاء الرحلة', e, stackTrace);
      return Left(ServerFailure('فشل الإنهاء: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, TripEntity>> pauseTrip(String tripId) async {
    try {
      AppLogger.info('[TripsRepository] إيقاف رحلة مؤقتاً: $tripId');
      
      final tripResult = await get(tripId);
      
      return tripResult.fold(
        (failure) => Left(failure),
        (trip) async {
          if (trip == null) {
            return const Left(NotFoundFailure('الرحلة غير موجودة'));
          }
          
          final updatedTrip = trip.copyWith(
            status: TripStatus.paused,
            pausedAt: DateTime.now(),
          );
          
          return update(updatedTrip);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRepository] فشل إيقاف الرحلة', e, stackTrace);
      return Left(ServerFailure('فشل الإيقاف: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, TripEntity>> resumeTrip(String tripId) async {
    try {
      AppLogger.info('[TripsRepository] استئناف رحلة: $tripId');
      
      final tripResult = await get(tripId);
      
      return tripResult.fold(
        (failure) => Left(failure),
        (trip) async {
          if (trip == null) {
            return const Left(NotFoundFailure('الرحلة غير موجودة'));
          }
          
          // حساب مدة التوقف
          Duration pausedDuration = trip.totalPausedDuration;
          if (trip.pausedAt != null) {
            pausedDuration = pausedDuration + DateTime.now().difference(trip.pausedAt!);
          }
          
          final updatedTrip = trip.copyWith(
            status: TripStatus.active,
            totalPausedDuration: pausedDuration,
          );
          
          return update(updatedTrip);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRepository] فشل استئناف الرحلة', e, stackTrace);
      return Left(ServerFailure('فشل الاستئناف: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, TripEntity>> cancelTrip(String tripId) async {
    try {
      AppLogger.info('[TripsRepository] إلغاء رحلة: $tripId');
      
      final tripResult = await get(tripId);
      
      return tripResult.fold(
        (failure) => Left(failure),
        (trip) async {
          if (trip == null) {
            return const Left(NotFoundFailure('الرحلة غير موجودة'));
          }
          
          final updatedTrip = trip.copyWith(
            status: TripStatus.cancelled,
            endTime: DateTime.now(),
          );
          
          return update(updatedTrip);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRepository] فشل إلغاء الرحلة', e, stackTrace);
      return Left(ServerFailure('فشل الإلغاء: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, TripEntity>> updateLocation({
    required String tripId,
    required Location location,
  }) async {
    try {
      AppLogger.info('[TripsRepository] تحديث موقع رحلة: $tripId');
      
      final tripResult = await get(tripId);
      
      return tripResult.fold(
        (failure) => Left(failure),
        (trip) async {
          if (trip == null) {
            return const Left(NotFoundFailure('الرحلة غير موجودة'));
          }
          
          // إضافة الموقع الجديد لسجل المواقع
          final updatedLocationHistory = [...trip.locationHistory, location];
          
          // حساب المسافة المقطوعة
          double additionalDistance = 0.0;
          if (trip.locationHistory.isNotEmpty) {
            final lastLocation = trip.locationHistory.last;
            additionalDistance = lastLocation.distanceTo(location);
          }
          final newDistanceTraveled = trip.distanceTraveled + additionalDistance;
          
          // حساب السرعة القصوى
          final currentSpeed = trip.calculateCurrentSpeed();
          double? newMaxSpeed = trip.maxSpeed;
          if (currentSpeed != null) {
            newMaxSpeed = trip.maxSpeed != null 
                ? (currentSpeed > trip.maxSpeed! ? currentSpeed : trip.maxSpeed)
                : currentSpeed;
          }
          
          // حساب متوسط السرعة
          double? newAverageSpeed;
          if (trip.locationHistory.length > 1) {
            final totalTime = location.timestamp.difference(trip.startTime).inSeconds;
            if (totalTime > 0) {
              // المسافة بالمتر / الوقت بالثواني * 3.6 = كم/ساعة
              newAverageSpeed = (newDistanceTraveled / totalTime) * 3.6;
            }
          }
          
          final updatedTrip = trip.copyWith(
            locationHistory: updatedLocationHistory,
            currentLocation: location,
            lastKnownLocation: location,
            distanceTraveled: newDistanceTraveled,
            maxSpeed: newMaxSpeed,
            averageSpeed: newAverageSpeed,
          );
          
          AppLogger.success('[TripsRepository] تم تحديث الموقع - المسافة: ${newDistanceTraveled.toStringAsFixed(2)}م');
          return update(updatedTrip);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRepository] فشل تحديث الموقع', e, stackTrace);
      return Left(ServerFailure('فشل التحديث: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, TripEntity?>> getActiveTrip(String userId) async {
    try {
      AppLogger.info('[TripsRepository] جلب الرحلة النشطة: user=$userId');
      
      // ✅ 1. بحث في المخزن المحلي أولاً
      final allResult = await getAllLocal();
      
      final localActiveTrip = allResult.fold<TripEntity?>(
        (failure) => null,
        (trips) => trips
            .where((trip) =>
                trip.userId == userId &&
                trip.status == TripStatus.active)
            .firstOrNull,
      );

      if (localActiveTrip != null) {
        AppLogger.success('[TripsRepository] وجدت رحلة نشطة محلياً: ${localActiveTrip.id}');
        return Right(localActiveTrip);
      }

      // ✅ 2. إذا لم توجد محلياً وكان متصلاً، تحقق من السيرفر
      if (connectivityService.isConnected) {
        AppLogger.info('[TripsRepository] لا توجد رحلة نشطة محلياً - تحقق من السيرفر');
        try {
          final remoteTrip = await remoteDataSource.getActiveTrip(userId);
          if (remoteTrip != null) {
            // حفظ محلياً
            await hiveService.put<TripModel>('trips', remoteTrip.id, remoteTrip);
            AppLogger.success('[TripsRepository] وجدت رحلة نشطة في السيرفر: ${remoteTrip.id}');
            return Right(remoteTrip.toEntity());
          }
        } catch (e) {
          AppLogger.warning('[TripsRepository] فشل التحقق من السيرفر: $e');
        }
      }

      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRepository] فشل جلب الرحلة النشطة', e, stackTrace);
      return Left(ServerFailure('فشل الجلب: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<TripEntity>>> getTripHistory({
    required String userId,
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      AppLogger.info('[TripsRepository] جلب سجل الرحلات: user=$userId');
      
      final allResult = await getAllLocal();
      
      return allResult.fold(
        (failure) async {
          // فشل المحلي، جرب السيرفر
          if (!connectivityService.isConnected) {
            AppLogger.warning('[TripsRepository] لا يوجد اتصال - لا يمكن جلب من السيرفر');
            return Left(failure);
          }
          
          return await _fetchUserTripsFromServer(
            userId: userId,
            limit: limit,
            startDate: startDate,
            endDate: endDate,
          );
        },
        (trips) async {
          var filtered = trips.where((trip) => trip.userId == userId);
          
          AppLogger.info('[TripsRepository] تم العثور على ${filtered.length} رحلة محلياً');
          
          if (startDate != null) {
            filtered = filtered.where((t) => t.startTime.isAfter(startDate));
          }
          
          if (endDate != null) {
            filtered = filtered.where((t) => t.startTime.isBefore(endDate));
          }
          
          var result = filtered.toList()
            ..sort((a, b) => b.startTime.compareTo(a.startTime));
          
          // ✅ إذا كان المخزن المحلي فارغاً وكان متصلاً، جلب من السيرفر
          if (result.isEmpty && connectivityService.isConnected) {
            AppLogger.info('[TripsRepository] المخزن المحلي فارغ - جلب من السيرفر');
            return await _fetchUserTripsFromServer(
              userId: userId,
              limit: limit,
              startDate: startDate,
              endDate: endDate,
            );
          }
          
          if (limit != null && result.length > limit) {
            result = result.take(limit).toList();
          }
          
          return Right(result);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRepository] فشل جلب السجل', e, stackTrace);
      return Left(ServerFailure('فشل الجلب: ${e.toString()}'));
    }
  }

  /// جلب رحلات المستخدم من السيرفر (من كلا المسارين)
  Future<Either<Failure, List<TripEntity>>> _fetchUserTripsFromServer({
    required String userId,
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      AppLogger.info('[TripsRepository] جلب رحلات $userId من Firestore');
      
      final allEntities = <TripEntity>[];
      
      // 1. جلب من subcollection: /users/{userId}/trips
      try {
        Query subcollectionQuery = _firestore
            .collection('users')
            .doc(userId)
            .collection('trips');
        
        if (startDate != null) {
          subcollectionQuery = subcollectionQuery
              .where('startTime', isGreaterThanOrEqualTo: startDate.toIso8601String());
        }
        
        if (endDate != null) {
          subcollectionQuery = subcollectionQuery
              .where('startTime', isLessThanOrEqualTo: endDate.toIso8601String());
        }
        
        if (limit != null) {
          subcollectionQuery = subcollectionQuery
              .orderBy('startTime', descending: true)
              .limit(limit);
        }
        
        final subcollectionSnapshot = await subcollectionQuery.get();
        
        if (subcollectionSnapshot.docs.isNotEmpty) {
          AppLogger.info('[TripsRepository] وُجد ${subcollectionSnapshot.docs.length} رحلة في subcollection');
          
          final subcollectionModels = subcollectionSnapshot.docs
              .map((doc) => TripModel.fromJson(doc.data() as Map<String, dynamic>))
              .toList();
          
          allEntities.addAll(subcollectionModels.map((m) => m.toEntity()));
        }
      } catch (e) {
        AppLogger.warning('[TripsRepository] فشل جلب من subcollection: $e');
      }
      
      // 2. جلب من legacy collection: /trips
      try {
        Query legacyQuery = _firestore
            .collection('trips')
            .where('userId', isEqualTo: userId);
        
        if (startDate != null) {
          legacyQuery = legacyQuery
              .where('startTime', isGreaterThanOrEqualTo: startDate.toIso8601String());
        }
        
        if (endDate != null) {
          legacyQuery = legacyQuery
              .where('startTime', isLessThanOrEqualTo: endDate.toIso8601String());
        }
        
        if (limit != null) {
          legacyQuery = legacyQuery
              .orderBy('startTime', descending: true)
              .limit(limit);
        }
        
        final legacySnapshot = await legacyQuery.get();
        
        if (legacySnapshot.docs.isNotEmpty) {
          AppLogger.info('[TripsRepository] وُجد ${legacySnapshot.docs.length} رحلة في legacy collection');
          
          final legacyModels = legacySnapshot.docs
              .map((doc) => TripModel.fromJson(doc.data() as Map<String, dynamic>))
              .toList();
          
          // تجنب التكرار
          for (final entity in legacyModels.map((m) => m.toEntity())) {
            if (!allEntities.any((e) => e.id == entity.id)) {
              allEntities.add(entity);
            }
          }
        }
      } catch (e) {
        AppLogger.warning('[TripsRepository] فشل جلب من legacy collection: $e');
      }
      
      if (allEntities.isEmpty) {
        AppLogger.info('[TripsRepository] لا توجد رحلات للمستخدم $userId');
        return const Right([]);
      }
      
      // ترتيب حسب الوقت
      allEntities.sort((a, b) => b.startTime.compareTo(a.startTime));
      
      // حفظ جميع الرحلات محلياً
      await saveAllLocal(allEntities);
      
      AppLogger.success('[TripsRepository] تم جلب ${allEntities.length} رحلة من السيرفر');
      return Right(allEntities);
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRepository] فشل جلب من السيرفر', e, stackTrace);
      return Left(ServerFailure('فشل الجلب من السيرفر: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, TripEntity>> getTripById(String tripId) async {
    AppLogger.info('[TripsRepository] جلب رحلة: $tripId');
    
    final result = await get(tripId);
    return result.fold(
      (failure) => Left(failure),
      (trip) => trip != null 
          ? Right(trip) 
          : const Left(NotFoundFailure('الرحلة غير موجودة')),
    );
  }

  @override
  Future<Either<Failure, List<Deviation>>> getTripDeviations(String tripId) async {
    try {
      AppLogger.info('[TripsRepository] جلب انحرافات رحلة: $tripId');
      
      final tripResult = await get(tripId);
      
      return tripResult.fold(
        (failure) => Left(failure),
        (trip) {
          if (trip == null) {
            return const Left(NotFoundFailure('الرحلة غير موجودة'));
          }
          
          return Right(trip.deviations);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRepository] فشل جلب الانحرافات', e, stackTrace);
      return Left(ServerFailure('فشل الجلب: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> syncTrip(String tripId) async {
    try {
      AppLogger.info('[TripsRepository] مزامنة رحلة: $tripId');
      
      final tripResult = await get(tripId);
      
      return tripResult.fold(
        (failure) => Left(failure),
        (trip) async {
          if (trip == null) {
            return const Left(NotFoundFailure('الرحلة غير موجودة'));
          }
          
          // المزامنة تتم تلقائياً من خلال BaseOfflineRepository
          // هنا نجبر المزامنة الفورية
          await update(trip);
          
          return const Right(null);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRepository] فشلت المزامنة', e, stackTrace);
      return Left(ServerFailure('فشلت المزامنة: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteTrip(String tripId) async {
    AppLogger.info('[TripsRepository] حذف رحلة: $tripId');
    
    // حذف من Hive محلياً
    final localResult = await deleteLocal(tripId);
    
    // حذف من Firestore إذا متصل
    if (connectivityService.isConnected) {
      try {
        await remoteDataSource.deleteTrip(tripId);
        AppLogger.success('[TripsRepository] تم حذف الرحلة من السيرفر: $tripId');
      } catch (e) {
        AppLogger.warning('[TripsRepository] فشل حذف الرحلة من السيرفر: $e');
      }
    }
    
    return localResult;
  }

  @override
  Future<Either<Failure, void>> clearAllTrips(String userId) async {
    try {
      AppLogger.info('[TripsRepository] مسح جميع رحلات المستخدم: $userId');
      
      // جلب جميع الرحلات المحلية
      final allResult = await getAllLocal();
      
      return allResult.fold(
        (failure) => Left(failure),
        (allTrips) async {
          // تصفية حسب userId
          final userTrips = allTrips.where((t) => t.userId == userId).toList();
          
          // حذف من Hive
          for (final trip in userTrips) {
            await hiveService.delete('trips', trip.id);
          }
          
          AppLogger.info('[TripsRepository] تم حذف ${userTrips.length} رحلة محلياً');
          
          // حذف من Firestore إذا متصل
          if (connectivityService.isConnected) {
            try {
              for (final trip in userTrips) {
                await remoteDataSource.deleteTrip(trip.id);
              }
              AppLogger.success('[TripsRepository] تم مسح جميع الرحلات من السيرفر');
            } catch (e) {
              AppLogger.warning('[TripsRepository] فشل مسح الرحلات من السيرفر: $e');
            }
          }
          
          AppLogger.success('[TripsRepository] تم مسح جميع رحلات المستخدم');
          return const Right(null);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRepository] فشل مسح السجل', e, stackTrace);
      return Left(ServerFailure('فشل المسح: ${e.toString()}')); // ignore: prefer_const_constructors
    }
  }

  // ==================== Helper Methods ====================

  /// تحديث نقطة طريق عند الوصول
  Future<Either<Failure, TripEntity>> updateWaypointProgress({
    required String tripId,
    required String waypointId,
    required bool visited,
  }) async {
    try {
      AppLogger.info('[TripsRepository] تحديث نقطة طريق: $waypointId');
      
      final tripResult = await get(tripId);
      
      return tripResult.fold(
        (failure) => Left(failure),
        (trip) async {
          if (trip == null) {
            return const Left(NotFoundFailure('الرحلة غير موجودة'));
          }
          
          List<String> updatedVisited = List.from(trip.visitedWaypointIds);
          List<String> updatedMissed = List.from(trip.missedWaypointIds);
          
          if (visited) {
            if (!updatedVisited.contains(waypointId)) {
              updatedVisited.add(waypointId);
            }
            updatedMissed.remove(waypointId);
          } else {
            if (!updatedMissed.contains(waypointId)) {
              updatedMissed.add(waypointId);
            }
          }
          
          // تحديث currentWaypointIndex
          int newIndex = trip.currentWaypointIndex;
          if (visited && newIndex < trip.route.waypoints.length - 1) {
            newIndex++;
          }
          
          final updatedTrip = trip.copyWith(
            visitedWaypointIds: updatedVisited,
            missedWaypointIds: updatedMissed,
            currentWaypointIndex: newIndex,
          );
          
          AppLogger.success('[TripsRepository] تم تحديث نقطة الطريق');
          return update(updatedTrip);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRepository] فشل تحديث نقطة الطريق', e, stackTrace);
      return Left(ServerFailure('فشل التحديث: ${e.toString()}'));
    }
  }

  /// إضافة انحراف جديد
  Future<Either<Failure, TripEntity>> addDeviation({
    required String tripId,
    required Deviation deviation,
  }) async {
    try {
      AppLogger.info('[TripsRepository] إضافة انحراف: ${deviation.severity.name}');
      
      final tripResult = await get(tripId);
      
      return tripResult.fold(
        (failure) => Left(failure),
        (trip) async {
          if (trip == null) {
            return const Left(NotFoundFailure('الرحلة غير موجودة'));
          }
          
          final updatedDeviations = [...trip.deviations, deviation];
          
          final updatedTrip = trip.copyWith(
            deviations: updatedDeviations,
            currentDeviation: deviation,
            totalDeviations: trip.totalDeviations + 1,
          );
          
          AppLogger.success('[TripsRepository] تم إضافة الانحراف');
          return update(updatedTrip);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRepository] فشل إضافة الانحراف', e, stackTrace);
      return Left(ServerFailure('فشل الإضافة: ${e.toString()}'));
    }
  }

  /// حل الانحراف الحالي
  Future<Either<Failure, TripEntity>> resolveCurrentDeviation({
    required String tripId,
  }) async {
    try {
      AppLogger.info('[TripsRepository] حل الانحراف الحالي');
      
      final tripResult = await get(tripId);
      
      return tripResult.fold(
        (failure) => Left(failure),
        (trip) async {
          if (trip == null) {
            return const Left(NotFoundFailure('الرحلة غير موجودة'));
          }
          
          if (trip.currentDeviation == null) {
            return Right(trip); // لا يوجد انحراف لحله
          }
          
          // حل الانحراف
          final resolvedDeviation = trip.currentDeviation!.resolve();
          
          // تحديث قائمة الانحرافات
          final updatedDeviations = trip.deviations.map((d) {
            if (d.id == resolvedDeviation.id) {
              return resolvedDeviation;
            }
            return d;
          }).toList();
          
          final updatedTrip = trip.copyWith(
            deviations: updatedDeviations,
            currentDeviation: null,
          );
          
          AppLogger.success('[TripsRepository] تم حل الانحراف');
          return update(updatedTrip);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRepository] فشل حل الانحراف', e, stackTrace);
      return Left(ServerFailure('فشل الحل: ${e.toString()}'));
    }
  }

  // ==================== Get Route By ID ====================

  @override
  Future<Either<Failure, dynamic>> getRouteById(String routeId) async {
    try {
      AppLogger.info('[TripsRepository] طلب جلب المسار: $routeId');
      return await _getRoute(routeId);
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRepository] فشل في getRouteById', e, stackTrace);
      return Left(ServerFailure('فشل جلب المسار: ${e.toString()}'));
    }
  }

  // ==================== Trip Settings ====================

  @override
  Future<Either<Failure, void>> saveTripSettings(TripSettingsEntity settings) async {
    try {
      AppLogger.info('[TripsRepository] حفظ إعدادات الرحلات للمستخدم: ${settings.userId}');
      
      // تحويل Entity إلى Model للحصول على toJson()
      final settingsModel = TripSettingsModel.fromEntity(settings);
      
      // 1. الحفظ المحلي (Hive) - دائماً أولاً
      try {
        // التحقق من أن الـ box مفتوح أولاً
        if (!Hive.isBoxOpen('trip_settings')) {
          AppLogger.info('[TripsRepository] فتح box: trip_settings');
          await Hive.openBox('trip_settings');
        }
        
        final box = _hive.getBox('trip_settings');
        await box.put(settings.userId, settingsModel.toJson());
        
        AppLogger.success('[TripsRepository] تم حفظ الإعدادات محلياً');
      } catch (e) {
        AppLogger.error('[TripsRepository] فشل الحفظ المحلي', e);
        // نستمر للمزامنة حتى لو فشل الحفظ المحلي
      }
      
      // 2. المزامنة مع Firebase (إذا كان متصل)
      if (connectivityService.isConnected) {
        try {
          AppLogger.info('[TripsRepository] مزامنة الإعدادات مع Firebase');
          
          await _firestore
              .collection('users')
              .doc(settings.userId)
              .collection('trip_settings')
              .doc('settings')
              .set(settingsModel.toJson(), SetOptions(merge: true));
          
          AppLogger.success('[TripsRepository] تمت المزامنة مع Firebase بنجاح');
        } catch (e) {
          AppLogger.warning('[TripsRepository] فشلت المزامنة مع Firebase: $e (ستتم لاحقاً)');
          // لا نرجع خطأ - الحفظ المحلي كافٍ
        }
      } else {
        AppLogger.info('[TripsRepository] لا يوجد اتصال - ستتم المزامنة لاحقاً');
      }
      
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRepository] فشل حفظ الإعدادات', e, stackTrace);
      return Left(CacheFailure('فشل حفظ الإعدادات: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, TripSettingsEntity>> getTripSettings(String userId) async {
    try {
      AppLogger.info('[TripsRepository] جلب إعدادات الرحلات للمستخدم: $userId');
      
      // 1. محاولة الجلب من Hive أولاً (أسرع)
      try {
        if (!Hive.isBoxOpen('trip_settings')) {
          AppLogger.info('[TripsRepository] فتح box: trip_settings');
          await Hive.openBox('trip_settings');
        }
        
        final box = _hive.getBox('trip_settings');
        final data = box.get(userId);
        
        if (data != null) {
          final settings = TripSettingsModel.fromJson(
            Map<String, dynamic>.from(data as Map),
          ).toEntity();
          
          AppLogger.success('[TripsRepository] تم جلب الإعدادات من التخزين المحلي');
          return Right(settings);
        }
      } catch (e) {
        AppLogger.warning('[TripsRepository] فشل الجلب من Hive: $e');
      }
      
      // 2. إذا لم توجد محلياً، نجلب من Firebase
      if (connectivityService.isConnected) {
        try {
          AppLogger.info('[TripsRepository] جلب الإعدادات من Firebase');
          
          final doc = await _firestore
              .collection('users')
              .doc(userId)
              .collection('trip_settings')
              .doc('settings')
              .get();
          
          if (doc.exists && doc.data() != null) {
            final model = TripSettingsModel.fromJson(doc.data()!);
            
            // حفظ في Hive للاستخدام في المرة القادمة
            try {
              final box = _hive.getBox('trip_settings');
              await box.put(userId, model.toJson());
              AppLogger.info('[TripsRepository] تم حفظ الإعدادات محلياً من Firebase');
            } catch (e) {
              AppLogger.warning('[TripsRepository] فشل حفظ الإعدادات محلياً: $e');
            }
            
            AppLogger.success('[TripsRepository] تم جلب الإعدادات من Firebase');
            return Right(model.toEntity());
          }
        } catch (e) {
          AppLogger.warning('[TripsRepository] فشل الجلب من Firebase: $e');
        }
      }
      
      // 3. إذا لم توجد في أي مكان، إنشاء إعدادات افتراضية
      AppLogger.info('[TripsRepository] لا توجد إعدادات - إنشاء إعدادات افتراضية');
      
      final defaultSettings = TripSettingsModel.createDefault(userId);
      
      // حفظ الإعدادات الافتراضية محلياً
      try {
        final box = _hive.getBox('trip_settings');
        await box.put(userId, defaultSettings.toJson());
        AppLogger.info('[TripsRepository] تم حفظ الإعدادات الافتراضية محلياً');
      } catch (e) {
        AppLogger.warning('[TripsRepository] فشل حفظ الإعدادات الافتراضية: $e');
      }
      
      // مزامنة مع Firebase إذا كان متصل
      if (connectivityService.isConnected) {
        try {
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('trip_settings')
              .doc('settings')
              .set(defaultSettings.toJson());
          AppLogger.success('[TripsRepository] تمت مزامنة الإعدادات الافتراضية مع Firebase');
        } catch (e) {
          AppLogger.warning('[TripsRepository] فشلت المزامنة: $e (ستتم لاحقاً)');
        }
      }
      
      return Right(defaultSettings.toEntity());
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRepository] خطأ غير متوقع في جلب الإعدادات', e, stackTrace);
      // في حالة الخطأ الشامل، إرجاع الإعدادات الافتراضية
      return Right(TripSettingsEntity.defaults(userId));
    }
  }

  /// حفظ مسار معدل محلياً
  /// Single Responsibility: حفظ المسار المعدل في التخزين المحلي فقط
  @override
  Future<Either<Failure, void>> saveModifiedRoute(dynamic route) async {
    try {
      final routeEntity = route as RouteEntity;
      AppLogger.info('[TripsRepository] حفظ المسار المعدل محلياً: ${routeEntity.id}');
      
      // ✅ استخدام HiveService (TypedBox) مثل بقية الكود - يحفظ RouteModel object
      final routeModel = RouteModel.fromEntity(routeEntity);
      await hiveService.put<RouteModel>('routes', routeEntity.id, routeModel);
      
      AppLogger.success('[TripsRepository] تم حفظ المسار المعدل في Hive: ${routeEntity.id}');
      
      // ✅ إضافة للطابور للمزامنة مع Firebase لاحقاً
      await syncService.addToQueue(SyncOperation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        entity: 'routes',
        operation: 'create',
        data: routeModel.toJson(),
        timestamp: DateTime.now(),
      ));
      AppLogger.info('[TripsRepository] تمت إضافة المسار المعدل لطابور المزامنة');
      
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRepository] فشل حفظ المسار المعدل', e, stackTrace);
      return Left(CacheFailure('فشل حفظ المسار: ${e.toString()}'));
    }
  }

  /// مزامنة المسار المعدل مع Firebase
  /// Single Responsibility: مزامنة المسار المعدل مع السحابة
  @override
  Future<Either<Failure, void>> syncModifiedRouteToFirebase(dynamic route) async {
    try {
      final routeEntity = route as RouteEntity;
      AppLogger.info('[TripsRepository] مزامنة المسار المعدل مع Firebase: ${routeEntity.id}');
      
      if (!connectivityService.isConnected) {
        AppLogger.warning('[TripsRepository] لا يوجد اتصال - سيتم المزامنة من الطابور لاحقاً');
        // لا نُعيد Left - الطابور سيتكفل بالمزامنة
        return const Right(null);
      }
      
      final routeModel = RouteModel.fromEntity(routeEntity);
      final routeData = routeModel.toJson();
      
      // ✅ كتابة في كلا المسارين (subcollection + legacy)
      await Future.wait([
        _firestore
            .collection('users')
            .doc(routeEntity.userId)
            .collection('routes')
            .doc(routeEntity.id)
            .set(routeData, SetOptions(merge: true)),
        _firestore
            .collection('routes')
            .doc(routeEntity.id)
            .set(routeData, SetOptions(merge: true)),
      ]);
      
      AppLogger.success('[TripsRepository] تمت مزامنة المسار المعدل (subcollection + legacy)');
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error('[TripsRepository] فشلت مزامنة المسار مع Firebase', e, stackTrace);
      // لا نُفشل العملية - الرحلة ستبدأ حتى لو فشلت المزامنة
      return const Right(null);
    }
  }
}
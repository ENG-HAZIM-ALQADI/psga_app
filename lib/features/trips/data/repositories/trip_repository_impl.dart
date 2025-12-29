import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/services/sync/sync_manager.dart';
import '../../../../core/services/sync/sync_item.dart';
import '../../domain/entities/trip_entity.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/entities/deviation_entity.dart';
import '../../domain/repositories/trip_repository.dart';
import '../../domain/repositories/route_repository.dart';
import '../datasources/trip_local_datasource.dart';
import '../datasources/trip_remote_datasource.dart';
import '../models/trip_model.dart';
import '../models/location_model.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🛣️ TripRepositoryImpl - تنفيذ واجهة Trips Repository (Data Layer)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف من هذا الملف:
/// هذا الملف هو **الجسر بين Domain و Data Layers**
/// 
/// المسؤوليات الرئيسية:
/// 1. 💾 التعامل مع التخزين المحلي (Hive Database)
/// 2. ☁️ التعامل مع البيانات السحابية (Firebase)
/// 3. 🔄 مزامنة البيانات بين Local و Remote
/// 4. ❌ معالجة الأخطاء وتحويلها لـ Failures
/// 5. 📊 إدارة حالة الرحلات (نشطة، مكتملة، ملغاة)
/// 6. 📝 تسجيل التحديثات في Sync Queue (لمزامنة لاحقة)
///
/// نمط Repository:
/// ```
/// Repository = واجهة موحدة للبيانات
/// بدلاً من أن يعرف BLoC أين تأتي البيانات:
/// 
/// ❌ BAD: BLoC يعرف عن Hive و Firebase
///    BLoC → اختيار Hive أم Firebase؟
///    BLoC → معالجة الأخطاء → BLoC مختنق بالتفاصيل!
/// 
/// ✅ GOOD: BLoC لا يهمه أين تأتي البيانات
///    BLoC → Repository
///    Repository → يختار Hive أم Firebase
///    Repository → معالجة الأخطاء والمزامنة
///    BLoC ← نتيجة نظيفة (Either)
/// ```
///
/// مثال على دورة حياة عملية:
/// ```
/// 1. TripBloc.add(StartTripEvent)
/// 2. TripBloc يستدعي: startTripUseCase()
/// 3. startTripUseCase يستدعي: tripRepository.startTrip()
/// 4. TripRepositoryImpl.startTrip() يفعل:
///    - ينشئ TripModel
///    - يحفظ في Hive (محلياً)
///    - يضيف إلى Sync Queue (لنقل Firebase لاحقاً)
///    - يحدث عدادات في RouteRepository
/// 5. النتيجة ترجع: Right(trip)
/// 6. BLoC يصدر: emit(TripActive(trip))
/// 7. الواجهة تحدث وتعرض الخريطة
/// ```

class TripRepositoryImpl implements TripRepository {
  /// 🔗 الاعتماديات (التخزين والمزامنة)

  /// 💾 LOCAL: Hive Database
  /// الدور: حفظ البيانات محلياً على الجهاز
  /// الفوائد:
  /// - ⚡ سريع جداً (لا يحتاج إنترنت)
  /// - 🔒 آمن (بيانات خاصة على الجهاز)
  /// - 📴 يعمل بدون إنترنت (Offline-First)
  /// 
  /// الاستخدام: الرحلات النشطة والسجل المحلي
  final TripLocalDataSource localDataSource;

  /// ☁️ REMOTE: Firebase
  /// الدور: مزامنة البيانات مع السحابة
  /// الفوائد:
  /// - 🌍 متاح من أي مكان
  /// - 🔄 متزامن على أجهزة متعددة
  /// - 📊 نسخة احتياطية آمنة
  /// 
  /// الاستخدام: حفظ نسخة من الرحلات (للنسخ الاحتياطي والمزامنة)
  final TripRemoteDataSource remoteDataSource;

  /// 🛣️ المسارات
  /// الدور: ربط الرحلات بالمسارات الأصلية
  /// لماذا نحتاجه؟
  /// - التحقق من أن المسار موجود قبل بدء رحلة
  /// - تحديث إحصائيات المسار (عدد مرات الاستخدام)
  /// - الحصول على معلومات المسار (النقاط والاسم)
  final RouteRepository routeRepository;

  /// 🔄 مدير المزامنة المركزي
  /// الدور: إدارة queue المزامنة
  /// 
  /// كيفية العمل:
  /// 1. عند حفظ رحلة محلياً → أضفها إلى Sync Queue
  /// 2. SyncManager يراقب الاتصال بالإنترنت
  /// 3. عند الاتصال → يرسل كل العمليات لـ Firebase
  /// 4. بعد النجاح → يحذفها من Queue
  /// 
  /// الفائدة: لا نفقد البيانات حتى لو انقطع الإنترنت!
  final SyncManager _syncManager = SyncManager.instance;

  /// ═══════════════════════════════════════════════════════════════════════════
  /// Constructor - تهيئة Repository
  /// ═══════════════════════════════════════════════════════════════════════════
  /// 
  /// كل اعتماديات يتم حقنها من الخارج (Dependency Injection)
  /// لماذا؟ سهولة الاختبار + المرونة

  TripRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.routeRepository,
  });

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🚗 startTrip() - بدء رحلة جديدة
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// المعاملات:
  /// [routeId]: معرف المسار الذي تريد بدء رحلة عليه
  /// [startLocation]: الموقع الحالي (نقطة البداية)
  ///
  /// الإرجاع:
  /// Either<Failure, TripEntity> = نجاح أو فشل

  @override
  Future<Either<Failure, TripEntity>> startTrip(
    String routeId,
    LocationEntity startLocation,
  ) async {
    try {
      /// 1️⃣ جلب بيانات المسار من Repository
      /// لماذا؟ نحتاج معرف المستخدم والبيانات الأخرى من المسار
      final routeResult = await routeRepository.getRoute(routeId);

      /// معالجة النتيجة: إما فشل أو نجاح
      return routeResult.fold(
        /// ❌ المسار غير موجود
        (failure) => Left(failure),

        /// ✅ تم جلب المسار بنجاح
        (route) async {
          /// 2️⃣ إنشاء معرف فريد للرحلة الجديدة
          /// نستخدم الـ timestamp (الوقت الحالي بالمللي ثانية)
          /// مثال: "1703088123456" = رقم فريد وغير متكرر
          final tripId = DateTime.now().millisecondsSinceEpoch.toString();

          /// 3️⃣ إنشاء TripModel (نموذج الرحلة)
          /// 
          /// ما الفرق بين TripEntity و TripModel؟
          /// - TripEntity: في Domain (مستقلة عن Firebase/Hive)
          /// - TripModel: في Data (تحتوي على @HiveType و toJson())
          /// 
          /// المعلومات الأساسية:
          /// - id: معرف فريد للرحلة
          /// - userId: من المسار
          /// - routeId: المسار المختار
          /// - status: TripStatus.active (الرحلة نشطة الآن)
          /// - startTime: وقت البدء
          /// - startLocation: موقع البداية
          /// - currentLocation: نفس موقع البداية الآن
          /// - locationHistory: [startLocation] (سنضيف مواقع لاحقاً)
          final trip = TripModel(
            id: tripId,
            userId: route.userId,        /// من بيانات المسار
            routeId: routeId,
            routeName: route.name,       /// اسم المسار
            status: TripStatus.active,   /// الحالة: نشطة
            startTime: DateTime.now(),   /// وقت البدء
            startLocation: startLocation,
            currentLocation: startLocation,
            locationHistory: [startLocation],
          );

          /// 4️⃣ حفظ الرحلة محلياً في Hive
          /// لماذا Hive أولاً؟
          /// ⚡ سريع جداً
          /// 📴 يعمل بدون إنترنت
          /// البيانات متاحة فوراً للشاشة
          await localDataSource.saveTrip(trip);

          /// 5️⃣ إضافة الرحلة إلى Sync Queue
          /// 
          /// ما هو SyncItem؟
          /// object يمثل "عملية يجب مزامنتها مع Firebase"
          /// 
          /// البيانات:
          /// - id: معرف الرحلة
          /// - type: SyncItemType.trip (نوع العملية: رحلة)
          /// - action: SyncAction.create (العملية: إنشاء)
          /// - data: trip.toJson() (البيانات بصيغة JSON)
          /// 
          /// كيف يعمل؟
          /// 1. نضيف الـ SyncItem للـ Queue
          /// 2. SyncManager ينتظر اتصال الإنترنت
          /// 3. عند الاتصال: يرسل البيانات لـ Firebase
          /// 4. بعد النجاح: يحذف الـ Item من Queue
          final syncItem = SyncItem(
            createdAt: DateTime.now(),
            id: trip.id,
            type: SyncItemType.trip,
            action: SyncAction.create,
            data: trip.toJson(),
            localId: trip.id,
          );
          await _syncManager.addToQueue(syncItem);

          /// 6️⃣ تحديث إحصائيات المسار
          /// 
          /// لماذا هذا مهم؟
          /// - نريد تتبع: كم مرة استُخدم هذا المسار؟
          /// - هذا يساعد المستخدم على معرفة أكثر المسارات استخداماً
          /// 
          /// العملية:
          /// 1. نسخ بيانات المسار
          /// 2. نزيد عداد الاستخدام بـ 1
          /// 3. نحدث وقت التعديل
          /// 4. نحفظه في Repository
          final updatedRoute = route.copyWith(
            usageCount: route.usageCount + 1,
            updatedAt: DateTime.now(),
          );
          await routeRepository.updateRoute(updatedRoute);

          /// 7️⃣ تسجيل النجاح
          AppLogger.success('[TripRepo] بدء رحلة: ${route.name}');

          /// 8️⃣ إرجاع النتيجة الناجحة
          /// Right = النجاح ✅
          /// trip = بيانات الرحلة الجديدة
          return Right(trip);
        },
      );
    } catch (e) {
      /// ❌ خطأ غير متوقع
      AppLogger.error('[TripRepo] خطأ في بدء الرحلة: $e');
      return const Left(ServerFailure(message: 'فشل في بدء الرحلة'));
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🏁 endTrip() - إنهاء الرحلة الحالية
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// ما يحدث عند إنهاء الرحلة:
  /// 1️⃣ حساب المسافة الكلية (من جميع المواقع المسجلة)
  /// 2️⃣ حساب الوقت المستغرق
  /// 3️⃣ حساب السرعة المتوسطة
  /// 4️⃣ حفظ كل البيانات
  /// 5️⃣ تحديث حالة الرحلة من "active" إلى "completed"

  @override
  Future<Either<Failure, TripEntity>> endTrip(
    String tripId,
    LocationEntity endLocation,
  ) async {
    try {
      /// 1️⃣ جلب الرحلة من Hive
      final trip = await localDataSource.getTrip(tripId);

      /// التحقق: هل الرحلة موجودة؟
      if (trip == null) {
        return const Left(NotFoundFailure(message: 'الرحلة غير موجودة'));
      }

      /// 2️⃣ حساب المسافة الكلية
      /// 
      /// الفكرة: نمر على كل المواقع المسجلة ونحسب المسافة بينها
      /// 
      /// مثال:
      /// locationHistory = [موقع1, موقع2, موقع3, موقع4]
      /// 
      /// distance = расстояние(موقع1→موقع2) 
      ///          + расстояние(موقع2→موقع3) 
      ///          + расстояние(موقع3→موقع4)
      ///          + расстояние(موقع4→endLocation)

      double totalDistance = 0;
      final history = trip.locationHistory;
      for (int i = 1; i < history.length; i++) {
        /// distanceTo() دالة توجد المسافة بين نقطتين (بالكيلومترات تقريباً)
        totalDistance += history[i - 1].distanceTo(history[i]);
      }
      /// إضافة المسافة من آخر موقع إلى موقع الإنهاء
      totalDistance += trip.currentLocation?.distanceTo(endLocation) ?? 0;

      /// 3️⃣ حساب الوقت والسرعة المتوسطة
      /// 
      /// الصيغة الأساسية:
      /// السرعة = المسافة ÷ الزمن
      /// السرعة (كم/ساعة) = المسافة (كم) ÷ الزمن (ساعة)

      final endTime = DateTime.now();
      final duration = endTime.difference(trip.startTime);

      /// حساب السرعة (كم/ساعة)
      /// duration.inSeconds: الوقت بالثواني
      /// نقسم على 3600 للتحويل لساعات
      /// totalDistance بالكيلومترات / 1000 (تحويل من متر لكم)
      final avgSpeed = duration.inSeconds > 0
          ? (totalDistance / 1000) / (duration.inSeconds / 3600)
          : 0.0;

      /// 4️⃣ إنشاء الرحلة المحدثة (المكتملة)
      /// 
      /// ننسخ البيانات ونضيف المعلومات الجديدة:
      /// - endTime: وقت الإنهاء
      /// - endLocation: موقع الإنهاء
      /// - status: TripStatus.completed
      /// - totalDistance و averageSpeed (محسوبة للتو)

      final updatedTrip = TripModel(
        id: trip.id,
        userId: trip.userId,
        routeId: trip.routeId,
        routeName: trip.routeName,
        status: TripStatus.completed,    /// ✅ الرحلة اكتملت
        startTime: trip.startTime,
        endTime: endTime,                 /// الوقت الحالي
        startLocation: trip.startLocation,
        endLocation: endLocation,
        currentLocation: endLocation,
        locationHistory: [...trip.locationHistory, endLocation],
        deviations: trip.deviations,
        alertsTriggered: trip.alertsTriggered,
        totalDistance: totalDistance / 1000,  /// بالكيلومترات
        averageSpeed: avgSpeed,
        notes: trip.notes,
      );

      /// 5️⃣ حفظ التحديثات
      /// أولاً: محلياً في Hive
      await localDataSource.updateTrip(updatedTrip);

      /// ثانياً: إضافة إلى Sync Queue (لمزامنة Firebase)
      final syncItem = SyncItem(
        createdAt: DateTime.now(),
        id: trip.id,
        type: SyncItemType.trip,
        action: SyncAction.update,
        data: updatedTrip.toJson(),
        localId: trip.id,
      );
      await _syncManager.addToQueue(syncItem);

      /// 6️⃣ تسجيل النجاح
      AppLogger.success('[TripRepo] انتهاء الرحلة: ${trip.routeName}');
      return Right(updatedTrip);

    } catch (e) {
      AppLogger.error('[TripRepo] خطأ في إنهاء الرحلة: $e');
      return const Left(ServerFailure(message: 'فشل في إنهاء الرحلة'));
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// ⏸️ pauseTrip() - إيقاف الرحلة مؤقتاً
  /// ═══════════════════════════════════════════════════════════════════════════
  /// 
  /// الهدف: وضع الرحلة على "pause"
  /// الفرق عن "end":
  /// - pause: الرحلة معلقة مؤقتاً (يمكن استئنافها)
  /// - end: الرحلة انتهت نهائياً

  @override
  Future<Either<Failure, TripEntity>> pauseTrip(String tripId) async {
    try {
      final trip = await localDataSource.getTrip(tripId);

      if (trip == null) {
        return const Left(NotFoundFailure(message: 'الرحلة غير موجودة'));
      }

      /// تحديث الحالة من active إلى paused
      final updatedTrip = TripModel.fromEntity(trip.copyWith(status: TripStatus.paused));

      await localDataSource.updateTrip(updatedTrip);

      /// إضافة إلى Sync Queue
      final syncItem = SyncItem(
        createdAt: DateTime.now(),
        id: trip.id,
        type: SyncItemType.trip,
        action: SyncAction.update,
        data: updatedTrip.toJson(),
        localId: trip.id,
      );
      await _syncManager.addToQueue(syncItem);

      AppLogger.info('[TripRepo] إيقاف مؤقت للرحلة');
      return Right(updatedTrip);
    } catch (e) {
      AppLogger.error('[TripRepo] خطأ في إيقاف الرحلة: $e');
      return const Left(ServerFailure(message: 'فشل في إيقاف الرحلة'));
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// ▶️ resumeTrip() - استئناف الرحلة الموقوفة
  /// ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<Either<Failure, TripEntity>> resumeTrip(String tripId) async {
    try {
      final trip = await localDataSource.getTrip(tripId);

      if (trip == null) {
        return const Left(NotFoundFailure(message: 'الرحلة غير موجودة'));
      }

      /// تحديث الحالة من paused إلى active
      final updatedTrip = TripModel.fromEntity(trip.copyWith(status: TripStatus.active));

      await localDataSource.updateTrip(updatedTrip);

      final syncItem = SyncItem(
        createdAt: DateTime.now(),
        id: trip.id,
        type: SyncItemType.trip,
        action: SyncAction.update,
        data: updatedTrip.toJson(),
        localId: trip.id,
      );
      await _syncManager.addToQueue(syncItem);

      AppLogger.info('[TripRepo] استئناف الرحلة');
      return Right(updatedTrip);
    } catch (e) {
      AppLogger.error('[TripRepo] خطأ في استئناف الرحلة: $e');
      return const Left(ServerFailure(message: 'فشل في استئناف الرحلة'));
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// ❌ cancelTrip() - إلغاء الرحلة نهائياً
  /// ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<Either<Failure, void>> cancelTrip(String tripId) async {
    try {
      final trip = await localDataSource.getTrip(tripId);

      if (trip == null) {
        return const Left(NotFoundFailure(message: 'الرحلة غير موجودة'));
      }

      /// تحديث الحالة إلى cancelled
      final updatedTrip = TripModel.fromEntity(trip.copyWith(
        status: TripStatus.cancelled,
        endTime: DateTime.now(),
      ));

      await localDataSource.updateTrip(updatedTrip);

      final syncItem = SyncItem(
        createdAt: DateTime.now(),
        id: trip.id,
        type: SyncItemType.trip,
        action: SyncAction.delete,  /// عملية: حذف
        data: {'id': trip.id},
        localId: trip.id,
      );
      await _syncManager.addToQueue(syncItem);

      AppLogger.info('[TripRepo] تم إلغاء الرحلة');
      return const Right(null);
    } catch (e) {
      AppLogger.error('[TripRepo] خطأ في إلغاء الرحلة: $e');
      return const Left(ServerFailure(message: 'فشل في إلغاء الرحلة'));
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 📍 getActiveTrip() - جلب الرحلة النشطة الحالية
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// الهدف: الحصول على الرحلة النشطة الآن
  /// 
  /// الاستراتيجية (Offline-First):
  /// 1️⃣ ابحث محلياً في Hive (سريع جداً)
  /// 2️⃣ إذا لم تجد: ابحث في Firebase (قد تكون تمت مزامنتها من جهاز آخر)
  /// 3️⃣ إذا وجدتها هناك: احفظها محلياً لسرعة أكبر
  ///
  /// الفائدة: يعمل بدون إنترنت + متزامن مع أجهزة أخرى

  @override
  Future<Either<Failure, TripEntity?>> getActiveTrip(String userId) async {
    try {
      /// 1️⃣ محاولة جلب من Hive أولاً
      var trip = await localDataSource.getActiveTrip(userId);

      /// 2️⃣ إذا لم توجد محلياً:
      if (trip == null) {
        AppLogger.info('[TripRepo] 📥 جلب الرحلة النشطة من Firebase...');
        /// ابحث في Firebase
        trip = await remoteDataSource.getActiveTrip(userId);

        /// 3️⃣ إذا وجدت في Firebase: احفظها محلياً
        if (trip != null) {
          await localDataSource.saveTrip(trip);
          AppLogger.success('[TripRepo] ✅ تم حفظ الرحلة النشطة محلياً');
        }
      }

      return Right(trip);
    } catch (e) {
      AppLogger.error('[TripRepo] ❌ خطأ في جلب الرحلة النشطة: $e');
      return const Left(ServerFailure(message: 'فشل في جلب الرحلة النشطة'));
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 📜 getTripHistory() - جلب سجل جميع الرحلات السابقة
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// المعاملات:
  /// [userId]: معرف المستخدم
  /// [limit]: عدد الرحلات المطلوبة (آخر 10 مثلاً)
  /// [from]: من تاريخ (فلترة)
  /// [to]: إلى تاريخ (فلترة)

  @override
  Future<Either<Failure, List<TripEntity>>> getTripHistory(
    String userId, {
    int? limit,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      /// 1️⃣ جلب من Firebase أولاً (للحصول على أحدث البيانات)
      List<TripModel> remoteTrips = [];
      try {
        remoteTrips = await remoteDataSource.getTripHistory(
          userId,
          limit: limit,
          from: from,
          to: to,
        );
        /// حفظ البيانات محلياً للإسراع في المستقبل
        for (var trip in remoteTrips) {
          await localDataSource.saveTrip(trip);
        }
        AppLogger.success('[TripRepo] ✅ جلب وحفظ ${remoteTrips.length} رحلة من Firebase في Hive');
      } catch (e) {
        /// إذا فشل جلب Firebase: استخدم البيانات المحلية
        AppLogger.warning('[TripRepo] ⚠️ فشل جلب البيانات من Firebase، استخدام التخزين المحلي: $e');
      }

      /// 2️⃣ قراءة البيانات من Hive (السريع)
      AppLogger.info('[TripRepo] 📖 قراءة الرحلات من Hive...');
      var trips = await localDataSource.getTripHistory(userId);
      AppLogger.info('[TripRepo] 📖 تم قراءة ${trips.length} رحلة من Hive');

      /// 3️⃣ تطبيق الفلاتر (if provided)
      if (from != null) {
        trips = trips.where((t) => t.startTime.isAfter(from)).toList();
      }
      if (to != null) {
        trips = trips.where((t) => t.startTime.isBefore(to)).toList();
      }
      if (limit != null && trips.length > limit) {
        trips = trips.take(limit).toList();
      }

      AppLogger.success('[TripRepo] ✅ تم جلب ${trips.length} رحلة للمستخدم: $userId');
      return Right(trips);
    } catch (e) {
      AppLogger.error('[TripRepo] خطأ في جلب سجل الرحلات: $e');
      return const Left(ServerFailure(message: 'فشل في جلب سجل الرحلات'));
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 📍 updateTripLocation() - تحديث موقع الرحلة الحالي
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// متى يتم استدعاء هذه الدالة؟
  /// كل ثانية تقريباً (حسب تحديثات GPS)
  /// 
  /// ما يحدث:
  /// 1️⃣ حفظ الموقع الجديد
  /// 2️⃣ إضافته لـ locationHistory
  /// 3️⃣ مزامنة مع Firebase

  @override
  Future<Either<Failure, TripEntity>> updateTripLocation(
    String tripId,
    LocationEntity location,
  ) async {
    try {
      final trip = await localDataSource.getTrip(tripId);

      if (trip == null) {
        return const Left(NotFoundFailure(message: 'الرحلة غير موجودة'));
      }

      /// تحويل إلى LocationModel (للحفظ في Database)
      final locationModel = LocationModel.fromEntity(location);

      /// حفظ في سجل المواقع
      await localDataSource.saveLocationToHistory(tripId, locationModel);

      /// تحديث الرحلة بالموقع الجديد
      final updatedTrip = TripModel.fromEntity(trip.copyWith(
        currentLocation: location,
        locationHistory: [...trip.locationHistory, location],
      ));

      await localDataSource.updateTrip(updatedTrip);

      /// إضافة للمزامنة
      final syncItem = SyncItem(
        createdAt: DateTime.now(),
        id: trip.id,
        type: SyncItemType.trip,
        action: SyncAction.update,
        data: updatedTrip.toJson(),
        localId: trip.id,
      );
      await _syncManager.addToQueue(syncItem);

      return Right(updatedTrip);
    } catch (e) {
      AppLogger.error('[TripRepo] خطأ في تحديث الموقع: $e');
      return const Left(ServerFailure(message: 'فشل في تحديث الموقع'));
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// ⚠️ addDeviation() - تسجيل انحراف عن المسار
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// الانحراف: عندما ينحرف المستخدم عن المسار المرسوم
  /// مثال: كان يجب أن يذهب لليسار لكنه ذهب لليمين
  ///
  /// ما يحدث:
  /// 1️⃣ حفظ الانحراف (نقطة الانحراف، الوصف، إلخ)
  /// 2️⃣ زيادة عداد الانحرافات
  /// 3️⃣ قد يؤدي لتنبيه تلقائي (Alert)

  @override
  Future<Either<Failure, void>> addDeviation(
    String tripId,
    DeviationEntity deviation,
  ) async {
    try {
      final trip = await localDataSource.getTrip(tripId);

      if (trip == null) {
        return const Left(NotFoundFailure(message: 'الرحلة غير موجودة'));
      }

      /// تحديث الرحلة:
      /// 1. إضافة الانحراف للقائمة
      /// 2. زيادة عداد الانحرافات
      final updatedTrip = TripModel.fromEntity(trip.copyWith(
        deviations: [...trip.deviations, deviation],
        alertsTriggered: trip.alertsTriggered + 1,
      ));

      await localDataSource.updateTrip(updatedTrip);

      final syncItem = SyncItem(
        createdAt: DateTime.now(),
        id: trip.id,
        type: SyncItemType.trip,
        action: SyncAction.update,
        data: (updatedTrip).toJson(),
        localId: trip.id,
      );
      await _syncManager.addToQueue(syncItem);

      AppLogger.warning('[TripRepo] تم تسجيل انحراف جديد');
      return const Right(null);
    } catch (e) {
      AppLogger.error('[TripRepo] خطأ في إضافة الانحراف: $e');
      return const Left(ServerFailure(message: 'فشل في تسجيل الانحراف'));
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 📡 tripUpdates() - Stream لتحديثات الرحلة (Real-time)
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// Stream = تدفق مستمر من البيانات
  /// مثل راديو يستقبل باستمرار (لا تنتهي المحطة أبداً)
  ///
  /// الاستخدام:
  /// - تحديثات الموقع الفوري على الخريطة
  /// - تحديثات الانحرافات
  /// - إشعارات الرحلة الحية

  @override
  Stream<TripEntity> tripUpdates(String tripId) {
    /// توجيه الطلب للـ Remote DataSource (Firebase Realtime)
    /// Firebase سيرسل التحديثات تلقائياً عند أي تغيير
    return remoteDataSource.tripUpdates(tripId);
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// ملخص تدفق البيانات الكامل في TripRepositoryImpl:
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// ```
/// UI (MapPage)
///   ↓ يضغط "ابدأ الرحلة"
/// TripBloc.add(StartTripEvent)
///   ↓
/// TripBloc استدعاء: startTripUseCase()
///   ↓
/// startTripUseCase استدعاء: tripRepository.startTrip()
///   ↓ ← أنت هنا!
/// TripRepositoryImpl.startTrip():
///   1. جلب بيانات المسار ✓
///   2. إنشاء TripModel ✓
///   3. حفظ في Hive (محلياً) ✓
///   4. إضافة لـ Sync Queue (لـ Firebase) ✓
///   5. تحديث إحصائيات المسار ✓
///   ↓
/// النتيجة: Right(trip) أو Left(failure)
///   ↓
/// BLoC معالجة النتيجة:
///   emit(TripActive(trip)) أو emit(TripError(message))
///   ↓
/// BlocBuilder يرى الحالة الجديدة:
///   تحديث الواجهة وعرض الخريطة
/// ```
/// 
/// ═══════════════════════════════════════════════════════════════════════════

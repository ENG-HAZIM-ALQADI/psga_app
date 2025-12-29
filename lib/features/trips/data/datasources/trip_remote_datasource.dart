import 'dart:async';
import 'package:hive/hive.dart';
import '../../../../core/services/storage/hive_boxes.dart';
import '../models/trip_model.dart';


/// ═══════════════════════════════════════════════════════════════════════════
/// ☁️ TripRemoteDataSource - واجهة البيانات البعيدة (Cloud/Firebase)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف: تعريف العمليات للبيانات البعيدة (Firebase أو API)
///
/// الفرق عن Local:
/// - Local (Hive): سريع، محلي، بدون إنترنت
/// - Remote (Firebase): بطيء، سحابي، يحتاج إنترنت
///
/// الاستخدام:
/// - مزامنة البيانات مع السحابة
/// - نسخ احتياطية
/// - مشاركة البيانات على أجهزة متعددة
/// - التحديثات الفورية (Stream/Realtime)

abstract class TripRemoteDataSource {
  /// حفظ رحلة على الخادم
  Future<void> saveTrip(TripModel trip);

  /// جلب رحلة من الخادم
  Future<TripModel?> getTrip(String id);

  /// جلب الرحلة النشطة من الخادم
  Future<TripModel?> getActiveTrip(String userId);

  /// جلب سجل الرحلات من الخادم (مع فلترة)
  Future<List<TripModel>> getTripHistory(
    String userId, {
    int? limit,
    DateTime? from,
    DateTime? to,
  });

  /// تحديث رحلة على الخادم
  Future<void> updateTrip(TripModel trip);

  /// استقبال تحديثات الرحلة الفورية (Real-time Stream)
  Stream<TripModel> tripUpdates(String tripId);
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🧪 MockTripRemoteDataSource - نسخة وهمية للاختبار
/// ═══════════════════════════════════════════════════════════════════════════

class MockTripRemoteDataSource implements TripRemoteDataSource {
  /// 💾 Storage محلي (محاكاة الخادم)
  final Map<String, TripModel> _trips = {};

  /// 📡 StreamControllers لـ Real-time updates
  /// كل رحلة لها stream خاص بها
  final Map<String, StreamController<TripModel>> _tripControllers = {};

  @override
  Future<void> saveTrip(TripModel trip) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _trips[trip.id] = trip;
    _notifyTripUpdate(trip);  /// إخطار المستمعين بالتحديث
  }

  @override
  Future<TripModel?> getTrip(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _trips[id];
  }

  @override
  Future<TripModel?> getActiveTrip(String userId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return _trips.values.firstWhere(
        (trip) => trip.userId == userId && trip.isActive,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<TripModel>> getTripHistory(
    String userId, {
    int? limit,
    DateTime? from,
    DateTime? to,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));

    var trips = _trips.values.where((trip) => trip.userId == userId);

    /// فلترة بـ التاريخ
    if (from != null) {
      trips = trips.where((trip) => trip.startTime.isAfter(from));
    }
    if (to != null) {
      trips = trips.where((trip) => trip.startTime.isBefore(to));
    }

    /// ترتيب من الأحدث للأقدم
    var result = trips.toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    /// تحديد الحد الأقصى
    if (limit != null && result.length > limit) {
      result = result.take(limit).toList();
    }

    return result;
  }

  @override
  Future<void> updateTrip(TripModel trip) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _trips[trip.id] = trip;
    _notifyTripUpdate(trip);
  }

  /// Stream للتحديثات الفورية
  /// العميل يستمع على هذا الـ Stream ليحصل على التحديثات فوراً
  @override
  Stream<TripModel> tripUpdates(String tripId) {
    _tripControllers.putIfAbsent(
      tripId,
      () => StreamController<TripModel>.broadcast(),
    );
    return _tripControllers[tripId]!.stream;
  }

  /// إخطار المستمعين بتحديث الرحلة
  void _notifyTripUpdate(TripModel trip) {
    if (_tripControllers.containsKey(trip.id)) {
      _tripControllers[trip.id]!.add(trip);
    }
  }

  /// تنظيف الموارد
  void dispose() {
    for (final controller in _tripControllers.values) {
      controller.close();
    }
    _tripControllers.clear();
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🔥 FirebaseTripRemoteDataSource - تطبيق Firebase الفعلي
/// ═══════════════════════════════════════════════════════════════════════════


class FirebaseTripRemoteDataSource implements TripRemoteDataSource {
  // @override
  // Future<void> saveTrip(TripModel trip) async {
  //   await Future.delayed(const Duration(milliseconds: 300));
  // }
  @override
  Future<void> saveTrip(TripModel trip) async {
    /// TODO: تطبيق Firebase Firestore
    /// await FirebaseFirestore.instance
    ///   .collection('trips')
    ///   .doc(trip.id)
    ///   .set(trip.toFirestore());
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<TripModel?> getTrip(String id) async {
    /// TODO: تطبيق Firebase
    await Future.delayed(const Duration(milliseconds: 200));
    return null;
  }


  @override
  Future<TripModel?> getActiveTrip(String userId) async {
    /// TODO: تطبيق Firebase
    await Future.delayed(const Duration(milliseconds: 200));
    return null;
  }

  @override
  Future<List<TripModel>> getTripHistory(
    String userId, {
    int? limit,
    DateTime? from,
    DateTime? to,
  }) async {
    // ✅ تطبيق صحيح: جلب من Hive المحلي (البيانات المزامنة)
    try {
      final tripsBox = Hive.box<TripModel>(HiveBoxes.trips);
      var trips = tripsBox.values
          .where((trip) => trip.userId == userId)
          .toList();

      if (from != null) {
        trips = trips.where((trip) => trip.startTime.isAfter(from)).toList();
      }
      if (to != null) {
        trips = trips.where((trip) => trip.startTime.isBefore(to)).toList();
      }

      trips.sort((a, b) => b.startTime.compareTo(a.startTime));

      if (limit != null && trips.length > limit) {
        trips = trips.take(limit).toList();
      }

      return trips;
    } catch (e) {
      return [];
    }
  }

  // @override
  // Future<void> updateTrip(TripModel trip) async {
  //   await Future.delayed(const Duration(milliseconds: 300));
  // }

  @override
  Future<void> updateTrip(TripModel trip) async {
    /// TODO: تطبيق Firebase
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Stream<TripModel> tripUpdates(String tripId) {
    /// TODO: تطبيق Firestore Real-time Listener
    /// return FirebaseFirestore.instance
    ///   .collection('trips')
    ///   .doc(tripId)
    ///   .snapshots()
    ///   .map((doc) => TripModel.fromFirestore(doc.data(), doc.id));
    return const Stream.empty();
  }
}



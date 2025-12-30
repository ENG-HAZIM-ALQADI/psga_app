import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../storage/hive_boxes.dart';
import 'sync_item.dart';

import '../../../features/trips/data/models/route_model.dart';
import '../../../features/trips/data/models/trip_model.dart';
import '../../../features/alerts/data/models/contact_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../di/injection_container.dart';
import '../../../features/trips/presentation/bloc/route_bloc.dart';
import '../../../features/trips/presentation/bloc/route_event.dart';
import '../../../features/trips/presentation/bloc/trip_bloc.dart';
import '../../../features/trips/presentation/bloc/trip_event.dart';
import '../../../features/alerts/presentation/bloc/contact_bloc.dart';
import '../../../features/alerts/presentation/bloc/contact_event.dart';

/// خدمة المزامنة الأساسية - Singleton
/// تدير قائمة المزامنة والعمليات الأساسية
class SyncService {
  SyncService._();

  static final SyncService _instance = SyncService._();
  static SyncService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// إضافة عنصر لقائمة المزامنة
  Future<void> addToSyncQueue(SyncItem item) async {
    try {
      final box = Hive.box<SyncItem>(HiveBoxes.syncQueue);
      await box.put(item.id, item);

      debugPrint('🔄 [Sync] إضافة للقائمة: ${item.type.name} - ${item.action.name}');
      debugPrint('🔄 [Sync] ID: ${item.localId}');
    } catch (e) {
      debugPrint('🔄 [Sync] ❌ خطأ في الإضافة: $e');
      rethrow;
    }
  }

  /// حذف عنصر من قائمة المزامنة
  Future<void> removeFromSyncQueue(String itemId) async {
    try {
      final box = Hive.box<SyncItem>(HiveBoxes.syncQueue);
      await box.delete(itemId);

      debugPrint('🔄 [Sync] ✅ حذف من القائمة: $itemId');
    } catch (e) {
      debugPrint('🔄 [Sync] ❌ خطأ في الحذف: $e');
    }
  }

  /// جلب العناصر المنتظرة
  Future<List<SyncItem>> getPendingItems() async {
    try {
      final box = Hive.box<SyncItem>(HiveBoxes.syncQueue);
      final items = box.values
          .where((item) =>
      item.status == SyncItemStatus.pending ||
          item.status == SyncItemStatus.failed)
          .toList();

      // ترتيب حسب وقت الإنشاء
      items.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      debugPrint('🔄 [Sync] عناصر منتظرة: ${items.length}');
      return items;
    } catch (e) {
      debugPrint('🔄 [Sync] ❌ خطأ في جلب العناصر: $e');
      return [];
    }
  }

  /// عدد العناصر المنتظرة
  Future<int> getPendingCount() async {
    try {
      final items = await getPendingItems();
      return items.length;
    } catch (e) {
      debugPrint('🔄 [Sync] ❌ خطأ في العد: $e');
      return 0;
    }
  }

  /// معالجة قائمة المزامنة
  Future<void> processQueue() async {
    try {
      final items = await getPendingItems();

      if (items.isEmpty) {
        debugPrint('🔄 [Sync] لا توجد عناصر للمزامنة');
        return;
      }

      debugPrint('🔄 [Sync] ═══════════════════════════════════');
      debugPrint('🔄 [Sync] بدء معالجة ${items.length} عنصر');

      int successCount = 0;
      int failCount = 0;

      for (final item in items) {
        final result = await syncItem(item);

        if (result.success) {
          successCount++;
          await removeFromSyncQueue(item.id);
        } else {
          failCount++;
          // تحديث العنصر بالخطأ وزيادة المحاولات
          final updatedItem = item.copyWith(
            attempts: item.attempts + 1,
            lastAttempt: DateTime.now(),
            error: result.error,
            status: SyncItemStatus.failed,
          );
          await addToSyncQueue(updatedItem);
        }
      }

      debugPrint('🔄 [Sync] ✅ نجحت: $successCount');
      debugPrint('🔄 [Sync] ❌ فشلت: $failCount');
      debugPrint('🔄 [Sync] ═══════════════════════════════════');
    } catch (e) {
      debugPrint('🔄 [Sync] ❌ خطأ في المعالجة: $e');
    }
  }

  /// مزامنة عنصر واحد مع Firestore
  Future<SyncResult> syncItem(SyncItem item) async {
    try {
      debugPrint('🔄 [Sync] مزامنة: ${item.type.name} - ${item.action.name}');

      final collection = _getCollectionName(item.type);
      final docRef = _firestore.collection(collection).doc(item.localId);

      // التأكد من وجود userId في البيانات قبل الإرسال لضمان الأذونات
      final data = Map<String, dynamic>.from(item.data);
      if (!data.containsKey('userId') || data['userId'] == null || data['userId'].toString().isEmpty) {
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        if (currentUid != null) {
          data['userId'] = currentUid;
          debugPrint('🔄 [Sync] 🛡️ تم تعويض userId المفقود في البيانات لضمان الأذونات');
        }
      }

      switch (item.action) {
        case SyncAction.create:
          await docRef.set(data);
          debugPrint('🔄 [Sync] ✅ تم الإنشاء: ${item.localId}');
          break;

        case SyncAction.update:
          await docRef.update(data);
          debugPrint('🔄 [Sync] ✅ تم التحديث: ${item.localId}');
          break;

        case SyncAction.delete:
          await docRef.delete();
          debugPrint('🔄 [Sync] ✅ تم الحذف: ${item.localId}');
          break;
      }

      return SyncResult.success(remoteId: item.localId);
    } catch (e) {
      debugPrint('🔄 [Sync] ❌ فشلت المزامنة: $e');
      return SyncResult.failure(e.toString());
    }
  }

  /// مزامنة مع Firestore (للاستخدام من SyncManager)
  Future<SyncResult> syncToFirestore(SyncItem item) async {
    return await syncItem(item);
  }

  /// مسح قائمة المزامنة
  Future<void> clearQueue() async {
    try {
      final box = Hive.box<SyncItem>(HiveBoxes.syncQueue);
      await box.clear();
      debugPrint('🔄 [Sync] ✅ تم مسح القائمة');
    } catch (e) {
      debugPrint('🔄 [Sync] ❌ خطأ في مسح القائمة: $e');
    }
  }

  /// إعادة محاولة العناصر الفاشلة
  Future<void> retryFailedItems() async {
    try {
      final box = Hive.box<SyncItem>(HiveBoxes.syncQueue);
      final failedItems = box.values
          .where((item) => item.status == SyncItemStatus.failed)
          .toList();

      debugPrint('🔄 [Sync] إعادة محاولة ${failedItems.length} عنصر فاشل');

      for (final item in failedItems) {
        // إعادة تعيين الحالة للمحاولة مرة أخرى
        final resetItem = item.copyWith(
          status: SyncItemStatus.pending,
          error: null,
        );
        await box.put(resetItem.id, resetItem);
      }

      // محاولة المعالجة
      await processQueue();
    } catch (e) {
      debugPrint('🔄 [Sync] ❌ خطأ في إعادة المحاولة: $e');
    }
  }

  /// جلب البيانات من Firestore وتحديث التخزين المحلي
  Future<void> pullFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('🔄 [Sync] ⚠️ لا يوجد مستخدم مسجل لجلب البيانات - تخطي pullFromFirestore');
        return;
      }

      final userId = user.uid;
      debugPrint('🔄 [Sync] ═══════════════════════════════════');
      debugPrint('🔄 [Sync] 📥 بدء جلب البيانات من Firebase للمستخدم: $userId');
      debugPrint('🔄 [Sync] ═══════════════════════════════════');

      // 1. جلب المسارات
      debugPrint('🔄 [Sync] 📥 جاري جلب المسارات...');
      final routesSnapshot = await _firestore
          .collection('routes')
          .where('userId', isEqualTo: userId)
          .get();

      int routesCount = 0;
      if (routesSnapshot.docs.isNotEmpty) {
        final routesBox = Hive.box<RouteModel>(HiveBoxes.routes);
        for (var doc in routesSnapshot.docs) {
          try {
            final route = RouteModel.fromFirestore(doc.data(), doc.id);

            // تحقق مما إذا كان المسار موجوداً بالفعل وبنفس البيانات لتجنب الكتابة المتكررة
            final existingRoute = routesBox.get(route.id);
            if (existingRoute == null || existingRoute.updatedAt != route.updatedAt) {
              await routesBox.put(route.id, route);
              routesCount++;
              debugPrint('🔄 [Sync]   ✅ تحديث مسار محلياً: ${route.name}');
            }
          } catch (e) {
            debugPrint('🔄 [Sync]   ❌ خطأ في معالجة مسار (ID: ${doc.id}): $e');
          }
        }
        debugPrint('🔄 [Sync] ✅ جلب ومعالجة ${routesSnapshot.docs.length} مسار');
      }

      // 2. جلب الرحلات
      debugPrint('🔄 [Sync] 📥 جاري جلب الرحلات...');
      final tripsSnapshot = await _firestore
          .collection('trips')
          .where('userId', isEqualTo: userId)
          .get();

      int tripsCount = 0;
      if (tripsSnapshot.docs.isNotEmpty) {
        final tripsBox = Hive.box<TripModel>(HiveBoxes.trips);
        for (var doc in tripsSnapshot.docs) {
          try {
            final trip = TripModel.fromFirestore(doc.data(), doc.id);

            // تحقق مما إذا كانت الرحلة موجودة بالفعل لتجنب الكتابة المتكررة
            final existingTrip = tripsBox.get(trip.id);
            if (existingTrip == null) {
              await tripsBox.put(trip.id, trip);
              tripsCount++;
              debugPrint('🔄 [Sync]   ✅ إضافة رحلة جديدة محلياً: ${trip.routeName}');
            }
          } catch (e) {
            debugPrint('🔄 [Sync]   ❌ خطأ في معالجة رحلة (ID: ${doc.id}): $e');
          }
        }
        debugPrint('🔄 [Sync] ✅ جلب ومعالجة ${tripsSnapshot.docs.length} رحلة');
      }

      // 3. جلب جهات الاتصال
      debugPrint('🔄 [Sync] 📥 جاري جلب جهات الاتصال...');
      final contactsSnapshot = await _firestore
          .collection('contacts')
          .where('userId', isEqualTo: userId)
          .get();

      int contactsCount = 0;
      if (contactsSnapshot.docs.isNotEmpty) {
        final contactsBox = Hive.box<ContactModel>(HiveBoxes.contacts);
        for (var doc in contactsSnapshot.docs) {
          try {
            final contact = ContactModel.fromFirestore(doc.data(), doc.id);

            // تحقق مما إذا كانت جهة الاتصال موجودة بالفعل لتجنب الكتابة المتكررة
            final existingContact = contactsBox.get(contact.id);
            if (existingContact == null) {
              await contactsBox.put(contact.id, contact);
              contactsCount++;
              debugPrint('🔄 [Sync]   ✅ إضافة جهة اتصال جديدة محلياً: ${contact.name}');
            }
          } catch (e) {
            debugPrint('🔄 [Sync]   ❌ خطأ في معالجة جهة اتصال (ID: ${doc.id}): $e');
          }
        }
        debugPrint('🔄 [Sync] ✅ جلب ومعالجة ${contactsSnapshot.docs.length} جهة اتصال');
      }

      debugPrint('🔄 [Sync] ═══════════════════════════════════');
      debugPrint('🔄 [Sync] ✅ اكتمل جلب البيانات بنجاح:');
      debugPrint('🔄 [Sync]   📍 المسارات: $routesCount');
      debugPrint('🔄 [Sync]   🚗 الرحلات: $tripsCount');
      debugPrint('🔄 [Sync]   👥 جهات الاتصال: $contactsCount');
      debugPrint('🔄 [Sync] ═══════════════════════════════════');

      // 4. إخطار الـ BLoCs بالتحديثات فقط إذا حدث تغيير حقيقي
      if (routesCount > 0 || tripsCount > 0 || contactsCount > 0) {
        _notifyBlocsOfUpdates(userId);
      } else {
        debugPrint('🔄 [Sync] ℹ️ لم يتم العثور على تغييرات جديدة، تخطي إخطار الـ BLoCs');
      }
    } catch (e) {
      debugPrint('🔄 [Sync] ❌ خطأ في جلب البيانات: $e');
      rethrow;
    }
  }

  /// إخطار الـ BLoCs بوجود بيانات جديدة
  void _notifyBlocsOfUpdates(String userId) {
    try {
      debugPrint('🔄 [Sync] 📢 إرسال إشعارات التحديث للـ BLoCs...');

      // نستخدم sl.isRegistered للتحقق من وجود الـ BLoCs وتجنب الأخطاء
      if (sl.isRegistered<RouteBloc>()) {
        sl<RouteBloc>().add(LoadRoutes(userId));
      }

      if (sl.isRegistered<TripBloc>()) {
        sl<TripBloc>().add(LoadTripHistory(userId: userId));
        sl<TripBloc>().add(LoadActiveTrip(userId));
      }

      if (sl.isRegistered<ContactBloc>()) {
        sl<ContactBloc>().add(LoadContactsEvent(userId));
      }

      debugPrint('🔄 [Sync] ✅ تم إرسال إشعارات التحديث');
    } catch (e) {
      debugPrint('🔄 [Sync] ⚠️ خطأ في إخطار الـ BLoCs: $e');
    }
  }

  /// الحصول على اسم Collection حسب النوع
  String _getCollectionName(SyncItemType type) {
    switch (type) {
      case SyncItemType.user:
        return 'users';
      case SyncItemType.route:
        return 'routes';
      case SyncItemType.trip:
        return 'trips';
      case SyncItemType.alert:
        return 'alerts';
      case SyncItemType.contact:
        return 'contacts';
      case SyncItemType.alertConfig:
        return 'alert_configs';
    }
  }

  /// إحصائيات قائمة المزامنة
  Future<Map<String, int>> getQueueStats() async {
    try {
      final box = Hive.box<SyncItem>(HiveBoxes.syncQueue);
      final items = box.values.toList();

      final stats = {
        'total': items.length,
        'pending': items.where((i) => i.status == SyncItemStatus.pending).length,
        'syncing': items.where((i) => i.status == SyncItemStatus.syncing).length,
        'synced': items.where((i) => i.status == SyncItemStatus.synced).length,
        'failed': items.where((i) => i.status == SyncItemStatus.failed).length,
      };

      return stats;
    } catch (e) {
      debugPrint('🔄 [Sync] ❌ خطأ في الإحصائيات: $e');
      return {
        'total': 0,
        'pending': 0,
        'syncing': 0,
        'synced': 0,
        'failed': 0,
      };
    }
  }

  /// طباعة إحصائيات قائمة المزامنة
  Future<void> printQueueStats() async {
    final stats = await getQueueStats();

    debugPrint('🔄 [Sync] ═══════════════════════════════════');
    debugPrint('🔄 [Sync] Queue Statistics:');
    debugPrint('🔄 [Sync] Total: ${stats['total']}');
    debugPrint('🔄 [Sync] Pending: ${stats['pending']}');
    debugPrint('🔄 [Sync] Syncing: ${stats['syncing']}');
    debugPrint('🔄 [Sync] Synced: ${stats['synced']}');
    debugPrint('🔄 [Sync] Failed: ${stats['failed']}');
    debugPrint('🔄 [Sync] ═══════════════════════════════════');
  }
}
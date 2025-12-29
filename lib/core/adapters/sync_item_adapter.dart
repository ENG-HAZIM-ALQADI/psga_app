import 'package:hive/hive.dart';
import '../services/sync/sync_item.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🔄 SyncItemAdapter - المحوّل الخاص بعناصر المزامنة بين Local و Cloud
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// 🎯 الموقع في Clean Architecture:
/// - الطبقة: Core Layer > Adapters
/// - الوظيفة: تحويل SyncItem (عنصر مزامنة) من/إلى Binary
/// 
/// 📌 ما هو SyncItem؟
/// SyncItem هو "بطاقة مهمة" للمزامنة بين التخزين المحلي (Hive) والسحابة (Firebase):
/// - يحتوي على: ماذا تم تغييره؟ (create/update/delete)
/// - أين؟ (Route, Trip, Alert, إلخ)
/// - متى؟ (timestamp)
/// - هل نجحت المزامنة؟ (pending, syncing, synced, failed)
/// 
/// 💡 لماذا نحتاج SyncItem؟
/// تخيل هذا السيناريو:
/// 1. المستخدم ينشئ Route جديد (لا يوجد إنترنت)
/// 2. نحفظه في Hive محلياً ✅
/// 3. ننشئ SyncItem: "يوجد Route جديد يحتاج مزامنة!"
/// 4. عندما يعود الإنترنت، نقرأ SyncItems
/// 5. نرفع كل SyncItem للسحابة واحد تلو الآخر
/// 6. ✅ المزامنة تمت بنجاح!
/// 
/// 🔢 typeId = 7

class SyncItemAdapter extends TypeAdapter<SyncItem> {
  @override
  final int typeId = 7;

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 📖 read() - قراءة SyncItem من Hive
  /// ═══════════════════════════════════════════════════════════════════════════
  /// 
  /// 🎯 متى تُستدعى؟
  /// - عند فتح التطبيق (نتحقق: هل يوجد عناصر معلقة للمزامنة؟)
  /// - عند عودة الإنترنت (نبدأ المزامنة التلقائية)
  /// - عند عرض حالة المزامنة للمستخدم
  /// 
  /// 📊 بنية SyncItem:
  /// SyncItem {
  ///   id: "sync_123",
  ///   type: SyncItemType.route,      // نوع البيانات
  ///   action: SyncAction.create,     // العملية (create/update/delete)
  ///   data: {...},                   // البيانات الكاملة
  ///   localId: "route_local_456",    // الـ ID المحلي
  ///   remoteId: null,                // الـ ID السحابي (null حتى تنجح المزامنة)
  ///   createdAt: DateTime.now(),
  ///   attempts: 0,                   // كم مرة حاولنا المزامنة؟
  ///   lastAttempt: null,
  ///   error: null,
  ///   status: SyncItemStatus.pending // pending/syncing/synced/failed
  /// }
  @override
  SyncItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return SyncItem(
      id: fields[0] as String,
      
      /// نحول int → Enum
      /// مثال: 1 → SyncItemType.route
      type: SyncItemType.values[fields[1] as int],
      action: SyncAction.values[fields[2] as int],
      
      /// البيانات الكاملة للعنصر (مثلاً: بيانات Route كاملة)
      /// محفوظة كـ Map
      data: Map<String, dynamic>.from(fields[3] as Map),
      
      localId: fields[4] as String,
      remoteId: fields[5] as String?,
      createdAt: DateTime.parse(fields[6] as String),
      
      /// عدد المحاولات - مفيد لمنع إعادة المحاولة إلى ما لا نهاية!
      /// مثال: إذا فشلت 5 مرات، نوقف المزامنة ونطلب تدخل يدوي
      attempts: fields[7] as int,
      
      lastAttempt: fields[8] != null 
          ? DateTime.parse(fields[8] as String) 
          : null,
      
      /// رسالة الخطأ (إذا فشلت المزامنة)
      /// مثال: "Network error: No internet connection"
      error: fields[9] as String?,
      
      status: SyncItemStatus.values[fields[10] as int],
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 💾 write() - حفظ SyncItem في Hive
  /// ═══════════════════════════════════════════════════════════════════════════
  /// 
  /// 🎯 متى تُستدعى؟
  /// - عند إنشاء/تعديل/حذف أي عنصر محلياً (ننشئ SyncItem)
  /// - عند بدء محاولة مزامنة (نحدّث attempts و status)
  /// - عند نجاح المزامنة (نحدّث status → synced و remoteId)
  /// - عند فشل المزامنة (نحدّث error و status → failed)
  @override
  void write(BinaryWriter writer, SyncItem obj) {
    writer
      ..writeByte(11)  // 11 حقل
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type.index)    // Enum → int
      ..writeByte(2)
      ..write(obj.action.index)
      ..writeByte(3)
      ..write(obj.data)          // Map كامل
      ..writeByte(4)
      ..write(obj.localId)
      ..writeByte(5)
      ..write(obj.remoteId)
      ..writeByte(6)
      ..write(obj.createdAt.toIso8601String())
      ..writeByte(7)
      ..write(obj.attempts)
      ..writeByte(8)
      ..write(obj.lastAttempt?.toIso8601String())
      ..writeByte(9)
      ..write(obj.error)
      ..writeByte(10)
      ..write(obj.status.index);
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎓 خلاصة نظام المزامنة:
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// 🔄 دورة حياة SyncItem الكاملة:
/// 
/// ```dart
/// // 1. المستخدم ينشئ Route جديد (offline)
/// final route = RouteModel(...);
/// await routeBox.put(route.id, route);  // حفظ محلياً
/// 
/// // 2. إنشاء SyncItem للمزامنة لاحقاً
/// final syncItem = SyncItem(
///   type: SyncItemType.route,
///   action: SyncAction.create,
///   data: route.toJson(),
///   localId: route.id,
///   createdAt: DateTime.now(),
///   status: SyncItemStatus.pending,
/// );
/// await syncBox.put(syncItem.id, syncItem);  // Adapter يشتغل هنا!
/// 
/// // 3. عندما يعود الإنترنت، نبدأ المزامنة
/// for (final item in syncBox.values.where((i) => i.status == pending)) {
///   try {
///     // محاولة رفع للسحابة
///     final remoteId = await uploadToFirebase(item.data);
///     
///     // نجحت! نحدّث SyncItem
///     final synced = item.copyWith(
///       remoteId: remoteId,
///       status: SyncItemStatus.synced,
///     );
///     await syncBox.put(item.id, synced);
///     
///   } catch (e) {
///     // فشلت! نسجل الخطأ
///     final failed = item.copyWith(
///       attempts: item.attempts + 1,
///       lastAttempt: DateTime.now(),
///       error: e.toString(),
///       status: SyncItemStatus.failed,
///     );
///     await syncBox.put(item.id, failed);
///   }
/// }
/// ```
/// 
/// 💡 استراتيجيات المزامنة الذكية:
/// 
/// 1️⃣ **Exponential Backoff** (إعادة المحاولة الذكية):
///    محاولة 1: انتظر 5 ثواني
///    محاولة 2: انتظر 10 ثواني
///    محاولة 3: انتظر 20 ثانية
///    محاولة 4: انتظر 40 ثانية
///    محاولة 5: استسلم واطلب تدخل يدوي
/// 
/// 2️⃣ **Priority Queue** (أولوية المزامنة):
///    - Alerts: أولوية عالية جداً (حالات طوارئ!)
///    - Trips: أولوية عالية
///    - Routes: أولوية متوسطة
///    - Settings: أولوية منخفضة
/// 
/// 3️⃣ **Batch Sync** (مزامنة دفعات):
///    بدلاً من رفع كل SyncItem لوحده، نجمعهم في دفعات (10-20 عنصر)
///    ونرفعهم مرة واحدة → أسرع وأوفر للبيانات!
/// ═══════════════════════════════════════════════════════════════════════════

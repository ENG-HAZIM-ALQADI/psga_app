import 'package:hive/hive.dart';
import '../../../features/auth/data/models/user_model.dart';
import '../../../features/trips/data/models/route_model.dart';
import '../../../features/trips/data/models/trip_model.dart';
import '../../../features/alerts/data/models/alert_model.dart';
import '../../../features/alerts/data/models/contact_model.dart';
import '../../../features/alerts/data/models/alert_config_model.dart';
import '../sync/sync_item.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📦 HiveBoxes - قائمة صناديق التخزين المحلي
/// ═══════════════════════════════════════════════════════════════════════════
///
/// 🎯 الموقع في Clean Architecture:
/// - الطبقة: Core Layer > Services > Storage
/// - النوع: Static Constants Class
/// - الوظيفة: تنظيم أسماء جميع الـ Boxes في مكان واحد
///
/// 📌 ما هو Hive Box؟
/// تخيل Hive Box كـ "صندوق" أو "خزانة" في التخزين المحلي:
/// - كل Box يحتوي على نوع معين من البيانات
/// - مثلاً: users_box للمستخدمين، trips_box للرحلات
/// - كل Box مستقل ويمكن فتحه/إغلاقه/مسحه بشكل منفصل
///
/// 💡 لماذا نضع الأسماء هنا؟
///
/// ❌ بدون HiveBoxes:
/// ```dart
/// // في كل مكان في الكود:
/// final box = Hive.box('users_box');  // خطأ إملائي محتمل!
/// final box2 = Hive.box('user_box');  // اسم مختلف!
/// ```
///
/// ✅ مع HiveBoxes:
/// ```dart
/// // اسم موحد في كل مكان:
/// final box = Hive.box(HiveBoxes.users);  // ✅ صحيح دائماً!
/// ```
///
/// 🎯 الفوائد:
/// 1. **Single Source of Truth**: كل الأسماء في مكان واحد
/// 2. **منع الأخطاء الإملائية**: IDE يساعدك بالـ autocomplete
/// 3. **سهولة التعديل**: تغيير الاسم في مكان واحد فقط
/// 4. **قائمة شاملة**: نعرف جميع Boxes الموجودة

class HiveBoxes {
  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🔒 Private Constructor
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// هذا الكلاس فقط للـ Constants، لا نحتاج إنشاء كائن منه
  HiveBoxes._();

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 📋 أسماء الـ Boxes
  /// ═══════════════════════════════════════════════════════════════════════════

  /// 👤 Users Box - صندوق المستخدمين
  ///
  /// يحتوي على:
  /// - معلومات المستخدم الحالي (UserModel)
  /// - بيانات الملف الشخصي
  ///
  /// 💡 الاستخدام:
  /// ```dart
  /// final usersBox = Hive.box<UserModel>(HiveBoxes.users);
  /// final currentUser = usersBox.get('current_user');
  /// ```
  static const String users = 'users_box';

  /// 🗺️ Routes Box - صندوق المسارات (الخطط)
  ///
  /// يحتوي على:
  /// - جميع المسارات المحفوظة (RouteModel)
  /// - الوجهات والطرق المفضلة
  ///
  /// 💡 الاستخدام:
  /// ```dart
  /// final routesBox = Hive.box<RouteModel>(HiveBoxes.routes);
  /// final allRoutes = routesBox.values.toList();
  /// ```
  static const String routes = 'routes_box';

  /// 🚗 Trips Box - صندوق الرحلات (التنفيذ الفعلي)
  ///
  /// يحتوي على:
  /// - جميع الرحلات المنفذة والحالية (TripModel)
  /// - سجل الرحلات السابقة
  ///
  /// 💡 الفرق بين Route و Trip:
  /// - Route = الخطة (سأذهب من A إلى B)
  /// - Trip = التنفيذ الفعلي (ذهبت من A إلى B اليوم الساعة 3 مساءً)
  ///
  /// 📝 مثال:
  /// ```dart
  /// final tripsBox = Hive.box<TripModel>(HiveBoxes.trips);
  ///
  /// // جلب الرحلة النشطة
  /// final activeTrip = tripsBox.values.firstWhere(
  ///   (trip) => trip.status == TripStatus.active,
  ///   orElse: () => null,
  /// );
  /// ```
  static const String trips = 'trips_box';

  /// 🚨 Alerts Box - صندوق التنبيهات
  ///
  /// يحتوي على:
  /// - جميع التنبيهات (AlertModel)
  /// - انحرافات، SOS، بطارية منخفضة، إلخ
  ///
  /// 💡 الاستخدام:
  /// ```dart
  /// final alertsBox = Hive.box<AlertModel>(HiveBoxes.alerts);
  ///
  /// // جلب التنبيهات غير المقروءة
  /// final unread = alertsBox.values.where(
  ///   (alert) => alert.status == AlertStatus.pending
  /// ).toList();
  /// ```
  static const String alerts = 'alerts_box';

  /// 📞 Contacts Box - صندوق جهات الاتصال
  ///
  /// يحتوي على:
  /// - جهات الاتصال الطوارئ (ContactModel)
  /// - الأشخاص الذين سيُشعَرون عند SOS
  ///
  /// 💡 الاستخدام:
  /// ```dart
  /// final contactsBox = Hive.box<ContactModel>(HiveBoxes.contacts);
  ///
  /// // جلب جهات الاتصال الطوارئ فقط
  /// final emergencyContacts = contactsBox.values.where(
  ///   (contact) => contact.isEmergencyContact
  /// ).toList();
  /// ```
  static const String contacts = 'contacts_box';

  /// ⚙️ Alert Configs Box - صندوق إعدادات التنبيهات
  ///
  /// يحتوي على:
  /// - إعدادات التنبيهات (AlertConfigModel)
  /// - متى يُرسل تنبيه؟ كم المسافة للانحراف؟ إلخ
  ///
  /// 💡 الاستخدام:
  /// ```dart
  /// final configBox = Hive.box<AlertConfigModel>(HiveBoxes.alertConfigs);
  /// final config = configBox.get('default_config');
  ///
  /// // التحقق من تفعيل SOS
  /// if (config?.sosEnabled == true) {
  ///   // SOS مفعّل
  /// }
  /// ```
  static const String alertConfigs = 'alert_configs_box';

  /// 🎚️ Settings Box - صندوق الإعدادات العامة
  ///
  /// يحتوي على:
  /// - إعدادات التطبيق (Theme، Language، إلخ)
  /// - تفضيلات المستخدم
  ///
  /// ⚠️ ملاحظة: هذا Box غير مُحدد النوع (dynamic)
  ///
  /// 💡 الاستخدام:
  /// ```dart
  /// final settingsBox = Hive.box(HiveBoxes.settings);
  ///
  /// // حفظ إعداد
  /// await settingsBox.put('theme', 'dark');
  /// await settingsBox.put('language', 'ar');
  ///
  /// // قراءة إعداد
  /// final theme = settingsBox.get('theme', defaultValue: 'light');
  /// ```
  static const String settings = 'settings_box';

  /// 🔄 Sync Queue Box - صندوق طابور المزامنة
  ///
  /// يحتوي على:
  /// - العناصر المنتظرة للمزامنة مع السحابة (SyncItem)
  /// - البيانات المُعدلة محلياً والتي لم تُرسل للسيرفر بعد
  ///
  /// 💡 كيف يعمل؟
  /// 1. المستخدم يُعدل بيانات (مثلاً يضيف جهة اتصال)
  /// 2. البيانات تُحفظ محلياً في contactsBox
  /// 3. يُضاف SyncItem في syncQueueBox (للمزامنة لاحقاً)
  /// 4. عند توفر الإنترنت، SyncManager يُرسل البيانات للسيرفر
  ///
  /// 📝 مثال:
  /// ```dart
  /// final syncBox = Hive.box<SyncItem>(HiveBoxes.syncQueue);
  ///
  /// // إضافة عنصر للمزامنة
  /// final syncItem = SyncItem(
  ///   id: 'sync_${DateTime.now().millisecondsSinceEpoch}',
  ///   type: SyncItemType.contact,
  ///   action: SyncAction.create,
  ///   data: newContact.toJson(),
  ///   status: SyncItemStatus.pending,
  ///   createdAt: DateTime.now(),
  /// );
  ///
  /// await syncBox.put(syncItem.id, syncItem);
  /// ```
  static const String syncQueue = 'sync_queue_box';

  /// 💾 Cache Box - صندوق التخزين المؤقت
  ///
  /// يحتوي على:
  /// - بيانات مؤقتة (API responses، صور، إلخ)
  /// - بيانات يمكن مسحها دون مشاكل
  ///
  /// ⚠️ ملاحظة: هذا Box غير مُحدد النوع (dynamic)
  ///
  /// 💡 الاستخدام:
  /// ```dart
  /// final cacheBox = Hive.box(HiveBoxes.cache);
  ///
  /// // حفظ response من API
  /// await cacheBox.put('weather_data', {
  ///   'temp': 25,
  ///   'condition': 'sunny',
  ///   'cachedAt': DateTime.now().toIso8601String(),
  /// });
  ///
  /// // قراءة مع expiry
  /// final weatherData = cacheBox.get('weather_data');
  /// if (weatherData != null) {
  ///   final cachedAt = DateTime.parse(weatherData['cachedAt']);
  ///   final isExpired = DateTime.now().difference(cachedAt).inHours > 1;
  ///
  ///   if (!isExpired) {
  ///     // استخدم البيانات المُخزنة
  ///   } else {
  ///     // البيانات انتهت صلاحيتها، احذفها واجلب جديدة
  ///     await cacheBox.delete('weather_data');
  ///   }
  /// }
  /// ```
  static const String cache = 'cache_box';

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 📜 قائمة جميع أسماء الـ Boxes
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 🎯 الفائدة:
  /// - Loop على جميع Boxes (مثلاً للمسح عند Logout)
  /// - التحقق من التهيئة
  /// - طباعة معلومات التخزين
  ///
  /// 📝 مثال الاستخدام:
  /// ```dart
  /// // مسح جميع البيانات:
  /// for (final boxName in HiveBoxes.allBoxNames) {
  ///   if (Hive.isBoxOpen(boxName)) {
  ///     await Hive.box(boxName).clear();
  ///   }
  /// }
  ///
  /// // طباعة معلومات:
  /// for (final boxName in HiveBoxes.allBoxNames) {
  ///   if (Hive.isBoxOpen(boxName)) {
  ///     print('$boxName: ${Hive.box(boxName).length} items');
  ///   }
  /// }
  /// ```
  static const List<String> allBoxNames = [
    users,
    routes,
    trips,
    alerts,
    contacts,
    alertConfigs,
    settings,
    syncQueue,
    cache,
  ];
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎛️ BoxManager - مدير الصناديق للوصول الآمن
/// ═══════════════════════════════════════════════════════════════════════════
///
/// 🎯 الوظيفة:
/// توفير getters آمنة للوصول للـ Boxes مع Type Safety
///
/// 💡 لماذا نحتاج BoxManager؟
///
/// ❌ بدون BoxManager:
/// ```dart
/// final box = Hive.box<UserModel>(HiveBoxes.users);  // ❌ قد يُرمى Exception!
/// ```
///
/// ✅ مع BoxManager:
/// ```dart
/// try {
///   final box = BoxManager.usersBox;  // ✅ يتحقق من الفتح أولاً!
/// } catch (e) {
///   print('Box is not open!');
/// }
/// ```
///
/// 🔒 الأمان:
/// - يتحقق من أن Box مفتوح قبل الوصول
/// - يرمي Exception واضحة إذا لم يكن مفتوحاً
/// - يوفر Type Safety (لا يمكن وضع TripModel في usersBox!)

class BoxManager {
  /// Private Constructor
  BoxManager._();

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 📦 Getters للـ Boxes
  /// ═══════════════════════════════════════════════════════════════════════════

  /// 👤 Users Box
  ///
  /// 📝 الاستخدام:
  /// ```dart
  /// final user = BoxManager.usersBox.get('current_user');
  /// await BoxManager.usersBox.put('current_user', newUser);
  /// ```
  static Box<UserModel> get usersBox {
    if (!Hive.isBoxOpen(HiveBoxes.users)) {
      throw Exception('Users box is not open');
    }
    return Hive.box<UserModel>(HiveBoxes.users);
  }

  /// 🗺️ Routes Box
  static Box<RouteModel> get routesBox {
    if (!Hive.isBoxOpen(HiveBoxes.routes)) {
      throw Exception('Routes box is not open');
    }
    return Hive.box<RouteModel>(HiveBoxes.routes);
  }

  /// 🚗 Trips Box
  static Box<TripModel> get tripsBox {
    if (!Hive.isBoxOpen(HiveBoxes.trips)) {
      throw Exception('Trips box is not open');
    }
    return Hive.box<TripModel>(HiveBoxes.trips);
  }

  /// 🚨 Alerts Box
  static Box<AlertModel> get alertsBox {
    if (!Hive.isBoxOpen(HiveBoxes.alerts)) {
      throw Exception('Alerts box is not open');
    }
    return Hive.box<AlertModel>(HiveBoxes.alerts);
  }

  /// 📞 Contacts Box
  static Box<ContactModel> get contactsBox {
    if (!Hive.isBoxOpen(HiveBoxes.contacts)) {
      throw Exception('Contacts box is not open');
    }
    return Hive.box<ContactModel>(HiveBoxes.contacts);
  }

  /// ⚙️ Alert Configs Box
  static Box<AlertConfigModel> get alertConfigsBox {
    if (!Hive.isBoxOpen(HiveBoxes.alertConfigs)) {
      throw Exception('Alert configs box is not open');
    }
    return Hive.box<AlertConfigModel>(HiveBoxes.alertConfigs);
  }

  /// 🎚️ Settings Box (dynamic)
  ///
  /// ⚠️ ملاحظة: غير محدد النوع
  static Box<dynamic> get settingsBox {
    if (!Hive.isBoxOpen(HiveBoxes.settings)) {
      throw Exception('Settings box is not open');
    }
    return Hive.box(HiveBoxes.settings);
  }

  /// 🔄 Sync Queue Box
  static Box<SyncItem> get syncQueueBox {
    if (!Hive.isBoxOpen(HiveBoxes.syncQueue)) {
      throw Exception('Sync queue box is not open');
    }
    return Hive.box<SyncItem>(HiveBoxes.syncQueue);
  }

  /// 💾 Cache Box (dynamic)
  ///
  /// ⚠️ ملاحظة: غير محدد النوع
  static Box<dynamic> get cacheBox {
    if (!Hive.isBoxOpen(HiveBoxes.cache)) {
      throw Exception('Cache box is not open');
    }
    return Hive.box(HiveBoxes.cache);
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🛠️ Helper Methods - دوال مساعدة
  /// ═══════════════════════════════════════════════════════════════════════════

  /// عدد العناصر في box معين
  ///
  /// 📝 مثال:
  /// ```dart
  /// final tripCount = BoxManager.count(HiveBoxes.trips);
  /// print('لديك $tripCount رحلة محفوظة');
  /// ```
  static int count(String boxName) {
    if (!Hive.isBoxOpen(boxName)) {
      return 0;
    }
    return Hive.box(boxName).length;
  }

  /// هل الـ box فارغ؟
  ///
  /// 📝 مثال:
  /// ```dart
  /// if (BoxManager.isEmpty(HiveBoxes.contacts)) {
  ///   showMessage('لم تضف أي جهة اتصال بعد');
  /// }
  /// ```
  static bool isEmpty(String boxName) {
    if (!Hive.isBoxOpen(boxName)) {
      return true;
    }
    return Hive.box(boxName).isEmpty;
  }

  /// هل الـ box مفتوح؟
  ///
  /// 💡 مفيد للتحقق قبل الوصول
  static bool isOpen(String boxName) {
    return Hive.isBoxOpen(boxName);
  }

  /// مسح box معين
  ///
  /// ⚠️ تحذير: هذا سيحذف جميع البيانات في Box!
  ///
  /// 📝 مثال:
  /// ```dart
  /// // مسح التخزين المؤقت
  /// await BoxManager.clear(HiveBoxes.cache);
  /// ```
  static Future<void> clear(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box(boxName).clear();
    }
  }

  /// حذف عنصر من box
  ///
  /// 📝 مثال:
  /// ```dart
  /// await BoxManager.delete(HiveBoxes.trips, 'trip_123');
  /// ```
  static Future<void> delete(String boxName, dynamic key) async {
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box(boxName).delete(key);
    }
  }

  /// الحصول على جميع المفاتيح
  ///
  /// 📝 مثال:
  /// ```dart
  /// final keys = BoxManager.getKeys(HiveBoxes.routes);
  /// print('Route IDs: $keys');
  /// ```
  static Iterable<dynamic> getKeys(String boxName) {
    if (!Hive.isBoxOpen(boxName)) {
      return [];
    }
    return Hive.box(boxName).keys;
  }

  /// الحصول على جميع القيم
  ///
  /// 📝 مثال:
  /// ```dart
  /// final allTrips = BoxManager.getValues(HiveBoxes.trips).toList();
  /// ```
  static Iterable<dynamic> getValues(String boxName) {
    if (!Hive.isBoxOpen(boxName)) {
      return [];
    }
    return Hive.box(boxName).values;
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎓 ملاحظات إضافية - Hive Best Practices
/// ═══════════════════════════════════════════════════════════════════════════
///
/// 🔒 Box Types - أنواع الصناديق:
///
/// 1️⃣ **Typed Box** (مُحدد النوع):
///    ```dart
///    Box<UserModel> usersBox = Hive.box<UserModel>('users');
///    await usersBox.put('key', UserModel(...));  // ✅ Type safe
///    await usersBox.put('key', TripModel(...));  // ❌ Compile error!
///    ```
///
/// 2️⃣ **Dynamic Box** (غير محدد):
///    ```dart
///    Box<dynamic> settingsBox = Hive.box('settings');
///    await settingsBox.put('theme', 'dark');      // ✅
///    await settingsBox.put('count', 42);          // ✅
///    await settingsBox.put('user', UserModel());  // ✅
///    ```
///
/// 💡 متى نستخدم أيهما؟
/// - **Typed**: للبيانات المهمة (Users، Trips، Alerts)
/// - **Dynamic**: للإعدادات والـ Cache
///
/// 📊 Box Keys - مفاتيح التخزين:
///
/// يمكن استخدام String أو int كمفاتيح:
/// ```dart
/// // String keys (الأكثر شيوعاً)
/// await box.put('trip_123', trip);
/// await box.put('current_user', user);
///
/// // int keys (للترتيب التلقائي)
/// await box.put(0, firstItem);
/// await box.put(1, secondItem);
/// ```
///
/// 🔄 Listening to Changes - الاستماع للتغيرات:
///
/// ```dart
/// // الاستماع لتغيرات Box معين
/// final box = BoxManager.tripsBox;
/// box.watch().listen((BoxEvent event) {
///   print('Box changed!');
///   print('Key: ${event.key}');
///   print('Value: ${event.value}');
///   print('Deleted: ${event.deleted}');
///
///   // تحديث UI
///   setState(() {
///     trips = box.values.toList();
///   });
/// });
/// ```
///
/// 🧹 Cleaning Strategy - استراتيجية التنظيف:
///
/// ```dart
/// class CleanupService {
///   // مسح Cache القديم (كل أسبوع مثلاً)
///   static Future<void> cleanOldCache() async {
///     final cacheBox = BoxManager.cacheBox;
///     final now = DateTime.now();
///
///     final keysToDelete = <dynamic>[];
///
///     for (final key in cacheBox.keys) {
///       final value = cacheBox.get(key);
///       if (value is Map && value['cachedAt'] != null) {
///         final cachedAt = DateTime.parse(value['cachedAt']);
///         final age = now.difference(cachedAt);
///
///         if (age.inDays > 7) {
///           keysToDelete.add(key);
///         }
///       }
///     }
///
///     for (final key in keysToDelete) {
///       await cacheBox.delete(key);
///     }
///
///     print('تم مسح ${keysToDelete.length} عنصر قديم');
///   }
///
///   // مسح Sync Queue بعد النجاح
///   static Future<void> cleanSyncedItems() async {
///     final syncBox = BoxManager.syncQueueBox;
///
///     final keysToDelete = syncBox.values
///         .where((item) => item.status == SyncItemStatus.synced)
///         .map((item) => item.id)
///         .toList();
///
///     for (final key in keysToDelete) {
///       await syncBox.delete(key);
///     }
///   }
/// }
/// ```
/// ═══════════════════════════════════════════════════════════════════════════

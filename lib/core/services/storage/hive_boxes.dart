import 'package:hive/hive.dart';
import '../../../features/auth/data/models/user_model.dart';
import '../../../features/trips/data/models/route_model.dart';
import '../../../features/trips/data/models/trip_model.dart';
import '../../../features/alerts/data/models/alert_model.dart';
import '../../../features/alerts/data/models/contact_model.dart';
import '../../../features/alerts/data/models/alert_config_model.dart';
import '../sync/sync_item.dart';

/// أسماء الـ Boxes في Hive
class HiveBoxes {
  HiveBoxes._();

  // Box Names
  static const String users = 'users_box';
  static const String routes = 'routes_box';
  static const String trips = 'trips_box';
  static const String alerts = 'alerts_box';
  static const String contacts = 'contacts_box';
  static const String alertConfigs = 'alert_configs_box';
  static const String settings = 'settings_box';
  static const String syncQueue = 'sync_queue_box';
  static const String cache = 'cache_box';

  /// قائمة جميع أسماء الـ Boxes
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

/// مدير الـ Boxes - للوصول الآمن
class BoxManager {
  BoxManager._();

  /// Users Box
  static Box<UserModel> get usersBox {
    if (!Hive.isBoxOpen(HiveBoxes.users)) {
      throw Exception('Users box is not open');
    }
    return Hive.box<UserModel>(HiveBoxes.users);
  }

  /// Routes Box
  static Box<RouteModel> get routesBox {
    if (!Hive.isBoxOpen(HiveBoxes.routes)) {
      throw Exception('Routes box is not open');
    }
    return Hive.box<RouteModel>(HiveBoxes.routes);
  }

  /// Trips Box
  static Box<TripModel> get tripsBox {
    if (!Hive.isBoxOpen(HiveBoxes.trips)) {
      throw Exception('Trips box is not open');
    }
    return Hive.box<TripModel>(HiveBoxes.trips);
  }

  /// Alerts Box
  static Box<AlertModel> get alertsBox {
    if (!Hive.isBoxOpen(HiveBoxes.alerts)) {
      throw Exception('Alerts box is not open');
    }
    return Hive.box<AlertModel>(HiveBoxes.alerts);
  }

  /// Contacts Box
  static Box<ContactModel> get contactsBox {
    if (!Hive.isBoxOpen(HiveBoxes.contacts)) {
      throw Exception('Contacts box is not open');
    }
    return Hive.box<ContactModel>(HiveBoxes.contacts);
  }

  /// Alert Configs Box
  static Box<AlertConfigModel> get alertConfigsBox {
    if (!Hive.isBoxOpen(HiveBoxes.alertConfigs)) {
      throw Exception('Alert configs box is not open');
    }
    return Hive.box<AlertConfigModel>(HiveBoxes.alertConfigs);
  }

  /// Settings Box (dynamic)
  static Box<dynamic> get settingsBox {
    if (!Hive.isBoxOpen(HiveBoxes.settings)) {
      throw Exception('Settings box is not open');
    }
    return Hive.box(HiveBoxes.settings);
  }

  /// Sync Queue Box
  static Box<SyncItem> get syncQueueBox {
    if (!Hive.isBoxOpen(HiveBoxes.syncQueue)) {
      throw Exception('Sync queue box is not open');
    }
    return Hive.box<SyncItem>(HiveBoxes.syncQueue);
  }

  /// Cache Box (dynamic)
  static Box<dynamic> get cacheBox {
    if (!Hive.isBoxOpen(HiveBoxes.cache)) {
      throw Exception('Cache box is not open');
    }
    return Hive.box(HiveBoxes.cache);
  }

  /// عدد العناصر في box معين
  static int count(String boxName) {
    if (!Hive.isBoxOpen(boxName)) {
      return 0;
    }
    return Hive.box(boxName).length;
  }

  /// هل الـ box فارغ؟
  static bool isEmpty(String boxName) {
    if (!Hive.isBoxOpen(boxName)) {
      return true;
    }
    return Hive.box(boxName).isEmpty;
  }

  /// هل الـ box مفتوح؟
  static bool isOpen(String boxName) {
    return Hive.isBoxOpen(boxName);
  }

  /// مسح box معين
  static Future<void> clear(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box(boxName).clear();
    }
  }

  /// حذف عنصر من box
  static Future<void> delete(String boxName, dynamic key) async {
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box(boxName).delete(key);
    }
  }

  /// الحصول على جميع المفاتيح
  static Iterable<dynamic> getKeys(String boxName) {
    if (!Hive.isBoxOpen(boxName)) {
      return [];
    }
    return Hive.box(boxName).keys;
  }

  /// الحصول على جميع القيم
  static Iterable<dynamic> getValues(String boxName) {
    if (!Hive.isBoxOpen(boxName)) {
      return [];
    }
    return Hive.box(boxName).values;
  }
}
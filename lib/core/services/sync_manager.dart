import 'dart:async';
import 'package:psga_app/core/services/connectivity_service.dart';
import 'package:psga_app/core/services/sync_service.dart';
import 'package:psga_app/core/storage/local_storage_service.dart';
import 'package:psga_app/core/utils/logger.dart';

/// مدير المزامنة الذكي
class SyncManager {
  static SyncManager? _instance;
  static SyncManager get instance => _instance ??= SyncManager._();

  SyncManager._();

  final SyncService _syncService = SyncService.instance;
  final ConnectivityService _connectivityService = ConnectivityService.instance;
  LocalStorageService? _localStorage;

  Timer? _autoSyncTimer;
  bool _isAutoSyncEnabled = false;
  bool _isInitialized = false;

  // إعدادات المزامنة
  Duration _syncInterval = const Duration(minutes: 5);
  bool _syncOnlyOnWifi = false;
  DateTime? _lastSyncTime;

  // ==================== Initialization ====================

  Future<void> init(LocalStorageService localStorage) async {
    if (_isInitialized) {
      AppLogger.warning('[SyncManager] المدير مُهيأ بالفعل');
      return;
    }

    try {
      AppLogger.info('[SyncManager] جاري تهيئة مدير المزامنة');

      _localStorage = localStorage;

      // تحميل الإعدادات المحفوظة
      await _loadSettings();

      // تسجيل callback لعودة الاتصال - مزامنة فورية تلقائياً
      _connectivityService.onConnected(() {
        AppLogger.info('[SyncManager] 🌐 تم الاتصال - مزامنة تلقائية فورية');
        unawaited(syncAll());
      });

      // بدء المزامنة التلقائية إذا كانت مفعلة
      if (_isAutoSyncEnabled) {
        await startAutoSync();
      }

      _isInitialized = true;
      AppLogger.success('[SyncManager] تم تهيئة مدير المزامنة بنجاح');
    } catch (e, stackTrace) {
      AppLogger.error('[SyncManager] فشل تهيئة مدير المزامنة', e, stackTrace);
      rethrow;
    }
  }

  /// تحميل الإعدادات المحفوظة
  Future<void> _loadSettings() async {
    try {
      // تفعيل المزامنة التلقائية افتراضياً
      _isAutoSyncEnabled = _localStorage?.getSetting<bool>(
            'auto_sync_enabled',
            defaultValue: true, // ✅ مفعل افتراضياً
          ) ??
          true;

      _syncOnlyOnWifi = _localStorage?.getSetting<bool>(
            'sync_only_on_wifi',
            defaultValue: false,
          ) ??
          false;

      final intervalMinutes = _localStorage?.getSetting<int>(
            'sync_interval_minutes',
            defaultValue: 5, // ✅ كل 5 دقائق
          ) ??
          5;
      _syncInterval = Duration(minutes: intervalMinutes);

      final lastSyncStr = _localStorage?.getSetting<String>('last_sync_time');
      if (lastSyncStr != null) {
        _lastSyncTime = DateTime.parse(lastSyncStr);
      }

      AppLogger.info('[SyncManager] تم تحميل الإعدادات:');
      AppLogger.info('  - Auto Sync: $_isAutoSyncEnabled');
      AppLogger.info('  - WiFi Only: $_syncOnlyOnWifi');
      AppLogger.info('  - Interval: ${_syncInterval.inMinutes} دقيقة');
    } catch (e) {
      AppLogger.error('[SyncManager] فشل تحميل الإعدادات', e);
    }
  }

  // ==================== Auto Sync ====================

  /// بدء المزامنة التلقائية
  Future<void> startAutoSync() async {
    try {
      AppLogger.info('[SyncManager] بدء المزامنة التلقائية');

      _isAutoSyncEnabled = true;
      await _localStorage?.saveSetting('auto_sync_enabled', true);

      // إلغاء Timer السابق إن وجد
      _autoSyncTimer?.cancel();

      // بدء Timer جديد
      _autoSyncTimer = Timer.periodic(_syncInterval, (timer) {
        unawaited(_performAutoSync());
      });

      // مزامنة فورية
      unawaited(_performAutoSync());

      AppLogger.success('[SyncManager] تم بدء المزامنة التلقائية');
    } catch (e) {
      AppLogger.error('[SyncManager] فشل بدء المزامنة التلقائية', e);
      rethrow;
    }
  }

  /// إيقاف المزامنة التلقائية
  Future<void> stopAutoSync() async {
    try {
      AppLogger.info('[SyncManager] إيقاف المزامنة التلقائية');

      _isAutoSyncEnabled = false;
      await _localStorage?.saveSetting('auto_sync_enabled', false);

      _autoSyncTimer?.cancel();
      _autoSyncTimer = null;

      AppLogger.success('[SyncManager] تم إيقاف المزامنة التلقائية');
    } catch (e) {
      AppLogger.error('[SyncManager] فشل إيقاف المزامنة التلقائية', e);
      rethrow;
    }
  }

  /// تنفيذ المزامنة التلقائية
  Future<void> _performAutoSync() async {
    try {
      // التحقق من الاتصال
      if (!_connectivityService.isConnected) {
        AppLogger.info('[SyncManager] لا يوجد اتصال - تخطي المزامنة');
        return;
      }

      // التحقق من WiFi إذا كان مطلوباً
      if (_syncOnlyOnWifi) {
        final isWifi = await _connectivityService.isWifi();
        if (!isWifi) {
          AppLogger.info('[SyncManager] ليس WiFi - تخطي المزامنة');
          return;
        }
      }

      AppLogger.info('[SyncManager] بدء المزامنة التلقائية');
      await syncAll();
    } catch (e) {
      AppLogger.error('[SyncManager] خطأ في المزامنة التلقائية', e);
    }
  }

  // ==================== Manual Sync ====================

  /// مزامنة فورية
  Future<void> syncNow() async {
    try {
      AppLogger.info('[SyncManager] مزامنة فورية');

      if (!_connectivityService.isConnected) {
        throw Exception('لا يوجد اتصال بالإنترنت');
      }

      await syncAll();
      AppLogger.success('[SyncManager] تمت المزامنة الفورية بنجاح');
    } catch (e) {
      AppLogger.error('[SyncManager] فشلت المزامنة الفورية', e);
      rethrow;
    }
  }

  /// مزامنة جميع الكيانات
  Future<void> syncAll() async {
    try {
      AppLogger.info('[SyncManager] مزامنة جميع الكيانات');

      await _syncService.syncAll();

      // حفظ وقت آخر مزامنة
      _lastSyncTime = DateTime.now();
      await _localStorage?.saveSetting(
        'last_sync_time',
        _lastSyncTime!.toIso8601String(),
      );

      AppLogger.success('[SyncManager] تمت مزامنة جميع الكيانات');
    } catch (e) {
      AppLogger.error('[SyncManager] فشلت المزامنة', e);
      rethrow;
    }
  }

  /// مزامنة كيان محدد
  Future<void> syncEntity(String entity) async {
    try {
      AppLogger.info('[SyncManager] مزامنة $entity');

      if (!_connectivityService.isConnected) {
        throw Exception('لا يوجد اتصال بالإنترنت');
      }

      // TODO: تنفيذ مزامنة كيان محدد
      await _syncService.syncAll();

      AppLogger.success('[SyncManager] تمت مزامنة $entity');
    } catch (e) {
      AppLogger.error('[SyncManager] فشلت مزامنة $entity', e);
      rethrow;
    }
  }

  // ==================== Settings ====================

  /// تعيين فاصل المزامنة
  Future<void> setSyncInterval(Duration interval) async {
    try {
      AppLogger.info('[SyncManager] تغيير فاصل المزامنة: ${interval.inMinutes} دقيقة');

      _syncInterval = interval;
      await _localStorage?.saveSetting('sync_interval_minutes', interval.inMinutes);

      // إعادة تشغيل Auto Sync إذا كان مفعلاً
      if (_isAutoSyncEnabled) {
        await stopAutoSync();
        await startAutoSync();
      }

      AppLogger.success('[SyncManager] تم تغيير فاصل المزامنة');
    } catch (e) {
      AppLogger.error('[SyncManager] فشل تغيير فاصل المزامنة', e);
      rethrow;
    }
  }

  /// تفعيل/تعطيل المزامنة على WiFi فقط
  Future<void> setSyncOnlyOnWifi(bool enabled) async {
    try {
      AppLogger.info('[SyncManager] WiFi فقط: $enabled');

      _syncOnlyOnWifi = enabled;
      await _localStorage?.saveSetting('sync_only_on_wifi', enabled);

      AppLogger.success('[SyncManager] تم تحديث إعداد WiFi');
    } catch (e) {
      AppLogger.error('[SyncManager] فشل تحديث إعداد WiFi', e);
      rethrow;
    }
  }

  // ==================== Getters ====================

  bool get isAutoSyncEnabled => _isAutoSyncEnabled;
  bool get syncOnlyOnWifi => _syncOnlyOnWifi;
  Duration get syncInterval => _syncInterval;
  DateTime? get lastSyncTime => _lastSyncTime;
  
  int get pendingOperations => _syncService.getPendingCount();
  SyncStatus get currentStatus => _syncService.currentStatus;
  Stream<SyncStatus> get statusStream => _syncService.statusStream;

  /// الوقت منذ آخر مزامنة
  Duration? get timeSinceLastSync {
    if (_lastSyncTime == null) return null;
    return DateTime.now().difference(_lastSyncTime!);
  }

  /// وصف آخر مزامنة
  String get lastSyncDescription {
    if (_lastSyncTime == null) return 'لم تتم المزامنة بعد';

    final duration = timeSinceLastSync!;

    if (duration.inSeconds < 60) {
      return 'منذ ${duration.inSeconds} ثانية';
    } else if (duration.inMinutes < 60) {
      return 'منذ ${duration.inMinutes} دقيقة';
    } else if (duration.inHours < 24) {
      return 'منذ ${duration.inHours} ساعة';
    } else {
      return 'منذ ${duration.inDays} يوم';
    }
  }

  // ==================== Lifecycle ====================

  Future<void> dispose() async {
    try {
      AppLogger.info('[SyncManager] إيقاف مدير المزامنة');

      _autoSyncTimer?.cancel();
      _autoSyncTimer = null;
      _isInitialized = false;

      AppLogger.success('[SyncManager] تم إيقاف مدير المزامنة');
    } catch (e) {
      AppLogger.error('[SyncManager] خطأ في إيقاف المدير', e);
    }
  }

  // ==================== Utility ====================

  Map<String, dynamic> getInfo() {
    return {
      'isInitialized': _isInitialized,
      'isAutoSyncEnabled': _isAutoSyncEnabled,
      'syncOnlyOnWifi': _syncOnlyOnWifi,
      'syncInterval': '${_syncInterval.inMinutes} دقيقة',
      'lastSyncTime': _lastSyncTime?.toIso8601String() ?? 'لم تتم',
      'timeSinceLastSync': lastSyncDescription,
      'pendingOperations': pendingOperations,
      'currentStatus': currentStatus.toString(),
      'isConnected': _connectivityService.isConnected,
    };
  }

  void printInfo() {
    final info = getInfo();
    AppLogger.info('[SyncManager] معلومات المدير:');
    info.forEach((key, value) {
      AppLogger.info('  $key: $value');
    });
  }
}

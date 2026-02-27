import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:psga_app/core/utils/logger.dart';

/// مدير إعدادات البيئة
/// 
/// يدير تحميل واسترجاع المتغيرات من ملف .env
class EnvConfig {
  static Future<void> load() async {
    try {
      AppLogger.info('[EnvConfig] تحميل إعدادات البيئة');
      await dotenv.load(fileName: '.env');
      AppLogger.success('[EnvConfig] تم تحميل الإعدادات بنجاح');
    } catch (e, stackTrace) {
      AppLogger.error('[EnvConfig] فشل تحميل الإعدادات', e, stackTrace);
      // استخدام القيم الافتراضية
    }
  }

  // ==================== Google Maps ====================
  
  static String get googleMapsApiKey => 
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'AIzaSyDOm51mVPayEUvccSg4tWPgUSyV5fmPziM';

  // ==================== App ====================
  
  static String get appName => dotenv.env['APP_NAME'] ?? 'PSGA';
  
  static String get appVersion => dotenv.env['APP_VERSION'] ?? '1.0.0';
  
  static String get appEnv => dotenv.env['APP_ENV'] ?? 'development';
  
  static bool get isProduction => appEnv == 'production';
  
  static bool get isDevelopment => appEnv == 'development';

  // ==================== Offline Maps ====================
  
  static int get offlineMapsMaxSizeMB => 
      int.tryParse(dotenv.env['OFFLINE_MAPS_MAX_SIZE_MB'] ?? '500') ?? 500;
  
  static List<int> get offlineMapsDefaultZoomLevels {
    final zooms = dotenv.env['OFFLINE_MAPS_DEFAULT_ZOOM_LEVELS'] ?? '12,13,14';
    return zooms.split(',').map((z) => int.tryParse(z) ?? 12).toList();
  }
  
  static String get offlineMapsTileServer => 
      dotenv.env['OFFLINE_MAPS_TILE_SERVER'] ?? 'https://tile.openstreetmap.org';

  // ==================== Cache ====================
  
  static int get cacheExpiryHours => 
      int.tryParse(dotenv.env['CACHE_EXPIRY_HOURS'] ?? '24') ?? 24;
  
  static int get cacheMaxAgeDays => 
      int.tryParse(dotenv.env['CACHE_MAX_AGE_DAYS'] ?? '7') ?? 7;

  // ==================== Location Tracking ====================
  
  static int get locationUpdateIntervalSeconds => 
      int.tryParse(dotenv.env['LOCATION_UPDATE_INTERVAL_SECONDS'] ?? '5') ?? 5;
  
  static int get locationDistanceFilterMeters => 
      int.tryParse(dotenv.env['LOCATION_DISTANCE_FILTER_METERS'] ?? '10') ?? 10;

  // ==================== Deviation Detection ====================
  
  static int get deviationCheckIntervalSeconds => 
      int.tryParse(dotenv.env['DEVIATION_CHECK_INTERVAL_SECONDS'] ?? '10') ?? 10;
  
  static double get deviationThresholdMeters => 
      double.tryParse(dotenv.env['DEVIATION_THRESHOLD_METERS'] ?? '50') ?? 50.0;
  
  static double get deviationCriticalThresholdMeters => 
      double.tryParse(dotenv.env['DEVIATION_CRITICAL_THRESHOLD_METERS'] ?? '200') ?? 200.0;

  // ==================== Notifications ====================
  
  static String get notificationChannelId => 
      dotenv.env['NOTIFICATION_CHANNEL_ID'] ?? 'psga_notifications';
  
  static String get notificationChannelName => 
      dotenv.env['NOTIFICATION_CHANNEL_NAME'] ?? 'PSGA Notifications';

  // ==================== ML Service ====================
  
  static String get mlServerUrl => 
      dotenv.env['ML_SERVER_URL'] ?? 'http://10.0.2.2:8000';

  /// طباعة جميع الإعدادات (للتطوير فقط)
  static void printConfig() {
    if (!isDevelopment) return;
    
    AppLogger.debug('[EnvConfig] === بيئة التطبيق ===');
    AppLogger.debug('[EnvConfig] App Name: $appName');
    AppLogger.debug('[EnvConfig] App Version: $appVersion');
    AppLogger.debug('[EnvConfig] Environment: $appEnv');
    AppLogger.debug('[EnvConfig] Google Maps API Key: ${googleMapsApiKey.substring(0, 10)}...');
    AppLogger.debug('[EnvConfig] Offline Maps Max Size: $offlineMapsMaxSizeMB MB');
    AppLogger.debug('[EnvConfig] Cache Expiry: $cacheExpiryHours hours');
    AppLogger.debug('[EnvConfig] Location Update Interval: $locationUpdateIntervalSeconds seconds');
    AppLogger.debug('[EnvConfig] ========================');
  }
}

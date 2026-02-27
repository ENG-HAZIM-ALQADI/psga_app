/// النصوص الثابتة للتطبيق
class AppStrings {
  AppStrings._();

  // معلومات التطبيق
  static const String appName = 'PSGA';
  static const String appFullName = 'Personal Security Guard App';
  static const String appVersion = '1.0.0';

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String routesCollection = 'routes';
  static const String tripsCollection = 'trips';
  static const String alertsCollection = 'alerts';
  static const String contactsCollection = 'contacts';
  static const String devicesCollection = 'devices';

  // Hive Boxes
  static const String userBox = 'user_box';
  static const String routeBox = 'route_box';
  static const String tripBox = 'trip_box';
  static const String alertBox = 'alert_box';
  static const String contactBox = 'contact_box';
  static const String syncQueueBox = 'sync_queue_box';
  static const String settingsBox = 'settings_box';
  static const String cacheBox = 'cache_box';
  static const String mlModelsBox = 'ml_models_box';

  // SharedPreferences Keys
  static const String keyIsFirstLaunch = 'is_first_launch';
  static const String keyLanguage = 'language';
  static const String keyThemeMode = 'theme_mode';
  static const String keyUserId = 'user_id';
  static const String keyUserToken = 'user_token';
  static const String keyFCMToken = 'fcm_token';
  static const String keyLastSyncTime = 'last_sync_time';

  // Routes (Navigation)
  static const String splashRoute = '/';
  static const String onboardingRoute = '/onboarding';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String forgotPasswordRoute = '/forgot-password';
  static const String verifyEmailRoute = '/verify-email';
  static const String homeRoute = '/home';
  static const String routesListRoute = '/routes';
  static const String createRouteRoute = '/routes/create';
  static const String routeDetailsRoute = '/routes/:id';
  static const String activeTripRoute = '/trip/active';
  static const String tripHistoryRoute = '/trip/history';
  static const String tripDetailsRoute = '/trip/:id';
  static const String emergencyRoute = '/emergency';
  static const String contactsRoute = '/contacts';
  static const String addContactRoute = '/contacts/add';
  static const String alertHistoryRoute = '/alerts';
  static const String settingsRoute = '/settings';
  static const String profileRoute = '/profile';
  static const String mapRoute = '/map';

  // API Endpoints (if needed)
  static const String baseUrl = 'https://api.psga.com';

  // Error Messages
  static const String errorUnknown = 'An unknown error occurred';
  static const String errorNetwork = 'Network error. Please check your connection.';
  static const String errorServer = 'Server error. Please try again later.';
  static const String errorAuth = 'Authentication error';
  static const String errorPermission = 'Permission denied';
  static const String errorNotFound = 'Resource not found';
  static const String errorValidation = 'Validation error';

  // Success Messages
  static const String successSaved = 'Saved successfully';
  static const String successDeleted = 'Deleted successfully';
  static const String successUpdated = 'Updated successfully';

  // Validation Messages
  static const String validationRequired = 'This field is required';
  static const String validationEmail = 'Invalid email address';
  static const String validationPassword = 'Password must be at least 8 characters';
  static const String validationPasswordMatch = 'Passwords do not match';
  static const String validationPhone = 'Invalid phone number';

  // Default Values
  static const int defaultDeviationThreshold = 100; // متر
  static const int defaultCountdownDuration = 30; // ثانية
  static const int defaultLocationUpdateInterval = 10; // ثانية
  static const int defaultSyncInterval = 300; // 5 دقائق بالثواني
  static const double defaultMapZoom = 15.0;

  // ML Constants
  static const double dbscanEpsilon = 50.0; // متر
  static const int dbscanMinPoints = 3;
  static const int kmeansDefaultClusters = 3;

  // Notification Channels
  static const String tripNotificationChannelId = 'trip_channel';
  static const String tripNotificationChannelName = 'Trip Notifications';
  static const String alertNotificationChannelId = 'alert_channel';
  static const String alertNotificationChannelName = 'Alert Notifications';
  static const String sosNotificationChannelId = 'sos_channel';
  static const String sosNotificationChannelName = 'SOS Notifications';

  // Assets Paths
  static const String imagesPath = 'assets/images/';
  static const String iconsPath = 'assets/icons/';
  static const String fontsPath = 'assets/fonts/';

  // Emergency Numbers (يمكن تخصيصها حسب البلد)
  static const String emergencyNumber = '911';
  static const String emergencyNumberLabel = 'Emergency Services';

  // Date Formats
  static const String dateFormat = 'yyyy-MM-dd';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm';
  static const String displayDateFormat = 'MMM dd, yyyy';
  static const String displayTimeFormat = 'hh:mm a';
  static const String displayDateTimeFormat = 'MMM dd, yyyy hh:mm a';

  // Units
  static const String unitKilometer = 'km';
  static const String unitMeter = 'm';
  static const String unitKilometerPerHour = 'km/h';
  static const String unitMile = 'mi';
  static const String unitMilePerHour = 'mph';

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration syncTimeout = Duration(minutes: 2);
  static const Duration locationTimeout = Duration(seconds: 10);
}

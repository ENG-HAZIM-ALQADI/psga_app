import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// امتدادات على String
extension StringExtensions on String {
  /// تحويل أول حرف لحرف كبير
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// تحويل كل كلمة لتبدأ بحرف كبير
  String capitalizeWords() {
    if (isEmpty) return this;
    return split(' ').map((word) => word.capitalize()).join(' ');
  }

  /// التحقق من أن النص بريد إلكتروني صحيح
  bool get isValidEmail {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(this);
  }

  /// التحقق من أن النص رقم هاتف صحيح
  bool get isValidPhone {
    final cleaned = replaceAll(RegExp(r'[\s-]'), '');
    return RegExp(r'^[+]?[0-9]{10,15}$').hasMatch(cleaned);
  }

  /// إزالة المسافات الزائدة
  String removeExtraSpaces() {
    return replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// قص النص بطول معين مع إضافة ...
  String truncate(int maxLength, {String suffix = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}$suffix';
  }
}

/// امتدادات على DateTime
extension DateTimeExtensions on DateTime {
  /// تنسيق التاريخ
  String format([String pattern = 'yyyy-MM-dd']) {
    return DateFormat(pattern).format(this);
  }

  /// تنسيق الوقت
  String formatTime([String pattern = 'HH:mm']) {
    return DateFormat(pattern).format(this);
  }

  /// تنسيق التاريخ والوقت
  String formatDateTime([String pattern = 'yyyy-MM-dd HH:mm']) {
    return DateFormat(pattern).format(this);
  }

  /// هل التاريخ اليوم؟
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// هل التاريخ أمس؟
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  /// هل التاريخ في المستقبل؟
  bool get isFuture => isAfter(DateTime.now());

  /// هل التاريخ في الماضي؟
  bool get isPast => isBefore(DateTime.now());

  /// الحصول على اسم اليوم
  String get dayName {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[weekday - 1];
  }

  /// الحصول على اسم الشهر
  String get monthName {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  /// الفرق بالأيام من الآن
  int get daysFromNow => DateTime.now().difference(this).inDays;

  /// الفرق بالساعات من الآن
  int get hoursFromNow => DateTime.now().difference(this).inHours;

  /// الفرق بالدقائق من الآن
  int get minutesFromNow => DateTime.now().difference(this).inMinutes;

  /// تنسيق نسبي (منذ 5 دقائق، منذ ساعتين، إلخ)
  String get timeAgo {
    final difference = DateTime.now().difference(this);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${difference.inDays ~/ 365 > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${difference.inDays ~/ 30 > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}

/// امتدادات على int و double
extension NumExtensions on num {
  /// تنسيق كمسافة (1500 → 1.5 km)
  String formatDistance() {
    if (this >= 1000) {
      return '${(this / 1000).toStringAsFixed(1)} km';
    } else {
      return '${toInt()} m';
    }
  }

  /// تنسيق كمدة زمنية (3661 ثانية → 1h 1m 1s)
  String formatDuration() {
    final duration = Duration(seconds: toInt());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// تنسيق كسرعة (25 → 25 km/h)
  String formatSpeed() {
    return '${toStringAsFixed(1)} km/h';
  }

  /// تحويل إلى نسبة مئوية
  String toPercentage([int decimals = 0]) {
    return '${(this * 100).toStringAsFixed(decimals)}%';
  }
}

/// امتدادات على BuildContext
extension ContextExtensions on BuildContext {
  /// الوصول السريع للترجمة - context.l10n.appName
  AppLocalizations get l10n => AppLocalizations.of(this)!;

  /// الحصول على حجم الشاشة
  Size get screenSize => MediaQuery.of(this).size;

  /// الحصول على عرض الشاشة
  double get screenWidth => screenSize.width;

  /// الحصول على ارتفاع الشاشة
  double get screenHeight => screenSize.height;

  /// هل الشاشة صغيرة (موبايل)؟
  bool get isMobile => screenWidth < 600;

  /// هل الشاشة متوسطة (تابلت)؟
  bool get isTablet => screenWidth >= 600 && screenWidth < 900;

  /// هل الشاشة كبيرة (ديسكتوب)؟
  bool get isDesktop => screenWidth >= 900;

  /// الحصول على الثيم
  ThemeData get theme => Theme.of(this);

  /// الحصول على الألوان
  ColorScheme get colors => theme.colorScheme;

  /// الحصول على أنماط النص
  TextTheme get textTheme => theme.textTheme;

  /// التنقل إلى صفحة جديدة
  Future<T?> push<T>(Widget page) {
    return Navigator.of(this).push<T>(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  /// التنقل إلى صفحة جديدة مع استبدال الحالية
  Future<T?> pushReplacement<T>(Widget page) {
    return Navigator.of(this).pushReplacement<T, void>(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  /// الرجوع للصفحة السابقة
  void pop<T>([T? result]) {
    Navigator.of(this).pop(result);
  }

  /// إظهار SnackBar
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colors.error : null,
      ),
    );
  }

  /// إظهار SnackBar للنجاح
  void showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// إظهار SnackBar للخطأ
  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFF44336),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// إظهار SnackBar للمعلومات
  void showInfoSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF2196F3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// إظهار SnackBar للتحذير
  void showWarningSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFFF9800),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// ترجمة مفتاح خطأ قادم من BLoC إلى نص مترجم
  /// BLoC يُصدر مفاتيح ARB، والـ Widget يترجمها هنا
  String translateErrorKey(String key) {
    final l = l10n;
    switch (key) {
      // Trip errors
      case 'locationTrackingFailed': return l.locationTrackingFailed;
      case 'unexpectedError': return l.unexpectedError;
      case 'systemError': return l.systemError;
      case 'noActiveTripError': return l.noActiveTripError;
      case 'emergencyActivationFailed': return l.emergencyActivationFailed;
      case 'autoTrackingFailed': return l.autoTrackingFailed;
      case 'routeInfoLoadFailed2': return l.routeInfoLoadFailed2;
      case 'invalidRoute2': return l.invalidRoute2;
      case 'locationDetermFailed': return l.locationDetermFailed;
      case 'locationCheckError': return l.locationCheckError;
      case 'tripStartError': return l.tripStartError;
      // Alert errors
      case 'alertTriggerFailed': return l.alertTriggerFailed;
      case 'sosSendFailed': return l.sosSendFailed;
      case 'alertAcknowledgeFailed': return l.alertAcknowledgeFailed;
      case 'alertLoadFailed': return l.alertLoadFailed;
      case 'escalationStartFailed': return l.escalationStartFailed;
      case 'escalationCancelFailed': return l.escalationCancelFailed;
      case 'alertSettingsSaveFailed': return l.alertSettingsSaveFailed;
      case 'alertSettingsLoadFailed': return l.alertSettingsLoadFailed;
      // Routes errors
      case 'routesLoadError': return l.routesLoadError;
      case 'routeCreateError': return l.routeCreateError;
      case 'routeUpdateError': return l.routeUpdateError;
      case 'routeDeleteError': return l.routeDeleteError;
      case 'activeRoutesLoadError': return l.activeRoutesLoadError;
      case 'routeStatusUpdateError': return l.routeStatusUpdateError;
      case 'favoritesLoadError': return l.favoritesLoadError;
      // Contact errors
      case 'contactsLoadFailed': return l.contactsLoadFailed;
      case 'emergencyContactsLoadFailed': return l.emergencyContactsLoadFailed;
      case 'contactAddFailed': return l.contactAddFailed;
      case 'contactUpdateFailed': return l.contactUpdateFailed;
      case 'contactDeleteFailed': return l.contactDeleteFailed;
      case 'contactSearchFailed': return l.contactSearchFailed;
      case 'setPrimaryContactFailed': return l.setPrimaryContactFailed;
      // Maps messages
      case 'calculatingRoute': return l.calculatingRoute;
      case 'routeCalcError': return l.routeCalcError;
      case 'searchingAlternatives': return l.searchingAlternatives;
      case 'noRoutesFound': return l.noRoutesFound;
      case 'alternativeSearchError': return l.alternativeSearchError;
      case 'searching': return l.searching;
      case 'noSearchResults': return l.noSearchResults;
      case 'searchError': return l.searchError;
      case 'searchingNearby': return l.searchingNearby;
      case 'noNearbyPlaces': return l.noNearbyPlaces;
      case 'loadingDetails': return l.loadingDetails;
      case 'featureUnderDevelopment': return l.featureUnderDevelopment;
      case 'loadingError': return l.loadingError;
      case 'searchingEmergency': return l.searchingEmergency;
      case 'preparingDownload': return l.preparingDownload;
      case 'regionDownloadFailed': return l.regionDownloadFailed;
      case 'downloadError': return l.downloadError;
      case 'regionDeleteFailed': return l.regionDeleteFailed;
      case 'deleteError': return l.deleteError;
      case 'mapsDeleteFailed': return l.mapsDeleteFailed;
      // Fallback
      default: return key;
    }
  }

  /// إظهار Dialog
  Future<T?> showCustomDialog<T>(Widget dialog) {
    return showDialog<T>(
      context: this,
      builder: (_) => dialog,
    );
  }
}

/// امتدادات على Duration
extension DurationExtensions on Duration {
  /// تنسيق المدة (1:23:45)
  String format() {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(inHours);
    final minutes = twoDigits(inMinutes.remainder(60));
    final seconds = twoDigits(inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  /// تنسيق مختصر (1h 23m)
  String formatShort() {
    if (inHours > 0) {
      return '${inHours}h ${inMinutes.remainder(60)}m';
    } else if (inMinutes > 0) {
      return '${inMinutes}m ${inSeconds.remainder(60)}s';
    } else {
      return '${inSeconds}s';
    }
  }
}

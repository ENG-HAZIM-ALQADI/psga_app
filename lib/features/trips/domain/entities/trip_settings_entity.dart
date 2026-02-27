import 'package:equatable/equatable.dart';

/// كيان إعدادات الرحلات
/// Single Responsibility: يحتوي فقط على إعدادات الرحلات
/// 
/// ملاحظة: تمت إضافة دعم المزامنة مع Firebase
class TripSettingsEntity extends Equatable {
  /// معرف المستخدم (للمزامنة مع Firebase)
  final String userId;
  
  /// تاريخ الإنشاء (للمزامنة)
  final DateTime createdAt;
  
  /// تاريخ آخر تحديث (للمزامنة)
  final DateTime? updatedAt;
  
  /// عتبة المسافة للتحقق من موقع البداية (بالمتر)
  /// القيمة الافتراضية: 50 متر
  final double startLocationThreshold;

  /// عتبة الانحراف المنخفض (بالمتر)
  /// القيمة الافتراضية: 50 متر
  final double lowDeviationThreshold;

  /// عتبة الانحراف المتوسط (بالمتر)
  /// القيمة الافتراضية: 150 متر
  final double mediumDeviationThreshold;

  /// عتبة الانحراف العالي (بالمتر)
  /// القيمة الافتراضية: 300 متر
  final double highDeviationThreshold;

  /// تفعيل التحقق التلقائي من الموقع قبل بدء الرحلة
  final bool enableLocationValidation;

  /// تفعيل الحساب التلقائي للمسارات
  final bool enableAutoRouteCalculation;

  /// البدء دائماً من الموقع الحالي (بدون التحقق والسؤال)
  final bool alwaysStartFromCurrentLocation;

  /// تحديث المسار الأصلي عند البدء من موقع مختلف
  final bool updateOriginalRoute;

  /// عدد مرات استخدام "ابدأ من هنا" - للإحصائيات
  final int startFromHereUsageCount;

  const TripSettingsEntity({
    required this.userId,
    required this.createdAt,
    this.updatedAt,
    this.startLocationThreshold = 50.0,
    this.lowDeviationThreshold = 50.0,
    this.mediumDeviationThreshold = 150.0,
    this.highDeviationThreshold = 300.0,
    this.enableLocationValidation = true,
    this.enableAutoRouteCalculation = true,
    this.alwaysStartFromCurrentLocation = false,
    this.updateOriginalRoute = false,
    this.startFromHereUsageCount = 0,
  });

  /// القيم الافتراضية
  factory TripSettingsEntity.defaults(String userId) {
    return TripSettingsEntity(
      userId: userId,
      createdAt: DateTime.now(),
    );
  }

  /// نسخ مع تعديل
  TripSettingsEntity copyWith({
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? startLocationThreshold,
    double? lowDeviationThreshold,
    double? mediumDeviationThreshold,
    double? highDeviationThreshold,
    bool? enableLocationValidation,
    bool? enableAutoRouteCalculation,
    bool? alwaysStartFromCurrentLocation,
    bool? updateOriginalRoute,
    int? startFromHereUsageCount,
  }) {
    return TripSettingsEntity(
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      startLocationThreshold: startLocationThreshold ?? this.startLocationThreshold,
      lowDeviationThreshold: lowDeviationThreshold ?? this.lowDeviationThreshold,
      mediumDeviationThreshold: mediumDeviationThreshold ?? this.mediumDeviationThreshold,
      highDeviationThreshold: highDeviationThreshold ?? this.highDeviationThreshold,
      enableLocationValidation: enableLocationValidation ?? this.enableLocationValidation,
      enableAutoRouteCalculation: enableAutoRouteCalculation ?? this.enableAutoRouteCalculation,
      alwaysStartFromCurrentLocation: alwaysStartFromCurrentLocation ?? this.alwaysStartFromCurrentLocation,
      updateOriginalRoute: updateOriginalRoute ?? this.updateOriginalRoute,
      startFromHereUsageCount: startFromHereUsageCount ?? this.startFromHereUsageCount,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        createdAt,
        updatedAt,
        startLocationThreshold,
        lowDeviationThreshold,
        mediumDeviationThreshold,
        highDeviationThreshold,
        enableLocationValidation,
        enableAutoRouteCalculation,
        alwaysStartFromCurrentLocation,
        updateOriginalRoute,
        startFromHereUsageCount,
      ];
}

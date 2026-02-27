import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';

/// خدمة تحليل الذكاء الاصطناعي
/// 
/// تتواصل مع خادم Python ML للحصول على:
/// - تحليل المسار وكشف الانحرافات
/// - تحليل الأنماط الزمنية
/// - حساب درجة الخطورة
class MLAnalysisService {
  static final instance = MLAnalysisService._();
  MLAnalysisService._();
  
  // عنوان الخادم - غيّره حسب بيئتك
  // للتطوير المحلي على Android Emulator: http://10.0.2.2:8000
  // للتطوير المحلي على iOS Simulator: http://localhost:8000
  // للإنتاج: https://your-app.railway.app
  String _baseUrl = 'https://your-ml-server.railway.app';
  
  /// تعيين عنوان الخادم
  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    AppLogger.info('[ML] تم تعيين عنوان الخادم: $_baseUrl');
  }
  
  /// فحص صحة الاتصال بالخادم
  Future<bool> checkHealth() async {
    try {
      AppLogger.info('[ML] فحص اتصال الخادم...');
      
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        AppLogger.success('[ML] الخادم يعمل بشكل صحيح');
        return true;
      }
      
      AppLogger.warning('[ML] الخادم استجاب لكن بحالة: ${response.statusCode}');
      return false;
    } catch (e) {
      AppLogger.error('[ML] فشل الاتصال بالخادم', e);
      return false;
    }
  }
  
  /// تحليل المسار وكشف الانحرافات
  Future<RouteAnalysisResult?> analyzeRoute({
    required String routeId,
    required List<Location> locations,
    required List<Location> plannedRoute,
  }) async {
    try {
      AppLogger.info('[ML] بدء تحليل المسار: $routeId (${locations.length} نقطة)');
      
      final body = {
        'route_id': routeId,
        'locations': locations.map((loc) => {
          'lat': loc.latitude,
          'lng': loc.longitude,
          'timestamp': loc.timestamp.toIso8601String(),
        }).toList(),
        'planned_route': plannedRoute.map((loc) => {
          'lat': loc.latitude,
          'lng': loc.longitude,
        }).toList(),
      };
      
      final response = await http.post(
        Uri.parse('$_baseUrl/analyze-route'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.success('[ML] تم تحليل المسار - خطر: ${data['analysis']['risk_score']}/100');
        return RouteAnalysisResult.fromJson(data);
      }
      
      AppLogger.error('[ML] فشل تحليل المسار: ${response.statusCode}');
      return null;
    } catch (e, stackTrace) {
      AppLogger.error('[ML] خطأ في تحليل المسار', e, stackTrace);
      return null;
    }
  }
  
  /// تحليل الأنماط الزمنية
  Future<PatternAnalysisResult?> analyzePatterns({
    required String userId,
    required List<TripHistoryItem> tripsHistory,
    required CurrentTripInfo currentTrip,
  }) async {
    try {
      AppLogger.info('[ML] بدء تحليل الأنماط للمستخدم: $userId');
      
      final body = {
        'user_id': userId,
        'trips_history': tripsHistory.map((trip) => trip.toJson()).toList(),
        'current_trip': currentTrip.toJson(),
      };
      
      final response = await http.post(
        Uri.parse('$_baseUrl/analyze-patterns'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.success('[ML] تم تحليل الأنماط - شذوذ: ${data['current_analysis']['anomaly_score']}/100');
        return PatternAnalysisResult.fromJson(data);
      }
      
      AppLogger.error('[ML] فشل تحليل الأنماط: ${response.statusCode}');
      return null;
    } catch (e, stackTrace) {
      AppLogger.error('[ML] خطأ في تحليل الأنماط', e, stackTrace);
      return null;
    }
  }
  
  /// تحليل شامل
  Future<ComprehensiveAnalysisResult?> comprehensiveAnalysis({
    required TripEntity currentTrip,
    required List<TripEntity> tripHistory,
  }) async {
    try {
      AppLogger.info('[ML] بدء التحليل الشامل للرحلة: ${currentTrip.id}');
      
      final body = {
        'trip': {
          'trip_id': currentTrip.id,
          'user_id': currentTrip.userId,
          'start_time': currentTrip.startTime.toIso8601String(),
          'locations': currentTrip.locationHistory.map((loc) => {
            'lat': loc.latitude,
            'lng': loc.longitude,
            'timestamp': loc.timestamp.toIso8601String(),
          }).toList(),
          'planned_route': currentTrip.route.waypoints.map((wp) => {
            'lat': wp.location.latitude,
            'lng': wp.location.longitude,
          }).toList(),
        },
        'user_history': {
          'trips': tripHistory.map((trip) => {
            'trip_id': trip.id,
            'start_time': trip.startTime.toIso8601String(),
            'duration_minutes': trip.endTime?.difference(trip.startTime).inMinutes ?? 0,
            'route_id': trip.routeId,
          }).toList(),
        },
      };
      
      final response = await http.post(
        Uri.parse('$_baseUrl/comprehensive-analysis'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.success('[ML] التحليل الشامل - خطر: ${data['overall_risk_score']}/100');
        return ComprehensiveAnalysisResult.fromJson(data);
      }
      
      AppLogger.error('[ML] فشل التحليل الشامل: ${response.statusCode}');
      return null;
    } catch (e, stackTrace) {
      AppLogger.error('[ML] خطأ في التحليل الشامل', e, stackTrace);
      return null;
    }
  }
}

// ==================== نماذج البيانات ====================

/// نتيجة تحليل المسار
class RouteAnalysisResult {
  final String routeId;
  final DateTime timestamp;
  final RouteAnalysis analysis;
  
  RouteAnalysisResult({
    required this.routeId,
    required this.timestamp,
    required this.analysis,
  });
  
  factory RouteAnalysisResult.fromJson(Map<String, dynamic> json) {
    return RouteAnalysisResult(
      routeId: json['route_id'],
      timestamp: DateTime.parse(json['timestamp']),
      analysis: RouteAnalysis.fromJson(json['analysis']),
    );
  }
}

class RouteAnalysis {
  final int totalPoints;
  final int anomalyCount;
  final double anomalyPercentage;
  final double avgDeviationMeters;
  final double maxDeviationMeters;
  final double riskScore;
  final String riskLevel;
  final String riskColor;
  final String recommendedAction;
  
  RouteAnalysis({
    required this.totalPoints,
    required this.anomalyCount,
    required this.anomalyPercentage,
    required this.avgDeviationMeters,
    required this.maxDeviationMeters,
    required this.riskScore,
    required this.riskLevel,
    required this.riskColor,
    required this.recommendedAction,
  });
  
  factory RouteAnalysis.fromJson(Map<String, dynamic> json) {
    return RouteAnalysis(
      totalPoints: json['total_points'],
      anomalyCount: json['anomaly_count'],
      anomalyPercentage: json['anomaly_percentage'].toDouble(),
      avgDeviationMeters: json['avg_deviation_meters'].toDouble(),
      maxDeviationMeters: json['max_deviation_meters'].toDouble(),
      riskScore: json['risk_score'].toDouble(),
      riskLevel: json['risk_level'],
      riskColor: json['risk_color'],
      recommendedAction: json['recommended_action'],
    );
  }
}

/// نتيجة تحليل الأنماط
class PatternAnalysisResult {
  final String userId;
  final DateTime timestamp;
  final UserPatterns patterns;
  final CurrentAnalysis currentAnalysis;
  
  PatternAnalysisResult({
    required this.userId,
    required this.timestamp,
    required this.patterns,
    required this.currentAnalysis,
  });
  
  factory PatternAnalysisResult.fromJson(Map<String, dynamic> json) {
    return PatternAnalysisResult(
      userId: json['user_id'],
      timestamp: DateTime.parse(json['timestamp']),
      patterns: UserPatterns.fromJson(json['patterns']),
      currentAnalysis: CurrentAnalysis.fromJson(json['current_analysis']),
    );
  }
}

class UserPatterns {
  final int mostCommonHour;
  final int mostCommonDay;
  final double avgDuration;
  final String? mostFrequentRoute;
  final int totalTrips;
  
  UserPatterns({
    required this.mostCommonHour,
    required this.mostCommonDay,
    required this.avgDuration,
    required this.totalTrips,
    this.mostFrequentRoute,
  });
  
  factory UserPatterns.fromJson(Map<String, dynamic> json) {
    return UserPatterns(
      mostCommonHour: json['most_common_hour'],
      mostCommonDay: json['most_common_day'],
      avgDuration: json['avg_duration'].toDouble(),
      mostFrequentRoute: json['most_frequent_route'],
      totalTrips: json['total_trips'],
    );
  }
}

class CurrentAnalysis {
  final bool isUnusual;
  final List<Anomaly> anomalies;
  final int anomalyScore;
  final String recommendation;
  
  CurrentAnalysis({
    required this.isUnusual,
    required this.anomalies,
    required this.anomalyScore,
    required this.recommendation,
  });
  
  factory CurrentAnalysis.fromJson(Map<String, dynamic> json) {
    return CurrentAnalysis(
      isUnusual: json['is_unusual'],
      anomalies: (json['anomalies'] as List)
          .map((a) => Anomaly.fromJson(a))
          .toList(),
      anomalyScore: json['anomaly_score'],
      recommendation: json['recommendation'],
    );
  }
}

class Anomaly {
  final String type;
  final String message;
  final String severity;
  
  Anomaly({
    required this.type,
    required this.message,
    required this.severity,
  });
  
  factory Anomaly.fromJson(Map<String, dynamic> json) {
    return Anomaly(
      type: json['type'],
      message: json['message'],
      severity: json['severity'],
    );
  }
}

/// نتيجة التحليل الشامل
class ComprehensiveAnalysisResult {
  final String tripId;
  final String userId;
  final DateTime timestamp;
  final double overallRiskScore;
  final String alertLevel;
  final String alertMessage;
  final String recommendedAction;
  final RouteAnalysisResult routeAnalysis;
  final PatternAnalysisResult patternAnalysis;
  
  ComprehensiveAnalysisResult({
    required this.tripId,
    required this.userId,
    required this.timestamp,
    required this.overallRiskScore,
    required this.alertLevel,
    required this.alertMessage,
    required this.recommendedAction,
    required this.routeAnalysis,
    required this.patternAnalysis,
  });
  
  factory ComprehensiveAnalysisResult.fromJson(Map<String, dynamic> json) {
    return ComprehensiveAnalysisResult(
      tripId: json['trip_id'],
      userId: json['user_id'],
      timestamp: DateTime.parse(json['timestamp']),
      overallRiskScore: json['overall_risk_score'].toDouble(),
      alertLevel: json['alert_level'],
      alertMessage: json['alert_message'],
      recommendedAction: json['recommended_action'],
      routeAnalysis: RouteAnalysisResult.fromJson(json['details']['route_analysis']),
      patternAnalysis: PatternAnalysisResult.fromJson(json['details']['pattern_analysis']),
    );
  }
}

/// عنصر في سجل الرحلات
class TripHistoryItem {
  final String tripId;
  final String startTime;
  final int durationMinutes;
  final String routeId;
  
  TripHistoryItem({
    required this.tripId,
    required this.startTime,
    required this.durationMinutes,
    required this.routeId,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'trip_id': tripId,
      'start_time': startTime,
      'duration_minutes': durationMinutes,
      'route_id': routeId,
    };
  }
}

/// معلومات الرحلة الحالية
class CurrentTripInfo {
  final String startTime;
  final String routeId;
  
  CurrentTripInfo({
    required this.startTime,
    required this.routeId,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'start_time': startTime,
      'route_id': routeId,
    };
  }
}

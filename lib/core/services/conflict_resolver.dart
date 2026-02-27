import 'package:psga_app/core/utils/logger.dart';

/// استراتيجية حل التعارضات
enum ConflictStrategy {
  serverWins,    // السيرفر يفوز
  clientWins,    // الجهاز يفوز
  newerWins,     // الأحدث يفوز
  mergeFields,   // دمج الحقول
}

/// نتيجة حل التعارض
class ConflictResolution<T> {
  final T resolvedData;
  final ConflictStrategy usedStrategy;
  final String? note;

  const ConflictResolution({
    required this.resolvedData,
    required this.usedStrategy,
    this.note,
  });
}

/// خدمة حل التعارضات عند المزامنة
class ConflictResolver {
  static final ConflictResolver _instance = ConflictResolver._();
  factory ConflictResolver() => _instance;
  ConflictResolver._();

  static ConflictResolver get instance => _instance;

  /// حل تعارض بيانات عامة
  ConflictResolution<Map<String, dynamic>> resolve({
    required Map<String, dynamic> serverData,
    required Map<String, dynamic> clientData,
    ConflictStrategy strategy = ConflictStrategy.newerWins,
  }) {
    AppLogger.info('[ConflictResolver] حل تعارض بإستراتيجية: $strategy');

    switch (strategy) {
      case ConflictStrategy.serverWins:
        return ConflictResolution(
          resolvedData: serverData,
          usedStrategy: strategy,
          note: 'اختير بيانات السيرفر',
        );

      case ConflictStrategy.clientWins:
        return ConflictResolution(
          resolvedData: clientData,
          usedStrategy: strategy,
          note: 'اختير بيانات الجهاز',
        );

      case ConflictStrategy.newerWins:
        return _resolveByTimestamp(serverData, clientData);

      case ConflictStrategy.mergeFields:
        return _mergeFields(serverData, clientData);
    }
  }

  /// حل بناءً على التاريخ
  ConflictResolution<Map<String, dynamic>> _resolveByTimestamp(
    Map<String, dynamic> serverData,
    Map<String, dynamic> clientData,
  ) {
    try {
      final serverTime = _extractTimestamp(serverData);
      final clientTime = _extractTimestamp(clientData);

      if (serverTime == null && clientTime == null) {
        // لا يوجد timestamps، استخدم السيرفر
        return ConflictResolution(
          resolvedData: serverData,
          usedStrategy: ConflictStrategy.serverWins,
          note: 'لا توجد timestamps، اختير السيرفر',
        );
      }

      if (serverTime == null) {
        return ConflictResolution(
          resolvedData: clientData,
          usedStrategy: ConflictStrategy.clientWins,
          note: 'timestamp السيرفر مفقود',
        );
      }

      if (clientTime == null) {
        return ConflictResolution(
          resolvedData: serverData,
          usedStrategy: ConflictStrategy.serverWins,
          note: 'timestamp الجهاز مفقود',
        );
      }

      // المقارنة
      final isServerNewer = serverTime.isAfter(clientTime);
      
      return ConflictResolution(
        resolvedData: isServerNewer ? serverData : clientData,
        usedStrategy: ConflictStrategy.newerWins,
        note: isServerNewer ? 'السيرفر أحدث' : 'الجهاز أحدث',
      );
    } catch (e) {
      AppLogger.error('[ConflictResolver] خطأ في حل التعارض', e);
      // في حالة الخطأ، استخدم السيرفر
      return ConflictResolution(
        resolvedData: serverData,
        usedStrategy: ConflictStrategy.serverWins,
        note: 'خطأ في المقارنة، اختير السيرفر',
      );
    }
  }

  /// دمج الحقول
  ConflictResolution<Map<String, dynamic>> _mergeFields(
    Map<String, dynamic> serverData,
    Map<String, dynamic> clientData,
  ) {
    final merged = Map<String, dynamic>.from(serverData);

    // دمج الحقول من الجهاز
    clientData.forEach((key, value) {
      if (!merged.containsKey(key) || value != null) {
        merged[key] = value;
      }
    });

    return ConflictResolution(
      resolvedData: merged,
      usedStrategy: ConflictStrategy.mergeFields,
      note: 'تم دمج ${merged.length} حقل',
    );
  }

  /// استخراج timestamp من البيانات
  DateTime? _extractTimestamp(Map<String, dynamic> data) {
    try {
      // البحث عن حقول التاريخ المعروفة
      final possibleFields = [
        'updatedAt',
        'updated_at',
        'modifiedAt',
        'modified_at',
        'createdAt',
        'created_at',
        'timestamp',
      ];

      for (final field in possibleFields) {
        if (data.containsKey(field)) {
          final value = data[field];
          if (value is String) {
            return DateTime.parse(value);
          } else if (value is DateTime) {
            return value;
          } else if (value is int) {
            return DateTime.fromMillisecondsSinceEpoch(value);
          }
        }
      }

      return null;
    } catch (e) {
      AppLogger.error('[ConflictResolver] خطأ في استخراج timestamp', e);
      return null;
    }
  }

  /// حل تعارض Routes
  ConflictResolution<Map<String, dynamic>> resolveRoute({
    required Map<String, dynamic> serverData,
    required Map<String, dynamic> clientData,
  }) {
    // Routes: الجهاز يفوز لأنها بيانات محلية
    return resolve(
      serverData: serverData,
      clientData: clientData,
      strategy: ConflictStrategy.clientWins,
    );
  }

  /// حل تعارض Trips
  ConflictResolution<Map<String, dynamic>> resolveTrip({
    required Map<String, dynamic> serverData,
    required Map<String, dynamic> clientData,
  }) {
    // Trips: الأحدث يفوز
    return resolve(
      serverData: serverData,
      clientData: clientData,
      strategy: ConflictStrategy.newerWins,
    );
  }

  /// حل تعارض Alerts
  ConflictResolution<Map<String, dynamic>> resolveAlert({
    required Map<String, dynamic> serverData,
    required Map<String, dynamic> clientData,
  }) {
    // Alerts: السيرفر يفوز للأمان
    return resolve(
      serverData: serverData,
      clientData: clientData,
      strategy: ConflictStrategy.serverWins,
    );
  }

  /// حل تعارض Contacts
  ConflictResolution<Map<String, dynamic>> resolveContact({
    required Map<String, dynamic> serverData,
    required Map<String, dynamic> clientData,
  }) {
    // Contacts: دمج الحقول
    return resolve(
      serverData: serverData,
      clientData: clientData,
      strategy: ConflictStrategy.mergeFields,
    );
  }
}

import '../models/alert_model.dart';
import '../models/alert_config_model.dart';
import '../../domain/entities/alert_entity.dart';

abstract class AlertRemoteDataSource {
  Future<AlertModel> createAlert(AlertModel alert);
  Future<void> updateAlert(AlertModel alert);
  Future<AlertModel?> getActiveAlert(String tripId);
  Future<List<AlertModel>> getAlertHistory(String userId, {int? limit});
  Future<void> acknowledgeAlert(String alertId);
  Future<void> escalateAlert(String alertId, AlertLevel newLevel);
  Future<AlertConfigModel> getAlertConfig(String userId);
  Future<void> updateAlertConfig(AlertConfigModel config);
  Stream<AlertModel> alertUpdates(String tripId);
}

class MockAlertRemoteDataSource implements AlertRemoteDataSource {
  final Map<String, AlertModel> _alerts = {};
  AlertConfigModel? _config;

  @override
  Future<AlertModel> createAlert(AlertModel alert) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _alerts[alert.id] = alert;
    return alert;
  }

  @override
  Future<void> updateAlert(AlertModel alert) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _alerts[alert.id] = alert;
  }

  @override
  Future<AlertModel?> getActiveAlert(String tripId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return _alerts.values.firstWhere(
        (alert) => alert.tripId == tripId && 
                   (alert.status == AlertStatus.active || alert.status == AlertStatus.pending),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<AlertModel>> getAlertHistory(String userId, {int? limit}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    var alerts = _alerts.values.where((a) => a.userId == userId).toList()
      ..sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
    if (limit != null && alerts.length > limit) {
      alerts = alerts.take(limit).toList();
    }
    return alerts;
  }

  @override
  Future<void> acknowledgeAlert(String alertId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (_alerts.containsKey(alertId)) {
      final alert = _alerts[alertId]!;
      _alerts[alertId] = AlertModel(
        id: alert.id,
        tripId: alert.tripId,
        userId: alert.userId,
        type: alert.type,
        level: alert.level,
        status: AlertStatus.acknowledged,
        location: alert.location,
        message: alert.message,
        triggeredAt: alert.triggeredAt,
        acknowledgedAt: DateTime.now(),
        escalatedAt: alert.escalatedAt,
        sentToContacts: alert.sentToContacts,
        deliveryMethod: alert.deliveryMethod,
        metadata: alert.metadata,
      );
    }
  }

  @override
  Future<void> escalateAlert(String alertId, AlertLevel newLevel) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (_alerts.containsKey(alertId)) {
      final alert = _alerts[alertId]!;
      _alerts[alertId] = AlertModel(
        id: alert.id,
        tripId: alert.tripId,
        userId: alert.userId,
        type: alert.type,
        level: newLevel,
        status: AlertStatus.escalated,
        location: alert.location,
        message: alert.message,
        triggeredAt: alert.triggeredAt,
        acknowledgedAt: alert.acknowledgedAt,
        escalatedAt: DateTime.now(),
        sentToContacts: alert.sentToContacts,
        deliveryMethod: alert.deliveryMethod,
        metadata: alert.metadata,
      );
    }
  }

  @override
  Future<AlertConfigModel> getAlertConfig(String userId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _config ?? AlertConfigModel.defaultConfig(userId);
  }

  @override
  Future<void> updateAlertConfig(AlertConfigModel config) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _config = config;
  }

  @override
  Stream<AlertModel> alertUpdates(String tripId) {
    return const Stream.empty();
  }
}

class FirebaseAlertRemoteDataSource implements AlertRemoteDataSource {
  @override
  Future<AlertModel> createAlert(AlertModel alert) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return alert;
  }

  @override
  Future<void> updateAlert(AlertModel alert) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<AlertModel?> getActiveAlert(String tripId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return null;
  }

  @override
  Future<List<AlertModel>> getAlertHistory(String userId, {int? limit}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [];
  }

  @override
  Future<void> acknowledgeAlert(String alertId) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<void> escalateAlert(String alertId, AlertLevel newLevel) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<AlertConfigModel> getAlertConfig(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return AlertConfigModel.defaultConfig(userId);
  }

  @override
  Future<void> updateAlertConfig(AlertConfigModel config) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Stream<AlertModel> alertUpdates(String tripId) {
    return const Stream.empty();
  }
}

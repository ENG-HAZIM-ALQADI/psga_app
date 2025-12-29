import '../models/alert_model.dart';
import '../models/alert_config_model.dart';
import '../../domain/entities/alert_entity.dart';

abstract class AlertLocalDataSource {
  Future<AlertModel> createAlert(AlertModel alert);
  Future<void> updateAlert(AlertModel alert);
  Future<AlertModel?> getActiveAlert(String tripId);
  Future<List<AlertModel>> getAlertHistory(String userId, {int? limit});
  Future<void> acknowledgeAlert(String alertId);
  Future<void> escalateAlert(String alertId, AlertLevel newLevel);
  Future<AlertConfigModel> getAlertConfig(String userId);
  Future<void> updateAlertConfig(AlertConfigModel config);
}

class MockAlertLocalDataSource implements AlertLocalDataSource {
  final List<AlertModel> _alerts = [];
  final Map<String, AlertConfigModel> _configs = {};

  @override
  Future<AlertModel> createAlert(AlertModel alert) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _alerts.add(alert);
    return alert;
  }

  @override
  Future<void> updateAlert(AlertModel alert) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final index = _alerts.indexWhere((a) => a.id == alert.id);
    if (index != -1) {
      _alerts[index] = alert;
    }
  }

  @override
  Future<AlertModel?> getActiveAlert(String tripId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return _alerts.firstWhere(
        (a) => a.tripId == tripId && a.isActive,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<AlertModel>> getAlertHistory(String userId, {int? limit}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    var alerts = _alerts.where((a) => a.userId == userId).toList();
    alerts.sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
    if (limit != null && alerts.length > limit) {
      alerts = alerts.take(limit).toList();
    }
    return alerts;
  }

  @override
  Future<void> acknowledgeAlert(String alertId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final index = _alerts.indexWhere((a) => a.id == alertId);
    if (index != -1) {
      final alert = _alerts[index];
      _alerts[index] = AlertModel(
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
    final index = _alerts.indexWhere((a) => a.id == alertId);
    if (index != -1) {
      final alert = _alerts[index];
      _alerts[index] = AlertModel(
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
    return _configs[userId] ?? AlertConfigModel.defaultConfig(userId);
  }

  @override
  Future<void> updateAlertConfig(AlertConfigModel config) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _configs[config.userId] = config;
  }
}

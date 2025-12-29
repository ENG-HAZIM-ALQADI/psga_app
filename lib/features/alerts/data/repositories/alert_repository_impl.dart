import 'package:dartz/dartz.dart';
import '../../../../config/app_config.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/services/sync/sync_manager.dart';
import '../../../../core/services/sync/sync_item.dart';
import '../../domain/entities/alert_entity.dart';
import '../../domain/entities/alert_config_entity.dart';
import '../../domain/repositories/alert_repository.dart';
import '../datasources/alert_local_datasource.dart';
import '../datasources/alert_remote_datasource.dart';
import '../models/alert_model.dart';
import '../models/alert_config_model.dart';

/// Repository للتنبيهات - يدير البيانات المحلية والبعيدة
/// - يحفظ محلياً أولاً (Hive)
/// - يضيف إلى قائمة المزامنة
/// - يُزامن مع Firebase تلقائياً
class AlertRepositoryImpl implements AlertRepository {
  final AlertLocalDataSource localDataSource;
  final AlertRemoteDataSource remoteDataSource;
  late final bool useMock;
  final SyncManager _syncManager = SyncManager.instance;

  AlertRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    bool? useMock,
  }) {
    this.useMock = useMock ?? AppConfig.enableFirebase == false;
  }

  @override
  Future<Either<Failure, AlertEntity>> createAlert(AlertEntity alert) async {
    try {
      final alertModel = AlertModel.fromEntity(alert);
      
      if (useMock) {
        final result = await localDataSource.createAlert(alertModel);
        
        final syncItem = SyncItem(
        createdAt: DateTime.now(),
          id: alert.id,
          type: SyncItemType.alert,
          action: SyncAction.create,
          data: alertModel.toJson(),
          localId: alert.id,
        );
        await _syncManager.addToQueue(syncItem);
        
        AppLogger.info('[AlertRepo] تم إنشاء التنبيه: ${alert.id}');
        return Right(result);
      } else {
        final result = await remoteDataSource.createAlert(alertModel);
        await localDataSource.createAlert(alertModel);
        
        final syncItem = SyncItem(
        createdAt: DateTime.now(),
          id: alert.id,
          type: SyncItemType.alert,
          action: SyncAction.create,
          data: alertModel.toJson(),
          localId: alert.id,
        );
        await _syncManager.addToQueue(syncItem);
        
        return Right(result);
      }
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'فشل في إنشاء التنبيه: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateAlert(AlertEntity alert) async {
    try {
      final alertModel = AlertModel.fromEntity(alert);
      
      if (useMock) {
        await localDataSource.updateAlert(alertModel);
      } else {
        await remoteDataSource.updateAlert(alertModel);
        await localDataSource.updateAlert(alertModel);
      }
      
      final syncItem = SyncItem(
        createdAt: DateTime.now(),
        id: alert.id,
        type: SyncItemType.alert,
        action: SyncAction.update,
        data: alertModel.toJson(),
        localId: alert.id,
      );
      await _syncManager.addToQueue(syncItem);
      
      AppLogger.info('[AlertRepo] تم تحديث التنبيه: ${alert.id}');
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'فشل في تحديث التنبيه: $e'));
    }
  }

  @override
  Future<Either<Failure, AlertEntity?>> getActiveAlert(String tripId) async {
    try {
      final alert = useMock
          ? await localDataSource.getActiveAlert(tripId)
          : await remoteDataSource.getActiveAlert(tripId);
      return Right(alert);
    } catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب التنبيه النشط: $e'));
    }
  }

  @override
  Future<Either<Failure, List<AlertEntity>>> getAlertHistory(
    String userId, {
    int? limit,
    AlertType? typeFilter,
    AlertStatus? statusFilter,
  }) async {
    try {
      // ✅ نمط Offline-First: جلب محلي أولاً
      var alerts = await localDataSource.getAlertHistory(userId, limit: limit);
      
      // إذا كانت القائمة فارغة، جلب من Firebase وحفظ محلياً
      if (alerts.isEmpty && !useMock) {
        AppLogger.info('[AlertRepo] 📥 جلب التنبيهات من Firebase...');
        alerts = await remoteDataSource.getAlertHistory(userId, limit: limit);
        
        // ✅ حفظ البيانات المجلوبة محلياً
        for (var alert in alerts) {
          final alertModel = AlertModel.fromEntity(alert);
          await localDataSource.createAlert(alertModel);
          AppLogger.info('[AlertRepo] 💾 تم حفظ تنبيه: ${alert.id}');
        }
        AppLogger.success('[AlertRepo] ✅ تم حفظ ${alerts.length} تنبيه محلياً');
      }

      if (typeFilter != null) {
        alerts = alerts.where((a) => a.type == typeFilter).toList();
      }
      if (statusFilter != null) {
        alerts = alerts.where((a) => a.status == statusFilter).toList();
      }

      AppLogger.info('[AlertRepo] تم جلب ${alerts.length} تنبيه');
      return Right(alerts);
    } catch (e) {
      AppLogger.error('[AlertRepo] ❌ خطأ في جلب سجل التنبيهات: $e');
      return Left(ServerFailure(message: 'فشل في جلب سجل التنبيهات: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> acknowledgeAlert(String alertId) async {
    try {
      if (useMock) {
        await localDataSource.acknowledgeAlert(alertId);
      } else {
        await remoteDataSource.acknowledgeAlert(alertId);
        await localDataSource.acknowledgeAlert(alertId);
      }
      
      AppLogger.success('[AlertRepo] تم إلغاء التنبيه: $alertId');
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'فشل في إلغاء التنبيه: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> escalateAlert(String alertId, AlertLevel newLevel) async {
    try {
      if (useMock) {
        await localDataSource.escalateAlert(alertId, newLevel);
      } else {
        await remoteDataSource.escalateAlert(alertId, newLevel);
        await localDataSource.escalateAlert(alertId, newLevel);
      }
      
      AppLogger.warning('[AlertRepo] تم تصعيد التنبيه إلى: ${newLevel.name}');
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'فشل في تصعيد التنبيه: $e'));
    }
  }

  @override
  Future<Either<Failure, AlertConfigEntity>> getAlertConfig(String userId) async {
    try {
      final config = useMock
          ? await localDataSource.getAlertConfig(userId)
          : await remoteDataSource.getAlertConfig(userId);
      return Right(config);
    } catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب إعدادات التنبيهات: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateAlertConfig(AlertConfigEntity config) async {
    try {
      final configModel = AlertConfigModel.fromEntity(config);
      
      if (useMock) {
        await localDataSource.updateAlertConfig(configModel);
      } else {
        await remoteDataSource.updateAlertConfig(configModel);
        await localDataSource.updateAlertConfig(configModel);
      }
      
      AppLogger.info('[AlertRepo] تم تحديث إعدادات التنبيهات');
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'فشل في تحديث الإعدادات: $e'));
    }
  }

  @override
  Stream<AlertEntity> alertUpdates(String tripId) {
    if (useMock) {
      return const Stream.empty();
    }
    return remoteDataSource.alertUpdates(tripId);
  }
}

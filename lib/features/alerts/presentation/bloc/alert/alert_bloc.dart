import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/services/alert_escalation_service.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';
import 'package:psga_app/features/alerts/domain/usecases/acknowledge_alert_usecase.dart';
import 'package:psga_app/features/alerts/domain/usecases/get_active_alerts_usecase.dart';
import 'package:psga_app/features/alerts/domain/usecases/get_alert_config_usecase.dart';
import 'package:psga_app/features/alerts/domain/usecases/get_contacts_usecase.dart';
import 'package:psga_app/features/alerts/domain/usecases/save_alert_config_usecase.dart';
import 'package:psga_app/features/alerts/domain/usecases/send_sos_usecase.dart';
import 'package:psga_app/features/alerts/domain/usecases/trigger_alert_usecase.dart';
import 'package:psga_app/features/alerts/presentation/bloc/alert/alert_event.dart';
import 'package:psga_app/features/alerts/presentation/bloc/alert/alert_state.dart';

class AlertBloc extends Bloc<AlertEvent, AlertState> {
  final TriggerAlertUseCase triggerAlertUseCase;
  final SendSOSUseCase sendSOSUseCase;
  final AcknowledgeAlertUseCase acknowledgeAlertUseCase;
  final GetActiveAlertsUseCase getActiveAlertsUseCase;
  final GetAlertConfigUseCase getAlertConfigUseCase;
  final SaveAlertConfigUseCase saveAlertConfigUseCase;
  final GetContactsUseCase getContactsUseCase;
  final AlertEscalationService escalationService;

  AlertBloc({
    required this.triggerAlertUseCase,
    required this.sendSOSUseCase,
    required this.acknowledgeAlertUseCase,
    required this.getActiveAlertsUseCase,
    required this.getAlertConfigUseCase,
    required this.saveAlertConfigUseCase,
    required this.getContactsUseCase,
    AlertEscalationService? escalationService,
  })  : escalationService = escalationService ?? AlertEscalationService.instance,
        super(AlertInitial()) {
    on<TriggerAlertEvent>(_onTriggerAlert);
    on<SendSOSEvent>(_onSendSOS);
    on<AcknowledgeAlertEvent>(_onAcknowledgeAlert);
    on<LoadActiveAlertsEvent>(_onLoadActiveAlerts);
    on<StartEscalationEvent>(_onStartEscalation);
    on<CancelEscalationEvent>(_onCancelEscalation);
    on<SendImmediateSOSEvent>(_onSendImmediateSOS);
    on<EscalationCountdownTickEvent>(_onEscalationCountdownTick);
    on<SaveAlertConfigEvent>(_onSaveAlertConfig);
    on<LoadAlertConfigEvent>(_onLoadAlertConfig);
  }

  Future<void> _onTriggerAlert(
    TriggerAlertEvent event,
    Emitter<AlertState> emit,
  ) async {
    try {
      emit(AlertLoading());

      final result = await triggerAlertUseCase(TriggerAlertParams(
        userId: event.userId,
        type: event.type,
        title: event.title,
        message: event.message,
        severity: event.severity,
        tripId: event.tripId,
        location: event.location,
        metadata: event.metadata,
      ));

      result.fold(
        (failure) => emit(AlertError(failure.message)),
        (alert) => emit(AlertTriggered(alert)),
      );
    } catch (e, stackTrace) {
      AppLogger.error('[AlertBloc] خطأ في إطلاق التنبيه', e, stackTrace);
      emit(const AlertError('alertTriggerFailed'));
    }
  }

  Future<void> _onSendSOS(
    SendSOSEvent event,
    Emitter<AlertState> emit,
  ) async {
    try {
      emit(AlertLoading());

      final result = await sendSOSUseCase(SendSOSParams(
        userId: event.userId,
        location: event.location,
        message: event.message,
      ));

      result.fold(
        (failure) => emit(AlertError(failure.message)),
        (alert) => emit(SOSSent(alert)),
      );
    } catch (e, stackTrace) {
      AppLogger.error('[AlertBloc] خطأ في SOS', e, stackTrace);
      emit(const AlertError('sosSendFailed'));
    }
  }

  Future<void> _onAcknowledgeAlert(
    AcknowledgeAlertEvent event,
    Emitter<AlertState> emit,
  ) async {
    try {
      final result = await acknowledgeAlertUseCase(AcknowledgeAlertParams(
        alertId: event.alertId,
        userId: event.userId,
      ));

      result.fold(
        (failure) => emit(AlertError(failure.message)),
        (alert) => emit(AlertAcknowledged(alert)),
      );
    } catch (e, stackTrace) {
      AppLogger.error('[AlertBloc] خطأ في الإقرار', e, stackTrace);
      emit(const AlertError('alertAcknowledgeFailed'));
    }
  }

  Future<void> _onLoadActiveAlerts(
    LoadActiveAlertsEvent event,
    Emitter<AlertState> emit,
  ) async {
    try {
      emit(AlertLoading());

      final result = await getActiveAlertsUseCase(event.userId);

      result.fold(
        (failure) => emit(AlertError(failure.message)),
        (alerts) => emit(ActiveAlertsLoaded(alerts)),
      );
    } catch (e, stackTrace) {
      AppLogger.error('[AlertBloc] خطأ في جلب التنبيهات', e, stackTrace);
      emit(const AlertError('alertLoadFailed'));
    }
  }

  // ==================== Escalation Handlers ====================

  Future<void> _onStartEscalation(
    StartEscalationEvent event,
    Emitter<AlertState> emit,
  ) async {
    try {
      AppLogger.info('[AlertBloc] بدء التصعيد: ${event.alert.id}');

      // جلب الإعدادات والجهات
      final configResult = await getAlertConfigUseCase(event.userId);
      final contactsResult = await getContactsUseCase(GetContactsParams(userId: event.userId));

      await configResult.fold(
        (failure) async => emit(AlertError(failure.message)),
        (config) async {
          await contactsResult.fold(
            (failure) async => emit(AlertError(failure.message)),
            (contacts) async {
              final totalSeconds = config.countdownDuration.inSeconds;

              // بدء التصعيد
              await escalationService.startEscalation(
                alert: event.alert,
                config: config,
                contacts: contacts,
                onEscalation: (level) {
                  AppLogger.info('[AlertBloc] تصعيد للمستوى: $level');
                },
                onCountdownTick: (remaining) {
                  // إرسال tick event للـ UI
                  add(EscalationCountdownTickEvent(
                    alertId: event.alert.id,
                    remainingSeconds: remaining,
                  ));
                },
                onCancelled: () {
                  AppLogger.info('[AlertBloc] تم الإلغاء');
                },
              );

              emit(EscalationInProgress(
                alert: event.alert,
                remainingSeconds: totalSeconds,
                totalSeconds: totalSeconds,
              ));
            },
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[AlertBloc] خطأ في بدء التصعيد', e, stackTrace);
      emit(const AlertError('escalationStartFailed'));
    }
  }

  Future<void> _onCancelEscalation(
    CancelEscalationEvent event,
    Emitter<AlertState> emit,
  ) async {
    try {
      AppLogger.info('[AlertBloc] إلغاء التصعيد: ${event.alertId}');

      escalationService.cancelEscalation(event.alertId);

      // تحديث حالة التنبيه
      final result = await acknowledgeAlertUseCase(AcknowledgeAlertParams(
        alertId: event.alertId,
        userId: event.userId,
      ));

      result.fold(
        (failure) => emit(AlertError(failure.message)),
        (alert) => emit(EscalationCancelled(
          alertId: event.alertId,
          userId: event.userId,
        )),
      );
    } catch (e, stackTrace) {
      AppLogger.error('[AlertBloc] خطأ في إلغاء التصعيد', e, stackTrace);
      emit(const AlertError('escalationCancelFailed'));
    }
  }

  Future<void> _onSendImmediateSOS(
    SendImmediateSOSEvent event,
    Emitter<AlertState> emit,
  ) async {
    try {
      AppLogger.info('[AlertBloc] إرسال SOS فوري');

      emit(AlertLoading());

      // إنشاء تنبيه SOS
      final alertResult = await triggerAlertUseCase(TriggerAlertParams(
        userId: event.userId,
        type: AlertType.sos,
        title: '🚨 طوارئ SOS',
        message: event.message ?? 'تنبيه طوارئ SOS',
        severity: AlertSeverity.critical,
        location: event.location,
      ));

      await alertResult.fold(
        (failure) async => emit(AlertError(failure.message)),
        (alert) async {
          // جلب الإعدادات والجهات
          final configResult = await getAlertConfigUseCase(event.userId);
          final contactsResult = await getContactsUseCase(GetContactsParams(userId: event.userId));

          await configResult.fold(
            (failure) async => emit(AlertError(failure.message)),
            (config) async {
              await contactsResult.fold(
                (failure) async => emit(AlertError(failure.message)),
                (contacts) async {
                  // إرسال SOS فوري
                  final results = await escalationService.sendImmediateSOS(
                    alert: alert,
                    contacts: contacts,
                    config: config,
                  );

                  emit(ImmediateSOSSent(
                    alert: alert,
                    results: results,
                  ));
                },
              );
            },
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[AlertBloc] خطأ في SOS فوري', e, stackTrace);
      emit(const AlertError('sosSendFailed'));
    }
  }

  void _onEscalationCountdownTick(
    EscalationCountdownTickEvent event,
    Emitter<AlertState> emit,
  ) {
    // تحديث حالة العد التنازلي في الـ UI
    if (state is EscalationInProgress) {
      final currentState = state as EscalationInProgress;
      emit(EscalationInProgress(
        alert: currentState.alert,
        remainingSeconds: event.remainingSeconds,
        totalSeconds: currentState.totalSeconds,
      ));
    }
  }

  Future<void> _onSaveAlertConfig(
    SaveAlertConfigEvent event,
    Emitter<AlertState> emit,
  ) async {
    try {
      AppLogger.info('[AlertBloc] حفظ إعدادات التنبيهات');

      emit(AlertLoading());

      final result = await saveAlertConfigUseCase(
        SaveAlertConfigParams(config: event.config),
      );

      result.fold(
        (failure) {
          AppLogger.error('[AlertBloc] فشل حفظ الإعدادات', failure.message);
          emit(AlertError(failure.message));
        },
        (config) {
          AppLogger.success('[AlertBloc] تم حفظ الإعدادات');
          emit(AlertConfigSaved(config));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[AlertBloc] خطأ في حفظ الإعدادات', e, stackTrace);
      emit(const AlertError('alertSettingsSaveFailed'));
    }
  }

  Future<void> _onLoadAlertConfig(
    LoadAlertConfigEvent event,
    Emitter<AlertState> emit,
  ) async {
    try {
      AppLogger.info('[AlertBloc] تحميل إعدادات التنبيهات للمستخدم: ${event.userId}');

      emit(AlertLoading());

      final result = await getAlertConfigUseCase(event.userId);

      result.fold(
        (failure) {
          AppLogger.error('[AlertBloc] فشل تحميل الإعدادات', failure.message);
          emit(AlertError(failure.message));
        },
        (config) {
          AppLogger.success('[AlertBloc] تم تحميل الإعدادات بنجاح');
          emit(AlertConfigLoaded(config));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[AlertBloc] خطأ في تحميل الإعدادات', e, stackTrace);
      emit(const AlertError('alertSettingsLoadFailed'));
    }
  }
}


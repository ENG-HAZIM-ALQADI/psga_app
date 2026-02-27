import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';
import 'package:psga_app/features/trips/domain/usecases/end_trip_usecase.dart';
import 'package:psga_app/features/trips/domain/usecases/get_active_trip_usecase.dart';
import 'package:psga_app/features/trips/domain/usecases/get_trip_details_usecase.dart';
import 'package:psga_app/features/trips/domain/usecases/get_trip_history_usecase.dart';
import 'package:psga_app/features/trips/domain/usecases/pause_trip_usecase.dart';
import 'package:psga_app/features/trips/domain/usecases/resume_trip_usecase.dart';
import 'package:psga_app/features/trips/domain/usecases/start_trip_usecase.dart';
import 'package:psga_app/features/trips/domain/usecases/update_location_usecase.dart';
import 'package:psga_app/features/trips/presentation/bloc/trip_event.dart';
import 'package:psga_app/features/trips/presentation/bloc/trip_state.dart';
// Alerts Integration
import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';
import 'package:psga_app/features/alerts/domain/entities/contact_entity.dart';
import 'package:psga_app/features/alerts/domain/usecases/trigger_alert_usecase.dart';
import 'package:psga_app/features/alerts/domain/usecases/get_contacts_usecase.dart';
import 'package:psga_app/features/alerts/domain/usecases/get_alert_config_usecase.dart';
import 'package:psga_app/core/services/alert_escalation_service.dart';
import 'package:psga_app/features/trips/domain/entities/deviation.dart';
import 'package:psga_app/core/services/notification_service.dart';
import 'package:psga_app/core/services/sms_service.dart';
import 'package:psga_app/injection_container.dart' as di;
// Maps & Tracking Integration
import 'package:psga_app/core/services/location_service.dart';
import 'package:psga_app/core/services/location_history_service.dart';
import 'package:psga_app/core/services/periodic_deviation_checker.dart';
import 'package:psga_app/core/services/deviation_detector.dart';
import 'package:psga_app/core/services/geocoding_service.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/features/routes/domain/entities/waypoint.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart';
import 'package:psga_app/core/errors/failures.dart';
// Auth Integration - لجلب معلومات المستخدم
import 'package:psga_app/features/auth/domain/usecases/get_current_user_usecase.dart';
/// BLoC لإدارة الرحلات
class TripBloc extends Bloc<TripEvent, TripState> {
  final StartTripUseCase startTripUseCase;
  final EndTripUseCase endTripUseCase;
  final PauseTripUseCase pauseTripUseCase;
  final ResumeTripUseCase resumeTripUseCase;
  final UpdateLocationUseCase updateLocationUseCase;
  final GetActiveTripUseCase getActiveTripUseCase;
  final GetTripHistoryUseCase getTripHistoryUseCase;
  final GetTripDetailsUseCase getTripDetailsUseCase;
  // Alerts Integration (optional)
  final TriggerAlertUseCase? triggerAlertUseCase;
  final GetContactsUseCase? getContactsUseCase;
  final GetAlertConfigUseCase? getAlertConfigUseCase;
  final AlertEscalationService escalationService;
  
  // Repository للوصول للـ helper methods
  final dynamic tripsRepository;
  
  // Maps & Tracking Integration
  final LocationService _locationService;
  final LocationHistoryService _historyService;
  final PeriodicDeviationChecker _deviationChecker;
  StreamSubscription<Location>? _locationSubscription;
  Timer? _statsUpdateTimer;

  TripBloc({
    required this.startTripUseCase,
    required this.endTripUseCase,
    required this.pauseTripUseCase,
    required this.resumeTripUseCase,
    required this.updateLocationUseCase,
    required this.getActiveTripUseCase,
    required this.getTripHistoryUseCase,
    required this.getTripDetailsUseCase,
    this.triggerAlertUseCase,
    this.getContactsUseCase,
    this.getAlertConfigUseCase,
    this.tripsRepository,
    AlertEscalationService? escalationService,
    LocationService? locationService,
    LocationHistoryService? historyService,
    PeriodicDeviationChecker? deviationChecker,
  })  : escalationService = escalationService ?? AlertEscalationService.instance,
        _locationService = locationService ?? LocationService.instance,
        _historyService = historyService ?? LocationHistoryService.instance,
        _deviationChecker = deviationChecker ?? PeriodicDeviationChecker.instance,
        super(const TripInitial()) {
    on<StartTripEvent>(_onStartTrip);
    on<EndTripEvent>(_onEndTrip);
    on<PauseTripEvent>(_onPauseTrip);
    on<ResumeTripEvent>(_onResumeTrip);
    on<CancelTripEvent>(_onCancelTrip);
    on<UpdateLocationEvent>(_onUpdateLocation);
    on<LoadActiveTripEvent>(_onLoadActiveTrip);
    on<LoadTripHistoryEvent>(_onLoadTripHistory);
    on<LoadTripDetailsEvent>(_onLoadTripDetails);
    on<RefreshActiveTripEvent>(_onRefreshActiveTrip);
    on<DeleteTripEvent>(_onDeleteTrip);
    on<ClearAllTripsEvent>(_onClearAllTrips); // ✅ مسح جميع الرحلات
    on<UpdateWaypointProgressEvent>(_onUpdateWaypointProgress);
    on<AddDeviationEvent>(_onAddDeviation);
    on<ResolveCurrentDeviationEvent>(_onResolveCurrentDeviation);
    // Event Handlers الجديدة
    on<StartAutoTrackingEvent>(_onStartAutoTracking);
    on<StopAutoTrackingEvent>(_onStopAutoTracking);
    on<UpdateTripStatsEvent>(_onUpdateTripStats);
    on<CheckDeviationEvent>(_onCheckDeviation);
    on<DismissDeviationAlertEvent>(_onDismissDeviationAlert);
    on<TriggerSOSEvent>(_onTriggerSOS);
    on<StartDeviationCountdownEvent>(_onStartDeviationCountdown);
    on<CancelDeviationCountdownEvent>(_onCancelDeviationCountdown);
    on<ValidateUserLocationEvent>(_onValidateUserLocation);
    on<StartTripFromCurrentLocationEvent>(_onStartTripFromCurrentLocation);
  }

  /// بدء رحلة جديدة
  Future<void> _onStartTrip(
    StartTripEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      AppLogger.info('[TripBloc] بدء رحلة جديدة');
      emit(const TripLoading());

      // تحميل وتطبيق إعدادات الرحلات
      await _loadAndApplyTripSettings(event.userId);

      final result = await startTripUseCase(
        StartTripParams(
          userId: event.userId,
          routeId: event.routeId,
          forceEndActiveTrip: event.forceEndActiveTrip,
        ),
      );

      await result.fold(
        (failure) async {
          AppLogger.error('[TripBloc] فشل بدء الرحلة: ${failure.message}');
          
          // معالجة خاصة للرحلة النشطة
          if (failure is ActiveTripExistsFailure) {
            emit(TripActiveTripExists(
              message: failure.message,
              activeTripId: failure.activeTripId,
              routeId: event.routeId,
            ));
          } else {
            emit(TripError(message: failure.message));
          }
        },
        (trip) async {
          AppLogger.success('[TripBloc] تم بدء الرحلة: ${trip.id}');
          
          // بدء تتبع الموقع في الخلفية
          final trackingStarted = await _locationService.startTracking(
            mode: LocationTrackingMode.background,
            distanceFilter: 10,
            intervalSeconds: 5,
            accuracy: LocationAccuracy.high,
          );
          
          if (!trackingStarted) {
            AppLogger.error('[TripBloc] فشل بدء تتبع الموقع');
            emit(const TripError(message: 'locationTrackingFailed'));
            return;
          }

          // الاستماع لتحديثات الموقع
          _locationSubscription = _locationService.locationStream.listen(
            (location) {
              // حفظ الموقع في التاريخ
              _historyService.saveLocation(
                tripId: trip.id,
                location: location,
              );
              
              // تحديث موقع الرحلة
              add(UpdateLocationEvent(
                tripId: trip.id,
                location: location,
              ));
            },
            onError: (error) {
              AppLogger.error('[TripBloc] خطأ في stream الموقع', error);
            },
          );

          // بدء الفحص الدوري للانحراف
          _deviationChecker.startChecking(
            route: trip.route,
            locationStream: _locationService.locationStream,
            onDeviation: (deviation) async {
              AppLogger.warning('[TripBloc] تم كشف انحراف: ${deviation.severity.name}');
              
              // إطلاق تنبيه للانحرافات العالية والحرجة
              if (deviation.severity == DeviationSeverity.high ||
                  deviation.severity == DeviationSeverity.critical) {
                await _triggerDeviationAlertWithEscalation(
                  tripId: trip.id,
                  userId: trip.userId,
                  deviation: deviation,
                );
              }
            },
            onResolved: (deviation) {
              AppLogger.info('[TripBloc] تم حل الانحراف');
            },
            onSeverityChange: (oldSeverity, newSeverity) {
              AppLogger.warning('[TripBloc] تغيرت شدة الانحراف: ${oldSeverity.name} → ${newSeverity.name}');
            },
          );

          // بدء Timer لتحديث الإحصائيات كل 10 ثوان
          _statsUpdateTimer = Timer.periodic(
            const Duration(seconds: 10),
            (_) => add(const UpdateTripStatsEvent()),
          );
          AppLogger.info('[TripBloc] تم بدء Timer الإحصائيات (كل 10 ثوان)');

          emit(TripActive(trip: trip));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في بدء الرحلة', e, stackTrace);
      emit(const TripError(message: 'unexpectedError'));
    }
  }

  /// إنهاء رحلة
  Future<void> _onEndTrip(
    EndTripEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      AppLogger.info('[TripBloc] إنهاء رحلة: ${event.tripId}');
      emit(const TripLoading());

      // إيقاف جميع الخدمات
      await _stopTrackingServices();

      final result = await endTripUseCase(
        EndTripParams(tripId: event.tripId),
      );

      result.fold(
        (failure) {
          AppLogger.error('[TripBloc] فشل إنهاء الرحلة: ${failure.message}');
          emit(TripError(message: failure.message));
        },
        (trip) {
          AppLogger.success('[TripBloc] تم إنهاء الرحلة');
          emit(TripCompleted(trip: trip));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في إنهاء الرحلة', e, stackTrace);
      emit(const TripError(message: 'unexpectedError'));
    }
  }

  /// إيقاف رحلة مؤقتاً
  Future<void> _onPauseTrip(
    PauseTripEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      AppLogger.info('[TripBloc] إيقاف رحلة: ${event.tripId}');

      // إيقاف الفحص الدوري فقط (الموقع يستمر)
      _deviationChecker.stopChecking();

      final result = await pauseTripUseCase(
        PauseTripParams(tripId: event.tripId),
      );

      result.fold(
        (failure) {
          AppLogger.error('[TripBloc] فشل إيقاف الرحلة: ${failure.message}');
          emit(TripError(message: failure.message));
        },
        (trip) {
          AppLogger.success('[TripBloc] تم إيقاف الرحلة');
          emit(TripPaused(trip: trip));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في إيقاف الرحلة', e, stackTrace);
      emit(const TripError(message: 'unexpectedError'));
    }
  }

  /// استئناف رحلة
  Future<void> _onResumeTrip(
    ResumeTripEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      AppLogger.info('[TripBloc] استئناف رحلة: ${event.tripId}');

      final result = await resumeTripUseCase(
        ResumeTripParams(tripId: event.tripId),
      );

      await result.fold(
        (failure) async {
          AppLogger.error('[TripBloc] فشل استئناف الرحلة: ${failure.message}');
          emit(TripError(message: failure.message));
        },
        (trip) async {
          AppLogger.success('[TripBloc] تم استئناف الرحلة');
          
          // إعادة بدء الفحص الدوري
          _deviationChecker.startChecking(
            route: trip.route,
            locationStream: _locationService.locationStream,
            onDeviation: (deviation) {
              if (deviation.severity == DeviationSeverity.critical) {
                _triggerDeviationAlert(
                  tripId: trip.id,
                  userId: trip.userId,
                  deviation: deviation,
                );
              }
            },
          );
          
          emit(TripActive(trip: trip));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في استئناف الرحلة', e, stackTrace);
      emit(const TripError(message: 'unexpectedError'));
    }
  }

  /// تحديث موقع الرحلة
  Future<void> _onUpdateLocation(
    UpdateLocationEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      final result = await updateLocationUseCase(
        UpdateLocationParams(
          tripId: event.tripId,
          location: event.location,
        ),
      );

      await result.fold(
        (failure) async {
          AppLogger.error('[TripBloc] فشل تحديث الموقع: ${failure.message}');
          // لا نُصدر خطأ هنا لتجنب قطع الرحلة
        },
        (trip) async {
          // التحقق من الانحرافات وإطلاق تنبيه إذا لزم
          if (trip.currentDeviation != null) {
            await _checkAndTriggerDeviationAlert(
              tripId: trip.id,
              userId: trip.userId,
              deviation: trip.currentDeviation!,
              location: event.location,
            );
          }

          // تحديث الحالة بناءً على حالة الرحلة
          if (trip.isActive) {
            emit(TripActive(trip: trip));
          } else if (trip.isPaused) {
            emit(TripPaused(trip: trip));
          }
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في تحديث الموقع', e, stackTrace);
    }
  }

  /// تحميل الرحلة النشطة
  Future<void> _onLoadActiveTrip(
    LoadActiveTripEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      AppLogger.info('[TripBloc] تحميل الرحلة النشطة');
      
      // ✅ إذا كانت الرحلة نشطة بالفعل → لا نُصدر TripLoading (يسبب rebuild للخريطة)
      final currentState = state;
      final isAlreadyActive = currentState is TripActive;
      
      if (!isAlreadyActive) {
        emit(const TripLoading());
      }

      final result = await getActiveTripUseCase(
        GetActiveTripParams(userId: event.userId),
      );

      result.fold(
        (failure) {
          AppLogger.error('[TripBloc] فشل تحميل الرحلة: ${failure.message}');
          emit(TripError(message: failure.message));
        },
        (trip) {
          if (trip == null) {
            AppLogger.info('[TripBloc] لا توجد رحلة نشطة');
            emit(const NoActiveTrip());
          } else {
            AppLogger.success('[TripBloc] تم تحميل الرحلة النشطة');
            if (trip.isActive) {
              emit(TripActive(trip: trip));
            } else if (trip.isPaused) {
              emit(TripPaused(trip: trip));
            }
          }
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في تحميل الرحلة', e, stackTrace);
      emit(const TripError(message: 'unexpectedError'));
    }
  }

  /// تحميل سجل الرحلات
  Future<void> _onLoadTripHistory(
    LoadTripHistoryEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      AppLogger.info('[TripBloc] تحميل سجل الرحلات');
      emit(const TripLoading());

      final result = await getTripHistoryUseCase(
        GetTripHistoryParams(
          userId: event.userId,
          limit: event.limit,
          startDate: event.startDate,
          endDate: event.endDate,
        ),
      );

      result.fold(
        (failure) {
          AppLogger.error('[TripBloc] فشل تحميل السجل: ${failure.message}');
          emit(TripError(message: failure.message));
        },
        (trips) {
          AppLogger.success('[TripBloc] تم تحميل ${trips.length} رحلة');
          emit(TripHistoryLoaded(
            trips: trips,
            totalCount: trips.length,
          ));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في تحميل السجل', e, stackTrace);
      emit(const TripError(message: 'unexpectedError'));
    }
  }

  /// تحميل تفاصيل رحلة
  Future<void> _onLoadTripDetails(
    LoadTripDetailsEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      AppLogger.info('[TripBloc] تحميل تفاصيل رحلة: ${event.tripId}');
      emit(const TripLoading());

      final result = await getTripDetailsUseCase(
        GetTripDetailsParams(tripId: event.tripId),
      );

      result.fold(
        (failure) {
          AppLogger.error('[TripBloc] فشل تحميل التفاصيل: ${failure.message}');
          emit(TripError(message: failure.message));
        },
        (trip) {
          AppLogger.success('[TripBloc] تم تحميل التفاصيل');
          emit(TripDetailsLoaded(trip: trip));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في تحميل التفاصيل', e, stackTrace);
      emit(const TripError(message: 'unexpectedError'));
    }
  }

  /// تحديث الرحلة النشطة
  Future<void> _onRefreshActiveTrip(
    RefreshActiveTripEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      final result = await getActiveTripUseCase(
        GetActiveTripParams(userId: event.userId),
      );

      result.fold(
        (failure) => null, // تجاهل الأخطاء في التحديث
        (trip) {
          if (trip != null) {
            if (trip.isActive) {
              emit(TripActive(trip: trip));
            } else if (trip.isPaused) {
              emit(TripPaused(trip: trip));
            }
          }
        },
      );
    } catch (e) {
      // تجاهل الأخطاء في التحديث
    }
  }

  /// إلغاء رحلة
  Future<void> _onCancelTrip(
    CancelTripEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      AppLogger.info('[TripBloc] إلغاء رحلة: ${event.tripId}');
      emit(const TripLoading());

      // إيقاف جميع الخدمات
      await _stopTrackingServices();

      // لا يوجد cancelTrip UseCase لذا سنستخدم endTrip
      final result = await endTripUseCase(
        EndTripParams(tripId: event.tripId),
      );

      result.fold(
        (failure) {
          AppLogger.error('[TripBloc] فشل إلغاء الرحلة: ${failure.message}');
          emit(TripError(message: failure.message));
        },
        (trip) {
          AppLogger.success('[TripBloc] تم إلغاء الرحلة');
          emit(TripOperationSuccess(
            message: 'تم إلغاء الرحلة بنجاح',
            trip: trip,
          ));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في إلغاء الرحلة', e, stackTrace);
      emit(const TripError(message: 'unexpectedError'));
    }
  }

  /// حذف رحلة
  Future<void> _onDeleteTrip(
    DeleteTripEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      AppLogger.info('[TripBloc] حذف رحلة: ${event.tripId}');

      if (tripsRepository == null) {
        emit(const TripError(message: 'systemError'));
        return;
      }

      final result = await tripsRepository!.deleteTrip(event.tripId);
      
      result.fold(
        (failure) {
          AppLogger.error('[TripBloc] فشل حذف الرحلة', failure);
          emit(TripError(message: failure.message));
        },
        (_) {
          AppLogger.success('[TripBloc] تم حذف الرحلة: ${event.tripId}');
          emit(TripDeleted(tripId: event.tripId));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في حذف الرحلة', e, stackTrace);
      emit(const TripError(message: 'unexpectedError'));
    }
  }

  Future<void> _onClearAllTrips(
    ClearAllTripsEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      AppLogger.info('[TripBloc] مسح جميع رحلات: ${event.userId}');

      if (tripsRepository == null) {
        emit(const TripError(message: 'systemError'));
        return;
      }

      final result = await tripsRepository!.clearAllTrips(event.userId);
      
      result.fold(
        (failure) {
          AppLogger.error('[TripBloc] فشل مسح السجل', failure);
          emit(TripError(message: failure.message));
        },
        (_) {
          AppLogger.success('[TripBloc] تم مسح جميع الرحلات');
          emit(const TripHistoryCleared());
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في مسح السجل', e, stackTrace);
      emit(const TripError(message: 'unexpectedError'));
    }
  }

  /// تحديث نقطة طريق
  Future<void> _onUpdateWaypointProgress(
    UpdateWaypointProgressEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      AppLogger.info('[TripBloc] تحديث نقطة طريق: ${event.waypointId}');

      if (tripsRepository == null) {
        AppLogger.error('[TripBloc] Repository غير متوفر');
        emit(const TripError(message: 'systemError'));
        return;
      }

      final result = await tripsRepository.updateWaypointProgress(
        tripId: event.tripId,
        waypointId: event.waypointId,
        visited: event.visited,
      );

      result.fold(
        (failure) {
          AppLogger.error('[TripBloc] فشل تحديث النقطة: ${failure.message}');
          emit(TripError(message: failure.message));
        },
        (trip) {
          AppLogger.success('[TripBloc] تم تحديث نقطة الطريق');
          emit(WaypointProgressUpdated(
            trip: trip,
            waypointId: event.waypointId,
            visited: event.visited,
          ));
          
          // تحديث الحالة الأساسية
          if (trip.isActive) {
            emit(TripActive(trip: trip));
          } else if (trip.isPaused) {
            emit(TripPaused(trip: trip));
          }
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في تحديث النقطة', e, stackTrace);
      emit(const TripError(message: 'unexpectedError'));
    }
  }

  /// إضافة انحراف
  Future<void> _onAddDeviation(
    AddDeviationEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      AppLogger.info('[TripBloc] إضافة انحراف: ${event.deviation.severity.name}');

      if (tripsRepository == null) {
        AppLogger.error('[TripBloc] Repository غير متوفر');
        return;
      }

      final result = await tripsRepository.addDeviation(
        tripId: event.tripId,
        deviation: event.deviation,
      );

      result.fold(
        (failure) {
          AppLogger.error('[TripBloc] فشل إضافة الانحراف: ${failure.message}');
          emit(TripError(message: failure.message));
        },
        (trip) {
          AppLogger.success('[TripBloc] تم إضافة الانحراف');
          
          // إطلاق تنبيه إذا كان الانحراف خطير
          if (event.deviation.severity == DeviationSeverity.high ||
              event.deviation.severity == DeviationSeverity.critical) {
            _triggerDeviationAlert(
              tripId: trip.id,
              userId: trip.userId,
              deviation: event.deviation,
            );
          }
          
          emit(DeviationAdded(
            trip: trip,
            deviation: event.deviation,
          ));
          
          // تحديث الحالة الأساسية
          if (trip.isActive) {
            emit(TripActive(trip: trip));
          } else if (trip.isPaused) {
            emit(TripPaused(trip: trip));
          }
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في إضافة الانحراف', e, stackTrace);
      emit(const TripError(message: 'unexpectedError'));
    }
  }

  /// حل الانحراف الحالي
  Future<void> _onResolveCurrentDeviation(
    ResolveCurrentDeviationEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      AppLogger.info('[TripBloc] حل الانحراف الحالي');

      if (tripsRepository == null) {
        AppLogger.error('[TripBloc] Repository غير متوفر');
        return;
      }

      final result = await tripsRepository.resolveCurrentDeviation(
        tripId: event.tripId,
      );

      result.fold(
        (failure) {
          AppLogger.error('[TripBloc] فشل حل الانحراف: ${failure.message}');
          emit(TripError(message: failure.message));
        },
        (trip) {
          AppLogger.success('[TripBloc] تم حل الانحراف');
          emit(DeviationResolved(trip: trip));
          
          // تحديث الحالة الأساسية
          if (trip.isActive) {
            emit(TripActive(trip: trip));
          } else if (trip.isPaused) {
            emit(TripPaused(trip: trip));
          }
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في حل الانحراف', e, stackTrace);
      emit(const TripError(message: 'unexpectedError'));
    }
  }

  // ========== Alerts Integration Helper Methods ==========

  /// إطلاق تنبيه انحراف مع نظام التصعيد المحسّن
  Future<void> _triggerDeviationAlertWithEscalation({
    required String tripId,
    required String userId,
    required Deviation deviation,
  }) async {
    try {
      AppLogger.info('[TripBloc] بدء تنبيه انحراف مع التصعيد');

      if (triggerAlertUseCase == null) {
        AppLogger.warning('[TripBloc] TriggerAlertUseCase غير متوفر');
        return;
      }

      // جلب اسم المستخدم الحالي
      String userName = 'مستخدم';
      try {
        final getCurrentUserUseCase = di.sl<GetCurrentUserUseCase>();
        final userResult = await getCurrentUserUseCase();
        userResult.fold(
          (failure) => AppLogger.warning('[TripBloc] فشل جلب المستخدم: ${failure.message}'),
          (user) {
            if (user != null && user.name.isNotEmpty) {
              userName = user.name;
              AppLogger.success('[TripBloc] تم جلب اسم المستخدم: $userName');
            }
          },
        );
      } catch (e) {
        AppLogger.warning('[TripBloc] خطأ في جلب اسم المستخدم: $e');
      }

      // 1. إنشاء التنبيه مع اسم المستخدم
      final alertResult = await triggerAlertUseCase!(
        TriggerAlertParams(
          userId: userId,
          type: AlertType.deviation,
          title: 'انحراف عن المسار',
          message: 'أنت على بعد ${deviation.distanceFromRoute.toStringAsFixed(0)} متر من المسار المحدد',
          severity: _convertDeviationSeverity(deviation.severity),
          tripId: tripId,
          location: deviation.deviationLocation,
          metadata: {
            'deviationType': deviation.type.toString(),
            'distance': deviation.distanceFromRoute,
            'duration': deviation.currentDuration.inSeconds,
            'userName': userName, // ✅ إضافة اسم المستخدم
          },
        ),
      );

      await alertResult.fold(
        (failure) async {
          AppLogger.error('[TripBloc] فشل إنشاء التنبيه', failure.message);
        },
        (alert) async {
          AppLogger.success('[TripBloc] تم إنشاء التنبيه: ${alert.id}');

          // 2. جلب الإعدادات والجهات
          if (getAlertConfigUseCase == null || getContactsUseCase == null) {
            AppLogger.warning('[TripBloc] UseCases غير متوفرة للتصعيد');
            return;
          }

          final configResult = await getAlertConfigUseCase!(userId);
          final contactsResult = await getContactsUseCase!(GetContactsParams(userId: userId));

          await configResult.fold(
            (failure) async {
              AppLogger.error('[TripBloc] فشل جلب الإعدادات', failure.message);
            },
            (config) async {
              await contactsResult.fold(
                (failure) async {
                  AppLogger.error('[TripBloc] فشل جلب الجهات', failure.message);
                },
                (contacts) async {
                  // 3. بدء التصعيد التلقائي
                  AppLogger.info('[TripBloc] بدء التصعيد التلقائي');
                  
                  await escalationService.startEscalation(
                    alert: alert,
                    config: config,
                    contacts: contacts,
                    onEscalation: (level) {
                      AppLogger.info('[TripBloc] تصعيد للمستوى: $level');
                    },
                    onCountdownTick: (remaining) {
                      // يمكن إضافة event هنا لتحديث UI
                      AppLogger.debug('[TripBloc] عد تنازلي: $remaining ثانية');
                    },
                    onCancelled: () {
                      AppLogger.info('[TripBloc] تم إلغاء التصعيد');
                    },
                  );
                },
              );
            },
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في التصعيد', e, stackTrace);
    }
  }

  /// تحويل DeviationSeverity إلى AlertSeverity
  AlertSeverity _convertDeviationSeverity(DeviationSeverity severity) {
    switch (severity) {
      case DeviationSeverity.none:
      case DeviationSeverity.low:
        return AlertSeverity.low;
      case DeviationSeverity.medium:
        return AlertSeverity.medium;
      case DeviationSeverity.high:
        return AlertSeverity.high;
      case DeviationSeverity.critical:
        return AlertSeverity.critical;
    }
  }

  // ========== Old Alert Methods (للتوافق الخلفي) ==========

  /// التحقق وإطلاق تنبيه انحراف إذا لزم الأمر
  Future<void> _checkAndTriggerDeviationAlert({
    required String tripId,
    required String userId,
    required Deviation deviation,
    required dynamic location,
  }) async {
    try {
      // فقط للانحرافات الخطيرة
      if (deviation.severity != DeviationSeverity.high &&
          deviation.severity != DeviationSeverity.critical) {
        return;
      }

      if (triggerAlertUseCase == null) {
        AppLogger.warning('[Trip] TriggerAlertUseCase غير متوفر');
        return;
      }

      AppLogger.warning('[Trip] انحراف ${deviation.severity} - إطلاق تنبيه');

      // جلب اسم المستخدم
      String userName = 'مستخدم';
      try {
        final getCurrentUserUseCase = di.sl<GetCurrentUserUseCase>();
        final userResult = await getCurrentUserUseCase();
        userResult.fold(
          (failure) => null,
          (user) {
            if (user != null && user.name.isNotEmpty) {
              userName = user.name;
            }
          },
        );
      } catch (e) {
        AppLogger.warning('[Trip] خطأ في جلب اسم المستخدم: $e');
      }

      final alertResult = await triggerAlertUseCase!(
        TriggerAlertParams(
          userId: userId,
          type: AlertType.deviation,
          title: 'انحراف عن المسار',
          message:
              'تم اكتشاف انحراف ${deviation.type.name} بمسافة ${deviation.distanceFromRoute.toInt()}م',
          severity: deviation.severity == DeviationSeverity.critical
              ? AlertSeverity.critical
              : AlertSeverity.high,
          tripId: tripId,
          location: location,
          metadata: {
            'deviation_distance': deviation.distanceFromRoute,
            'deviation_type': deviation.type.toString(),
            'deviation_severity': deviation.severity.toString(),
            'userName': userName, // ✅ إضافة اسم المستخدم
          },
        ),
      );

      alertResult.fold(
        (failure) =>
            AppLogger.error('[Trip] فشل إطلاق التنبيه', failure.message),
        (alert) async {
          AppLogger.success('[Trip] تم إطلاق تنبيه: ${alert.id}');

          // إرسال notification محلية
          try {
            await di.sl<NotificationService>().showAlertNotification(alert);
          } catch (e) {
            AppLogger.error('[Trip] فشل الإشعار المحلي', e);
          }

          // إرسال SMS لجهات الطوارئ (للانحرافات الحرجة فقط)
          if (deviation.severity == DeviationSeverity.critical) {
            await _notifyEmergencyContacts(alert, userId);
          }
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[Trip] خطأ في التحقق من التنبيه', e, stackTrace);
    }
  }

  /// إشعار جهات الاتصال الطارئة
  Future<void> _notifyEmergencyContacts(
    AlertEntity alert,
    String userId,
  ) async {
    try {
      if (getContactsUseCase == null) {
        AppLogger.warning('[Trip] GetContactsUseCase غير متوفر');
        return;
      }

      final contactsResult = await getContactsUseCase!(GetContactsParams(userId: userId));

      contactsResult.fold(
        (failure) =>
            AppLogger.error('[Trip] فشل جلب جهات الاتصال', failure.message),
        (contacts) async {
          final emergencyContacts = contacts
              .where((c) => c.isPrimary || c.type == ContactType.emergency)
              .take(3) // أول 3 جهات اتصال
              .toList();

          if (emergencyContacts.isEmpty) {
            AppLogger.warning('[Trip] لا توجد جهات اتصال طارئة');
            return;
          }

          try {
            await di.sl<SMSService>().sendDeviationAlert(
              alert: alert,
              contacts: emergencyContacts,
            );
            AppLogger.success(
                '[Trip] تم إرسال SMS لـ ${emergencyContacts.length} جهة اتصال');
          } catch (e) {
            AppLogger.error('[Trip] فشل إرسال SMS', e);
          }
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[Trip] خطأ في إشعار جهات الاتصال', e, stackTrace);
    }
  }

  /// إيقاف جميع خدمات التتبع
  Future<void> _stopTrackingServices() async {
    try {
      // إيقاف تتبع الموقع
      await _locationSubscription?.cancel();
      _locationSubscription = null;
      await _locationService.stopTracking();
      
      // إيقاف الفحص الدوري
      _deviationChecker.stopChecking();
      
      // إيقاف Timer الإحصائيات
      _statsUpdateTimer?.cancel();
      _statsUpdateTimer = null;
      
      // إيقاف Timer العد التنازلي
      _deviationCountdownTimer?.cancel();
      _deviationCountdownTimer = null;
      
      AppLogger.info('[TripBloc] تم إيقاف جميع خدمات التتبع');
    } catch (e) {
      AppLogger.error('[TripBloc] خطأ في إيقاف التتبع', e);
    }
  }

  /// إطلاق تنبيه انحراف
  Future<void> _triggerDeviationAlert({
    required String tripId,
    required String userId,
    required Deviation deviation,
  }) async {
    if (triggerAlertUseCase == null) return;

    try {
      await triggerAlertUseCase!(TriggerAlertParams(
        userId: userId,
        type: AlertType.deviation,
        title: 'انحراف ${_getSeverityText(deviation.severity)} عن المسار',
        message: 'المسافة: ${deviation.distanceFromRoute.toStringAsFixed(0)} متر',
        severity: _mapDeviationToAlertSeverity(deviation.severity),
        tripId: tripId,
        location: deviation.deviationLocation,
      ));
    } catch (e) {
      AppLogger.error('[TripBloc] فشل إطلاق تنبيه الانحراف', e);
    }
  }

  String _getSeverityText(DeviationSeverity severity) {
    switch (severity) {
      case DeviationSeverity.none:
        return 'لا يوجد';
      case DeviationSeverity.low:
        return 'منخفض';
      case DeviationSeverity.medium:
        return 'متوسط';
      case DeviationSeverity.high:
        return 'عالي';
      case DeviationSeverity.critical:
        return 'حرج';
    }
  }

  AlertSeverity _mapDeviationToAlertSeverity(DeviationSeverity deviation) {
    switch (deviation) {
      case DeviationSeverity.none:
        return AlertSeverity.low;
      case DeviationSeverity.low:
        return AlertSeverity.low;
      case DeviationSeverity.medium:
        return AlertSeverity.medium;
      case DeviationSeverity.high:
        return AlertSeverity.high;
      case DeviationSeverity.critical:
        return AlertSeverity.critical;
    }
  }

  /// تحديث الإحصائيات
  Future<void> _onUpdateTripStats(
    UpdateTripStatsEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      // الحصول على الرحلة النشطة من state
      if (state is! TripActive && state is! TripStatsUpdated) {
        return;
      }

      final TripEntity currentTrip;
      if (state is TripActive) {
        currentTrip = (state as TripActive).trip;
      } else {
        currentTrip = (state as TripStatsUpdated).trip;
      }

      final locationHistory = await _historyService.getLocations(currentTrip.id);

      if (locationHistory.isEmpty) {
        return;
      }

      // حساب الإحصائيات
      final currentSpeed = _calculateCurrentSpeed(locationHistory);
      final distanceTraveled = _calculateDistanceTraveled(locationHistory);
      final elapsed = DateTime.now().difference(currentTrip.startTime);
      final remainingDistance = _calculateRemainingDistance(
        currentTrip,
        locationHistory.last,
      );
      final estimatedTime = _calculateEstimatedTime(
        remainingDistance,
        currentSpeed,
      );

      emit(TripStatsUpdated(
        trip: currentTrip,
        currentSpeed: currentSpeed,
        distanceTraveled: distanceTraveled,
        elapsed: elapsed,
        remainingDistance: remainingDistance,
        estimatedTime: estimatedTime,
      ));

      AppLogger.info(
        '[TripBloc] تحديث الإحصائيات - السرعة: ${currentSpeed.toStringAsFixed(1)} كم/س، '
        'المسافة: ${distanceTraveled.toStringAsFixed(2)} كم',
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في تحديث الإحصائيات', e, stackTrace);
    }
  }

  /// فحص الانحراف
  Future<void> _onCheckDeviation(
    CheckDeviationEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      // الحصول على الرحلة النشطة
      if (state is! TripActive && state is! TripStatsUpdated) {
        return;
      }

      final TripEntity currentTrip;
      if (state is TripActive) {
        currentTrip = (state as TripActive).trip;
      } else {
        currentTrip = (state as TripStatsUpdated).trip;
      }

      // استخدام DeviationDetector للكشف
      final deviationDetector = di.sl<DeviationDetector>();
      final deviation = deviationDetector.detectDeviation(
        currentLocation: event.location,
        route: currentTrip.route,
      );

      if (deviation != null && deviation.severity != DeviationSeverity.none) {
        AppLogger.warning(
          '[TripBloc] انحراف مكتشف! الشدة: ${deviation.severity.name}, '
          'المسافة: ${deviation.distanceFromRoute.toStringAsFixed(0)}م',
        );

        emit(DeviationDetectedState(
          trip: currentTrip,
          deviation: deviation,
          isActive: true,
        ));

        // بدء العد التنازلي للانحرافات الحرجة
        if (deviation.severity == DeviationSeverity.critical ||
            deviation.severity == DeviationSeverity.high) {
          add(StartDeviationCountdownEvent(deviation: deviation));
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في فحص الانحراف', e, stackTrace);
    }
  }

  /// بدء العد التنازلي للانحراف
  Timer? _deviationCountdownTimer;
  int _countdownSeconds = 30;

  Future<void> _onStartDeviationCountdown(
    StartDeviationCountdownEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      // إلغاء أي countdown سابق
      _deviationCountdownTimer?.cancel();

      // الحصول على الرحلة النشطة
      if (state is! DeviationDetectedState) {
        return;
      }

      final currentTrip = (state as DeviationDetectedState).trip;
      _countdownSeconds = 30;

      AppLogger.info('[TripBloc] بدء العد التنازلي: 30 ثانية');

      _deviationCountdownTimer = Timer.periodic(
        const Duration(seconds: 1),
        (timer) async {
          _countdownSeconds--;

          emit(DeviationCountdownState(
            trip: currentTrip,
            deviation: event.deviation,
            secondsRemaining: _countdownSeconds,
          ));

          AppLogger.info('[TripBloc] العد التنازلي: $_countdownSeconds ثانية');

          if (_countdownSeconds <= 0) {
            timer.cancel();
            AppLogger.warning('[TripBloc] انتهى العد التنازلي - تصعيد للتنبيه');

            // تصعيد للتنبيه
            await _triggerDeviationAlertWithEscalation(
              tripId: currentTrip.id,
              userId: currentTrip.userId,
              deviation: event.deviation,
            );
          }
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في بدء العد التنازلي', e, stackTrace);
    }
  }

  /// إلغاء العد التنازلي
  Future<void> _onCancelDeviationCountdown(
    CancelDeviationCountdownEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      _deviationCountdownTimer?.cancel();
      _deviationCountdownTimer = null;

      AppLogger.info('[TripBloc] تم إلغاء العد التنازلي');

      // العودة للحالة النشطة
      if (state is DeviationCountdownState) {
        final trip = (state as DeviationCountdownState).trip;
        emit(TripActive(trip: trip));
      }
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في إلغاء العد التنازلي', e, stackTrace);
    }
  }

  /// تأكيد "أنا بخير"
  Future<void> _onDismissDeviationAlert(
    DismissDeviationAlertEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      AppLogger.info('[TripBloc] المستخدم أكد "أنا بخير"');

      // إلغاء العد التنازلي
      _deviationCountdownTimer?.cancel();
      _deviationCountdownTimer = null;

      // حل الانحراف الحالي
      add(ResolveCurrentDeviationEvent(tripId: event.tripId));
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في تأكيد أنا بخير', e, stackTrace);
    }
  }

  /// تفعيل SOS
  Future<void> _onTriggerSOS(
    TriggerSOSEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      AppLogger.warning('[TripBloc] تفعيل SOS للرحلة: ${event.tripId}');

      // الحصول على الرحلة الحالية
      TripEntity? currentTrip;
      if (state is TripActive) {
        currentTrip = (state as TripActive).trip;
      } else if (state is TripStatsUpdated) {
        currentTrip = (state as TripStatsUpdated).trip;
      } else if (state is DeviationCountdownState) {
        currentTrip = (state as DeviationCountdownState).trip;
      }

      if (currentTrip == null) {
        AppLogger.error('[TripBloc] لا توجد رحلة نشطة لتفعيل SOS');
        emit(const TripError(message: 'noActiveTripError'));
        return;
      }

      // تحويل الرحلة لحالة طوارئ
      emit(TripEmergencyState(
        trip: currentTrip,
        triggeredAt: DateTime.now(),
      ));

      // جلب اسم المستخدم
      String userName = 'مستخدم';
      try {
        final getCurrentUserUseCase = di.sl<GetCurrentUserUseCase>();
        final userResult = await getCurrentUserUseCase();
        userResult.fold(
          (failure) => null,
          (user) {
            if (user != null && user.name.isNotEmpty) {
              userName = user.name;
            }
          },
        );
      } catch (e) {
        AppLogger.warning('[TripBloc] خطأ في جلب اسم المستخدم: $e');
      }

      // إرسال تنبيه SOS فوري لجميع جهات الاتصال
      if (triggerAlertUseCase != null) {
        await triggerAlertUseCase!(TriggerAlertParams(
          userId: currentTrip.userId,
          type: AlertType.sos,
          title: '🆘 تنبيه طوارئ SOS',
          message: 'تم تفعيل زر الطوارئ من قبل المستخدم',
          severity: AlertSeverity.critical,
          tripId: event.tripId,
          location: event.currentLocation,
          metadata: {
            'userName': userName, // ✅ إضافة اسم المستخدم
            'sosType': 'manual', // زر SOS يدوي
          },
        ));

        AppLogger.success('[TripBloc] تم إرسال تنبيه SOS لجميع جهات الاتصال');
      }
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في تفعيل SOS', e, stackTrace);
      emit(const TripError(message: 'emergencyActivationFailed'));
    }
  }

  /// بدء التتبع التلقائي
  Future<void> _onStartAutoTracking(
    StartAutoTrackingEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      AppLogger.info('[TripBloc] بدء التتبع التلقائي للرحلة: ${event.tripId}');

      final trackingStarted = await _locationService.startTracking(
        mode: LocationTrackingMode.background,
        distanceFilter: 10,
        intervalSeconds: 5,
        accuracy: LocationAccuracy.high,
      );

      if (!trackingStarted) {
        AppLogger.error('[TripBloc] فشل بدء التتبع التلقائي');
        emit(const TripError(message: 'autoTrackingFailed'));
        return;
      }

      // الاستماع لتحديثات الموقع
      _locationSubscription = _locationService.locationStream.listen(
        (location) {
          add(UpdateLocationEvent(
            tripId: event.tripId,
            location: location,
          ));

          // فحص الانحراف
          add(CheckDeviationEvent(location: location));
        },
        onError: (error) {
          AppLogger.error('[TripBloc] خطأ في stream الموقع', error);
        },
      );

      AppLogger.success('[TripBloc] تم بدء التتبع التلقائي بنجاح');
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في بدء التتبع التلقائي', e, stackTrace);
    }
  }

  /// إيقاف التتبع التلقائي
  Future<void> _onStopAutoTracking(
    StopAutoTrackingEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      AppLogger.info('[TripBloc] إيقاف التتبع التلقائي');
      await _stopTrackingServices();
      AppLogger.success('[TripBloc] تم إيقاف التتبع التلقائي');
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في إيقاف التتبع', e, stackTrace);
    }
  }

  // Helper methods للحسابات
  double _calculateCurrentSpeed(List<Location> history) {
    if (history.length < 2) return 0;

    final last = history.last;
    final previous = history[history.length - 2];

    final distance = _calculateDistanceBetweenLocations(previous, last);
    final timeDiff = last.timestamp.difference(previous.timestamp);

    if (timeDiff.inSeconds == 0) return 0;

    // م/ث → كم/س
    return (distance / timeDiff.inSeconds) * 3.6;
  }

  double _calculateDistanceTraveled(List<Location> history) {
    double total = 0;

    for (int i = 0; i < history.length - 1; i++) {
      total += _calculateDistanceBetweenLocations(
        history[i],
        history[i + 1],
      );
    }

    return total / 1000; // متر → كم
  }

  double _calculateRemainingDistance(TripEntity trip, Location currentLocation) {
    final remainingWaypoints = trip.route.waypoints
        .where((w) => !trip.visitedWaypointIds.contains(w.id))
        .toList();

    if (remainingWaypoints.isEmpty) return 0;

    double total = 0;

    // من الموقع الحالي للنقطة التالية
    total += _calculateDistanceBetweenLocations(
      currentLocation,
      remainingWaypoints.first.location,
    );

    // بين النقاط المتبقية
    for (int i = 0; i < remainingWaypoints.length - 1; i++) {
      total += _calculateDistanceBetweenLocations(
        remainingWaypoints[i].location,
        remainingWaypoints[i + 1].location,
      );
    }

    return total / 1000; // متر → كم
  }

  Duration? _calculateEstimatedTime(double remainingKm, double currentSpeedKmh) {
    if (currentSpeedKmh == 0) return null;

    final hours = remainingKm / currentSpeedKmh;
    return Duration(minutes: (hours * 60).round());
  }

  double _calculateDistanceBetweenLocations(Location loc1, Location loc2) {
    return Geolocator.distanceBetween(
      loc1.latitude,
      loc1.longitude,
      loc2.latitude,
      loc2.longitude,
    );
  }

  /// التحقق من موقع المستخدم قبل بدء الرحلة
  /// Single Responsibility: التحقق من أن المستخدم قريب من نقطة البداية
  Future<void> _onValidateUserLocation(
    ValidateUserLocationEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      AppLogger.info('[TripBloc] التحقق من موقع المستخدم قبل بدء الرحلة');
      emit(const TripLoading());

      // جلب إعدادات الرحلات للمستخدم
      final settingsResult = await tripsRepository.getTripSettings(event.userId);
      double allowedDistance = DeviationDetector.lowThreshold;
      bool alwaysStartFromCurrentLocation = false;
      bool enableLocationValidation = true;
      
      settingsResult.fold(
        (failure) {
          AppLogger.warning('[TripBloc] فشل جلب الإعدادات - استخدام القيمة الافتراضية');
        },
        (settings) {
          allowedDistance = settings.startLocationThreshold;
          alwaysStartFromCurrentLocation = settings.alwaysStartFromCurrentLocation;
          enableLocationValidation = settings.enableLocationValidation;
          AppLogger.info('[TripBloc] تم جلب الإعدادات - عتبة الموقع: $allowedDistance متر');
          AppLogger.info('[TripBloc] البدء دائماً من الموقع الحالي: $alwaysStartFromCurrentLocation');
        },
      );

      // إذا كان المستخدم قد فعّل "البدء دائماً من الموقع الحالي"
      if (alwaysStartFromCurrentLocation || !enableLocationValidation) {
        AppLogger.info('[TripBloc] المستخدم فعّل البدء التلقائي من الموقع الحالي - بدء الرحلة مباشرة');
        add(StartTripFromCurrentLocationEvent(
          userId: event.userId,
          routeId: event.routeId,
        ));
        return;
      }

      // الحصول على معلومات المسار من tripsRepository
      final routeResult = await tripsRepository.getRouteById(event.routeId);
      
      await routeResult.fold(
        (failure) async {
          AppLogger.error('[TripBloc] فشل في جلب معلومات المسار: ${failure.message}');
          emit(const TripError(message: 'routeInfoLoadFailed2'));
        },
        (route) async {
          if (route == null || route.waypoints.isEmpty) {
            AppLogger.error('[TripBloc] المسار غير موجود أو لا يحتوي على نقاط');
            emit(const TripError(message: 'invalidRoute2'));
            return;
          }

          // الحصول على الموقع الحالي للمستخدم
          final currentLocation = await _locationService.getCurrentLocation();
          
          if (currentLocation == null) {
            AppLogger.error('[TripBloc] فشل في تحديد الموقع الحالي');
            emit(const TripError(message: 'locationDetermFailed'));
            return;
          }

          // الحصول على نقطة البداية من المسار
          final startPoint = route.waypoints.first;
          
          // حساب المسافة بين الموقع الحالي ونقطة البداية
          final distance = _calculateDistanceBetweenLocations(
            currentLocation,
            startPoint.location,
          );

          AppLogger.info('[TripBloc] المسافة من نقطة البداية: ${distance.toStringAsFixed(1)} متر');
          AppLogger.info('[TripBloc] العتبة المسموحة: ${allowedDistance.toStringAsFixed(1)} متر');

          if (distance > allowedDistance) {
            // المستخدم بعيد عن نقطة البداية
            AppLogger.warning('[TripBloc] المستخدم بعيد عن نقطة البداية بمقدار ${distance.toStringAsFixed(1)} متر');
            emit(TripUserFarFromStartPoint(
              routeId: event.routeId,
              routeName: route.name,
              distanceFromStart: distance,
              userId: event.userId,
            ));
          } else {
            // المستخدم قريب من نقطة البداية - يمكن بدء الرحلة مباشرة
            AppLogger.success('[TripBloc] المستخدم في نقطة البداية - بدء الرحلة');
            add(StartTripEvent(
              userId: event.userId,
              routeId: event.routeId,
            ));
          }
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في التحقق من الموقع', e, stackTrace);
      emit(const TripError(message: 'locationCheckError'));
    }
  }

  /// تحميل وتطبيق إعدادات الرحلات
  /// Single Responsibility: تحميل الإعدادات وتطبيقها على DeviationDetector
  Future<void> _loadAndApplyTripSettings(String userId) async {
    try {
      AppLogger.info('[TripBloc] تحميل إعدادات الرحلات للمستخدم: $userId');
      
      final settingsResult = await tripsRepository.getTripSettings(userId);
      
      settingsResult.fold(
        (failure) {
          AppLogger.warning(
            '[TripBloc] فشل تحميل الإعدادات - استخدام القيم الافتراضية: ${failure.message}',
          );
          // استخدام القيم الافتراضية
          DeviationDetector.instance.resetToDefaults();
        },
        (settings) {
          AppLogger.success('[TripBloc] تم تحميل إعدادات الرحلات');
          AppLogger.info(
            '[TripBloc] تطبيق العتبات: '
            'Start=${settings.startLocationThreshold}م, '
            'Low=${settings.lowDeviationThreshold}م, '
            'Medium=${settings.mediumDeviationThreshold}م, '
            'High=${settings.highDeviationThreshold}م',
          );
          
          // تطبيق العتبات على DeviationDetector
          DeviationDetector.instance.updateThresholds(
            low: settings.lowDeviationThreshold,
            medium: settings.mediumDeviationThreshold,
            high: settings.highDeviationThreshold,
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TripBloc] خطأ في تحميل الإعدادات', e, stackTrace);
      // في حالة الخطأ، استخدام القيم الافتراضية
      DeviationDetector.instance.resetToDefaults();
    }
  }

  /// بدء الرحلة من الموقع الحالي (تجاهل التحقق من المسافة)
  /// Single Responsibility: بدء الرحلة مباشرة بغض النظر عن المسافة من نقطة البداية
  /// يُستخدم عندما يختار المستخدم البدء من موقعه الحالي رغم البُعد عن نقطة البداية الأصلية
  Future<void> _onStartTripFromCurrentLocation(
    StartTripFromCurrentLocationEvent event,
    Emitter<TripState> emit,
  ) async {
    try {
      AppLogger.info(
        '[TripBloc] بدء رحلة من الموقع الحالي (تجاهل التحقق من المسافة): ${event.routeId}',
      );
      emit(const TripLoading());
      
      // الحصول على الموقع الحالي
      final currentLocation = await _locationService.getCurrentLocation();
      if (currentLocation == null) {
        AppLogger.error('[TripBloc] فشل في تحديد الموقع الحالي');
        emit(const TripError(message: 'locationDetermFailed'));
        return;
      }
      
      // الحصول على المسار الأصلي
      final routeResult = await tripsRepository.getRouteById(event.routeId);
      await routeResult.fold(
        (failure) async {
          AppLogger.error('[TripBloc] فشل في جلب معلومات المسار: ${failure.message}');
          emit(const TripError(message: 'routeInfoLoadFailed2'));
        },
        (route) async {
          if (route == null || route.waypoints.isEmpty) {
            AppLogger.error('[TripBloc] المسار غير موجود أو لا يحتوي على نقاط');
            emit(const TripError(message: 'invalidRoute2'));
            return;
          }
          
          // تحديث عداد استخدام "ابدأ من هنا" في الإعدادات
          final settingsResult = await tripsRepository.getTripSettings(event.userId);
          await settingsResult.fold(
            (failure) async {
              AppLogger.warning('[TripBloc] فشل جلب الإعدادات - استخدام القيم الافتراضية');
            },
            (settings) async {
              final updatedSettings = settings.copyWith(
                startFromHereUsageCount: settings.startFromHereUsageCount + 1,
              );
              await tripsRepository.saveTripSettings(updatedSettings);
              AppLogger.info(
                '[TripBloc] تم تحديث إحصائيات "ابدأ من هنا": ${updatedSettings.startFromHereUsageCount}',
              );
            },
          );
          
          // ═══════════════════════════════════════════════════════
          // إنشاء مسار جديد تلقائي بنقطة بداية من الموقع الحالي
          // ═══════════════════════════════════════════════════════
          
          // جلب العنوان الحالي للمستخدم
          final currentAddress = await _getAddressFromLocation(currentLocation);
          final timeLabel = DateTime.now().toString().substring(11, 16);
          
          // إنشاء نقطة بداية جديدة من الموقع الحالي (نوع صريح لتجنب List<dynamic>)
          final currentWaypoint = route.waypoints.first.copyWith(
            location: currentLocation,
            name: 'موقعك الحالي ($timeLabel)',
            description: currentAddress,
          );
          
          // بناء قائمة النقاط: الموقع الحالي + بقية نقاط المسار الأصلي
          final modifiedWaypoints = <Waypoint>[
            currentWaypoint,
            ...route.waypoints.skip(1),
          ];
          
          // ✅ إنشاء مسار جديد بـ ID جديد (وليس تعديل الأصلي)
          // يظهر في قائمة المسارات ويمكن استخدامه مستقبلاً
          final newRouteId = DateTime.now().millisecondsSinceEpoch.toString();
          final newRouteName = '${route.name} (من موقعي)';
          
          // نُعيد بناء الـ entity بـ ID جديد
          final brandNewRoute = RouteEntity(
            id: newRouteId,
            userId: route.userId,
            name: newRouteName,
            waypoints: modifiedWaypoints,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            description: 'مسار تلقائي من "ابدأ من هنا" - ${route.name}',
            status: route.status,
            isFavorite: false,
            estimatedDistance: null,
            estimatedDuration: null,
          );
          
          AppLogger.info('[TripBloc] إنشاء مسار جديد: $newRouteName (ID: $newRouteId)');
          
          // ✅ حفظ المسار الجديد محلياً (يظهر في قائمة المسارات فوراً)
          try {
            await tripsRepository.saveModifiedRoute(brandNewRoute);
            AppLogger.success('[TripBloc] تم حفظ المسار الجديد محلياً: $newRouteId');
          } catch (e, stackTrace) {
            AppLogger.error('[TripBloc] فشل حفظ المسار الجديد محلياً', e, stackTrace);
            // الاستمرار حتى لو فشل الحفظ المحلي
          }
          
          // ✅ مزامنة المسار الجديد مع Firebase في الخلفية
          unawaited(
            tripsRepository.syncModifiedRouteToFirebase(brandNewRoute).then((_) {
              AppLogger.success('[TripBloc] تمت مزامنة المسار الجديد مع Firebase');
            }).catchError((e) {
              AppLogger.warning('[TripBloc] فشلت مزامنة المسار الجديد (ستتم لاحقاً): $e');
            }),
          );
          
          // استخدام المسار الجديد لبدء الرحلة
          final modifiedRoute = brandNewRoute;
          
          // ✅ بدء الرحلة على المسار الجديد (بـ ID الجديد)
          final result = await startTripUseCase(
            StartTripParams(
              userId: event.userId,
              routeId: brandNewRoute.id, // ← ID المسار الجديد
              modifiedRoute: modifiedRoute,
            ),
          );
          
          await result.fold(
            (failure) async {
              AppLogger.error('[TripBloc] فشل بدء الرحلة: ${failure.message}');
              emit(TripError(message: failure.message));
            },
            (trip) async {
              AppLogger.success('[TripBloc] تم بدء الرحلة من الموقع الحالي: ${trip.id}');
              
              // بدء تتبع الموقع في الخلفية
              final trackingStarted = await _locationService.startTracking(
                mode: LocationTrackingMode.background,
                distanceFilter: 10,
                intervalSeconds: 5,
                accuracy: LocationAccuracy.high,
              );
              
              if (!trackingStarted) {
                AppLogger.error('[TripBloc] فشل بدء تتبع الموقع');
                emit(const TripError(message: 'locationTrackingFailed'));
                return;
              }

              // الاستماع لتحديثات الموقع
              _locationSubscription = _locationService.locationStream.listen(
                (location) {
                  _historyService.saveLocation(tripId: trip.id, location: location);
                  add(UpdateLocationEvent(tripId: trip.id, location: location));
                },
                onError: (error) {
                  AppLogger.error('[TripBloc] خطأ في stream الموقع', error);
                },
              );

              // بدء الفحص الدوري للانحراف
              _deviationChecker.startChecking(
                route: trip.route,
                locationStream: _locationService.locationStream,
                onDeviation: (deviation) async {
                  AppLogger.warning('[TripBloc] تم كشف انحراف: ${deviation.severity.name}');
                  
                  if (deviation.severity == DeviationSeverity.high ||
                      deviation.severity == DeviationSeverity.critical) {
                    await _triggerDeviationAlertWithEscalation(
                      tripId: trip.id,
                      userId: trip.userId,
                      deviation: deviation,
                    );
                  }
                },
                onResolved: (deviation) {
                  AppLogger.info('[TripBloc] تم حل الانحراف');
                },
                onSeverityChange: (oldSeverity, newSeverity) {
                  AppLogger.warning(
                    '[TripBloc] تغيرت شدة الانحراف من ${oldSeverity.name} إلى ${newSeverity.name}',
                  );
                },
              );

              // بدء تحديث الإحصائيات كل 5 ثوان
              _statsUpdateTimer = Timer.periodic(
                const Duration(seconds: 5),
                (_) => add(const UpdateTripStatsEvent()),
              );

              emit(TripActive(trip: trip));
              AppLogger.success('[TripBloc] الرحلة نشطة الآن');
            },
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        '[TripBloc] خطأ في بدء الرحلة من الموقع الحالي',
        e,
        stackTrace,
      );
      emit(const TripError(message: 'tripStartError'));
    }
  }
  
  /// الحصول على العنوان من الموقع باستخدام Geocoding Service
  Future<String?> _getAddressFromLocation(Location location) async {
    try {
      final geocodingService = GeocodingService.instance;
      final address = await geocodingService.getAddressFromLocation(location);
      return address;
    } catch (e) {
      AppLogger.error('[TripBloc] فشل الحصول على العنوان', e);
      return null;
    }
  }


  @override
  Future<void> close() {
    _deviationCountdownTimer?.cancel();
    _stopTrackingServices();
    return super.close();
  }
}

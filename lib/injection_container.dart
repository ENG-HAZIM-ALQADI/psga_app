import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:psga_app/core/services/connectivity_service.dart';
import 'package:psga_app/core/services/sync_manager.dart';
import 'package:psga_app/core/services/sync_service.dart';
import 'package:psga_app/core/services/data_sync_service.dart';
import 'package:psga_app/core/storage/hive_service.dart';
import 'package:psga_app/core/storage/local_storage_service.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:psga_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:psga_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:psga_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:psga_app/features/auth/domain/usecases/change_password_usecase.dart';
import 'package:psga_app/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:psga_app/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:psga_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:psga_app/features/auth/domain/usecases/login_with_apple_usecase.dart';
import 'package:psga_app/features/auth/domain/usecases/login_with_google_usecase.dart';
import 'package:psga_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:psga_app/features/auth/domain/usecases/register_usecase.dart';
import 'package:psga_app/features/auth/domain/usecases/reset_password_usecase.dart';
import 'package:psga_app/features/auth/domain/usecases/send_email_verification_usecase.dart';
import 'package:psga_app/features/auth/domain/usecases/update_profile_usecase.dart';
import 'package:psga_app/features/auth/domain/usecases/upload_profile_photo_usecase.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:psga_app/features/routes/data/repositories/routes_repository_impl.dart';
import 'package:psga_app/features/routes/domain/repositories/routes_repository.dart';
import 'package:psga_app/features/routes/domain/usecases/create_route_usecase.dart';
import 'package:psga_app/features/routes/domain/usecases/get_user_routes_usecase.dart';
import 'package:psga_app/features/routes/domain/usecases/routes_usecases.dart';
import 'package:psga_app/features/routes/domain/usecases/sync_routes_usecase.dart';
import 'package:psga_app/features/routes/domain/usecases/update_route_status_usecase.dart';
import 'package:psga_app/features/routes/domain/usecases/get_active_routes_usecase.dart';
import 'package:psga_app/features/routes/presentation/bloc/routes_bloc.dart';
import 'package:psga_app/features/trips/data/datasources/trips_local_datasource.dart';
import 'package:psga_app/features/trips/data/datasources/trips_remote_datasource.dart';
import 'package:psga_app/features/trips/data/repositories/trips_repository_impl.dart';
import 'package:psga_app/features/trips/domain/repositories/trips_repository.dart';
import 'package:psga_app/features/trips/domain/usecases/end_trip_usecase.dart';
import 'package:psga_app/features/trips/domain/usecases/get_active_trip_usecase.dart';
import 'package:psga_app/features/trips/domain/usecases/get_trip_details_usecase.dart';
import 'package:psga_app/features/trips/domain/usecases/get_trip_history_usecase.dart';
import 'package:psga_app/features/trips/domain/usecases/pause_trip_usecase.dart';
import 'package:psga_app/features/trips/domain/usecases/resume_trip_usecase.dart';
import 'package:psga_app/features/trips/domain/usecases/start_trip_usecase.dart';
import 'package:psga_app/features/trips/domain/usecases/update_location_usecase.dart';
import 'package:psga_app/features/trips/domain/usecases/get_trip_settings_usecase.dart';
import 'package:psga_app/features/trips/domain/usecases/save_trip_settings_usecase.dart';
import 'package:psga_app/features/trips/presentation/bloc/trip_bloc.dart';

// Alerts Feature
import 'package:psga_app/features/alerts/data/datasources/alerts_local_datasource.dart';
import 'package:psga_app/features/alerts/data/datasources/alerts_remote_datasource.dart';
import 'package:psga_app/features/alerts/data/repositories/alerts_repository_impl.dart';
import 'package:psga_app/features/alerts/data/repositories/contacts_repository_impl.dart';
import 'package:psga_app/features/alerts/domain/repositories/alerts_repository.dart';
import 'package:psga_app/features/alerts/domain/repositories/contacts_repository.dart';
import 'package:psga_app/features/alerts/domain/usecases/acknowledge_alert_usecase.dart';
import 'package:psga_app/features/alerts/domain/usecases/escalate_alert_usecase.dart';
import 'package:psga_app/features/alerts/domain/usecases/get_active_alerts_usecase.dart';
import 'package:psga_app/features/alerts/domain/usecases/get_alert_config_usecase.dart';
import 'package:psga_app/features/alerts/domain/usecases/manage_contacts_usecase.dart';
import 'package:psga_app/features/alerts/domain/usecases/get_contacts_usecase.dart';
import 'package:psga_app/features/alerts/domain/usecases/save_alert_config_usecase.dart';
import 'package:psga_app/features/alerts/domain/usecases/send_sos_usecase.dart';
import 'package:psga_app/features/alerts/domain/usecases/trigger_alert_usecase.dart';
import 'package:psga_app/features/alerts/presentation/bloc/alert/alert_bloc.dart';
import 'package:psga_app/features/alerts/presentation/bloc/contact/contact_bloc.dart';

// Maps Feature
import 'package:http/http.dart' as http;
import 'package:psga_app/core/services/offline_maps_manager.dart';
import 'package:psga_app/features/maps/data/datasources/remote/maps_remote_data_source.dart';
import 'package:psga_app/features/maps/data/datasources/local/maps_local_data_source.dart';
import 'package:psga_app/features/maps/data/repositories/maps_repository_impl.dart';
import 'package:psga_app/features/maps/domain/repositories/maps_repository.dart';
import 'package:psga_app/features/maps/domain/usecases/directions_usecases.dart';
import 'package:psga_app/features/maps/domain/usecases/places_usecases.dart';
import 'package:psga_app/features/maps/presentation/bloc/location/location_bloc.dart';
import 'package:psga_app/features/maps/presentation/bloc/maps/maps_bloc.dart';

// Routes UseCases
import 'package:psga_app/features/routes/domain/usecases/get_address_from_location_usecase.dart';

// Core Services
import 'package:psga_app/core/services/conflict_resolver.dart';
import 'package:psga_app/core/services/deviation_detector.dart';
import 'package:psga_app/core/services/fcm_service.dart';
import 'package:psga_app/core/services/geocoding_service.dart';
import 'package:psga_app/core/services/location_history_service.dart';
import 'package:psga_app/core/services/location_service.dart';
import 'package:psga_app/core/services/notification_service.dart';
import 'package:psga_app/core/services/periodic_deviation_checker.dart';
import 'package:psga_app/core/services/sms_service.dart';
import 'package:psga_app/core/services/route_calculator_service.dart';

/// GetIt Service Locator
final sl = GetIt.instance;

/// تهيئة جميع الـ Dependencies
Future<void> setupDependencyInjection() async {
  AppLogger.start('[DI] تهيئة Dependency Injection');

  try {
    // ========== Core Services ==========

    // HTTP Client
    sl.registerLazySingleton(() => http.Client());
    AppLogger.info('[DI] ✅ HTTP Client');

    // Firebase
    sl.registerLazySingleton(() => FirebaseAuth.instance);
    sl.registerLazySingleton(() => FirebaseFirestore.instance);
    sl.registerLazySingleton(() => FirebaseStorage.instance);
    AppLogger.info('[DI] ✅ Firebase Services');

    // Storage Services
    sl.registerLazySingleton(() => HiveService.instance);
    sl.registerLazySingleton(() => LocalStorageService(sl()));
    AppLogger.info('[DI] ✅ Storage Services');

    // Connectivity & Sync Services
    sl.registerLazySingleton(() => ConnectivityService.instance);
    sl.registerLazySingleton(() => SyncService.instance);
    sl.registerLazySingleton(() => DataSyncService.instance);
    sl.registerLazySingleton(() => SyncManager.instance);
    AppLogger.info('[DI] ✅ Connectivity & Sync Services');

    // Location Services
    sl.registerLazySingleton(() => LocationService.instance);
    sl.registerLazySingleton(() => GeocodingService.instance);
    sl.registerLazySingleton(() => LocationHistoryService.instance);
    
    // Route Calculator (يحتاج تهيئة بعد تسجيل MapsRepository)
    sl.registerLazySingleton(() {
      final service = RouteCalculatorService.instance;
      // سيتم تهيئته بعد تسجيل MapsRepository
      return service;
    });
    
    AppLogger.info('[DI] ✅ Location Services');

    // Notification & Alert Services
    sl.registerLazySingleton(() => FCMService.instance);
    sl.registerLazySingleton(() => SMSService.instance);
    sl.registerLazySingleton(() => NotificationService.instance);
    AppLogger.info('[DI] ✅ Notification Services');

    // Analysis Services
    sl.registerLazySingleton(() => DeviationDetector.instance);
    sl.registerLazySingleton(() => PeriodicDeviationChecker.instance);
    sl.registerLazySingleton(() => ConflictResolver.instance);
    AppLogger.info('[DI] ✅ Analysis Services');


    // ========== Features - Auth ==========

    // DataSources (LazySingleton)
    sl.registerLazySingleton<AuthRemoteDataSource>(
          () => AuthRemoteDataSourceImpl(
        firebaseAuth: sl(),
        firestore: sl(),
        storage: sl(),
      ),
    );

    sl.registerLazySingleton<AuthLocalDataSource>(
          () => AuthLocalDataSourceImpl(sl()), // ✅ LocalStorageService
    );

    // Repository (LazySingleton)
    sl.registerLazySingleton<AuthRepository>(
          () => AuthRepositoryImpl(
        remoteDataSource: sl(),
        localDataSource: sl(),
      ),
    );

    // UseCases (LazySingleton)
    sl.registerLazySingleton(() => LoginUseCase(sl()));
    sl.registerLazySingleton(() => RegisterUseCase(sl()));
    sl.registerLazySingleton(() => LogoutUseCase(sl()));
    sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));
    sl.registerLazySingleton(() => ResetPasswordUseCase(sl()));
    sl.registerLazySingleton(() => SendEmailVerificationUseCase(sl()));
    sl.registerLazySingleton(() => UpdateProfileUseCase(sl()));
    sl.registerLazySingleton(() => UploadProfilePhotoUseCase(sl()));
    sl.registerLazySingleton(() => ChangePasswordUseCase(sl()));
    sl.registerLazySingleton(() => DeleteAccountUseCase(sl()));
    sl.registerLazySingleton(() => LoginWithGoogleUseCase(sl()));
    sl.registerLazySingleton(() => LoginWithAppleUseCase(sl()));

    // BLoC (Factory - new instance each time)
    sl.registerFactory(
          () => AuthBloc(
        loginUseCase: sl(),
        registerUseCase: sl(),
        logoutUseCase: sl(),
        getCurrentUserUseCase: sl(),
        resetPasswordUseCase: sl(),
        sendEmailVerificationUseCase: sl(),
        updateProfileUseCase: sl(),
        uploadProfilePhotoUseCase: sl(),
        changePasswordUseCase: sl(),
        deleteAccountUseCase: sl(),
        loginWithGoogleUseCase: sl(),
        loginWithAppleUseCase: sl(),
        repository: sl(),
      ),
    );

    AppLogger.info('[DI] ✅ Auth Feature');

    // ========== Features - Routes ==========

    // Repository (LazySingleton)
    // ✅ تصحيح: firestore بدلاً من firebaseFirestore
    sl.registerLazySingleton<RoutesRepository>(
          () => RoutesRepositoryImpl(
        firestore: sl<FirebaseFirestore>(),
      ),
    );

    // UseCases (LazySingleton)
    sl.registerLazySingleton(() => CreateRouteUseCase(sl(), calculatorService: sl()));
    sl.registerLazySingleton(() => GetUserRoutesUseCase(sl()));
    sl.registerLazySingleton(() => UpdateRouteUseCase(sl()));
    sl.registerLazySingleton(() => DeleteRouteUseCase(sl()));
    sl.registerLazySingleton(() => ToggleFavoriteUseCase(sl()));
    sl.registerLazySingleton(() => SearchRoutesUseCase(sl()));
    sl.registerLazySingleton(() => GetFavoriteRoutesUseCase(sl()));
    sl.registerLazySingleton(() => SyncRoutesUseCase(sl()));
    sl.registerLazySingleton(() => UpdateRouteStatusUseCase(sl()));
    sl.registerLazySingleton(() => GetActiveRoutesUseCase(sl()));
    sl.registerLazySingleton(() => GetRouteUseCase(sl()));
    
    // UseCases للخدمات المساعدة
    sl.registerLazySingleton(() => GetAddressFromLocationUseCase(geocodingService: sl()));

    // BLoC (Singleton - لضمان مشاركة نفس الـ instance)
    sl.registerLazySingleton(
          () => RoutesBloc(
        createRoute: sl(),
        getUserRoutes: sl(),
        updateRoute: sl(),
        deleteRoute: sl(),
        toggleFavorite: sl(),
        searchRoutes: sl(),
        getFavoriteRoutes: sl(),
        syncRoutes: sl(),
        updateRouteStatus: sl(),
        getActiveRoutes: sl(),
      ),
    );

    AppLogger.info('[DI] ✅ Routes Feature');

    // ========== Features - Trips ==========

    // DataSources (LazySingleton)
    sl.registerLazySingleton<TripsLocalDataSource>(
      () => TripsLocalDataSourceImpl(
        hiveService: sl(),
      ),
    );

    sl.registerLazySingleton<TripsRemoteDataSource>(
      () => TripsRemoteDataSourceImpl(
        firestore: sl<FirebaseFirestore>(),
      ),
    );

    // Repository (LazySingleton)
    sl.registerLazySingleton<TripsRepository>(
      () => TripsRepositoryImpl(
        localDataSource: sl(),
        remoteDataSource: sl(),
        connectivityService: sl(),
        firestore: sl<FirebaseFirestore>(),
      ),
    );

    // UseCases (LazySingleton)
    sl.registerLazySingleton(() => StartTripUseCase(sl()));
    sl.registerLazySingleton(() => EndTripUseCase(sl()));
    sl.registerLazySingleton(() => PauseTripUseCase(sl()));
    sl.registerLazySingleton(() => ResumeTripUseCase(sl()));
    sl.registerLazySingleton(() => UpdateLocationUseCase(sl()));
    sl.registerLazySingleton(() => GetActiveTripUseCase(sl()));
    sl.registerLazySingleton(() => GetTripHistoryUseCase(sl()));
    sl.registerLazySingleton(() => GetTripDetailsUseCase(sl()));
    sl.registerLazySingleton(() => GetTripSettingsUseCase(sl()));
    sl.registerLazySingleton(() => SaveTripSettingsUseCase(sl()));

    // BLoC (Factory)
    sl.registerFactory(
          () => TripBloc(
        startTripUseCase: sl(),
        endTripUseCase: sl(),
        pauseTripUseCase: sl(),
        resumeTripUseCase: sl(),
        updateLocationUseCase: sl(),
        getActiveTripUseCase: sl(),
        getTripHistoryUseCase: sl(),
        getTripDetailsUseCase: sl(),
        triggerAlertUseCase: sl(),
        getContactsUseCase: sl(),
        getAlertConfigUseCase: sl(),
        tripsRepository: sl<TripsRepository>(),
      ),
    );

    AppLogger.info('[DI] ✅ Trips Feature');

    // ========== Features - Alerts ==========

    // DataSources (LazySingleton)
    // ✅ تصحيح: firebaseFirestore بدلاً من firestore
    sl.registerLazySingleton<AlertsRemoteDataSource>(
          () => AlertsRemoteDataSourceImpl(
        firebaseFirestore: sl<FirebaseFirestore>(),
      ),
    );

    // ✅ تصحيح: hiveService بدلاً من sl()
    sl.registerLazySingleton<AlertsLocalDataSource>(
          () => AlertsLocalDataSourceImpl(
        hiveService: sl<HiveService>(),
      ),
    );

    // Repository (LazySingleton)
    // ✅ تصحيح: firestore بدلاً من remoteDataSource و localDataSource
    sl.registerLazySingleton<AlertsRepository>(
          () => AlertsRepositoryImpl(
        firestore: sl<FirebaseFirestore>(),
      ),
    );

    // Contacts Repository (LazySingleton)
    sl.registerLazySingleton<ContactsRepository>(
          () => ContactsRepositoryImpl(
        firestore: sl<FirebaseFirestore>(),
      ),
    );

    // Alert UseCases (LazySingleton)
    sl.registerLazySingleton(() => TriggerAlertUseCase(
      sl(),
      smsService: sl<SMSService>(),
      fcmService: sl<FCMService>(),
    ));
    sl.registerLazySingleton(() => EscalateAlertUseCase(sl()));
    sl.registerLazySingleton(() => AcknowledgeAlertUseCase(sl()));
    sl.registerLazySingleton(() => SendSOSUseCase(
      sl(),
      smsService: sl<SMSService>(),
      fcmService: sl<FCMService>(),
    ));
    sl.registerLazySingleton(() => GetActiveAlertsUseCase(sl()));
    sl.registerLazySingleton(() => GetAlertConfigUseCase(sl()));
    sl.registerLazySingleton(() => SaveAlertConfigUseCase(sl()));

    // Contact UseCases (LazySingleton) - تستخدم ContactsRepository
    sl.registerLazySingleton(() => AddContactUseCase(sl<ContactsRepository>()));
    sl.registerLazySingleton(() => UpdateContactUseCase(sl<ContactsRepository>()));
    sl.registerLazySingleton(() => DeleteContactUseCase(sl<ContactsRepository>()));
    sl.registerLazySingleton(() => GetContactsUseCase(sl<ContactsRepository>()));
    sl.registerLazySingleton(() => GetEmergencyContactsUseCase(sl<ContactsRepository>()));
    sl.registerLazySingleton(() => SetPrimaryContactUseCase(sl<ContactsRepository>()));

    // BLoCs (Factory)
    sl.registerFactory(
          () => AlertBloc(
        triggerAlertUseCase: sl(),
        sendSOSUseCase: sl(),
        acknowledgeAlertUseCase: sl(),
        getActiveAlertsUseCase: sl(),
        getAlertConfigUseCase: sl(),
        saveAlertConfigUseCase: sl(),
        getContactsUseCase: sl(),
      ),
    );

    sl.registerFactory(
          () => ContactBloc(
        addContactUseCase: sl(),
        updateContactUseCase: sl(),
        deleteContactUseCase: sl(),
        getContactsUseCase: sl(),
        getEmergencyContactsUseCase: sl(),
        setPrimaryContactUseCase: sl(),
      ),
    );

    AppLogger.info('[DI] ✅ Alerts Feature');

    // ========== Features - Maps ==========

    // Core Services
    sl.registerLazySingleton(() => OfflineMapsManager.instance);

    // Data Sources
    sl.registerLazySingleton<MapsRemoteDataSource>(
      () => MapsRemoteDataSourceImpl(client: sl()),
    );
    
    sl.registerLazySingleton<MapsLocalDataSource>(
      () => MapsLocalDataSourceImpl(hiveService: sl()),
    );

    // Repository
    sl.registerLazySingleton<MapsRepository>(
      () => MapsRepositoryImpl(
        remoteDataSource: sl(),
        localDataSource: sl(),
        connectivityService: sl(),
      ),
    );

    // UseCases - Places
    sl.registerLazySingleton(() => SearchPlacesUseCase(repository: sl()));
    sl.registerLazySingleton(() => SearchNearbyPlacesUseCase(repository: sl()));
    sl.registerLazySingleton(() => GetPlaceAutocompleteSuggestionsUseCase(repository: sl()));
    sl.registerLazySingleton(() => GetNearestPlaceUseCase(repository: sl()));

    // UseCases - Directions
    sl.registerLazySingleton(() => GetDirectionsUseCase(repository: sl()));
    sl.registerLazySingleton(() => GetPolylinePointsUseCase(repository: sl()));
    sl.registerLazySingleton(() => GetAlternativeRoutesUseCase(repository: sl()));

    // BLoCs (Factory)
    sl.registerFactory(() => LocationBloc());
    
    sl.registerFactory(
      () => MapsBloc(
        getDirectionsUseCase: sl(),
        getAlternativeRoutesUseCase: sl(),
        searchPlacesUseCase: sl(),
        searchNearbyPlacesUseCase: sl(),
        getPlaceAutocompleteSuggestionsUseCase: sl(),
        getNearestPlaceUseCase: sl(),
        offlineMapsManager: sl(),
      ),
    );

    // تهيئة RouteCalculatorService مع MapsRepository
    sl<RouteCalculatorService>().initialize(sl<MapsRepository>());

    AppLogger.info('[DI] ✅ Maps Feature');


    AppLogger.success('[DI] تم تهيئة جميع Dependencies بنجاح');
  } catch (e, stackTrace) {
    AppLogger.error('[DI] فشل تهيئة Dependencies', e, stackTrace);
    rethrow;
  }
}

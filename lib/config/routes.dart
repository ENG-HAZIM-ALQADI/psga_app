import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../features/splash/presentation/pages/splash_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/auth/presentation/pages/verify_email_page.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/presentation/bloc/auth_state.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/trips/presentation/pages/routes_list_page.dart';
import '../features/trips/presentation/pages/create_route_page.dart';
import '../features/trips/presentation/pages/route_details_page.dart';
import '../features/trips/presentation/pages/active_trip_page.dart';
import '../features/trips/presentation/pages/trip_history_page.dart';
import '../features/trips/presentation/pages/trip_details_page.dart';
import '../features/trips/presentation/pages/start_trip_page.dart';
import '../features/trips/domain/entities/route_entity.dart';
import '../features/trips/domain/entities/trip_entity.dart';
import '../features/alerts/presentation/pages/emergency_page.dart';
import '../features/alerts/presentation/pages/alert_settings_page.dart';
import '../features/alerts/presentation/pages/alert_history_page.dart';
import '../features/alerts/presentation/pages/contacts_page.dart';
import '../features/alerts/presentation/pages/add_contact_page.dart';
import '../features/alerts/presentation/bloc/alert_bloc.dart';
import '../features/alerts/presentation/bloc/contact_bloc.dart';
import '../features/alerts/domain/entities/contact_entity.dart';
import '../features/maps/presentation/pages/map_page.dart';
import '../features/maps/presentation/pages/select_location_page.dart';
import '../features/maps/presentation/pages/place_search_page.dart';
import '../features/maps/presentation/bloc/map_bloc.dart';
import '../core/di/injection_container.dart';
import '../core/utils/logger.dart';

String? _getUserIdFromAuthBloc(AuthBloc authBloc) {
  final authState = authBloc.state;
  if (authState is AuthSuccess) {
    return authState.user.id;
  }
  return null;
}

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String verifyEmail = '/verify-email';
  static const String home = '/home';
  static const String trip = '/trip';
  static const String tripActive = '/trip/active';
  static const String routes = '/routes';
  static const String routeCreate = '/routes/create';
  static const String routeDetails = '/routes/:id';
  static const String tripHistory = '/trips/history';
  static const String tripDetails = '/trips/:id';
  static const String contacts = '/contacts';
  static const String contactsAdd = '/contacts/add';
  static const String contactsEdit = '/contacts/edit/:id';
  static const String settings = '/settings';
  static const String alertSettings = '/settings/alerts';
  static const String alertHistory = '/alerts/history';
  static const String emergency = '/emergency';
  static const String profile = '/profile';
  static const String map = '/map';
  static const String selectLocation = '/select-location';
  static const String placeSearch = '/place-search';

  static const List<String> publicRoutes = [splash, login, register, forgotPassword, verifyEmail];
  static const List<String> authRoutes = [login, register, forgotPassword];
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter(AuthBloc authBloc) => GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: AppRoutes.splash,
  debugLogDiagnostics: true,
  redirect: (context, state) {
    final authState = authBloc.state;
    final isAuthenticated = authState is AuthSuccess;
    final isOnAuthPage = AppRoutes.publicRoutes.contains(state.matchedLocation);
    
    AppLogger.info('[Router] Redirect check - Path: ${state.matchedLocation}, Auth: $isAuthenticated', name: 'Router');
    
    if (state.matchedLocation == AppRoutes.splash) {
      return null;
    }
    
    if (!isAuthenticated && !isOnAuthPage) {
      AppLogger.info('[Router] Redirecting to login - unauthenticated user on protected route', name: 'Router');
      return AppRoutes.login;
    }
    
    if (isAuthenticated && AppRoutes.authRoutes.contains(state.matchedLocation)) {
      AppLogger.info('[Router] Redirecting to home - authenticated user on auth page', name: 'Router');
      return AppRoutes.home;
    }
    
    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      name: 'splash',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: AppRoutes.login,
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: AppRoutes.register,
      name: 'register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: AppRoutes.forgotPassword,
      name: 'forgotPassword',
      builder: (context, state) => const ForgotPasswordPage(),
    ),
    GoRoute(
      path: AppRoutes.verifyEmail,
      name: 'verifyEmail',
      builder: (context, state) {
        final email = state.uri.queryParameters['email'] ?? '';
        return VerifyEmailPage(email: email);
      },
    ),
    GoRoute(
      path: AppRoutes.home,
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: AppRoutes.routes,
      name: 'routes',
      builder: (context, state) {
        final userId = _getUserIdFromAuthBloc(authBloc);
        if (userId == null) {
          return const _ErrorPage(message: 'يجب تسجيل الدخول أولاً');
        }
        return RoutesListPage(userId: userId);
      },
    ),
    GoRoute(
      path: AppRoutes.routeCreate,
      name: 'routeCreate',
      builder: (context, state) {
        final userId = _getUserIdFromAuthBloc(authBloc);
        if (userId == null) {
          return const _ErrorPage(message: 'يجب تسجيل الدخول أولاً');
        }
        final existingRoute = state.extra as RouteEntity?;
        return CreateRoutePage(userId: userId, existingRoute: existingRoute);
      },
    ),
    GoRoute(
      path: AppRoutes.routeDetails,
      name: 'routeDetails',
      builder: (context, state) {
        final userId = _getUserIdFromAuthBloc(authBloc);
        if (userId == null) {
          return const _ErrorPage(message: 'يجب تسجيل الدخول أولاً');
        }
        final extras = state.extra;
        if (extras == null || extras is! Map<String, dynamic>) {
          return const _ErrorPage(message: 'بيانات المسار غير صالحة');
        }
        final route = extras['route'] as RouteEntity?;
        if (route == null) {
          return const _ErrorPage(message: 'المسار غير موجود');
        }
        return RouteDetailsPage(route: route, userId: userId);
      },
    ),
    GoRoute(
      path: AppRoutes.tripActive,
      name: 'tripActive',
      builder: (context, state) {
        final trip = state.extra;
        if (trip == null || trip is! TripEntity) {
          return const _ErrorPage(message: 'بيانات الرحلة غير صالحة');
        }
        return ActiveTripPage(trip: trip);
      },
    ),
    GoRoute(
      path: AppRoutes.tripHistory,
      name: 'tripHistory',
      builder: (context, state) {
        final userId = _getUserIdFromAuthBloc(authBloc);
        if (userId == null) {
          return const _ErrorPage(message: 'يجب تسجيل الدخول أولاً');
        }
        return TripHistoryPage(userId: userId);
      },
    ),
    GoRoute(
      path: AppRoutes.tripDetails,
      name: 'tripDetails',
      builder: (context, state) {
        final trip = state.extra;
        if (trip == null || trip is! TripEntity) {
          return const _ErrorPage(message: 'بيانات الرحلة غير صالحة');
        }
        return TripDetailsPage(trip: trip);
      },
    ),
    GoRoute(
      path: AppRoutes.trip,
      name: 'trip',
      builder: (context, state) {
        final userId = _getUserIdFromAuthBloc(authBloc);
        if (userId == null) {
          return const _ErrorPage(message: 'يجب تسجيل الدخول أولاً');
        }
        return StartTripPage(userId: userId);
      },
    ),
    GoRoute(
      path: AppRoutes.contacts,
      name: 'contacts',
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => sl<ContactBloc>()),
        ],
        child: const ContactsPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.contactsAdd,
      name: 'contactsAdd',
      builder: (context, state) => BlocProvider(
        create: (_) => sl<ContactBloc>(),
        child: const AddContactPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.contactsEdit,
      name: 'contactsEdit',
      builder: (context, state) {
        final contact = state.extra as ContactEntity?;
        return BlocProvider(
          create: (_) => sl<ContactBloc>(),
          child: AddContactPage(contact: contact),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.settings,
      name: 'settings',
      builder: (context, state) => const _PlaceholderPage(title: 'الإعدادات'),
    ),
    GoRoute(
      path: AppRoutes.alertSettings,
      name: 'alertSettings',
      builder: (context, state) => BlocProvider(
        create: (_) => sl<AlertBloc>(),
        child: const AlertSettingsPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.alertHistory,
      name: 'alertHistory',
      builder: (context, state) => BlocProvider(
        create: (_) => sl<AlertBloc>(),
        child: const AlertHistoryPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.emergency,
      name: 'emergency',
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => sl<AlertBloc>()),
          BlocProvider(create: (_) => sl<ContactBloc>()),
        ],
        child: const EmergencyPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.profile,
      name: 'profile',
      builder: (context, state) => const _PlaceholderPage(title: 'الملف الشخصي'),
    ),
    GoRoute(
      path: AppRoutes.map,
      name: 'map',
      builder: (context, state) => BlocProvider(
        create: (_) => sl<MapBloc>(),
        child: const MapPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.selectLocation,
      name: 'selectLocation',
      builder: (context, state) {
        final initialLocation = state.extra as LatLng?;
        return SelectLocationPage(
          initialLocation: initialLocation,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.placeSearch,
      name: 'placeSearch',
      builder: (context, state) => BlocProvider(
        create: (_) => sl<MapBloc>(),
        child: const PlaceSearchPage(),
      ),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'الصفحة غير موجودة',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text('المسار: ${state.uri.path}'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go(AppRoutes.home),
            child: const Text('العودة للرئيسية'),
          ),
        ],
      ),
    ),
  ),
);

class _PlaceholderPage extends StatelessWidget {
  final String title;

  const _PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text('قيد التطوير...'),
          ],
        ),
      ),
    );
  }
}

class _ErrorPage extends StatelessWidget {
  final String message;

  const _ErrorPage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('خطأ')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('العودة للرئيسية'),
            ),
          ],
        ),
      ),
    );
  }
}

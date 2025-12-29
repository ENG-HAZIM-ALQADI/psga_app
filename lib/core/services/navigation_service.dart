import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/routes.dart';
import '../utils/logger.dart';

class NavigationService {
  NavigationService._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static NavigatorState? get _navigator => navigatorKey.currentState;
  static BuildContext? get context => navigatorKey.currentContext;

  static void navigateTo(String route, {Object? extra}) {
    AppLogger.info('Navigating to: $route', name: 'NavigationService');
    if (context != null) {
      GoRouter.of(context!).push(route, extra: extra);
    }
  }

  static void navigateAndReplace(String route, {Object? extra}) {
    AppLogger.info('Navigating and replacing with: $route', name: 'NavigationService');
    if (context != null) {
      GoRouter.of(context!).pushReplacement(route, extra: extra);
    }
  }

  static void goBack<T>([T? result]) {
    AppLogger.info('Going back', name: 'NavigationService');
    if (_navigator?.canPop() ?? false) {
      _navigator?.pop(result);
    }
  }

  static void navigateToAndClearStack(String route, {Object? extra}) {
    AppLogger.info('Navigating to $route and clearing stack', name: 'NavigationService');
    if (context != null) {
      GoRouter.of(context!).go(route, extra: extra);
    }
  }

  static void goTo(String route, {Object? extra}) {
    AppLogger.info('Going to: $route', name: 'NavigationService');
    if (context != null) {
      GoRouter.of(context!).go(route, extra: extra);
    }
  }

  static bool canPop() {
    return _navigator?.canPop() ?? false;
  }

  static void popUntil(String route) {
    AppLogger.info('Popping until: $route', name: 'NavigationService');
    if (context != null) {
      while (GoRouter.of(context!).canPop()) {
        GoRouter.of(context!).pop();
      }
      GoRouter.of(context!).go(route);
    }
  }

  static void goToHome() {
    goTo(AppRoutes.home);
  }

  static void goToLogin() {
    goTo(AppRoutes.login);
  }

  static void goToSplash() {
    goTo(AppRoutes.splash);
  }
}

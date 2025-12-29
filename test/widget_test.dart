import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psga_app/app.dart';
import 'package:psga_app/core/di/injection_container.dart';
import 'package:psga_app/features/splash/presentation/pages/splash_page.dart';

void main() {
  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDependencies();
  });

  group('PSGAApp Widget Tests', () {
    testWidgets('App loads and renders MaterialApp', (WidgetTester tester) async {
      await tester.pumpWidget(const PSGAApp());
      await tester.pump();
      
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('App has correct title', (WidgetTester tester) async {
      await tester.pumpWidget(const PSGAApp());
      await tester.pump();
      
      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.title, equals('Personal Security Guard'));
    });

    testWidgets('Splash screen is displayed initially', (WidgetTester tester) async {
      await tester.pumpWidget(const PSGAApp());
      await tester.pump();
      
      expect(find.byType(SplashPage), findsOneWidget);
    });

    testWidgets('Splash screen shows app logo icon', (WidgetTester tester) async {
      await tester.pumpWidget(const PSGAApp());
      await tester.pump();
      
      expect(find.byIcon(Icons.security), findsOneWidget);
    });

    testWidgets('Splash screen shows loading indicator', (WidgetTester tester) async {
      await tester.pumpWidget(const PSGAApp());
      await tester.pump();
      
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Splash screen shows app name in Arabic', (WidgetTester tester) async {
      await tester.pumpWidget(const PSGAApp());
      await tester.pump();
      
      expect(find.text('حارسي الشخصي'), findsOneWidget);
    });

    testWidgets('Splash screen navigates to login after delay', (WidgetTester tester) async {
      await tester.pumpWidget(const PSGAApp());
      
      expect(find.byType(SplashPage), findsOneWidget);
      
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      
      expect(find.text('تسجيل الدخول'), findsWidgets);
    });
  });

  group('Theme Tests', () {
    testWidgets('App supports light theme', (WidgetTester tester) async {
      await tester.pumpWidget(const PSGAApp());
      await tester.pump();
      
      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.theme, isNotNull);
    });

    testWidgets('App supports dark theme', (WidgetTester tester) async {
      await tester.pumpWidget(const PSGAApp());
      await tester.pump();
      
      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.darkTheme, isNotNull);
    });
  });

  group('Localization Tests', () {
    testWidgets('App supports Arabic locale', (WidgetTester tester) async {
      await tester.pumpWidget(const PSGAApp());
      await tester.pump();
      
      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.supportedLocales, contains(const Locale('ar')));
    });

    testWidgets('App supports English locale', (WidgetTester tester) async {
      await tester.pumpWidget(const PSGAApp());
      await tester.pump();
      
      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.supportedLocales, contains(const Locale('en')));
    });
  });
}

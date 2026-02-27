import 'dart:convert';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/core/constants/app_dimensions.dart';
import 'package:psga_app/core/constants/app_strings.dart';
import 'package:psga_app/core/errors/exceptions.dart';
import 'package:psga_app/core/services/location_service.dart';
import 'package:psga_app/core/utils/extensions.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:psga_app/features/alerts/presentation/pages/contacts_page.dart';
import 'package:psga_app/features/alerts/presentation/pages/notifications_page.dart';
import 'package:psga_app/features/home/presentation/pages/settings_page.dart';
import 'package:psga_app/features/maps/presentation/widgets/map_helpers.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart';
import 'package:psga_app/features/routes/presentation/bloc/routes_bloc.dart';
import 'package:psga_app/features/routes/presentation/bloc/routes_event.dart';
import 'package:psga_app/features/routes/presentation/bloc/routes_state.dart';
import 'package:psga_app/features/routes/presentation/pages/route_detail_page.dart';
import 'package:psga_app/features/routes/presentation/pages/routes_list_page.dart';
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';
import 'package:psga_app/features/trips/presentation/bloc/trip_bloc.dart';
import 'package:psga_app/features/trips/presentation/bloc/trip_event.dart';
import 'package:psga_app/features/trips/presentation/bloc/trip_state.dart';
import 'package:psga_app/features/trips/presentation/pages/trip_history_page.dart';

// ══════════════════════════════════════════════════════════
// بيانات الطقس
// ══════════════════════════════════════════════════════════
class _WeatherData {
  final double temp;
  final int    code;
  final double wind;
  final double rain;

  const _WeatherData({required this.temp, required this.code,
      required this.wind, required this.rain});

  String desc(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (code == 0)   return l10n.weatherClear;
    if (code <= 3)   return l10n.weatherPartlyCloudy;
    if (code <= 49)  return l10n.weatherFoggy;
    if (code <= 67)  return l10n.weatherRainy;
    if (code <= 77)  return l10n.weatherSnowy;
    if (code <= 82)  return l10n.weatherRainy;
    return l10n.weatherStormy;
  }

  String get emoji {
    if (code == 0)  return '☀️';
    if (code <= 3)  return '⛅';
    if (code <= 49) return '🌫️';
    if (code <= 67) return '🌧️';
    if (code <= 77) return '❄️';
    if (code <= 82) return '🌦️';
    return '⛈️';
  }

  bool get hasWarning =>
      rain > 60 || code >= 51 || wind > 40 || temp > 42 || temp < 0;

  String warningMsg(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (temp > 42)               return l10n.weatherHeatWarning;
    if (code >= 51 && code <= 67) return l10n.weatherHeavyRainWarning;
    if (rain > 60)               return l10n.weatherRainWarning(rain.toInt().toString());
    if (wind > 40)               return l10n.weatherWindWarning(wind.toInt().toString());
    if (temp < 0)                return l10n.weatherColdWarning;
    return '';
  }

  Color get warnColor =>
      (temp > 42 || code >= 95) ? AppColors.red : AppColors.gold;
}

// ══════════════════════════════════════════════════════════
// HomePage
// ══════════════════════════════════════════════════════════
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(listener: (_, s) {
          if (s is Unauthenticated) Navigator.pushReplacementNamed(context, '/login');
        }),
        BlocListener<TripBloc, TripState>(listener: (ctx, s) {
          if (s is TripCompleted) {
            final a = ctx.read<AuthBloc>().state;
            if (a is Authenticated) {
              // إرسال LoadTripHistoryEvent لتحديث السجل فقط - بدون LoadActiveTripEvent هنا
              // لأن active_trip_page يتولى الانتقال لـ TripDetailPage
              ctx.read<TripBloc>().add(LoadTripHistoryEvent(userId: a.user.id));
            }
          }
        }),
      ],
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, auth) {
          if (auth is! Authenticated) {
            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          final uid = auth.user.id;
          final pages = <Widget>[
            DashboardTab(
              onViewAllTrips:   () => setState(() => _idx = 2),
              onViewAllRoutes:  () => setState(() => _idx = 1),
            ),
            RoutesListPage(
              onBack: _idx == 1 ? () => setState(() => _idx = 0) : null,
            ),
            TripHistoryPage(userId: uid),
            ContactsPage(userId: uid),
            const SettingsPage(),
          ];
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: IndexedStack(index: _idx, children: pages),
            bottomNavigationBar: _buildNav(),
          );
        },
      ),
    );
  }

  Widget _buildNav() => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      border: Border(top: BorderSide(color: Theme.of(context).dividerTheme.color ?? AppColors.darkBorder, width: 1)),
    ),
    child: BottomNavigationBar(
      currentIndex: _idx,
      backgroundColor: Colors.transparent,
      elevation: 0,
      onTap: (i) {
        if (i == 0 && _idx != 0) {
          final a = context.read<AuthBloc>().state;
          if (a is Authenticated) {
            context.read<TripBloc>().add(LoadActiveTripEvent(userId: a.user.id));
          }
        }
        setState(() => _idx = i);
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkTextSecondary
          : AppColors.textSecondary,
      selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
      items: [
        BottomNavigationBarItem(icon: const Icon(Icons.home_rounded),      label: AppLocalizations.of(context)!.home),
        BottomNavigationBarItem(icon: const Icon(Icons.route_rounded),      label: AppLocalizations.of(context)!.routes),
        BottomNavigationBarItem(icon: const Icon(Icons.history_rounded),    label: AppLocalizations.of(context)!.trips),
        BottomNavigationBarItem(icon: const Icon(Icons.contacts_rounded),   label: AppLocalizations.of(context)!.contacts),
        BottomNavigationBarItem(icon: const Icon(Icons.settings_rounded),   label: AppLocalizations.of(context)!.settings),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════
// DashboardTab
// ══════════════════════════════════════════════════════════
class DashboardTab extends StatefulWidget {
  final VoidCallback? onViewAllTrips;
  final VoidCallback? onViewAllRoutes;
  const DashboardTab({super.key, this.onViewAllTrips, this.onViewAllRoutes});
  @override State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  List<TripEntity> _trips = [];
  _WeatherData?    _weather;
  bool             _weatherLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { _load(); _fetchWeather(); });
  }

  void _load() {
    final a = context.read<AuthBloc>().state;
    if (a is! Authenticated) return;
    context.read<TripBloc>().add(LoadActiveTripEvent(userId: a.user.id));
    context.read<RoutesBloc>().add(LoadRoutesEvent(userId: a.user.id));
    context.read<TripBloc>().add(LoadTripHistoryEvent(userId: a.user.id, limit: 20));
  }

  /// جلب بيانات الطقس من Open-Meteo (مجاني، لا يحتاج API key)
  Future<void> _fetchWeather() async {
    try {
      setState(() => _weatherLoading = true);
      final loc = await LocationService.instance.getCurrentLocation();
      final lat = loc?.latitude  ?? 24.7136;
      final lon = loc?.longitude ?? 46.6753;

      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,weathercode,windspeed_10m'
        '&hourly=precipitation_probability'
        '&timezone=auto&forecast_days=1',
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final c = d['current'];
        final precip = (d['hourly']['precipitation_probability'] as List)
            .take(6).map((e) => (e as num).toDouble()).toList();
        final avg = precip.isEmpty ? 0.0 : precip.reduce((a, b) => a + b) / precip.length;
        if (mounted) {
          setState(() {
            _weather = _WeatherData(
              temp: (c['temperature_2m'] as num).toDouble(),
              code: c['weathercode'] as int,
              wind: (c['windspeed_10m'] as num).toDouble(),
              rain: avg,
            );
            _weatherLoading = false;
          });
        }
      } else {
        // استخدام NetworkException من exceptions.dart
        throw NetworkException('فشل جلب الطقس: HTTP ${res.statusCode}');
      }
    } on NetworkException catch (e) {
      AppLogger.warning('[Dashboard] خطأ شبكة الطقس: ${e.message}');
      if (mounted) { setState(() => _weatherLoading = false); }
    } on AppException catch (e) {
      AppLogger.warning('[Dashboard] خطأ تطبيق الطقس: ${e.message}');
      if (mounted) { setState(() => _weatherLoading = false); }
    } catch (e) {
      AppLogger.warning('[Dashboard] فشل جلب الطقس', e);
      if (mounted) { setState(() => _weatherLoading = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _appBar(),
      body: BlocListener<TripBloc, TripState>(
        listener: (_, s) {
          if (s is TripHistoryLoaded) setState(() => _trips = s.trips);
        },
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, auth) {
            if (auth is! Authenticated) return const Center(child: CircularProgressIndicator());
            return RefreshIndicator(
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context).cardTheme.color,
              onRefresh: () async { _load(); await _fetchWeather(); },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingMD, AppDimensions.paddingSM,
                AppDimensions.paddingMD, AppDimensions.paddingXXL),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _greeting(auth.user.name),
                  const SizedBox(height: 16),
                  _weatherCard(),
                  const SizedBox(height: 14),
                  _activeTripCard(),
                  const SizedBox(height: 14),
                  _lastRouteShortcut(),
                  const SizedBox(height: 16),
                  _weeklyStats(),
                  const SizedBox(height: 16),
                  _quickActions(),
                  const SizedBox(height: 16),
                  _miniMap(),
                  const SizedBox(height: 16),
                  _recentTrips(),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar() => AppBar(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor, elevation: 0,
    title: Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, AppColors.green]),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
      ),
      const SizedBox(width: 10),
      Text(AppStrings.appName, style: TextStyle(
        color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.darkTextPrimary, fontSize: 20,
        fontWeight: FontWeight.w700, letterSpacing: 1.2,
      )),
    ]),
    actions: [
      IconButton(
        icon: Icon(Icons.notifications_outlined, color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary),
        onPressed: () {
          final a = context.read<AuthBloc>().state;
          if (a is Authenticated) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => NotificationsPage(userId: a.user.id)));
          }
        },
      ),
    ],
  );

  // ─── ترحيب ────────────────────────────────────────────
  Widget _greeting(String name) {
    final h = DateTime.now().hour;
    final l10n = context.l10n;
    final g = h < 12 ? l10n.greetingMorning : h < 17 ? l10n.greetingAfternoon : l10n.greetingEvening;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(g, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary, fontSize: 14)),
      const SizedBox(height: 2),
      Text(name, style: TextStyle(
        color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.darkTextPrimary, fontSize: 26, fontWeight: FontWeight.w700)),
    ]);
  }

  // ─── بطاقة الطقس ──────────────────────────────────────
  Widget _weatherCard() {
    if (_weatherLoading) return _shimmer(100);
    if (_weather == null)  return const SizedBox.shrink();
    final w = _weather!;
    return _card(
      borderColor: w.hasWarning ? w.warnColor.withOpacity(0.45) : Theme.of(context).dividerTheme.color ?? AppColors.darkBorder,
      child: Column(children: [
        Row(children: [
          Text(w.emoji, style: const TextStyle(fontSize: 42)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppLocalizations.of(context)!.tempCelsius(w.temp.toStringAsFixed(1)),
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.darkTextPrimary, fontSize: 30, fontWeight: FontWeight.w700)),
            Text(w.desc(context), style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary, fontSize: 13)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _wChip(Icons.air_rounded, context.l10n.weatherWindSpeed(w.wind.toInt().toString())),
            const SizedBox(height: 6),
            _wChip(Icons.water_drop_outlined, context.l10n.weatherRainChance(w.rain.toInt().toString())),
          ]),
        ]),
        if (w.hasWarning) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: w.warnColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: w.warnColor.withOpacity(0.3)),
            ),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, color: w.warnColor, size: 15),
              const SizedBox(width: 8),
              Expanded(child: Text(w.warningMsg(context),
                style: TextStyle(color: w.warnColor, fontSize: 12, fontWeight: FontWeight.w600))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _wChip(IconData icon, String txt) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary, size: 13),
    const SizedBox(width: 4),
    Text(txt, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary, fontSize: 12)),
  ]);

  // ─── الرحلة النشطة ────────────────────────────────────
  Widget _activeTripCard() {
    return BlocBuilder<TripBloc, TripState>(
      buildWhen: (p, c) =>
          c is TripActive ||
          c is TripPaused ||
          c is NoActiveTrip ||
          c is TripCompleted ||
          c is TripInitial ||
          c is TripOperationSuccess ||
          c is TripStatsUpdated ||
          c is DeviationDetectedState ||
          c is DeviationCountdownState ||
          c is TripEmergencyState ||
          c is TripHistoryLoaded,
      builder: (context, state) {
        // إخفاء البطاقة عند انتهاء الرحلة أو عدم وجود رحلة نشطة
        if (state is TripCompleted ||
            state is NoActiveTrip ||
            state is TripInitial ||
            state is TripOperationSuccess ||
            state is TripHistoryLoaded) {
          return const SizedBox.shrink();
        }
        // استخراج الرحلة من الحالات المختلفة
        TripEntity? trip;
        if (state is TripActive) {
          trip = state.trip;
        } else if (state is TripPaused) {
          trip = state.trip;
        } else if (state is TripStatsUpdated) {
          trip = state.trip;
        } else if (state is DeviationDetectedState) {
          trip = state.trip;
        } else if (state is DeviationCountdownState) {
          trip = state.trip;
        } else if (state is TripEmergencyState) {
          trip = state.trip;
        }
        if (trip == null) return const SizedBox.shrink();
        final paused  = state is TripPaused;
        final elapsed = DateTime.now().difference(trip.startTime);
        final clr     = paused ? AppColors.gold : AppColors.green;
        return GestureDetector(
          onTap: () async {
            await Navigator.pushNamed(context, '/active-trip');
            // عند العودة من شاشة الرحلة النشطة، أعد تحميل الحالة
            if (context.mounted) {
              final auth = context.read<AuthBloc>().state;
              if (auth is Authenticated) {
                context.read<TripBloc>().add(LoadActiveTripEvent(userId: auth.user.id));
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: paused
                    ? [const Color(0xFF2C1A00), const Color(0xFF3D2800)]
                    : [const Color(0xFF0A2818), const Color(0xFF0F3D24)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: clr.withOpacity(0.35)),
            ),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(color: clr.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(paused ? Icons.pause_circle_rounded : Icons.navigation_rounded, color: clr, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(paused ? context.l10n.tripPausedStatus : context.l10n.activeTripNow,
                  style: TextStyle(color: clr, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(trip.route.name, style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.darkTextPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  '${elapsed.inHours > 0 ? context.l10n.tripElapsedTime(elapsed.inHours.toString(), (elapsed.inMinutes % 60).toString()) : context.l10n.tripElapsedMinutes(elapsed.inMinutes.toString())}  •  ${trip.distanceTraveled.toStringAsFixed(1)} ${context.l10n.distanceKm}',
                  style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary, fontSize: 11)),
              ])),
              Icon(Icons.arrow_forward_ios_rounded, color: Theme.of(context).textTheme.bodySmall?.color ?? AppColors.darkTextMuted, size: 15),
            ]),
          ),
        );
      },
    );
  }

  // ─── اختصار آخر مسار ──────────────────────────────────
  Widget _lastRouteShortcut() {
    return BlocBuilder<RoutesBloc, RoutesState>(
      builder: (context, state) {
        if (state is! RoutesLoaded || state.routes.isEmpty) return const SizedBox.shrink();
        final active = state.routes
            .where((r) => r.status == RouteStatus.active)
            .toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (active.isEmpty) return const SizedBox.shrink();
        final r  = active.first;
        // استخدام NumExtensions.formatDistance من extensions.dart
        final distanceM = r.estimatedDistance ?? 0;
        final km = (distanceM / 1000).toStringAsFixed(1);
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => RouteDetailPage(routeId: r.id))),
          child: _card(child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.flash_on_rounded, color: Theme.of(context).colorScheme.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.l10n.startLastRoute, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary, fontSize: 11)),
              const SizedBox(height: 2),
              Text(r.name, style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.darkTextPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(km == '0.0' ? 'ابدأ' : '$km كم',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ])),
        );
      },
    );
  }

  // ─── إحصائيات الأسبوع ─────────────────────────────────
  Widget _weeklyStats() {
    if (_trips.isEmpty) return const SizedBox.shrink();
    final now   = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final week  = _trips.where((t) => t.startTime.isAfter(start) && t.isCompleted).toList();
    final km    = week.fold<double>(0, (s, t) => s + t.distanceTraveled);
    final devs  = week.fold<int>(0, (s, t) => s + t.deviations.length);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.l10n.weeklyStats,
        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _statTile(km.toStringAsFixed(1), 'كم', 'المسافة', Icons.straighten_rounded, Theme.of(context).colorScheme.primary)),
        const SizedBox(width: 10),
        Expanded(child: _statTile(week.length.toString(), '', 'رحلات', Icons.route_rounded, AppColors.green)),
        const SizedBox(width: 10),
        Expanded(child: _statTile(devs.toString(), '', 'انحرافات', Icons.warning_amber_rounded,
          devs > 0 ? AppColors.gold : Theme.of(context).textTheme.bodySmall?.color ?? AppColors.darkTextMuted)),
      ]),
      const SizedBox(height: 10),
      _weekBar(week, start),
    ]);
  }

  Widget _statTile(String val, String unit, String lbl, IconData icon, Color clr) => _card(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: clr, size: 20),
      const SizedBox(height: 8),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(val, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.darkTextPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
        if (unit.isNotEmpty) ...[
          const SizedBox(width: 3),
          Padding(padding: const EdgeInsets.only(bottom: 3),
            child: Text(unit, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary, fontSize: 11))),
        ],
      ]),
      Text(lbl, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary, fontSize: 11)),
    ]),
  );

  Widget _weekBar(List<TripEntity> week, DateTime start) {
    final labels = [
        context.l10n.weekDayMon, context.l10n.weekDayTue, context.l10n.weekDayWed,
        context.l10n.weekDayThu, context.l10n.weekDayFri, context.l10n.weekDaySat, context.l10n.weekDaySun
      ];
    final today  = DateTime.now().weekday - 1;
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.l10n.weeklyActivity, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary, fontSize: 11)),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (i) {
          final day     = start.add(Duration(days: i));
          final hasTrip = week.any((t) => t.startTime.day == day.day && t.startTime.month == day.month);
          final isToday = i == today;
          return Column(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: hasTrip 
                    ? Theme.of(context).colorScheme.primary 
                    : isToday 
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.14) 
                        : Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkShimmer
                            : AppColors.greyLight,
                borderRadius: BorderRadius.circular(8),
                border: isToday ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5) : null,
              ),
              child: hasTrip 
                  ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 16) 
                  : null,
            ),
            const SizedBox(height: 5),
            Text(labels[i], style: TextStyle(
              color: isToday ? Theme.of(context).colorScheme.primary : Theme.of(context).textTheme.bodySmall?.color ?? AppColors.darkTextMuted,
              fontSize: 10,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
            )),
          ]);
        }),
      ),
    ]));
  }

  // ─── اختصارات سريعة ───────────────────────────────────
  Widget _quickActions() => Row(children: [
    Expanded(child: _qBtn(Icons.add_location_alt_rounded, context.l10n.createRoute,  Theme.of(context).colorScheme.primary,
      () => Navigator.pushNamed(context, '/create-route'))),
    const SizedBox(width: 10),
    Expanded(child: _qBtn(Icons.emergency_rounded, context.l10n.sos, AppColors.red,
      () => Navigator.pushNamed(context, '/emergency'))),
    const SizedBox(width: 10),
    Expanded(child: _qBtn(Icons.map_rounded, context.l10n.routes, AppColors.green,
      () => widget.onViewAllRoutes?.call())),
  ]);

  Widget _qBtn(IconData icon, String lbl, Color clr, VoidCallback fn) => GestureDetector(
    onTap: fn,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: clr.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: clr.withOpacity(0.25)),
      ),
      child: Column(children: [
        Icon(icon, color: clr, size: 26),
        const SizedBox(height: 6),
        Text(lbl, style: TextStyle(color: clr, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
      ]),
    ),
  );

  // ─── خريطة مصغّرة ─────────────────────────────────────
  Widget _miniMap() {
    return BlocBuilder<RoutesBloc, RoutesState>(
      builder: (context, state) {
        if (state is! RoutesLoaded) return const SizedBox.shrink();
        final routes = state.routes
            .where((r) => r.status == RouteStatus.active && r.waypoints.length >= 2)
            .take(5).toList();
        if (routes.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(context.l10n.routesMap,
              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            TextButton(
              onPressed: () => widget.onViewAllRoutes?.call(),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary, padding: EdgeInsets.zero,
                minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text(AppLocalizations.of(context)!.routes, style: const TextStyle(fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerTheme.color ?? AppColors.darkBorder),
                borderRadius: BorderRadius.circular(14),
              ),
              child: _MiniMapWidget(routes: routes),
            ),
          ),
        ]);
      },
    );
  }

  // ─── آخر الرحلات ──────────────────────────────────────
  Widget _recentTrips() {
    if (_trips.isEmpty) return const SizedBox.shrink();
    final recent = _trips.take(3).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(context.l10n.recentTrips,
          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        TextButton(
          onPressed: () => widget.onViewAllTrips?.call(),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary, padding: EdgeInsets.zero,
            minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: Text(AppLocalizations.of(context)!.routes, style: const TextStyle(fontSize: 12)),
        ),
      ]),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerTheme.color ?? AppColors.darkBorder),
        ),
        child: Column(
          children: recent.asMap().entries.map((e) => Column(children: [
            _TripRow(trip: e.value),
            if (e.key < recent.length - 1)
              Divider(height: 1, color: Theme.of(context).dividerTheme.color ?? AppColors.darkBorder, indent: 56),
          ])).toList(),
        ),
      ),
    ]);
  }

  // ─── مساعدات ──────────────────────────────────────────
  Widget _card({required Widget child, Color? borderColor}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: borderColor ?? AppColors.darkBorder),
    ),
    child: child,
  );

  Widget _shimmer(double h) {
    final colorScheme = Theme.of(context).colorScheme;
    return _WeatherShimmer(height: h, colorScheme: colorScheme);
  }
}

// ══════════════════════════════════════════════════════════
// خريطة مصغّرة
// ══════════════════════════════════════════════════════════
class _MiniMapWidget extends StatefulWidget {
  final List<RouteEntity> routes;
  const _MiniMapWidget({required this.routes});
  @override State<_MiniMapWidget> createState() => _MiniMapWidgetState();
}

class _MiniMapWidgetState extends State<_MiniMapWidget> {
  GoogleMapController? _ctrl;
  Set<Marker>    _markers   = {};
  Set<Polyline>  _polylines = {};

  static const _colors = [
    Color(0xFF1F6FEB), Color(0xFF238636), Color(0xFFE3B341),
    Color(0xFFDA3633), Color(0xFF8B949E),
  ];

  @override
  void initState() { super.initState(); _build(); }

  void _build() {
    final markers   = <Marker>{};
    final polylines = <Polyline>{};
    for (var i = 0; i < widget.routes.length; i++) {
      final r = widget.routes[i];
      if (r.waypoints.length < 2) continue;
      markers.add(Marker(
        markerId: MarkerId('s_${r.id}'),
        position: LatLng(r.waypoints.first.location.latitude, r.waypoints.first.location.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(i == 0 ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: r.name),
      ));
      polylines.add(Polyline(
        polylineId: PolylineId(r.id),
        points: r.waypoints.map((w) => LatLng(w.location.latitude, w.location.longitude)).toList(),
        color: _colors[i % _colors.length],
        width: 3,
        patterns: i > 0 ? [PatternItem.dash(12), PatternItem.gap(6)] : [],
      ));
    }
    setState(() { _markers = markers; _polylines = polylines; });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.routes.first.waypoints.first.location;
    // استخدام ستايل الخريطة المناسب للثيم الحالي (فاتح/داكن)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: LatLng(c.latitude, c.longitude), zoom: 12),
      markers: _markers, polylines: _polylines,
      style: isDark ? _darkStyle : null, // null = ستايل افتراضي فاتح
      myLocationEnabled: false, myLocationButtonEnabled: false,
      zoomControlsEnabled: false, mapToolbarEnabled: false,
      scrollGesturesEnabled: false, zoomGesturesEnabled: false,
      tiltGesturesEnabled: false, rotateGesturesEnabled: false,
      onMapCreated: (ctrl) {
        _ctrl = ctrl;
        _fit();
      },
    );
  }

  void _fit() async {
    if (_ctrl == null) return;
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      final pts = widget.routes.expand((r) => r.waypoints.map((w) => w.location)).toList();
      final bounds = MapHelpers.calculateBounds(pts);
      await _ctrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 40));
    } catch (e) { AppLogger.warning('[MiniMap] bounds error', e); }
  }

  @override
  void dispose() { _ctrl?.dispose(); super.dispose(); }
}

const _darkStyle = '[{"elementType":"geometry","stylers":[{"color":"#212121"}]},'
  '{"elementType":"labels.icon","stylers":[{"visibility":"off"}]},'
  '{"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},'
  '{"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},'
  '{"featureType":"road","elementType":"geometry","stylers":[{"color":"#373737"}]},'
  '{"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]}]';

// ══════════════════════════════════════════════════════════
// صف رحلة واحدة
// ══════════════════════════════════════════════════════════
class _TripRow extends StatelessWidget {
  final TripEntity trip;
  const _TripRow({required this.trip});

  @override
  Widget build(BuildContext context) {
    final clr = _clr(context, trip.status);
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/trip-detail', arguments: trip.id),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: clr.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(_icon(trip.status), color: clr, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(trip.route.name,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.darkTextPrimary, fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(_date(context, trip.startTime), style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary, fontSize: 11)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${trip.distanceTraveled.toStringAsFixed(1)} ${context.l10n.distanceKm}',
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.darkTextPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            // استخدام DurationExtensions.formatShort من extensions.dart
            Text(
              trip.actualDuration.inHours > 0
                ? '${trip.actualDuration.inHours} س ${trip.actualDuration.inMinutes % 60} د'
                : '${trip.actualDuration.inMinutes % 60} د',
              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary, fontSize: 11)),
          ]),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: Theme.of(context).textTheme.bodySmall?.color ?? AppColors.darkTextMuted, size: 17),
        ]),
      ),
    );
  }

  Color  _clr(BuildContext context, TripStatus s) { switch(s) {
    case TripStatus.completed: return AppColors.green;
    case TripStatus.cancelled: return AppColors.red;
    case TripStatus.active:    return Theme.of(context).colorScheme.primary;
    case TripStatus.paused:    return AppColors.gold;
  }}
  IconData _icon(TripStatus s) { switch(s) {
    case TripStatus.completed: return Icons.check_circle_rounded;
    case TripStatus.cancelled: return Icons.cancel_rounded;
    case TripStatus.active:    return Icons.navigation_rounded;
    case TripStatus.paused:    return Icons.pause_circle_rounded;
  }}
  String _date(BuildContext context, DateTime d) {
    // استخدام DateTimeExtensions من extensions.dart
    final l10n = AppLocalizations.of(context)!;
    if (d.isToday)     return '${l10n.today} ${d.formatTime()}';
    if (d.isYesterday) return '${l10n.yesterday} ${d.formatTime()}';
    final diff = DateTime.now().difference(d);
    if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
    return d.format('dd/MM/yyyy');
  }
}

/// ويدجت تحميل متحرك للطقس
class _WeatherShimmer extends StatefulWidget {
  final double height;
  final ColorScheme colorScheme;
  
  const _WeatherShimmer({required this.height, required this.colorScheme});

  @override
  State<_WeatherShimmer> createState() => _WeatherShimmerState();
}

class _WeatherShimmerState extends State<_WeatherShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.2, end: 0.6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: widget.colorScheme.surfaceContainerHighest.withOpacity(_anim.value),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.colorScheme.primary.withOpacity(0.65),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              l10n?.loading ?? 'جاري تحميل الطقس...',
              style: TextStyle(
                fontSize: 12,
                color: widget.colorScheme.onSurface.withOpacity(0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

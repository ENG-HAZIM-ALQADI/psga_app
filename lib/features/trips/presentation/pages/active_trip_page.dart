// ============================================================================
// 📄 ملف: active_trip_page.dart
// 🏗️ الطبقة: Presentation (عرض البيانات والواجهة)
// 🎯 الوظيفة: صفحة تعرض الرحلة النشطة الحالية مع تتبع الموقع الجغرافي في الوقت الفعلي
//           وكشف الانحرافات عن المسار وإدارة بدء/إيقاف الرحلة
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../maps/data/services/location_service.dart';
import '../../../maps/data/services/deviation_detector.dart';
import '../../../maps/presentation/widgets/deviation_warning.dart';
import '../../domain/entities/deviation_entity.dart';
import '../../domain/entities/trip_entity.dart';
import '../../domain/entities/location_entity.dart';
import '../bloc/trip_bloc.dart';
import '../bloc/trip_event.dart';
import '../bloc/trip_state.dart';
import '../widgets/trip_status_widget.dart';
import '../widgets/deviation_alert_widget.dart';

/// 📌 صفحة الرحلة النشطة (StatefulWidget)
/// الحاجة إلى StatefulWidget: نحتاج هنا لـ initState و dispose لإدارة موارد المؤقت والموقع
class ActiveTripPage extends StatefulWidget {
  final TripEntity trip;

  const ActiveTripPage({super.key, required this.trip});

  @override
  State<ActiveTripPage> createState() => _ActiveTripPageState();
}

class _ActiveTripPageState extends State<ActiveTripPage> {
  // ⚠️ متغيرات إدارة تنبيهات الانحرافات
  bool _showDeviationAlert = false;
  DeviationEntity? _currentDeviation;
  DeviationResult? _mapDeviation;
  
  // ⏱️ متغيرات المؤقت والوقت المنقضي
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;
  DateTime? _startTime;
  DateTime? _pauseTime;
  Duration _pausedDuration = Duration.zero;
  
  // 📊 متغيرات إحصائيات الرحلة
  double _currentDistance = 0.0;
  double _currentSpeed = 0.0;
  bool _isPaused = false;

  // 🌍 خدمات الموقع والكشف عن الانحرافات
  final LocationService _locationService = LocationService();
  final DeviationDetector _deviationDetector = DeviationDetector();
  GoogleMapController? _mapController;
  
  // 🗺️ بيانات الخريطة والموقع
  LatLng? _currentLocation;
  final List<LatLng> _trackingHistory = [];
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  
  // 📡 قناة الاستماع لتحديثات الموقع (StreamSubscription)
  /// ⚠️ أهمية إغلاقها: الـ Streams تفتح قناة استماع دائمة على البيانات
  /// يجب إغلاقها يدوياً في dispose() لتجنب تسريب الذاكرة (Memory Leaks)
  StreamSubscription? _locationSubscription;

  @override
  void initState() {
    /// 🔧 تهيئة حالة الـ Widget
    /// initState يُستدعى مرة واحدة فقط عند إنشاء الـ Widget
    super.initState();
    _startTime = widget.trip.startTime;
    _elapsedTime = DateTime.now().difference(widget.trip.startTime);
    _currentDistance = widget.trip.totalDistance;
    _currentSpeed = widget.trip.averageSpeed;
    _isPaused = widget.trip.status == TripStatus.paused;
    
    _initializeMap();
    
    if (!_isPaused) {
      _startTimer();
      _startLocationTracking();
    }
  }

  Future<void> _initializeMap() async {
    final hasPermission = await _locationService.checkPermissions();
    if (!hasPermission) return;

    final position = await _locationService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _trackingHistory.add(_currentLocation!);
      });
      _setupRouteOnMap();
    }
  }

  void _setupRouteOnMap() {
    // استخدام المسار من TripEntity إذا كان متاحاً
    final route = widget.trip.route;
    final routePoints = <LatLng>[];
    
    if (route != null && route.waypoints.isNotEmpty) {
      // استخدام نقاط المسار المخزنة
      for (final waypoint in route.allWaypoints) {
        routePoints.add(LatLng(
          waypoint.location.latitude,
          waypoint.location.longitude,
        ));
      }
    } else if (widget.trip.startLocation.latitude != 0) {
      // إذا لم يكن هناك مسار، استخدام نقطة البداية فقط
      routePoints.add(LatLng(
        widget.trip.startLocation.latitude,
        widget.trip.startLocation.longitude,
      ));
    }

    if (routePoints.isNotEmpty) {
      _deviationDetector.setRoute(routePoints);
      _deviationDetector.setThreshold(100);

      setState(() {
        _polylines.add(Polyline(
          polylineId: const PolylineId('route'),
          points: routePoints,
          color: Colors.blue,
          width: 5,
        ));

        _markers.add(Marker(
          markerId: const MarkerId('start'),
          position: routePoints.first,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'نقطة البداية'),
        ));

        if (routePoints.length > 1) {
          _markers.add(Marker(
            markerId: const MarkerId('end'),
            position: routePoints.last,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(title: 'نقطة النهاية'),
          ));
        }
      });
    }
  }

  /// 🌍 بدء تتبع الموقع الجغرافي
  /// هذه الدالة تفتح "قناة استماع دائمة" (Stream) على موقع المستخدم
  void _startLocationTracking() async {
    /// ⏳ await تعني "انتظر حتى تنتهي العملية ثم تابع"
    /// startTracking() تأخذ وقتاً للبحث عن الموقع
    await _locationService.startTracking();
    
    /// 📡 StreamSubscription: قناة استماع مستمرة تستقبل تحديثات الموقع
    /// هذا الـ Stream ينبض بالبيانات كل مرة يتحرك الموقع
    /// ⚠️ IMPORTANT: يجب إغلاق هذه القناة في dispose() لتجنب تسريب الذاكرة
    _locationSubscription = _locationService.positionStream.listen((position) {
      /// 💡 mounted: هل الـ Widget لا يزال موجوداً في الشاشة؟
      /// إذا كانت الصفحة أُغلقت بالفعل، لا نقوم بـ setState
      if (!mounted) return;

      final newLocation = LatLng(position.latitude, position.longitude);
      _trackingHistory.add(newLocation);

      if (_deviationDetector.hasRoute()) {
        final deviation = _deviationDetector.checkDeviation(newLocation);
        if (deviation.isDeviated) {
          setState(() {
            _mapDeviation = deviation;
          });
          AppLogger.warning('[ActiveTrip] انحراف: ${deviation.distanceFromRoute.round()} متر');
        } else {
          setState(() {
            _mapDeviation = null;
          });
        }
      }

      setState(() {
        _currentLocation = newLocation;
        _updateTrackingPolyline();
      });

      _animateToLocation(newLocation);

      /// 🎯 context.read() vs context.watch():
      /// - context.read(): نريد تنفيذ عملية (add Event) بدون الاستماع للتغييرات - لا يعيد بناء الـ Widget
      /// - context.watch(): نريد الاستماع للتغييرات وإعادة بناء الـ Widget عند كل تحديث
      context.read<TripBloc>().add(UpdateLocation(
        tripId: widget.trip.id,
        location: LocationEntity(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: DateTime.now(),
          accuracy: position.accuracy,
        ),
      ));
    });
  }

  void _updateTrackingPolyline() {
    _polylines.removeWhere((p) => p.polylineId.value == 'tracking');
    _polylines.add(Polyline(
      polylineId: const PolylineId('tracking'),
      points: _trackingHistory,
      color: Colors.green,
      width: 4,
    ));
  }

  void _animateToLocation(LatLng location) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: location, zoom: 16),
      ),
    );
  }

  @override
  void dispose() {
    /// 🧹 تنظيف موارد الـ Widget
    /// ⚠️ أهمية غاية القصوى: يجب إغلاق كل ما فتحناه لتجنب تسريب الذاكرة
    _timer?.cancel();                    // إيقاف المؤقت الدوري
    _locationSubscription?.cancel();     // إغلاق قناة الاستماع على الموقع
    _locationService.stopTracking();     // إيقاف خدمة تتبع الموقع
    _mapController?.dispose();           // تحرير موارد متحكم الخريطة
    super.dispose();                     // استدعاء dispose الأساسي
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) {
        setState(() {
          _elapsedTime = DateTime.now().difference(_startTime!) - _pausedDuration;
        });
      }
    });
  }

  void _pauseTimer() {
    AppLogger.info('[ActiveTrip] إيقاف المؤقت والموقع', name: 'ActiveTrip');
    _isPaused = true;
    _pauseTime = DateTime.now();
    _timer?.cancel();
    _locationSubscription?.cancel();
    _locationService.stopTracking();
  }

  void _resumeTimer() {
    AppLogger.info('[ActiveTrip] استئناف المؤقت والموقع', name: 'ActiveTrip');
    if (_pauseTime != null) {
      _pausedDuration += DateTime.now().difference(_pauseTime!);
    }
    _isPaused = false;
    _startTimer();
    _startLocationTracking();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    /// 🎯 BlocConsumer يجمع بين BlocBuilder (لإعادة رسم الواجهة) و BlocListener (للعمليات الجانبية)
    /// 📌 الفرق المهم:
    /// - BlocBuilder: يعيد بناء الـ Widget عند تغيير الحالة
    /// - BlocListener: ينفذ أكواد جانبية (SnackBar, Navigation) بدون إعادة بناء
    /// - listenWhen: يسمح بتنقية الحالات - نستمع فقط للحالات المهمة
    return BlocConsumer<TripBloc, TripState>(
      listenWhen: (previous, current) =>
          current is TripActive ||
          current is TripPaused ||
          current is TripCompleted ||
          current is TripError ||
          current is TripOperationSuccess,
      listener: (context, state) {
        /// 📡 هنا نستمع للتغييرات من BLoC ونقوم بعمليات جانبية (side effects)
        if (state is TripCompleted) {
          AppLogger.success('[ActiveTrip] تم إنهاء الرحلة من BLoC', name: 'ActiveTrip');
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إنهاء الرحلة بنجاح')),
          );
          Navigator.pop(context);
        } else if (state is TripPaused) {
          // ✅ فقط إيقاف إذا كانت الرحلة غير موقوفة بالفعل
          if (!_isPaused) {
            AppLogger.info('[ActiveTrip] الاستجابة لحالة TripPaused من BLoC', name: 'ActiveTrip');
            _pauseTimer();
            setState(() {
              _isPaused = true;
            });
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم إيقاف الرحلة مؤقتاً'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else if (state is TripActive) {
          // ✅ فقط استئناف إذا كانت الرحلة موقوفة بالفعل
          if (_isPaused) {
            AppLogger.info('[ActiveTrip] الاستجابة لحالة TripActive من BLoC', name: 'ActiveTrip');
            _resumeTimer();
            setState(() {
              _isPaused = false;
            });
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم استئناف الرحلة'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else if (state is TripOperationSuccess) {
          AppLogger.success('[ActiveTrip] عملية ناجحة: ${state.message}', name: 'ActiveTrip');
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (state is TripError) {
          AppLogger.error('[ActiveTrip] خطأ: ${state.message}', name: 'ActiveTrip');
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        } else if (state is DeviationDetected) {
          AppLogger.warning('[ActiveTrip] تم اكتشاف انحراف: ${state.deviation.distanceFromRoute} متر', name: 'ActiveTrip');
          setState(() {
            _showDeviationAlert = true;
            _currentDeviation = state.deviation;
          });
        }
      },
      builder: (context, state) {
        final currentTrip = state is TripActive 
            ? state.trip 
            : (state is TripPaused ? state.trip : widget.trip);

        return Scaffold(
          body: Stack(
            children: [
              _buildMap(theme),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => _showExitConfirmation(context),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentTrip.routeName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    TripStatusWidget(
                                      status: _isPaused ? TripStatus.paused : currentTrip.status,
                                      showLabel: true,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${_calculateRemainingDistance(currentTrip).toStringAsFixed(1)} كم متبقي',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_mapDeviation != null && _mapDeviation!.isDeviated)
                DeviationWarning(
                  deviation: _mapDeviation!,
                  onDismiss: () {
                    setState(() {
                      _mapDeviation = null;
                    });
                  },
                ),
              if (_showDeviationAlert && _currentDeviation != null)
                Positioned(
                  top: 100,
                  left: 0,
                  right: 0,
                  child: DeviationAlertWidget(
                    deviation: _currentDeviation!,
                    onImOkay: () {
                      AppLogger.info('[ActiveTrip] المستخدم أكد أنه بخير', name: 'ActiveTrip');
                      setState(() {
                        _showDeviationAlert = false;
                        _currentDeviation = null;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم تأكيد سلامتك'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    onDismiss: () {
                      AppLogger.info('[ActiveTrip] تم إخفاء تنبيه الانحراف', name: 'ActiveTrip');
                      setState(() {
                        _showDeviationAlert = false;
                        _currentDeviation = null;
                      });
                    },
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildControlButtons(context, currentTrip),
                        _buildLiveStatsBar(theme),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 230,
                child: Column(
                  children: [
                    _buildMapControlButton(
                      icon: Icons.my_location,
                      onPressed: () {
                        if (_currentLocation != null) {
                          _animateToLocation(_currentLocation!);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSOSButton(context),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 🗺️ بناء عنصر الخريطة
  /// GoogleMap: عنصر يعرض الخريطة التفاعلية مع تتبع الموقع الحي
  Widget _buildMap(ThemeData theme) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _currentLocation ?? const LatLng(24.7136, 46.6753),
        zoom: 15,
      ),
      onMapCreated: (controller) {
        /// 💾 حفظ متحكم الخريطة لاستخدامه لاحقاً
        /// مثل: تحريك الكاميرا، إضافة markers، إلخ
        _mapController = controller;
      },
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        color: Colors.grey[700],
      ),
    );
  }

  Widget _buildLiveStatsBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            theme,
            icon: Icons.speed,
            value: _currentSpeed.toStringAsFixed(0),
            unit: 'كم/س',
            label: 'السرعة',
          ),
          _buildDivider(theme),
          _buildStatItem(
            theme,
            icon: Icons.straighten,
            value: _currentDistance.toStringAsFixed(1),
            unit: 'كم',
            label: 'المسافة',
          ),
          _buildDivider(theme),
          _buildStatItem(
            theme,
            icon: Icons.timer,
            value: _formatDuration(_elapsedTime),
            unit: '',
            label: 'الوقت',
            isHighlighted: !_isPaused,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    ThemeData theme, {
    required IconData icon,
    required String value,
    required String unit,
    required String label,
    bool isHighlighted = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: isHighlighted ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isHighlighted ? theme.colorScheme.primary : null,
              ),
            ),
            if (unit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2, right: 2),
                child: Text(
                  unit,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Container(
      height: 40,
      width: 1,
      color: theme.dividerColor,
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildControlButtons(BuildContext context, TripEntity currentTrip) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: CustomButton(
              text: _isPaused ? 'استئناف' : 'إيقاف مؤقت',
              icon: _isPaused ? Icons.play_arrow : Icons.pause,
              isOutlined: true,
              onPressed: () {
                // ✅ السماح فقط لـ BLoC بالتحكم في حالة المؤقت
                if (_isPaused) {
                  AppLogger.info('[ActiveTrip] الضغط على زر الاستئناف', name: 'ActiveTrip');
                  context.read<TripBloc>().add(ResumeTrip(currentTrip.id));
                } else {
                  AppLogger.info('[ActiveTrip] الضغط على زر الإيقاف المؤقت', name: 'ActiveTrip');
                  context.read<TripBloc>().add(PauseTrip(currentTrip.id));
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CustomButton(
              text: 'إنهاء الرحلة',
              icon: Icons.stop,
              onPressed: () => _endTrip(context, currentTrip),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSOSButton(BuildContext context) {
    return FloatingActionButton.large(
      backgroundColor: Colors.red,
      onPressed: () => _triggerSOS(context),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sos, size: 32, color: Colors.white),
          Text(
            'طوارئ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مغادرة الرحلة'),
        content: const Text('هل تريد إنهاء الرحلة أو إلغاءها؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('متابعة الرحلة'),
          ),
          TextButton(
            onPressed: () {
              context.read<TripBloc>().add(CancelTrip(widget.trip.id));
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('إلغاء الرحلة', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  void _endTrip(BuildContext context, TripEntity currentTrip) {
    _timer?.cancel();
    _locationSubscription?.cancel();
    _locationService.stopTracking();
    
    final endLocation = _currentLocation != null
        ? LocationEntity(
            latitude: _currentLocation!.latitude,
            longitude: _currentLocation!.longitude,
            timestamp: DateTime.now(),
          )
        : currentTrip.currentLocation ?? LocationEntity(
            latitude: 24.7636,
            longitude: 46.7253,
            timestamp: DateTime.now(),
          );

    context.read<TripBloc>().add(EndTrip(
      tripId: currentTrip.id,
      endLocation: endLocation,
    ));
    
    AppLogger.info('[ActiveTrip] إنهاء الرحلة - المدة: ${_formatDuration(_elapsedTime)}, المسافة: ${_currentDistance.toStringAsFixed(2)} كم', name: 'ActiveTrip');
  }

  void _triggerSOS(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade50,
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('تنبيه طوارئ', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: const Text(
          'سيتم إرسال تنبيه طوارئ لجهات الاتصال المحددة مع موقعك الحالي.\n\nهل أنت متأكد؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم إرسال تنبيه الطوارئ'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('تأكيد الطوارئ'),
          ),
        ],
      ),
    );
  }

  double _calculateRemainingDistance(TripEntity trip) {
    if (_currentLocation == null) return 5.0;
    final distance = _deviationDetector.calculateDistanceToRoute(_currentLocation!);
    
    return distance.clamp(0.0, 5.0);
  }
}

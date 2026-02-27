import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart' as route_entity;
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';
import 'package:psga_app/features/trips/domain/entities/deviation.dart';
import 'package:psga_app/features/maps/presentation/widgets/map_widget.dart';

/// Widget خريطة متقدم للرحلات مع المسارات والانحرافات
class TripMapWidget extends StatefulWidget {
  final TripEntity? trip;
  final route_entity.RouteEntity? route;
  final Location? currentLocation;
  final List<Location> actualTrack; // المسار الفعلي المقطوع
  final List<Deviation>? deviations;
  final bool showDeviationMarkers;
  final bool showDirectionArrow;
  final bool showActualTrack;
  final bool showPlannedRoute;
  final bool autoCenter; // التوسط التلقائي على الموقع
  final bool showFullRoute; // عرض المسار كامل عند التحميل
  final double height;
  final VoidCallback? onDeviationTap;
  final Function(Location)? onLocationUpdate;
  final Function(GoogleMapController)? onMapCreated; // ✅ إضافة callback

  const TripMapWidget({
    this.trip,
    this.route,
    this.currentLocation,
    this.actualTrack = const [],
    this.deviations,
    this.showDeviationMarkers = true,
    this.showDirectionArrow = true,
    this.showActualTrack = true,
    this.showPlannedRoute = true,
    this.autoCenter = false,
    this.showFullRoute = false,
    this.height = 300,
    this.onDeviationTap,
    this.onLocationUpdate,
    this.onMapCreated, // ✅ إضافة callback
    super.key,
  }) : assert(trip != null || route != null, 'يجب توفير trip أو route');

  @override
  State<TripMapWidget> createState() => _TripMapWidgetState();
}

class _TripMapWidgetState extends State<TripMapWidget> {

  GoogleMapController? _controller;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Set<Circle> _circles = {};
  Location? _lastLocation;
  MapType _mapType = MapType.normal;
  Timer? _updateTimer; // ✅ مؤقت للتحديث الدوري

  // الحصول على المسار
  route_entity.RouteEntity get _route => widget.trip?.route ?? widget.route!;
  
  // الحصول على الموقع الحالي
  Location? get _currentLocation => 
      widget.currentLocation ?? 
      widget.trip?.currentLocation ?? 
      widget.actualTrack.lastOrNull;

  // الحصول على المسار الفعلي
  List<Location> get _actualTrack => 
      widget.actualTrack.isNotEmpty 
          ? widget.actualTrack 
          : (widget.trip?.locationHistory ?? []);

  // الحصول على الانحرافات
  List<Deviation> get _deviations => 
      widget.deviations ?? widget.trip?.deviations ?? [];

  // الانحراف الحالي
  Deviation? get _currentDeviation => widget.trip?.currentDeviation;



  @override
  void initState() {
    super.initState();
    _setupMapElements();
    
    // ✅ بدء تحديث دوري للإحصائيات كل ثانية
    if (widget.trip != null) {
      _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            // تحديث الإحصائيات فقط
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel(); // ✅ إيقاف المؤقت
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TripMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // تحديث العناصر عند تغيير البيانات
    if (oldWidget.trip != widget.trip ||
        oldWidget.route != widget.route ||
        oldWidget.currentLocation != widget.currentLocation ||
        oldWidget.actualTrack != widget.actualTrack ||
        oldWidget.deviations != widget.deviations) {
      _setupMapElements();
      
      // التوسط التلقائي فقط إذا تغير الموقع
      if (widget.autoCenter && _currentLocation != null) {
        if (_lastLocation == null || 
            _lastLocation!.distanceTo(_currentLocation!) > 10) { // 10 متر
          _centerOnCurrentLocation();
          _lastLocation = _currentLocation;
        }
      }
    }
  }

  void _setupMapElements() {
    setState(() {
      _markers = _buildMarkers();
      _polylines = _buildPolylines();
      _circles = _buildCircles();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_route.waypoints.length < 2) {
      return Container(
        height: widget.height,
        color: Colors.grey[200],
        child: Center(
          child: Text(AppLocalizations.of(context)!.routeNeedsPoints),
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          // الخريطة
          MapWidget(
            initialLocation: _currentLocation ?? _route.startLocation!,
            initialZoom: 14,
            markers: _markers,
            polylines: _polylines,
            circles: _circles,
            mapType: _mapType,
            myLocationEnabled: false, // نستخدم marker مخصص
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _controller = controller;
              
              // ✅ استدعاء callback إذا كان موجوداً
              widget.onMapCreated?.call(controller);
              
              // عرض المسار كامل إذا كان مطلوباً، وإلا التوسط على الموقع الحالي
              if (widget.showFullRoute) {
                _fitMapToRoute();
              } else if (_currentLocation != null) {
                _centerOnCurrentLocation();
              } else {
                _fitMapToRoute();
              }
            },
          ),

          // تنبيه الانحراف (إذا كان موجوداً)
          if (_currentDeviation != null && 
              _currentDeviation!.severity != DeviationSeverity.none)
            _buildDeviationOverlay(),

          // سهم الاتجاه للعودة للمسار
          if (widget.showDirectionArrow && 
              _currentDeviation != null && 
              _currentLocation != null)
            _buildDirectionArrow(),

          // أزرار التحكم
          Positioned(
            top: 8,
            right: 8,
            child: Column(
              children: [
                // نوع الخريطة
                _buildMapButton(
                  icon: Icons.layers,
                  onPressed: _showMapTypeDialog,
                  tooltip: AppLocalizations.of(context)!.mapType,
                ),
                const SizedBox(height: 8),
                // زر تكبير الخريطة (ملء الشاشة)
                _buildMapButton(
                  icon: Icons.fullscreen,
                  onPressed: _openFullscreenMap,
                  tooltip: 'ملء الشاشة',
                ),
                const SizedBox(height: 8),
                // زر موقعي
                if (_currentLocation != null)
                  _buildMapButton(
                    icon: Icons.my_location,
                    onPressed: _centerOnCurrentLocation,
                    tooltip: 'موقعي',
                  ),
                const SizedBox(height: 8),
                // زر عرض المسار كامل
                _buildMapButton(
                  icon: Icons.zoom_out_map,
                  onPressed: _fitMapToRoute,
                  tooltip: 'عرض المسار',
                ),
                // ملاحظة: تم إزالة أزرار التكبير/التصغير من هنا
                // لأنها متوفرة في وضع ملء الشاشة فقط
              ],
            ),
          ),

          // معلومات سريعة
          if (widget.trip != null)
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: _buildQuickInfo(),
            ),

          // عداد الانحرافات
          if (_deviations.isNotEmpty)
            Positioned(
              top: 8,
              left: 8,
              child: _buildDeviationCounter(),
            ),
        ],
      ),
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(4),
      elevation: 4,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Tooltip(
          message: tooltip ?? '',
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 22, color: Colors.grey[800]),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickInfo() {
    final trip = widget.trip!;
    
    // ✅ حساب المسافة المتبقية
    final totalDistance = _calculateTotalRouteDistance();
    final remainingDistance = totalDistance > 0 
        ? (totalDistance - trip.distanceTraveled).clamp(0, totalDistance)
        : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // المسافة المقطوعة
          _buildInfoItem(
            Icons.straighten,
            '${(trip.distanceTraveled / 1000).toStringAsFixed(1)} كم',
            'مقطوعة',
          ),
          _buildDivider(),
          // ✅ المسافة المتبقية
          _buildInfoItem(
            Icons.route,
            '${(remainingDistance / 1000).toStringAsFixed(1)} كم',
            'متبقية',
            color: remainingDistance < 500 ? Colors.green : AppColors.primary,
          ),
          _buildDivider(),
          // الوقت
          _buildInfoItem(
            Icons.access_time,
            _formatDuration(trip.actualDuration),
            'الوقت',
          ),
          if (trip.calculateCurrentSpeed() != null) ...[
            _buildDivider(),
            _buildInfoItem(
              Icons.speed,
              '${trip.calculateCurrentSpeed()!.toStringAsFixed(0)} كم/س',
              'السرعة',
            ),
          ],
          // ✅ ETA
          if (trip.calculateETA() != null) ...[
            _buildDivider(),
            _buildInfoItem(
              Icons.schedule,
              _formatDuration(trip.calculateETA()!),
              'ETA',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.grey[300],
    );
  }

  Widget _buildInfoItem(IconData icon, String value, String label, {Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color ?? AppColors.primary),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDeviationCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: _getDeviationCountColor(),
          ),
          const SizedBox(width: 6),
          Text(
            '${_deviations.length} انحراف',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _getDeviationCountColor(),
            ),
          ),
        ],
      ),
    );
  }

  Color _getDeviationCountColor() {
    if (_deviations.isEmpty) return Colors.green;
    
    final maxSeverity = _deviations
        .map((d) => d.severity)
        .reduce((a, b) => a.index > b.index ? a : b);
    
    return _getSeverityColor(maxSeverity);
  }

  /// بناء العلامات (Markers)
  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // علامة البداية (خضراء)
    markers.add(_createMarker(
      id: 'start',
      location: _route.waypoints.first.location,
      title: 'نقطة البداية',
      snippet: _route.waypoints.first.name,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    ));

    // علامة النهاية (حمراء)
    markers.add(_createMarker(
      id: 'end',
      location: _route.waypoints.last.location,
      title: 'نقطة النهاية',
      snippet: _route.waypoints.last.name,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    ));

    // النقاط الوسيطة (برتقالية)
    for (int i = 1; i < _route.waypoints.length - 1; i++) {
      final waypoint = _route.waypoints[i];
      final isVisited = widget.trip?.visitedWaypointIds.contains(waypoint.id) ?? false;
      
      markers.add(_createMarker(
        id: 'waypoint_$i',
        location: waypoint.location,
        title: waypoint.name,
        snippet: isVisited ? '✓ تم الزيارة' : 'نقطة ${i + 1}',
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isVisited ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange,
        ),
      ));
    }

    // علامات الانحراف (حمراء داكنة)
    if (widget.showDeviationMarkers) {
      for (int i = 0; i < _deviations.length; i++) {
        final deviation = _deviations[i];
        if (deviation.severity == DeviationSeverity.critical ||
            deviation.severity == DeviationSeverity.high) {
          markers.add(_createMarker(
            id: 'deviation_$i',
            location: deviation.deviationLocation,
            title: 'انحراف ${_getSeverityText(deviation.severity)}',
            snippet: 'المسافة: ${deviation.distance.toStringAsFixed(0)}م',
            icon: BitmapDescriptor.defaultMarkerWithHue(330), // أحمر داكن
            onTap: widget.onDeviationTap,
          ));
        }
      }
    }

    // الموقع الحالي (أزرق)
    if (_currentLocation != null) {
      markers.add(_createMarker(
        id: 'current',
        location: _currentLocation!,
        title: 'موقعك الحالي',
        snippet: 'السرعة: ${widget.trip?.calculateCurrentSpeed()?.toStringAsFixed(0) ?? '0'} كم/س',
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

    return markers;
  }

  Marker _createMarker({
    required String id,
    required Location location,
    required String title,
    String? snippet,
    BitmapDescriptor? icon,
    VoidCallback? onTap,
  }) {
    return Marker(
      markerId: MarkerId(id),
      position: LatLng(location.latitude, location.longitude),
      infoWindow: InfoWindow(
        title: title,
        snippet: snippet,
      ),
      icon: icon ?? BitmapDescriptor.defaultMarker,
      onTap: onTap,
    );
  }

  /// بناء الخطوط (Polylines)
  Set<Polyline> _buildPolylines() {
    final polylines = <Polyline>{};

    // المسار المحدد (أزرق)
    if (widget.showPlannedRoute) {
      polylines.add(Polyline(
        polylineId: const PolylineId('planned_route'),
        points: _route.waypoints
            .map((w) => LatLng(w.location.latitude, w.location.longitude))
            .toList(),
        color: AppColors.primary,
        width: 5,
        geodesic: true,
      ));
    }

    // المسار الفعلي المقطوع (أخضر)
    if (widget.showActualTrack && _actualTrack.length >= 2) {
      polylines.add(Polyline(
        polylineId: const PolylineId('actual_track'),
        points: _actualTrack
            .map((l) => LatLng(l.latitude, l.longitude))
            .toList(),
        color: AppColors.success,
        width: 4,
        geodesic: true,
      ));
    }

    // خط الانحراف الحالي (أحمر متقطع)
    if (_currentDeviation != null && _currentLocation != null) {
      final nearestPoint = _currentDeviation!.nearestPointOnRoute;
      polylines.add(Polyline(
        polylineId: const PolylineId('deviation_line'),
        points: [
          LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
          LatLng(nearestPoint.latitude, nearestPoint.longitude),
        ],
        color: AppColors.error,
        width: 3,
        patterns: [
          PatternItem.dash(20),
          PatternItem.gap(10),
        ],
      ));
    }

    // خطوط الانحرافات السابقة (رمادي منقط)
    if (widget.showDeviationMarkers) {
      for (int i = 0; i < _deviations.length; i++) {
        final deviation = _deviations[i];
        if (deviation.severity == DeviationSeverity.medium ||
            deviation.severity == DeviationSeverity.low) {
          polylines.add(Polyline(
            polylineId: PolylineId('old_deviation_$i'),
            points: [
              LatLng(deviation.deviationLocation.latitude,
                  deviation.deviationLocation.longitude),
              LatLng(deviation.nearestPointOnRoute.latitude,
                  deviation.nearestPointOnRoute.longitude),
            ],
            color: Colors.grey,
            width: 2,
            patterns: [
              PatternItem.dash(15),
              PatternItem.gap(8),
            ],
          ));
        }
      }
    }

    return polylines;
  }

  /// بناء الدوائر (Circles)
  Set<Circle> _buildCircles() {
    final circles = <Circle>{};

    // دائرة حول الموقع الحالي (دقة GPS)
    if (_currentLocation != null && _currentLocation!.accuracy != null) {
      circles.add(Circle(
        circleId: const CircleId('accuracy'),
        center: LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
        radius: _currentLocation!.accuracy!,
        fillColor: AppColors.primary.withOpacity(0.1),
        strokeColor: AppColors.primary,
        strokeWidth: 1,
      ));
    }

    // دوائر حول نقاط الانحراف الحرجة
    if (widget.showDeviationMarkers) {
      for (int i = 0; i < _deviations.length; i++) {
        final deviation = _deviations[i];
        if (deviation.severity == DeviationSeverity.critical) {
          circles.add(Circle(
            circleId: CircleId('deviation_circle_$i'),
            center: LatLng(
              deviation.deviationLocation.latitude,
              deviation.deviationLocation.longitude,
            ),
            radius: 50,
            fillColor: AppColors.error.withOpacity(0.2),
            strokeColor: AppColors.error,
            strokeWidth: 2,
          ));
        }
      }
    }

    return circles;
  }

  /// بناء تنبيه الانحراف
  Widget _buildDeviationOverlay() {
    final deviation = _currentDeviation!;
    final color = _getSeverityColor(deviation.severity);

    return Positioned(
      top: widget.trip != null ? 60 : 8,
      left: 8,
      right: 70,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.95),
        child: InkWell(
          onTap: widget.onDeviationTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'انحراف ${_getSeverityText(deviation.severity)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${deviation.distance.toStringAsFixed(0)} م من المسار',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onDeviationTap != null)
                  const Icon(Icons.chevron_right, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// بناء سهم الاتجاه
  Widget _buildDirectionArrow() {
    final deviation = _currentDeviation!;
    final angle = _calculateBearing(
      _currentLocation!,
      deviation.nearestPointOnRoute,
    );

    return Positioned(
      bottom: widget.trip != null ? 70 : 16,
      right: 16,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: angle * math.pi / 180,
              child: const Icon(
                Icons.navigation_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            Positioned(
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${deviation.distance.toStringAsFixed(0)}م',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// حساب الاتجاه بين نقطتين (بالدرجات)
  double _calculateBearing(Location from, Location to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  /// تكبير الخريطة لعرض المسار
  Future<void> _fitMapToRoute() async {
    if (_controller == null) return;

    await Future.delayed(const Duration(milliseconds: 100));

    final locations = _route.waypoints.map((w) => w.location).toList();
    if (locations.isEmpty) return;

    // حساب الحدود
    double minLat = locations.first.latitude;
    double maxLat = locations.first.latitude;
    double minLng = locations.first.longitude;
    double maxLng = locations.first.longitude;

    for (final location in locations) {
      if (location.latitude < minLat) minLat = location.latitude;
      if (location.latitude > maxLat) maxLat = location.latitude;
      if (location.longitude < minLng) minLng = location.longitude;
      if (location.longitude > maxLng) maxLng = location.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    try {
      await _controller!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 60),
      );
    } catch (e) {
      // في حالة الخطأ، استخدم zoom ثابت
      await _controller!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(
            _currentLocation?.latitude ?? _route.startLocation!.latitude,
            _currentLocation?.longitude ?? _route.startLocation!.longitude,
          ),
          14,
        ),
      );
    }
  }

  /// التوسط على الموقع الحالي
  void _centerOnCurrentLocation() {
    if (_controller == null || _currentLocation == null) return;

    _controller!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
        ),
        16,
      ),
    );
  }

  /// عرض dialog لاختيار نوع الخريطة
  void _showMapTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.mapType),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMapTypeOption('عادية', MapType.normal),
            _buildMapTypeOption('قمر صناعي', MapType.satellite),
            _buildMapTypeOption('تضاريس', MapType.terrain),
            _buildMapTypeOption('هجين', MapType.hybrid),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTypeOption(String title, MapType type) {
    return ListTile(
      title: Text(title),
      leading: Radio<MapType>(
        value: type,
        groupValue: _mapType,
        onChanged: (value) {
          if (value != null) {
            setState(() => _mapType = value);
            Navigator.pop(context);
          }
        },
      ),
      onTap: () {
        setState(() => _mapType = type);
        Navigator.pop(context);
      },
    );
  }

  /// فتح خريطة ملء الشاشة
  void _openFullscreenMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullscreenTripMap(
          trip: widget.trip,
          route: _route,
          currentLocation: _currentLocation,
          actualTrack: _actualTrack,
          deviations: _deviations,
          currentDeviation: _currentDeviation,
        ),
      ),
    );
  }

  String _getSeverityText(DeviationSeverity severity) {
    switch (severity) {
      case DeviationSeverity.low:
        return 'منخفض';
      case DeviationSeverity.medium:
        return 'متوسط';
      case DeviationSeverity.high:
        return 'عالي';
      case DeviationSeverity.critical:
        return 'حرج';
      case DeviationSeverity.none:
        return 'لا يوجد';
    }
  }

  Color _getSeverityColor(DeviationSeverity severity) {
    switch (severity) {
      case DeviationSeverity.low:
        return Colors.yellow.shade700;
      case DeviationSeverity.medium:
        return Colors.orange;
      case DeviationSeverity.high:
        return Colors.deepOrange;
      case DeviationSeverity.critical:
        return AppColors.error;
      case DeviationSeverity.none:
        return AppColors.success;
    }
  }

  /// حساب المسافة الإجمالية للمسار المخطط
  double _calculateTotalRouteDistance() {
    final waypoints = _route.waypoints;
    if (waypoints.length < 2) return 0.0;
    
    double totalDistance = 0.0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      totalDistance += _calculateDistance(
        waypoints[i].location.latitude,
        waypoints[i].location.longitude,
        waypoints[i + 1].location.latitude,
        waypoints[i + 1].location.longitude,
      );
    }
    
    return totalDistance;
  }
  
  /// حساب المسافة بين نقطتين (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // متر
    
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '$hours س $minutes د';
    }
    return '$minutes د';
  }
}

/// خريطة ملء الشاشة للرحلة
class _FullscreenTripMap extends StatefulWidget {
  final TripEntity? trip;
  final route_entity.RouteEntity route;
  final Location? currentLocation;
  final List<Location> actualTrack;
  final List<Deviation> deviations;
  final Deviation? currentDeviation;

  const _FullscreenTripMap({
    required this.route,
    required this.actualTrack,
    required this.deviations,
    this.trip,
    this.currentLocation,
    this.currentDeviation,
  });

  @override
  State<_FullscreenTripMap> createState() => _FullscreenTripMapState();
}

class _FullscreenTripMapState extends State<_FullscreenTripMap> {
  GoogleMapController? _controller;
  MapType _mapType = MapType.normal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.route.name),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            AppLogger.info('[FullscreenTripMap] إغلاق وضع ملء الشاشة');
            Navigator.pop(context);
          },
          tooltip: 'إغلاق',
        ),
        actions: [
          // زر نوع الخريطة
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: _showMapTypeDialog,
            tooltip: AppLocalizations.of(context)!.mapType,
          ),
        ],
      ),
      body: Stack(
        children: [
          // الخريطة
          TripMapWidget(
            trip: widget.trip,
            route: widget.route,
            currentLocation: widget.currentLocation,
            actualTrack: widget.actualTrack,
            deviations: widget.deviations,
            height: double.infinity,
            showDeviationMarkers: true,
            showDirectionArrow: true,
            showActualTrack: true,
            showPlannedRoute: true,
            onMapCreated: (controller) {
              // ✅ حفظ controller للاستخدام في الأزرار
              _controller = controller;
            },
          ),

          // أزرار التحكم المحسّنة
          Positioned(
            bottom: 80,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // زر التكبير (+)
                _buildFloatingButton(
                  icon: Icons.add,
                  onPressed: _zoomIn,
                  tooltip: 'تكبير',
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 12),
                // زر التصغير (-)
                _buildFloatingButton(
                  icon: Icons.remove,
                  onPressed: _zoomOut,
                  tooltip: 'تصغير',
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 12),
                // زر موقعي
                if (widget.currentLocation != null)
                  _buildFloatingButton(
                    icon: Icons.my_location,
                    onPressed: _centerOnCurrentLocation,
                    tooltip: 'موقعي',
                    backgroundColor: AppColors.primary,
                    iconColor: Colors.white,
                  ),
                const SizedBox(height: 12),
                // زر عرض المسار كامل
                _buildFloatingButton(
                  icon: Icons.zoom_out_map,
                  onPressed: _fitMapToRoute,
                  tooltip: 'عرض المسار',
                  backgroundColor: Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    Color backgroundColor = Colors.white,
    Color? iconColor,
  }) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: backgroundColor,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          child: Tooltip(
            message: tooltip,
            child: Icon(
              icon,
              size: 28,
              color: iconColor ?? Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _zoomIn() async {
    if (_controller == null) return;
    
    final currentZoom = await _controller!.getZoomLevel();
    await _controller!.animateCamera(
      CameraUpdate.zoomTo(currentZoom + 1),
    );
  }

  Future<void> _zoomOut() async {
    if (_controller == null) return;
    
    final currentZoom = await _controller!.getZoomLevel();
    await _controller!.animateCamera(
      CameraUpdate.zoomTo(currentZoom - 1),
    );
  }

  void _centerOnCurrentLocation() {
    if (_controller == null || widget.currentLocation == null) return;

    _controller!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(
          widget.currentLocation!.latitude,
          widget.currentLocation!.longitude,
        ),
        16,
      ),
    );
  }

  Future<void> _fitMapToRoute() async {
    if (_controller == null) return;

    await Future.delayed(const Duration(milliseconds: 100));

    final locations = widget.route.waypoints.map((w) => w.location).toList();
    if (locations.isEmpty) return;

    // حساب الحدود
    double minLat = locations.first.latitude;
    double maxLat = locations.first.latitude;
    double minLng = locations.first.longitude;
    double maxLng = locations.first.longitude;

    for (final location in locations) {
      if (location.latitude < minLat) minLat = location.latitude;
      if (location.latitude > maxLat) maxLat = location.latitude;
      if (location.longitude < minLng) minLng = location.longitude;
      if (location.longitude > maxLng) maxLng = location.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    try {
      await _controller!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 60),
      );
    } catch (e) {
      AppLogger.error('[FullscreenTripMap] فشل تكبير الخريطة: $e');
    }
  }

  void _showMapTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.mapType),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMapTypeOption('عادية', MapType.normal),
            _buildMapTypeOption('قمر صناعي', MapType.satellite),
            _buildMapTypeOption('تضاريس', MapType.terrain),
            _buildMapTypeOption('هجين', MapType.hybrid),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTypeOption(String title, MapType type) {
    return ListTile(
      title: Text(title),
      leading: Radio<MapType>(
        value: type,
        groupValue: _mapType,
        onChanged: (value) {
          if (value != null) {
            setState(() => _mapType = value);
            Navigator.pop(context);
          }
        },
      ),
      onTap: () {
        setState(() => _mapType = type);
        Navigator.pop(context);
      },
    );
  }
}

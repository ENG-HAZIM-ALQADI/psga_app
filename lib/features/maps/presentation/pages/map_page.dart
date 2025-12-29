import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:psga_app/features/maps/presentation/bloc/map_bloc.dart';
import 'package:psga_app/features/maps/presentation/bloc/map_event.dart';
import 'package:psga_app/features/maps/presentation/bloc/map_state.dart';
import 'package:psga_app/features/maps/presentation/widgets/map_widget.dart';
import 'package:psga_app/features/maps/presentation/widgets/deviation_warning.dart';
import 'package:psga_app/features/maps/presentation/widgets/distance_indicator.dart';
import 'package:psga_app/shared/widgets/loading_widget.dart';

/// شاشة الخريطة الرئيسية
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final TextEditingController _searchController = TextEditingController();
  MapType _currentMapType = MapType.normal;

  @override
  void initState() {
    super.initState();
    context.read<MapBloc>().add(const InitializeMap());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<MapBloc, MapState>(
        listener: (context, state) {
          if (state is MapError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is LocationPermissionDenied) {
            _showPermissionDialog(context);
          } else if (state is LocationServiceDisabled) {
            _showLocationServiceDialog(context);
          }
        },
        builder: (context, state) {
          if (state is MapLoading) {
            return const LoadingWidget();
          }

          return Stack(
            children: [
              _buildMap(state),
              _buildSearchBar(),
              _buildMapControls(),
              if (state is MapTracking && state.deviation != null)
                DeviationWarning(deviation: state.deviation!),
              if (state is MapReady && state.activeRoute != null)
                _buildRouteInfo(state),
            ],
          );
        },
      ),
    );
  }

  /// بناء الخريطة
  Widget _buildMap(MapState state) {
    LatLng? currentLocation;
    Set<Marker> markers = {};
    Set<Polyline> polylines = {};

    if (state is MapReady) {
      currentLocation = state.currentLocation;
      markers = state.markers;
      polylines = state.polylines;
    } else if (state is MapTracking) {
      currentLocation = state.currentLocation;
      markers = state.markers;
      polylines = state.polylines;
    }

    return MapWidget(
      initialPosition: currentLocation ?? const LatLng(24.7136, 46.6753),
      markers: markers,
      polylines: polylines,
      mapType: _currentMapType,
      showCurrentLocation: true,
      onMapCreated: (controller) {
        context.read<MapBloc>().add(MapControllerUpdated(controller));
      },
      onTap: (position) {},
    );
  }

  /// بناء شريط البحث
  Widget _buildSearchBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'ابحث عن مكان...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          onChanged: (value) {
            setState(() {});
          },
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              context.read<MapBloc>().add(SearchPlace(value));
            }
          },
        ),
      ),
    );
  }

  /// بناء أزرار التحكم
  Widget _buildMapControls() {
    return Positioned(
      right: 16,
      bottom: 150,
      child: Column(
        children: [
          _buildControlButton(
            icon: Icons.my_location,
            onPressed: () {
              context.read<MapBloc>().add(const LoadCurrentLocation());
            },
          ),
          const SizedBox(height: 8),
          _buildControlButton(
            icon: Icons.layers,
            onPressed: _showMapTypeSelector,
          ),
          const SizedBox(height: 8),
          _buildControlButton(
            icon: Icons.add,
            onPressed: () {},
          ),
          const SizedBox(height: 8),
          _buildControlButton(
            icon: Icons.remove,
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  /// بناء زر تحكم
  Widget _buildControlButton({
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

  /// بناء معلومات المسار
  Widget _buildRouteInfo(MapReady state) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.route, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.activeRoute?.name ?? 'المسار',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const DistanceIndicator(
              distance: 0,
              duration: Duration.zero,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'بدء رحلة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// عرض اختيار نوع الخريطة
  void _showMapTypeSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'نوع الخريطة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('عادية'),
              trailing: _currentMapType == MapType.normal
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
              onTap: () => _changeMapType(MapType.normal),
            ),
            ListTile(
              leading: const Icon(Icons.satellite),
              title: const Text('قمر صناعي'),
              trailing: _currentMapType == MapType.satellite
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
              onTap: () => _changeMapType(MapType.satellite),
            ),
            ListTile(
              leading: const Icon(Icons.terrain),
              title: const Text('تضاريس'),
              trailing: _currentMapType == MapType.terrain
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
              onTap: () => _changeMapType(MapType.terrain),
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('هجين'),
              trailing: _currentMapType == MapType.hybrid
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
              onTap: () => _changeMapType(MapType.hybrid),
            ),
          ],
        ),
      ),
    );
  }

  /// تغيير نوع الخريطة
  void _changeMapType(MapType type) {
    setState(() {
      _currentMapType = type;
    });
    context.read<MapBloc>().add(ChangeMapType(type));
    Navigator.pop(context);
  }

  /// عرض نافذة الصلاحيات
  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('صلاحية الموقع مطلوبة'),
        content: const Text(
          'يحتاج التطبيق إلى صلاحية الوصول للموقع لتتبع رحلتك وحمايتك.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<MapBloc>().add(const InitializeMap());
            },
            child: const Text('طلب الصلاحية'),
          ),
        ],
      ),
    );
  }

  /// عرض نافذة خدمة الموقع
  void _showLocationServiceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خدمة الموقع معطلة'),
        content: const Text(
          'يرجى تفعيل خدمة الموقع في الإعدادات للاستمرار.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }
}

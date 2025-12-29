// ============================================================================
// 📄 ملف: create_route_page.dart
// 🏗️ الطبقة: Presentation (الواجهة الأمامية)
// 🎯 الوظيفة: صفحة لإنشاء أو تعديل مسار جديد مع تحديد نقاط البداية والنهاية والوسيطة
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../maps/presentation/pages/select_location_page.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/entities/waypoint_entity.dart';
import '../../domain/entities/route_entity.dart';
import '../bloc/route_bloc.dart';
import '../bloc/route_event.dart';
import '../bloc/route_state.dart';

/// 📌 صفحة إنشاء/تعديل المسار
class CreateRoutePage extends StatefulWidget {
  final String userId;
  final RouteEntity? existingRoute;

  const CreateRoutePage({
    super.key,
    required this.userId,
    this.existingRoute,
  });

  @override
  State<CreateRoutePage> createState() => _CreateRoutePageState();
}

class _CreateRoutePageState extends State<CreateRoutePage> {
  // 📋 مفتاح التحقق من صحة النموذج (Form Validation)
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  // 📍 بيانات نقاط المسار
  LocationEntity? _startLocation;
  LocationEntity? _endLocation;
  final List<WaypointEntity> _intermediateWaypoints = [];
  String? _startAddress;
  String? _endAddress;
  bool _isLoading = false;

  @override
  void initState() {
    /// تحميل بيانات المسار إذا كان المقصود تعديل مسار موجود بالفعل
    super.initState();
    if (widget.existingRoute != null) {
      _nameController.text = widget.existingRoute!.name;
      _descriptionController.text = widget.existingRoute!.description ?? '';
      _startLocation = widget.existingRoute!.startPoint.location;
      _endLocation = widget.existingRoute!.endPoint.location;
      _startAddress = widget.existingRoute!.startPoint.name;
      _endAddress = widget.existingRoute!.endPoint.name;
      _intermediateWaypoints.addAll(
        widget.existingRoute!.waypoints.where((w) => w.type == WaypointType.intermediate),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingRoute != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'تعديل المسار' : 'مسار جديد'),
      ),
      body: BlocListener<RouteBloc, RouteState>(
        /// 📡 BlocListener: يستمع لتغييرات الحالة ويقوم بعمليات جانبية بدون إعادة رسم الواجهة
        /// الفرق عن BlocBuilder:
        /// - BlocBuilder: يرسم الواجهة (UI)
        /// - BlocListener: ينفذ أكواد جانبية (Side Effects) مثل الـ Navigation و SnackBar
        listener: (context, state) {
          /// ✅ تم الحفظ بنجاح
          if (state is RouteOperationSuccess) {
            /// أعد تحميل القائمة الكاملة للمسارات
            context.read<RouteBloc>().add(LoadRoutes(widget.userId));
            /// العودة للصفحة السابقة
            Navigator.pop(context);
          } 
          /// ❌ حدث خطأ
          else if (state is RoutesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
            setState(() => _isLoading = false);
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomTextField(
                  controller: _nameController,
                  label: 'اسم المسار',
                  hint: 'مثال: من البيت للعمل',
                  prefixIcon: Icons.route,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال اسم المسار';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _descriptionController,
                  label: 'الوصف (اختياري)',
                  hint: 'أضف وصفاً للمسار',
                  prefixIcon: Icons.description,
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                _buildLocationSection(
                  title: 'نقطة البداية',
                  icon: Icons.trip_origin,
                  iconColor: Colors.green,
                  location: _startLocation,
                  address: _startAddress,
                  onCurrentLocation: () => _setCurrentLocation(true),
                  onMapSelect: () => _selectFromMap(true),
                  onClear: () {
                    setState(() {
                      _startLocation = null;
                      _startAddress = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildLocationSection(
                  title: 'نقطة النهاية',
                  icon: Icons.flag,
                  iconColor: Colors.red,
                  location: _endLocation,
                  address: _endAddress,
                  onCurrentLocation: () => _setCurrentLocation(false),
                  onMapSelect: () => _selectFromMap(false),
                  onClear: () {
                    setState(() {
                      _endLocation = null;
                      _endAddress = null;
                    });
                  },
                ),
                const SizedBox(height: 24),
                _buildWaypointsSection(theme),
                const SizedBox(height: 24),
                if (_startLocation != null && _endLocation != null)
                  _buildRoutePreview(theme),
                const SizedBox(height: 32),
                CustomButton(
                  text: isEditing ? 'حفظ التعديلات' : 'حفظ المسار',
                  isLoading: _isLoading,
                  onPressed: _saveRoute,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    LocationEntity? location,
    String? address,
    required VoidCallback onCurrentLocation,
    required VoidCallback onMapSelect,
    required VoidCallback onClear,
  }) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (location != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(address ?? 'موقع محدد')),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: onClear,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.gps_fixed, size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'خط العرض: ${location.latitude.toStringAsFixed(6)}\n'
                              'خط الطول: ${location.longitude.toStringAsFixed(6)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.my_location),
                      label: const Text('موقعي الحالي'),
                      onPressed: onCurrentLocation,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.map),
                      label: const Text('من الخريطة'),
                      onPressed: onMapSelect,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaypointsSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.more_horiz),
                    const SizedBox(width: 8),
                    Text(
                      'نقاط وسيطة (اختياري)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة'),
                  onPressed: _addWaypoint,
                ),
              ],
            ),
            if (_intermediateWaypoints.isNotEmpty) ...[
              const SizedBox(height: 12),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _intermediateWaypoints.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _intermediateWaypoints.removeAt(oldIndex);
                    _intermediateWaypoints.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final waypoint = _intermediateWaypoints[index];
                  return Card(
                    key: Key(waypoint.id),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(waypoint.name ?? 'نقطة ${index + 1}'),
                      subtitle: Text(
                        'خط العرض: ${waypoint.location.latitude.toStringAsFixed(4)}, خط الطول: ${waypoint.location.longitude.toStringAsFixed(4)}',
                        style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _intermediateWaypoints.removeAt(index);
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoutePreview(ThemeData theme) {
    final distance = _startLocation!.distanceTo(_endLocation!);
    final estimatedMinutes = (distance / 1000) * 2;

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const Icon(Icons.straighten),
                const SizedBox(height: 4),
                Text(
                  '${(distance / 1000).toStringAsFixed(1)} كم',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('المسافة', style: theme.textTheme.bodySmall),
              ],
            ),
            Column(
              children: [
                const Icon(Icons.access_time),
                const SizedBox(height: 4),
                Text(
                  '${estimatedMinutes.toStringAsFixed(0)} دقيقة',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('الوقت المتوقع', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _setCurrentLocation(bool isStart) {
    const baseLatitude = 24.7136;
    const baseLongitude = 46.6753;
    
    final latitude = baseLatitude + (isStart ? 0 : 0.05) + (_intermediateWaypoints.length * 0.001);
    final longitude = baseLongitude + (isStart ? 0 : 0.05) + (_intermediateWaypoints.length * 0.001);
    
    final mockLocation = LocationEntity(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      address: isStart ? 'الموقع الحالي' : 'وجهة مختارة',
      accuracy: 10.0,
    );

    setState(() {
      if (isStart) {
        _startLocation = mockLocation;
        _startAddress = mockLocation.address;
      } else {
        _endLocation = mockLocation;
        _endAddress = mockLocation.address;
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم تحديد ${isStart ? "نقطة البداية" : "نقطة النهاية"}: '
          '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}'
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _selectFromMap(bool isStart) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectLocationPage(
          title: isStart ? 'تحديد نقطة البداية' : 'تحديد نقطة النهاية',
          initialLocation: isStart 
              ? (_startLocation != null ? LatLng(_startLocation!.latitude, _startLocation!.longitude) : null)
              : (_endLocation != null ? LatLng(_endLocation!.latitude, _endLocation!.longitude) : null),
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      final LatLng location = result['location'];
      final String address = result['address'];

      setState(() {
        final locationEntity = LocationEntity(
          latitude: location.latitude,
          longitude: location.longitude,
          timestamp: DateTime.now(),
          address: address,
        );

        if (isStart) {
          _startLocation = locationEntity;
          _startAddress = address;
        } else {
          _endLocation = locationEntity;
          _endAddress = address;
        }
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديد ${isStart ? "نقطة البداية" : "نقطة النهاية"} بنجاح'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _addWaypoint() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SelectLocationPage(
          title: 'إضافة نقطة وسيطة',
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      final LatLng location = result['location'];
      final String address = result['address'];

      final newWaypoint = WaypointEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        location: LocationEntity(
          latitude: location.latitude,
          longitude: location.longitude,
          timestamp: DateTime.now(),
          address: address,
        ),
        name: address.split(',').first,
        order: _intermediateWaypoints.length,
        type: WaypointType.intermediate,
      );

      setState(() {
        _intermediateWaypoints.add(newWaypoint);
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إضافة النقطة الوسيطة بنجاح'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 💾 حفظ المسار (إنشاء أو تعديل)
  void _saveRoute() {
    /// ✅ التحقق من صحة النموذج (Form Validation)
    /// validate() يتحقق من جميع الحقول في Form و validator functions
    if (!_formKey.currentState!.validate()) return;

    /// ✅ التحقق من أن نقاط البداية والنهاية محددة
    if (_startLocation == null || _endLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد نقطة البداية والنهاية'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    /// ⏳ تغيير حالة التحميل للظهور في الـ UI
    setState(() => _isLoading = true);

    final now = DateTime.now();
    /// 📏 حساب المسافة بين النقطتين (بالأمتار)
    final distance = _startLocation!.distanceTo(_endLocation!);
    
    /// 🏗️ بناء كائن RouteEntity
    /// هذا الكائن يمثل المسار في Domain Layer (Logic Layer)
    /// نفصل بين عرض البيانات (Presentation) والمنطق (Domain) عن طريق Entities
    final route = RouteEntity(
      id: widget.existingRoute?.id ?? now.millisecondsSinceEpoch.toString(),
      userId: widget.userId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty 
          ? null 
          : _descriptionController.text.trim(),
      startPoint: WaypointEntity(
        id: '${now.millisecondsSinceEpoch}_start',
        location: _startLocation!,
        name: _startAddress,
        order: 0,
        type: WaypointType.start,
      ),
      endPoint: WaypointEntity(
        id: '${now.millisecondsSinceEpoch}_end',
        location: _endLocation!,
        name: _endAddress,
        order: _intermediateWaypoints.length + 1,
        type: WaypointType.end,
      ),
      waypoints: _intermediateWaypoints,
      estimatedDuration: Duration(minutes: ((distance / 1000) * 2).round()),
      estimatedDistance: distance / 1000,
      createdAt: widget.existingRoute?.createdAt ?? now,
      updatedAt: now,
    );

    /// 🎯 إرسال الحدث للـ BLoC
    /// نستخدم context.read() لأننا نريد تنفيذ عملية فقط، بدون الاستماع للتغييرات
    /// و add() لإضافة Event للـ BLoC الذي سيعالجه ويعود برد أفعال
    /// 💡 معمارة Clean Architecture: نفصل الـ Presentation عن Business Logic عن طريق BLoC
    if (widget.existingRoute != null) {
      /// تعديل مسار موجود
      context.read<RouteBloc>().add(UpdateRoute(route));
    } else {
      /// إنشاء مسار جديد
      context.read<RouteBloc>().add(CreateRoute(route));
    }
  }
}

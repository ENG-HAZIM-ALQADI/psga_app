import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/features/routes/domain/entities/waypoint.dart';
import 'package:psga_app/features/maps/presentation/widgets/map_widget.dart';
import 'package:psga_app/core/services/geocoding_service.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/maps/presentation/bloc/maps/bloc.dart';
import 'package:psga_app/features/maps/domain/entities/place_entity.dart';
import 'package:psga_app/injection_container.dart';
import 'package:psga_app/shared/widgets/loading_widget.dart';

/// شاشة اختيار موقع على الخريطة
class LocationPickerScreen extends StatefulWidget {
  final Location? initialLocation;
  final String? title;
  final List<Waypoint>? existingWaypoints; // النقاط الموجودة لعرضها

  const LocationPickerScreen({
    this.initialLocation,
    this.title,
    this.existingWaypoints,
    super.key,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  Location? _selectedLocation;
  final Set<Marker> _markers = {};
  String? _selectedAddress;
  bool _isLoadingAddress = false;
  
  // متغيرات البحث عن الأماكن
  bool _showSearchResults = false;
  List<PlaceEntity> _searchResults = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  
  // Debouncing للبحث النصي
  Timer? _searchDebounceTimer;
  
  // Throttling للنقر على الخريطة
  Timer? _mapTapThrottleTimer;
  bool _canHandleMapTap = true;
  
  // حالة تحميل الخريطة
  bool _isMapReady = false;

  // حالة تحميل النقطة (عند اختيار نقطة على الخريطة)
  bool _isLoadingPoint = false;

  // لمنع تكرار initDependencies
  bool _dependenciesInitialized = false;

  @override
  void initState() {
    super.initState();
    AppLogger.info('[LocationPickerScreen] تم فتح شاشة اختيار الموقع');
    
    // التحقق من GPS عند فتح الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestGPS();
    });

    // إضافة marker للموقع الابتدائي (لا يحتاج context)
    if (widget.initialLocation != null) {
      AppLogger.info('[LocationPickerScreen] عرض الموقع الابتدائي: ${widget.initialLocation!.latitude}, ${widget.initialLocation!.longitude}');
      _selectedLocation = widget.initialLocation;
    } else {
      AppLogger.warning('[LocationPickerScreen] لا يوجد موقع ابتدائي');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // تنفيذ مرة واحدة فقط بعد اكتمال context
    if (_dependenciesInitialized) return;
    _dependenciesInitialized = true;

    final l10n = AppLocalizations.of(context)!;

    // إضافة markers للنقاط الموجودة - الآن يمكن استخدام context بأمان
    if (widget.existingWaypoints != null && widget.existingWaypoints!.isNotEmpty) {
      AppLogger.info('[LocationPickerScreen] عرض ${widget.existingWaypoints!.length} نقطة موجودة');
      for (int i = 0; i < widget.existingWaypoints!.length; i++) {
        final waypoint = widget.existingWaypoints![i];
        _markers.add(createMarker(
          id: 'existing_$i',
          location: waypoint.location,
          title: waypoint.name,
          snippet: l10n.waypoints,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ));
      }
    }

    // إضافة marker وتحميل عنوان الموقع الابتدائي
    if (widget.initialLocation != null) {
      _addMarker(widget.initialLocation!);
      _loadAddress(widget.initialLocation!);
    }
  }

  /// التحقق من تفعيل GPS وطلب تفعيله إجبارياً
  Future<void> _checkAndRequestGPS() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      
      if (!serviceEnabled) {
        AppLogger.warning('[LocationPickerScreen] GPS معطل - طلب التفعيل');
        if (mounted) {
          await _showGPSRequiredDialog();
        }
      } else {
        AppLogger.success('[LocationPickerScreen] GPS مفعّل');
      }
    } catch (e) {
      AppLogger.error('[LocationPickerScreen] خطأ في التحقق من GPS', e);
    }
  }

  /// عرض نافذة تفعيل GPS الإلزامية
  Future<void> _showGPSRequiredDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false, // لا يمكن إغلاقها بالنقر خارجها
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false, // منع الإغلاق بزر الرجوع
          child: AlertDialog(
            icon: const Icon(Icons.location_off, color: Colors.orange, size: 48),
            title: const Text(
              'GPS مطلوب',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'يجب تفعيل GPS لاختيار موقع على الخريطة.\n\nيُرجى تفعيل خدمة الموقع (GPS) من إعدادات جهازك للمتابعة.',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              // زر الرجوع - يُغلق النافذة ويعود للصفحة السابقة
              OutlinedButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text('رجوع'),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(width: 8),
              // زر فتح الإعدادات
              ElevatedButton.icon(
                icon: const Icon(Icons.settings),
                label: const Text('فتح الإعدادات'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _openSettingsAndRecheck(dialogContext),
              ),
            ],
          ),
        );
      },
    );
  }

  /// فتح إعدادات الموقع والتحقق بعد العودة
  Future<void> _openSettingsAndRecheck(BuildContext dialogContext) async {
    Navigator.of(dialogContext).pop();
    await Geolocator.openLocationSettings();

    if (!mounted) return;

    // انتظار ثانية للسماح بتفعيل GPS
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      // إذا لا يزال معطلاً، اعرض النافذة مرة أخرى
      await _showGPSRequiredDialog();
    } else {
      AppLogger.success('[LocationPickerScreen] تم تفعيل GPS بنجاح');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    _mapTapThrottleTimer?.cancel();
    super.dispose();
  }

  void _addMarker(Location location) {
    setState(() {
      // حذف marker الموقع المحدد السابق فقط (إن وجد)
      _markers.removeWhere((m) => m.markerId.value == 'selected');
      
      // إضافة marker الموقع الجديد
      _markers.add(createMarker(
        id: 'selected',
        location: location,
        title: AppLocalizations.of(context)!.selectLocationFirst,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    });
  }

  Future<void> _loadAddress(Location location) async {
    setState(() {
      _isLoadingAddress = true;
      _selectedAddress = null; // إعادة تعيين
    });
    
    try {
      final address = await GeocodingService.instance.getAddressFromLocation(location);
      
      if (mounted) {
        setState(() {
          if (address != null && address.isNotEmpty) {
            _selectedAddress = address;
          } else {
            // عرض الإحداثيات إذا فشل الحصول على العنوان
            _selectedAddress = 'موقع: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
          }
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // في حالة الخطأ، عرض الإحداثيات
          _selectedAddress = 'موقع: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
          _isLoadingAddress = false;
        });
      }
    }
  }

  /// البحث عن الأماكن حول الموقع المحدد
  void _searchNearbyPlaces() {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.selectLocationFirst),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    
    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });

    context.read<MapsBloc>().add(SearchNearbyPlacesEvent(
      location: _selectedLocation!,
      radius: 1000, // 1 كم
    ));
  }

  /// البحث عن مكان بالنص مع debouncing لتقليل الطلبات
  void _searchPlacesByText(String query) {
    // إلغاء أي timer سابق
    _searchDebounceTimer?.cancel();
    
    if (query.trim().isEmpty) {
      setState(() {
        _showSearchResults = false;
        _searchResults = [];
      });
      return;
    }

    if (query.trim().length < 2) return;
    
    // استخدام debouncing للانتظار 500ms قبل البحث
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      
      setState(() {
        _isSearching = true;
        _showSearchResults = true;
      });

      context.read<MapsBloc>().add(SearchPlacesEvent(
        query: query,
        location: _selectedLocation ?? widget.initialLocation,
        radius: 5000,
      ));
    });
  }

  /// اختيار مكان من نتائج البحث
  Future<void> _selectPlace(PlaceEntity place) async {
    // التحقق من GPS
    final gpsEnabled = await Geolocator.isLocationServiceEnabled();
    if (!gpsEnabled) {
      AppLogger.warning('[LocationPickerScreen] GPS معطل - لا يمكن اختيار المكان');
      if (mounted) await _showGPSRequiredDialog();
      return;
    }

    final location = Location(
      latitude: place.location.latitude,
      longitude: place.location.longitude,
      timestamp: DateTime.now(),
    );

    setState(() {
      _selectedLocation = location;
      _selectedAddress = place.address;
      _showSearchResults = false;
      _searchController.clear();
      _isLoadingPoint = true;
    });

    _addMarker(location);

    // تأخير قصير لإظهار loading
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      setState(() => _isLoadingPoint = false);
    }
  }

  /// معالجة النقر على الخريطة مع throttling لمنع الطلبات المتكررة
  Future<void> _onMapTap(LatLng latLng) async {
    // تجاهل النقرات المتكررة خلال 300ms
    if (!_canHandleMapTap || _isLoadingPoint) return;

    // التحقق من GPS قبل اختيار النقطة
    final gpsEnabled = await Geolocator.isLocationServiceEnabled();
    if (!gpsEnabled) {
      AppLogger.warning('[LocationPickerScreen] GPS معطل - لا يمكن اختيار النقطة');
      if (mounted) {
        await _showGPSRequiredDialog();
      }
      return;
    }
    
    _canHandleMapTap = false;
    _mapTapThrottleTimer?.cancel();
    _mapTapThrottleTimer = Timer(const Duration(milliseconds: 300), () {
      _canHandleMapTap = true;
    });

    final location = Location(
      latitude: latLng.latitude,
      longitude: latLng.longitude,
      timestamp: DateTime.now(),
    );

    // إظهار loading عند اختيار النقطة
    setState(() {
      _isLoadingPoint = true;
      _selectedLocation = location;
    });

    _addMarker(location);
    await _loadAddress(location);

    if (mounted) {
      setState(() => _isLoadingPoint = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<MapsBloc>(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title ?? AppLocalizations.of(context)!.selectStartPoint),
          // استخدام ألوان الثيم بدلاً من الأزرق الثابت
          actions: [
            TextButton(
              onPressed: _selectedLocation != null
                  ? () {
                      AppLogger.info('[LocationPickerScreen] تم تأكيد الموقع: ${_selectedLocation!.latitude}, ${_selectedLocation!.longitude}');
                      Navigator.pop(context, _selectedLocation);
                    }
                  : null,
              child: Text(
                AppLocalizations.of(context)!.confirm,
                style: TextStyle(
                  color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: BlocListener<MapsBloc, MapsState>(
          listener: (context, state) {
            if (state is PlacesLoaded) {
              setState(() {
                _searchResults = state.places;
                _isSearching = false;
              });
              AppLogger.success('[LocationPickerScreen] تم تحميل ${state.places.length} نتيجة بحث');
            } else if (state is MapsError) {
              setState(() {
                _isSearching = false;
              });
              AppLogger.error('[LocationPickerScreen] خطأ في البحث', state.message);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            } else if (state is MapsLoading) {
              setState(() {
                _isSearching = true;
              });
            }
          },
          child: LoadingOverlay(
            isLoading: _isLoadingPoint,
            message: 'جاري تحديد الموقع...',
            child: Stack(
            children: [
              // الخريطة
              MapWidget(
                initialLocation: _selectedLocation ?? widget.initialLocation,
                markers: _markers,
                onTap: _onMapTap,
                onLongPress: _onMapTap,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: true,
                onMapCreated: (controller) {
                  setState(() => _isMapReady = true);
                  AppLogger.success('[LocationPickerScreen] الخريطة جاهزة');
                },
              ),
              
              // طبقة Loading أثناء تحميل الخريطة
              if (!_isMapReady)
                Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 16),
                        Text(
                          'جاري تحميل الخريطة...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // شريط البحث
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: _buildSearchBar(),
              ),

              // نتائج البحث
              if (_showSearchResults)
                Positioned(
                  top: 80,
                  left: 16,
                  right: 16,
                  bottom: 250,
                  child: _buildSearchResults(),
                ),

              // بطاقة معلومات الموقع
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _buildLocationCard(),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  /// بناء شريط البحث
  Widget _buildSearchBar() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.searchPlace,
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: _searchPlacesByText,
                onSubmitted: _searchPlacesByText,
              ),
            ),
            // زر البحث عن الأماكن القريبة
            IconButton(
              icon: Icon(
                Icons.near_me,
                color: _selectedLocation != null ? Theme.of(context).colorScheme.primary : Colors.grey,
              ),
              onPressed: _selectedLocation != null ? _searchNearbyPlaces : null,
              tooltip: 'أماكن قريبة',
            ),
            if (_showSearchResults)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _showSearchResults = false;
                    _searchController.clear();
                  });
                },
                tooltip: 'إغلاق',
              ),
          ],
        ),
      ),
    );
  }

  /// بناء نتائج البحث
  Widget _buildSearchResults() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // عنوان النتائج
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.place, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'نتائج البحث (${_searchResults.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // قائمة النتائج
          Expanded(
            child: _isSearching
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _searchResults.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'لا توجد نتائج',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _searchResults.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final place = _searchResults[index];
                          return ListTile(
                            leading: Icon(Icons.place, color: Theme.of(context).colorScheme.primary),
                            title: Text(
                              place.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              place.address ?? 'لا يوجد عنوان',
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: place.rating != null
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star, size: 14, color: Colors.amber),
                                      const SizedBox(width: 4),
                                      Text(
                                        place.rating!.toStringAsFixed(1),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  )
                                : null,
                            onTap: () => _selectPlace(place),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  /// بناء بطاقة معلومات الموقع
  /// تستخدم ألوان الثيم الحالي (فاتح/داكن) بدلاً من الألوان الثابتة
  Widget _buildLocationCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme   = Theme.of(context).textTheme;
    final secondaryTextColor = textTheme.bodyMedium?.color ?? colorScheme.onSurface.withOpacity(0.6);
    final primaryTextColor   = textTheme.bodyLarge?.color  ?? colorScheme.onSurface;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الموقع المحدد',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
                if (_selectedLocation != null)
                  IconButton(
                    icon: Icon(Icons.near_me, size: 20, color: colorScheme.primary),
                    onPressed: _searchNearbyPlaces,
                    tooltip: 'عرض الأماكن القريبة',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            
            if (_selectedLocation != null) ...[
              // الإحداثيات
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: secondaryTextColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // العنوان
              if (_isLoadingAddress)
                Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'جاري تحميل العنوان...',
                      style: TextStyle(fontSize: 13, color: secondaryTextColor),
                    ),
                  ],
                )
              else if (_selectedAddress != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.place, size: 16, color: secondaryTextColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedAddress!,
                        style: TextStyle(
                          fontSize: 13,
                          // استخدام لون النص الأساسي من الثيم بدلاً من Colors.black87 الثابت
                          color: primaryTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
            ] else
              Text(
                'انقر على الخريطة أو ابحث عن مكان',
                style: TextStyle(fontSize: 14, color: secondaryTextColor),
              ),
          ],
        ),
      ),
    );
  }
}

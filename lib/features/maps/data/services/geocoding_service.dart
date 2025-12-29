import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:psga_app/core/utils/logger.dart';

/// نموذج اقتراح مكان
class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
  final double? latitude;
  final double? longitude;

  const PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    this.latitude,
    this.longitude,
  });
}

/// خدمة تحويل الإحداثيات لعناوين والعكس
/// - caching للعناوين (آخر 50 بحث)
/// - تحسين الأداء بعدم الاتصال بـ API مكرراً
class GeocodingService {
  static final GeocodingService _instance = GeocodingService._internal();
  factory GeocodingService() => _instance;
  GeocodingService._internal();

  final Map<String, String> _addressCache = {}; // cache للعناوين
  static const int _maxCacheSize = 50;

  /// تحويل الإحداثيات إلى عنوان نصي (مع caching)
  Future<String?> getAddressFromCoordinates(double lat, double lng) async {
    try {
      final key = '${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';
      
      // تحقق من الـ cache أولاً
      if (_addressCache.containsKey(key)) {
        return _addressCache[key];
      }

      AppLogger.info('[Geocoding] تحويل الإحداثيات: $lat, $lng');
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isNotEmpty) {
        final address = _formatAddress(placemarks.first);
        _addToCache(_addressCache, key, address);
        return address;
      }
      return null;
    } catch (e) {
      AppLogger.error('[Geocoding] خطأ: $e');
      return null;
    }
  }

  /// إضافة عنصر إلى الـ cache مع حد أقصى للحجم
  void _addToCache<K, V>(Map<K, V> cache, K key, V value) {
    if (cache.length >= _maxCacheSize) {
      cache.remove(cache.keys.first); // احذف الأول (FIFO)
    }
    cache[key] = value;
  }

  /// تنسيق العنوان من Placemark
  String _formatAddress(Placemark place) {
    final parts = <String>[];

    if (place.street != null && place.street!.isNotEmpty) {
      parts.add(place.street!);
    }
    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      parts.add(place.subLocality!);
    }
    if (place.locality != null && place.locality!.isNotEmpty) {
      parts.add(place.locality!);
    }
    if (place.administrativeArea != null &&
        place.administrativeArea!.isNotEmpty) {
      parts.add(place.administrativeArea!);
    }
    if (place.country != null && place.country!.isNotEmpty) {
      parts.add(place.country!);
    }

    return parts.join(', ');
  }

  /// تحويل العنوان النصي إلى إحداثيات
  Future<Position?> getCoordinatesFromAddress(String address) async {
    try {
      AppLogger.info('[Geocoding] البحث عن العنوان: $address');

      List<Location> locations = await locationFromAddress(address);

      if (locations.isNotEmpty) {
        final loc = locations.first;
        AppLogger.info('[Geocoding] الإحداثيات: ${loc.latitude}, ${loc.longitude}');
        return Position(
          latitude: loc.latitude,
          longitude: loc.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }

      return null;
    } catch (e) {
      AppLogger.error('[Geocoding] خطأ في البحث عن العنوان: $e');
      return null;
    }
  }

  /// البحث عن أماكن بناءً على نص البحث
  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    try {
      if (query.isEmpty) return [];

      AppLogger.info('[Geocoding] البحث عن: $query');

      List<Location> locations = await locationFromAddress(query);
      List<PlaceSuggestion> suggestions = [];

      for (var loc in locations) {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          loc.latitude,
          loc.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          suggestions.add(PlaceSuggestion(
            placeId: '${loc.latitude}_${loc.longitude}',
            description: _formatAddress(place),
            mainText: place.name ?? place.street ?? query,
            secondaryText: '${place.locality ?? ''}, ${place.country ?? ''}',
            latitude: loc.latitude,
            longitude: loc.longitude,
          ));
        }
      }

      AppLogger.info('[Geocoding] عدد النتائج: ${suggestions.length}');
      return suggestions;
    } catch (e) {
      AppLogger.error('[Geocoding] خطأ في البحث: $e');
      return [];
    }
  }

  /// الحصول على اسم المدينة من الإحداثيات
  Future<String?> getCityName(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        return placemarks.first.locality;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// الحصول على اسم الدولة من الإحداثيات
  Future<String?> getCountryName(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        return placemarks.first.country;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

import 'package:geocoding/geocoding.dart' as geo;
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';

/// خدمة التحويل الجغرافي
class GeocodingService {
  static final GeocodingService instance = GeocodingService._();
  GeocodingService._();

  /// تحويل عنوان إلى موقع (Geocoding)
  Future<Location?> getLocationFromAddress(String address) async {
    try {
      AppLogger.info('[Geocoding] البحث عن: $address');
      
      final locations = await geo.locationFromAddress(address);
      
      if (locations.isEmpty) {
        AppLogger.warning('[Geocoding] لم يتم العثور على نتائج');
        return null;
      }

      final location = locations.first;
      
      final result = Location(
        latitude: location.latitude,
        longitude: location.longitude,
        timestamp: DateTime.now(),
      );

      AppLogger.success('[Geocoding] تم العثور على الموقع: ${result.latitude}, ${result.longitude}');
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[Geocoding] خطأ في البحث', e, stackTrace);
      return null;
    }
  }

  /// تحويل موقع إلى عنوان (Reverse Geocoding)
  Future<String?> getAddressFromLocation(Location location) async {
    try {
      AppLogger.info('[Geocoding] الحصول على العنوان: ${location.latitude}, ${location.longitude}');
      
      final placemarks = await geo.placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isEmpty) {
        AppLogger.warning('[Geocoding] لم يتم العثور على عنوان');
        return null;
      }

      final placemark = placemarks.first;
      
      // تركيب العنوان
      final addressParts = <String>[];
      
      if (placemark.street != null && placemark.street!.isNotEmpty) {
        addressParts.add(placemark.street!);
      }
      
      if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
        addressParts.add(placemark.subLocality!);
      }
      
      if (placemark.locality != null && placemark.locality!.isNotEmpty) {
        addressParts.add(placemark.locality!);
      }
      
      if (placemark.country != null && placemark.country!.isNotEmpty) {
        addressParts.add(placemark.country!);
      }

      final address = addressParts.join(', ');
      
      AppLogger.success('[Geocoding] العنوان: $address');
      return address.isEmpty ? null : address;
    } catch (e, stackTrace) {
      AppLogger.error('[Geocoding] خطأ في الحصول على العنوان', e, stackTrace);
      return null;
    }
  }

  /// الحصول على معلومات تفصيلية عن الموقع
  Future<Map<String, String>?> getDetailedLocation(Location location) async {
    try {
      AppLogger.info('[Geocoding] الحصول على معلومات تفصيلية');
      
      final placemarks = await geo.placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isEmpty) {
        return null;
      }

      final placemark = placemarks.first;
      
      return {
        'street': placemark.street ?? '',
        'subLocality': placemark.subLocality ?? '',
        'locality': placemark.locality ?? '',
        'subAdministrativeArea': placemark.subAdministrativeArea ?? '',
        'administrativeArea': placemark.administrativeArea ?? '',
        'postalCode': placemark.postalCode ?? '',
        'country': placemark.country ?? '',
        'isoCountryCode': placemark.isoCountryCode ?? '',
      };
    } catch (e, stackTrace) {
      AppLogger.error('[Geocoding] خطأ في الحصول على المعلومات', e, stackTrace);
      return null;
    }
  }

  /// البحث عن مواقع متعددة من عنوان
  Future<List<Location>> searchLocations(String address) async {
    try {
      AppLogger.info('[Geocoding] البحث عن مواقع متعددة: $address');
      
      final locations = await geo.locationFromAddress(address);
      
      return locations.map((loc) => Location(
        latitude: loc.latitude,
        longitude: loc.longitude,
        timestamp: DateTime.now(),
      )).toList();
    } catch (e, stackTrace) {
      AppLogger.error('[Geocoding] خطأ في البحث', e, stackTrace);
      return [];
    }
  }

  /// التحقق من صحة العنوان
  Future<bool> isValidAddress(String address) async {
    try {
      final location = await getLocationFromAddress(address);
      return location != null;
    } catch (e) {
      return false;
    }
  }

  /// الحصول على اسم المدينة
  Future<String?> getCityName(Location location) async {
    try {
      final details = await getDetailedLocation(location);
      return details?['locality'] ?? details?['administrativeArea'];
    } catch (e) {
      return null;
    }
  }

  /// الحصول على اسم الدولة
  Future<String?> getCountryName(Location location) async {
    try {
      final details = await getDetailedLocation(location);
      return details?['country'];
    } catch (e) {
      return null;
    }
  }

  /// تنسيق العنوان للعرض (مختصر)
  String formatShortAddress(Map<String, String> details) {
    final parts = <String>[];
    
    if (details['street']?.isNotEmpty ?? false) {
      parts.add(details['street']!);
    }
    
    if (details['locality']?.isNotEmpty ?? false) {
      parts.add(details['locality']!);
    } else if (details['subAdministrativeArea']?.isNotEmpty ?? false) {
      parts.add(details['subAdministrativeArea']!);
    }
    
    return parts.join(', ');
  }

  /// تنسيق العنوان للعرض (كامل)
  String formatFullAddress(Map<String, String> details) {
    final parts = <String>[];
    
    for (final key in ['street', 'subLocality', 'locality', 'administrativeArea', 'country']) {
      if (details[key]?.isNotEmpty ?? false) {
        parts.add(details[key]!);
      }
    }
    
    return parts.join(', ');
  }

  /// التحقق من وجود موقع في منطقة معينة
  Future<bool> isLocationInArea({
    required Location location,
    required String areaName,
  }) async {
    try {
      final details = await getDetailedLocation(location);
      if (details == null) return false;

      final locality = details['locality']?.toLowerCase() ?? '';
      final admin = details['administrativeArea']?.toLowerCase() ?? '';
      final country = details['country']?.toLowerCase() ?? '';
      
      final searchTerm = areaName.toLowerCase();
      
      return locality.contains(searchTerm) || 
             admin.contains(searchTerm) || 
             country.contains(searchTerm);
    } catch (e) {
      return false;
    }
  }

  /// الحصول على الإحداثيات من عنوان مع تفاصيل إضافية
  Future<LocationWithAddress?> getLocationWithDetails(String address) async {
    try {
      final location = await getLocationFromAddress(address);
      if (location == null) return null;

      final details = await getDetailedLocation(location);
      final formattedAddress = await getAddressFromLocation(location);

      return LocationWithAddress(
        location: location,
        formattedAddress: formattedAddress ?? address,
        details: details ?? {},
      );
    } catch (e) {
      AppLogger.error('[Geocoding] خطأ في الحصول على التفاصيل', e);
      return null;
    }
  }

  /// البحث عن عناوين متعددة
  Future<List<LocationWithAddress>> searchAddresses(String query) async {
    try {
      final locations = await searchLocations(query);
      final results = <LocationWithAddress>[];

      for (final location in locations) {
        final address = await getAddressFromLocation(location);
        final details = await getDetailedLocation(location);

        results.add(LocationWithAddress(
          location: location,
          formattedAddress: address ?? query,
          details: details ?? {},
        ));
      }

      return results;
    } catch (e) {
      AppLogger.error('[Geocoding] خطأ في البحث عن عناوين', e);
      return [];
    }
  }
}

/// موقع مع عنوان
class LocationWithAddress {
  final Location location;
  final String formattedAddress;
  final Map<String, String> details;

  LocationWithAddress({
    required this.location,
    required this.formattedAddress,
    required this.details,
  });

  String get city => details['locality'] ?? details['administrativeArea'] ?? '';
  String get country => details['country'] ?? '';
  String get postalCode => details['postalCode'] ?? '';
}

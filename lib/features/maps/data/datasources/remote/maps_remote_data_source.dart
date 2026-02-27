import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:psga_app/core/errors/exceptions.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/core/config/env_config.dart';
import 'package:psga_app/features/maps/data/models/direction_model.dart';
import 'package:psga_app/features/maps/data/models/place_model.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/features/maps/domain/entities/place_entity.dart';
import 'package:psga_app/features/maps/domain/entities/place_suggestion.dart';

/// مصدر البيانات البعيد للخرائط (Google Maps API)
/// 
/// مسؤول عن التواصل مع Google Maps API
/// يطبق Single Responsibility Principle
abstract class MapsRemoteDataSource {
  /// الحصول على الاتجاهات من Google Directions API
  Future<DirectionModel> getDirections({
    required Location origin,
    required Location destination,
    List<Location>? waypoints,
    String travelMode = 'driving',
  });

  /// البحث عن أماكن من Google Places API
  Future<List<PlaceModel>> searchPlaces({
    required String query,
    Location? location,
    int radius = 5000,
    PlaceType? type,
  });

  /// البحث عن أماكن قريبة
  Future<List<PlaceModel>> searchNearbyPlaces({
    required Location location,
    int radius = 5000,
    PlaceType? type,
    String? keyword,
  });

  /// الحصول على اقتراحات تلقائية
  Future<List<PlaceSuggestion>> getAutocompleteSuggestions({
    required String input,
    Location? location,
    int radius = 50000,
  });

  /// الحصول على تفاصيل مكان
  Future<PlaceModel> getPlaceDetails({
    required String placeId,
    Location? currentLocation,
  });
}

/// تنفيذ مصدر البيانات البعيد
class MapsRemoteDataSourceImpl implements MapsRemoteDataSource {
  final http.Client client;
  
  // استخدام EnvConfig للحصول على API Key
  static String get _apiKey => EnvConfig.googleMapsApiKey;
  static const String _directionsBaseUrl = 'https://maps.googleapis.com/maps/api/directions/json';
  static const String _placesBaseUrl = 'https://maps.googleapis.com/maps/api/place';

  MapsRemoteDataSourceImpl({required this.client});

  @override
  Future<DirectionModel> getDirections({
    required Location origin,
    required Location destination,
    List<Location>? waypoints,
    String travelMode = 'driving',
  }) async {
    try {
      AppLogger.info('[MapsRemoteDataSource] جاري الحصول على الاتجاهات');

      final url = _buildDirectionsUrl(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
        travelMode: travelMode,
      );

      final response = await client.get(Uri.parse(url));

      if (response.statusCode != 200) {
        AppLogger.error('[MapsRemoteDataSource] فشل الطلب: ${response.statusCode}');
        throw ServerException('فشل الاتصال بخادم Google Maps');
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK') {
        AppLogger.error('[MapsRemoteDataSource] حالة غير صحيحة: ${data['status']}');
        throw ServerException('لا يمكن الحصول على الاتجاهات: ${data['status']}');
      }

      final directionModel = DirectionModel.fromJson(data);
      AppLogger.success('[MapsRemoteDataSource] تم الحصول على الاتجاهات بنجاح');
      
      return directionModel;
    } on ServerException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('[MapsRemoteDataSource] خطأ غير متوقع', e, stackTrace);
      throw ServerException('حدث خطأ أثناء الحصول على الاتجاهات');
    }
  }

  @override
  Future<List<PlaceModel>> searchPlaces({
    required String query,
    Location? location,
    int radius = 5000,
    PlaceType? type,
  }) async {
    try {
      AppLogger.info('[MapsRemoteDataSource] البحث عن: $query');

      final url = _buildSearchUrl(
        query: query,
        location: location,
        radius: radius,
        type: type,
      );

      final response = await client.get(Uri.parse(url));

      if (response.statusCode != 200) {
        AppLogger.error('[MapsRemoteDataSource] فشل الطلب: ${response.statusCode}');
        throw ServerException('فشل البحث عن الأماكن');
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
        AppLogger.error('[MapsRemoteDataSource] حالة غير صحيحة: ${data['status']}');
        throw ServerException('لا يمكن البحث عن الأماكن: ${data['status']}');
      }

      final results = data['results'] as List<dynamic>;
      final places = results
          .map((result) {
            try {
              return PlaceModel.fromJson(
                result,
                currentLocation: location,
                apiKey: _apiKey,
              );
            } catch (e) {
              AppLogger.warning('[MapsRemoteDataSource] خطأ في تحليل مكان: $e');
              return null;
            }
          })
          .whereType<PlaceModel>()
          .toList();

      AppLogger.success('[MapsRemoteDataSource] تم العثور على ${places.length} نتيجة');
      return places;
    } on ServerException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('[MapsRemoteDataSource] خطأ غير متوقع', e, stackTrace);
      throw ServerException('حدث خطأ أثناء البحث');
    }
  }

  @override
  Future<List<PlaceModel>> searchNearbyPlaces({
    required Location location,
    int radius = 5000,
    PlaceType? type,
    String? keyword,
  }) async {
    try {
      AppLogger.info('[MapsRemoteDataSource] البحث عن أماكن قريبة');

      final url = _buildNearbyUrl(
        location: location,
        radius: radius,
        type: type,
        keyword: keyword,
      );

      final response = await client.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw ServerException('فشل البحث عن أماكن قريبة');
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
        throw ServerException('لا يمكن البحث عن أماكن قريبة: ${data['status']}');
      }

      final results = data['results'] as List<dynamic>;
      final places = results
          .map((result) {
            try {
              return PlaceModel.fromJson(
                result,
                currentLocation: location,
                apiKey: _apiKey,
              );
            } catch (e) {
              return null;
            }
          })
          .whereType<PlaceModel>()
          .toList();

      AppLogger.success('[MapsRemoteDataSource] تم العثور على ${places.length} مكان قريب');
      return places;
    } on ServerException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('[MapsRemoteDataSource] خطأ غير متوقع', e, stackTrace);
      throw ServerException('حدث خطأ أثناء البحث عن أماكن قريبة');
    }
  }

  @override
  Future<List<PlaceSuggestion>> getAutocompleteSuggestions({
    required String input,
    Location? location,
    int radius = 50000,
  }) async {
    try {
      if (input.trim().isEmpty) return [];

      AppLogger.info('[MapsRemoteDataSource] الحصول على اقتراحات: $input');

      final url = _buildAutocompleteUrl(
        input: input,
        location: location,
        radius: radius,
      );

      final response = await client.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw ServerException('فشل الحصول على الاقتراحات');
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
        return [];
      }

      final predictions = data['predictions'] as List<dynamic>;
      final suggestions = predictions.map((prediction) {
        return PlaceSuggestion(
          placeId: prediction['place_id'] as String,
          description: prediction['description'] as String,
          mainText: prediction['structured_formatting']['main_text'] as String,
          secondaryText: prediction['structured_formatting']['secondary_text'] as String? ?? '',
        );
      }).toList();

      AppLogger.success('[MapsRemoteDataSource] ${suggestions.length} اقتراح');
      return suggestions;
    } on ServerException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('[MapsRemoteDataSource] خطأ غير متوقع', e, stackTrace);
      throw ServerException('حدث خطأ أثناء الحصول على الاقتراحات');
    }
  }

  @override
  Future<PlaceModel> getPlaceDetails({
    required String placeId,
    Location? currentLocation,
  }) async {
    try {
      AppLogger.info('[MapsRemoteDataSource] الحصول على تفاصيل: $placeId');

      final url = '$_placesBaseUrl/details/json?place_id=$placeId&key=$_apiKey&language=ar&fields=place_id,name,formatted_address,geometry,rating,user_ratings_total,formatted_phone_number,website,opening_hours,photos,types';

      final response = await client.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw ServerException('فشل الحصول على تفاصيل المكان');
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK') {
        throw ServerException('لا يمكن الحصول على تفاصيل المكان: ${data['status']}');
      }

      final result = data['result'];
      final placeModel = PlaceModel.fromJson(
        result,
        currentLocation: currentLocation,
        apiKey: _apiKey,
      );

      AppLogger.success('[MapsRemoteDataSource] تم الحصول على التفاصيل بنجاح');
      return placeModel;
    } on ServerException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('[MapsRemoteDataSource] خطأ غير متوقع', e, stackTrace);
      throw ServerException('حدث خطأ أثناء الحصول على التفاصيل');
    }
  }

  // ==================== دوال مساعدة ====================

  /// بناء URL للـ Directions API
  String _buildDirectionsUrl({
    required Location origin,
    required Location destination,
    required String travelMode,
    List<Location>? waypoints,
  }) {
    final params = <String, String>{
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': travelMode,
      'key': _apiKey,
      'language': 'ar',
    };

    if (waypoints != null && waypoints.isNotEmpty) {
      final waypointsStr = waypoints
          .map((w) => '${w.latitude},${w.longitude}')
          .join('|');
      params['waypoints'] = waypointsStr;
    }

    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '$_directionsBaseUrl?$queryString';
  }

  /// بناء URL للبحث النصي
  String _buildSearchUrl({
    required String query,
    required int radius,
    Location? location,
    PlaceType? type,
  }) {
    final params = <String, String>{
      'query': query,
      'key': _apiKey,
      'language': 'ar',
    };

    if (location != null) {
      params['location'] = '${location.latitude},${location.longitude}';
      params['radius'] = radius.toString();
    }

    if (type != null) {
      params['type'] = PlaceModel.placeTypeToApiString(type);
    }

    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '$_placesBaseUrl/textsearch/json?$queryString';
  }

  /// بناء URL للبحث عن أماكن قريبة
  String _buildNearbyUrl({
    required Location location,
    required int radius,
    PlaceType? type,
    String? keyword,
  }) {
    final params = <String, String>{
      'location': '${location.latitude},${location.longitude}',
      'radius': radius.toString(),
      'key': _apiKey,
      'language': 'ar',
    };

    if (type != null) {
      params['type'] = PlaceModel.placeTypeToApiString(type);
    }

    if (keyword != null && keyword.isNotEmpty) {
      params['keyword'] = keyword;
    }

    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '$_placesBaseUrl/nearbysearch/json?$queryString';
  }

  /// بناء URL للاقتراحات التلقائية
  String _buildAutocompleteUrl({
    required String input,
    required int radius,
    Location? location,
  }) {
    final params = <String, String>{
      'input': input,
      'key': _apiKey,
      'language': 'ar',
    };

    if (location != null) {
      params['location'] = '${location.latitude},${location.longitude}';
      params['radius'] = radius.toString();
    }

    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '$_placesBaseUrl/autocomplete/json?$queryString';
  }
}

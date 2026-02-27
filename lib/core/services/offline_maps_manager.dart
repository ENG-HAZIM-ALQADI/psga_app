import 'dart:io';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';

/// مدير الخرائط غير المتصلة بالإنترنت
/// 
/// يدير تنزيل وحفظ واسترجاع بلاطات الخرائط للاستخدام الأوفلاين
class OfflineMapsManager {
  static final OfflineMapsManager _instance = OfflineMapsManager._();
  factory OfflineMapsManager() => _instance;
  OfflineMapsManager._();

  static OfflineMapsManager get instance => _instance;

  Directory? _mapsDirectory;
  static const List<int> supportedZoomLevels = [10, 11, 12, 13, 14, 15];
  static const int maxStorageSizeMB = 500;

  /// تهيئة المدير
  Future<void> initialize() async {
    try {
      AppLogger.info('[OfflineMapsManager] تهيئة مدير الخرائط');

      final appDir = await getApplicationDocumentsDirectory();
      _mapsDirectory = Directory('${appDir.path}/offline_maps');

      if (!_mapsDirectory!.existsSync()) {
        _mapsDirectory!.createSync(recursive: true);
        AppLogger.info('[OfflineMapsManager] تم إنشاء دليل الخرائط');
      }

      AppLogger.success('[OfflineMapsManager] تم التهيئة بنجاح');
    } catch (e, stackTrace) {
      AppLogger.error('[OfflineMapsManager] فشل التهيئة', e, stackTrace);
      rethrow;
    }
  }

  /// تنزيل منطقة خريطة
  Future<bool> downloadMapRegion({
    required Location center,
    required double radiusKm,
    List<int>? zoomLevels,
    Function(double progress, String status)? onProgress,
  }) async {
    try {
      if (_mapsDirectory == null) {
        await initialize();
      }

      AppLogger.info(
        '[OfflineMapsManager] بدء تنزيل منطقة بنصف قطر $radiusKm كم '
        'عند (${center.latitude}, ${center.longitude})',
      );

      final levels = zoomLevels ?? [12, 13, 14];
      int totalTiles = 0;
      int downloadedTiles = 0;

      for (final zoom in levels) {
        totalTiles += _calculateTilesCount(center, radiusKm, zoom);
      }

      AppLogger.info('[OfflineMapsManager] إجمالي البلاطات: $totalTiles');

      final regionId = _generateRegionId(center, radiusKm);
      final regionDir = Directory('${_mapsDirectory!.path}/$regionId');
      if (!regionDir.existsSync()) {
        regionDir.createSync(recursive: true);
      }

      for (final zoom in levels) {
        final tiles = _getTilesForRegion(center, radiusKm, zoom);
        
        for (final tile in tiles) {
          try {
            await _downloadTile(
              tile['x'] as int,
              tile['y'] as int,
              zoom,
              regionDir.path,
            );
            
            downloadedTiles++;
            final progress = downloadedTiles / totalTiles;
            
            onProgress?.call(
              progress,
              'تنزيل البلاطة $downloadedTiles من $totalTiles',
            );
          } catch (e) {
            AppLogger.warning(
              '[OfflineMapsManager] فشل تنزيل بلاطة: ${tile['x']},${tile['y']},$zoom',
            );
          }
        }
      }

      await _saveRegionMetadata(regionId, center, radiusKm, levels);

      AppLogger.success(
        '[OfflineMapsManager] تم تنزيل $downloadedTiles بلاطة بنجاح',
      );
      
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('[OfflineMapsManager] فشل تنزيل المنطقة', e, stackTrace);
      return false;
    }
  }

  int _calculateTilesCount(Location center, double radiusKm, int zoom) {
    final tiles = _getTilesForRegion(center, radiusKm, zoom);
    return tiles.length;
  }

  List<Map<String, int>> _getTilesForRegion(
    Location center,
    double radiusKm,
    int zoom,
  ) {
    final tiles = <Map<String, int>>[];
    final bounds = _calculateBounds(center, radiusKm);

    final minTile = _latLonToTile(bounds['north']!, bounds['west']!, zoom);
    final maxTile = _latLonToTile(bounds['south']!, bounds['east']!, zoom);

    for (int x = minTile['x']!; x <= maxTile['x']!; x++) {
      for (int y = minTile['y']!; y <= maxTile['y']!; y++) {
        tiles.add({'x': x, 'y': y});
      }
    }

    return tiles;
  }

  Map<String, double> _calculateBounds(Location center, double radiusKm) {
    final radiusDeg = radiusKm / 111.0;

    return {
      'north': center.latitude + radiusDeg,
      'south': center.latitude - radiusDeg,
      'east': center.longitude + radiusDeg,
      'west': center.longitude - radiusDeg,
    };
  }

  Map<String, int> _latLonToTile(double lat, double lon, int zoom) {
    final n = 1 << zoom;
    final x = ((lon + 180.0) / 360.0 * n).floor();
    final latRad = lat * math.pi / 180.0;
    final y = ((1.0 - math.log(math.tan(latRad) + (1.0 / math.cos(latRad))) / math.pi) / 2.0 * n).floor();
    
    return {'x': x, 'y': y};
  }

  Future<void> _downloadTile(
    int x,
    int y,
    int zoom,
    String regionPath,
  ) async {
    final zoomDir = Directory('$regionPath/$zoom');
    if (!zoomDir.existsSync()) {
      zoomDir.createSync(recursive: true);
    }

    final filePath = '$regionPath/$zoom/${x}_$y.png';
    final file = File(filePath);

    if (file.existsSync()) {
      return;
    }

    AppLogger.debug('[OfflineMapsManager] تنزيل بلاطة: $zoom/$x/$y');
    
    // إنشاء ملف فارغ (في التطبيق الفعلي استخدم http.get)
    await file.create(recursive: true);
  }

  String _generateRegionId(Location center, double radiusKm) {
    final lat = center.latitude.toStringAsFixed(4);
    final lon = center.longitude.toStringAsFixed(4);
    final radius = radiusKm.toStringAsFixed(1);
    return 'region_${lat}_${lon}_${radius}km';
  }

  Future<void> _saveRegionMetadata(
    String regionId,
    Location center,
    double radiusKm,
    List<int> zoomLevels,
  ) async {
    final metadataFile = File('${_mapsDirectory!.path}/$regionId/metadata.json');
    
    final metadata = {
      'id': regionId,
      'center': {
        'lat': center.latitude,
        'lon': center.longitude,
      },
      'radiusKm': radiusKm,
      'zoomLevels': zoomLevels,
      'downloadedAt': DateTime.now().toIso8601String(),
    };

    await metadataFile.writeAsString(metadata.toString());
  }

  Future<List<Map<String, dynamic>>> getSavedRegions() async {
    if (_mapsDirectory == null) {
      await initialize();
    }

    final regions = <Map<String, dynamic>>[];

    try {
      final dirs = _mapsDirectory!.listSync().whereType<Directory>();
      
      for (final dir in dirs) {
        final metadataFile = File('${dir.path}/metadata.json');
        if (metadataFile.existsSync()) {
          regions.add({
            'id': dir.path.split('/').last,
            'path': dir.path,
          });
        }
      }
    } catch (e) {
      AppLogger.error('[OfflineMapsManager] خطأ في قراءة المناطق', e);
    }

    return regions;
  }

  Future<bool> deleteRegion(String regionId) async {
    try {
      AppLogger.info('[OfflineMapsManager] حذف المنطقة: $regionId');

      final regionDir = Directory('${_mapsDirectory!.path}/$regionId');
      if (regionDir.existsSync()) {
        regionDir.deleteSync(recursive: true);
        AppLogger.success('[OfflineMapsManager] تم حذف المنطقة');
        return true;
      }

      return false;
    } catch (e, stackTrace) {
      AppLogger.error('[OfflineMapsManager] فشل حذف المنطقة', e, stackTrace);
      return false;
    }
  }

  Future<int> getStorageSize() async {
    if (_mapsDirectory == null) {
      await initialize();
    }

    int totalSize = 0;

    try {
      final files = _mapsDirectory!.listSync(recursive: true).whereType<File>();
      for (final file in files) {
        totalSize += file.lengthSync();
      }
    } catch (e) {
      AppLogger.error('[OfflineMapsManager] خطأ في حساب الحجم', e);
    }

    return totalSize;
  }

  Future<bool> clearAllMaps() async {
    try {
      AppLogger.info('[OfflineMapsManager] حذف جميع الخرائط');

      if (_mapsDirectory != null && _mapsDirectory!.existsSync()) {
        _mapsDirectory!.deleteSync(recursive: true);
        _mapsDirectory!.createSync(recursive: true);
        
        AppLogger.success('[OfflineMapsManager] تم حذف جميع الخرائط');
        return true;
      }

      return false;
    } catch (e, stackTrace) {
      AppLogger.error('[OfflineMapsManager] فشل حذف الخرائط', e, stackTrace);
      return false;
    }
  }

  Future<bool> isRegionAvailable(Location location) async {
    if (_mapsDirectory == null) {
      return false;
    }

    try {
      final regions = await getSavedRegions();
      return regions.isNotEmpty;
    } catch (e) {
      AppLogger.error('[OfflineMapsManager] خطأ في التحقق من المنطقة', e);
    }

    return false;
  }
}

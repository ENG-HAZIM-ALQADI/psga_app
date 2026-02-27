import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/constants/app_dimensions.dart';
import 'package:psga_app/core/services/location_service.dart';
import 'package:psga_app/core/services/offline_maps_manager.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/features/maps/presentation/widgets/offline_maps_download_widget.dart';
import 'package:psga_app/features/maps/presentation/pages/places_search_page.dart';
import 'package:psga_app/features/maps/presentation/bloc/maps/bloc.dart';
import 'package:psga_app/injection_container.dart';

/// صفحة إعدادات الخرائط
class MapsSettingsPage extends StatefulWidget {
  const MapsSettingsPage({super.key});

  @override
  State<MapsSettingsPage> createState() => _MapsSettingsPageState();
}

class _MapsSettingsPageState extends State<MapsSettingsPage> {
  final _offlineMapsManager = OfflineMapsManager.instance;
  final _locationService = LocationService.instance;
  
  Location? _currentLocation;
  List<Map<String, dynamic>> _savedRegions = [];
  int _totalStorageBytes = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _getCurrentLocation(),
      _loadSavedRegions(),
      _loadStorageSize(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _currentLocation = Location(
            latitude: position.latitude,
            longitude: position.longitude,
            timestamp: DateTime.now(),
          );
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadSavedRegions() async {
    final regions = await _offlineMapsManager.getSavedRegions();
    if (mounted) {
      setState(() => _savedRegions = regions);
    }
  }

  Future<void> _loadStorageSize() async {
    final size = await _offlineMapsManager.getStorageSize();
    if (mounted) {
      setState(() => _totalStorageBytes = size);
    }
  }

  Future<void> _showDownloadDialog() async {
    if (_currentLocation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.selectLocationFirst)),
        );
      }
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => BlocProvider.value(
        value: sl<MapsBloc>(),
        child: Dialog(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingLG),
            child: OfflineMapsDownloadWidget(
              center: _currentLocation!,
            ),
          ),
        ),
      ),
    );
    
    await _loadData();
  }

  Future<void> _navigateToPlacesSearch() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlacesSearchPage(
          currentLocation: _currentLocation,
        ),
      ),
    );
  }

  Future<void> _deleteRegion(String regionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteArea),
        content: Text(AppLocalizations.of(context)!.deleteAreaContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _offlineMapsManager.deleteRegion(regionId);
      await _loadData();
    }
  }

  Future<void> _clearAllMaps() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteAllMaps),
        content: Text(AppLocalizations.of(context)!.deleteAllMapsContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.deleteAll),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _offlineMapsManager.clearAllMaps();
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.maps),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.paddingMD),
                children: [
                  _buildStorageInfo(),
                  const SizedBox(height: AppDimensions.spacingLG),
                  _buildActionsSection(),
                  const SizedBox(height: AppDimensions.spacingLG),
                  _buildSavedRegionsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildStorageInfo() {
    final sizeMB = (_totalStorageBytes / 1024 / 1024).toStringAsFixed(2);
    const maxSizeMB = OfflineMapsManager.maxStorageSizeMB;
    final percentage = (_totalStorageBytes / (maxSizeMB * 1024 * 1024) * 100).clamp(0.0, 100.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: AppDimensions.spacingSM),
                const Text(
                  'التخزين المستخدم',
                  style: TextStyle(
                    fontSize: AppDimensions.fontLG,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMD),
            Text(
              '$sizeMB / $maxSizeMB ميجابايت',
              style: const TextStyle(fontSize: AppDimensions.fontMD),
            ),
            const SizedBox(height: AppDimensions.spacingSM),
            LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                percentage > 80 ? Colors.red : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXS),
            Text(
              '${percentage.toStringAsFixed(1)}% مستخدم',
              style: TextStyle(
                fontSize: AppDimensions.fontSM,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'الإجراءات',
          style: TextStyle(
            fontSize: AppDimensions.fontLG,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingMD),
        ElevatedButton.icon(
          onPressed: _showDownloadDialog,
          icon: const Icon(Icons.download),
          label: Text(AppLocalizations.of(context)!.downloadOfflineMaps),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(AppDimensions.paddingMD),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSM),
        ElevatedButton.icon(
          onPressed: _navigateToPlacesSearch,
          icon: const Icon(Icons.search),
          label: Text(AppLocalizations.of(context)!.searchPlaces),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(AppDimensions.paddingMD),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSM),
        OutlinedButton.icon(
          onPressed: _savedRegions.isNotEmpty ? _clearAllMaps : null,
          icon: const Icon(Icons.delete_sweep),
          label: Text(AppLocalizations.of(context)!.deleteAllMapsBtn),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(AppDimensions.paddingMD),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedRegionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'المناطق المحفوظة (${_savedRegions.length})',
          style: const TextStyle(
            fontSize: AppDimensions.fontLG,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingMD),
        if (_savedRegions.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingXL),
              child: Column(
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: AppDimensions.iconXXL,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: AppDimensions.spacingMD),
                  Text(
                    'لا توجد خرائط محفوظة',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: AppDimensions.fontMD,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._savedRegions.map(
            (region) => Card(
              margin: const EdgeInsets.only(bottom: AppDimensions.spacingSM),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.map, color: Colors.white),
                ),
                title: Text(region['id'] as String),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteRegion(region['id'] as String),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

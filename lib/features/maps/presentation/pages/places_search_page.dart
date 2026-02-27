import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/constants/app_dimensions.dart';
import 'package:psga_app/core/services/location_service.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/features/maps/domain/entities/place_entity.dart';
import 'package:psga_app/features/maps/presentation/bloc/maps/bloc.dart';
import 'package:psga_app/shared/widgets/loading_widget.dart';
import 'package:psga_app/shared/widgets/error_widget.dart';
import 'package:psga_app/shared/widgets/empty_state_widget.dart';
import 'package:psga_app/injection_container.dart';

/// صفحة البحث عن الأماكن
/// 
/// تستخدم MapsBloc لإدارة الحالة بدلاً من PlacesService المباشر
class PlacesSearchPage extends StatefulWidget {
  final Location? currentLocation;
  final Function(PlaceEntity)? onPlaceSelected;

  const PlacesSearchPage({
    super.key,
    this.currentLocation,
    this.onPlaceSelected,
  });

  @override
  State<PlacesSearchPage> createState() => _PlacesSearchPageState();
}

class _PlacesSearchPageState extends State<PlacesSearchPage> {
  final _searchController = TextEditingController();
  final _locationService = LocationService.instance;
  late MapsBloc _mapsBloc;

  Location? _currentLocation;
  PlaceType? _selectedType;

  @override
  void initState() {
    super.initState();
    _mapsBloc = sl<MapsBloc>();
    _currentLocation = widget.currentLocation;
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapsBloc.close();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (_currentLocation != null) return;

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
      AppLogger.error('[PlacesSearch] فشل الحصول على الموقع', e);
    }
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      _mapsBloc.add(const ClearPlacesEvent());
      return;
    }

    _mapsBloc.add(SearchPlacesEvent(
      query: query,
      location: _currentLocation,
      type: _selectedType,
      radius: 5000,
    ));
  }

  void _searchNearby() {
    if (_currentLocation == null) {
      _showSnackBar('يجب تحديد الموقع الحالي أولاً');
      return;
    }

    _mapsBloc.add(SearchNearbyPlacesEvent(
      location: _currentLocation!,
      type: _selectedType,
      radius: 5000,
    ));
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _mapsBloc,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.maps),
          elevation: 0,
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            _buildFilters(),
            Expanded(
              child: BlocConsumer<MapsBloc, MapsState>(
                listener: (context, state) {
                  if (state is MapsError) {
                    _showSnackBar(state.message);
                  }
                },
                builder: (context, state) {
                  if (state is MapsLoading) {
                    return const LoadingWidget(
                      message: 'جاري البحث...',
                    );
                  }

                  if (state is PlacesLoaded) {
                    if (state.places.isEmpty) {
                      return const EmptyStateWidget(
                        message: 'لا توجد نتائج',
                        icon: Icons.search_off,
                      );
                    }
                    return _buildPlacesList(state.places);
                  }

                  if (state is MapsError) {
                    return ErrorDisplayWidget(
                      message: state.message,
                      onRetry: () => _performSearch(_searchController.text),
                    );
                  }

                  return const EmptyStateWidget(
                    message: 'ابحث عن الأماكن القريبة منك',
                    icon: Icons.search,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMD),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
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
                          _mapsBloc.add(const ClearPlacesEvent());
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {});
                if (value.length > 2) {
                  _performSearch(value);
                }
              },
              onSubmitted: _performSearch,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingSM),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _searchNearby,
            tooltip: 'البحث القريب',
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingMD,
          vertical: AppDimensions.paddingSM,
        ),
        children: [
          _buildFilterChip('الكل', null),
          _buildFilterChip('مطاعم', PlaceType.restaurant),
          _buildFilterChip('مستشفيات', PlaceType.hospital),
          _buildFilterChip('صيدليات', PlaceType.pharmacy),
          _buildFilterChip('محطات وقود', PlaceType.gasStation),
          _buildFilterChip('شرطة', PlaceType.police),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, PlaceType? type) {
    final isSelected = _selectedType == type;
    return Padding(
      padding: const EdgeInsets.only(right: AppDimensions.paddingSM),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedType = selected ? type : null;
          });
          
          if (_searchController.text.isNotEmpty) {
            _performSearch(_searchController.text);
          }
        },
        selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        checkmarkColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildPlacesList(List<PlaceEntity> places) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.paddingMD),
      itemCount: places.length,
      itemBuilder: (context, index) {
        final place = places[index];
        return _buildPlaceCard(place);
      },
    );
  }

  Widget _buildPlaceCard(PlaceEntity place) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingMD),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getPlaceTypeColor(place.type),
          child: Icon(
            _getPlaceTypeIcon(place.type),
            color: Colors.white,
            size: AppDimensions.iconSM,
          ),
        ),
        title: Text(
          place.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (place.address != null) ...[
              const SizedBox(height: AppDimensions.spacingXS),
              Text(
                place.address!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: AppDimensions.fontSM,
                ),
              ),
            ],
            if (place.distance != null) ...[
              const SizedBox(height: AppDimensions.spacingXS),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: AppDimensions.spacingXS),
                  Text(
                    '${place.distance!.toStringAsFixed(1)} كم',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: AppDimensions.fontSM,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: widget.onPlaceSelected != null
            ? IconButton(
                icon: const Icon(Icons.add_circle),
                color: Theme.of(context).colorScheme.primary,
                onPressed: () {
                  widget.onPlaceSelected!(place);
                  Navigator.of(context).pop();
                },
              )
            : null,
        onTap: () {
          if (widget.onPlaceSelected != null) {
            widget.onPlaceSelected!(place);
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  Color _getPlaceTypeColor(PlaceType type) {
    switch (type) {
      case PlaceType.hospital:
        return Colors.red;
      case PlaceType.pharmacy:
        return Colors.green;
      case PlaceType.gasStation:
        return Colors.orange;
      case PlaceType.restaurant:
        return Colors.purple;
      case PlaceType.police:
        return Colors.blue;
      case PlaceType.bank:
        return Colors.teal;
      case PlaceType.mosque:
        return Colors.indigo;
      case PlaceType.school:
      case PlaceType.university:
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  IconData _getPlaceTypeIcon(PlaceType type) {
    switch (type) {
      case PlaceType.hospital:
        return Icons.local_hospital;
      case PlaceType.pharmacy:
        return Icons.local_pharmacy;
      case PlaceType.gasStation:
        return Icons.local_gas_station;
      case PlaceType.restaurant:
        return Icons.restaurant;
      case PlaceType.cafe:
        return Icons.local_cafe;
      case PlaceType.police:
        return Icons.local_police;
      case PlaceType.bank:
        return Icons.account_balance;
      case PlaceType.atm:
        return Icons.atm;
      case PlaceType.mosque:
        return Icons.mosque;
      case PlaceType.school:
      case PlaceType.university:
        return Icons.school;
      case PlaceType.park:
        return Icons.park;
      case PlaceType.mall:
        return Icons.shopping_cart;
      case PlaceType.hotel:
        return Icons.hotel;
      case PlaceType.airport:
        return Icons.flight;
      default:
        return Icons.place;
    }
  }
}

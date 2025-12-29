import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:psga_app/features/maps/data/services/geocoding_service.dart';

/// شاشة البحث عن أماكن
class PlaceSearchPage extends StatefulWidget {
  const PlaceSearchPage({super.key});

  @override
  State<PlaceSearchPage> createState() => _PlaceSearchPageState();
}

class _PlaceSearchPageState extends State<PlaceSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final GeocodingService _geocodingService = GeocodingService();
  final FocusNode _focusNode = FocusNode();

  List<PlaceSuggestion> _suggestions = [];
  List<String> _recentSearches = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _loadRecentSearches() {
    _recentSearches = [
      'الرياض',
      'جدة',
      'مكة المكرمة',
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          decoration: const InputDecoration(
            hintText: 'ابحث عن مكان...',
            border: InputBorder.none,
          ),
          onChanged: _onSearchChanged,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _suggestions = [];
                });
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_suggestions.isNotEmpty) {
      return _buildSuggestionsList();
    }

    if (_searchController.text.isEmpty) {
      return _buildRecentAndFavorites();
    }

    return const Center(
      child: Text('لا توجد نتائج'),
    );
  }

  /// بناء قائمة الاقتراحات
  Widget _buildSuggestionsList() {
    return ListView.builder(
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.location_on, color: Colors.grey),
          ),
          title: Text(
            suggestion.mainText,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            suggestion.secondaryText,
            style: const TextStyle(color: Colors.grey),
          ),
          onTap: () => _selectPlace(suggestion),
        );
      },
    );
  }

  /// بناء قسم البحث الأخير والمفضلة
  Widget _buildRecentAndFavorites() {
    return ListView(
      children: [
        if (_recentSearches.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'عمليات البحث الأخيرة',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ..._recentSearches.map((search) => ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(search),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    setState(() {
                      _recentSearches.remove(search);
                    });
                  },
                ),
                onTap: () {
                  _searchController.text = search;
                  _onSearchChanged(search);
                },
              )),
        ],
        const Divider(),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'الأماكن المفضلة',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.home, color: Colors.blue),
          ),
          title: const Text('المنزل'),
          subtitle: const Text('أضف موقع المنزل'),
          onTap: () {},
        ),
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.work, color: Colors.orange),
          ),
          title: const Text('العمل'),
          subtitle: const Text('أضف موقع العمل'),
          onTap: () {},
        ),
      ],
    );
  }

  /// عند تغيير نص البحث
  Future<void> _onSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final suggestions = await _geocodingService.searchPlaces(query);

    if (mounted) {
      setState(() {
        _suggestions = suggestions;
        _isLoading = false;
      });
    }
  }

  /// اختيار مكان
  void _selectPlace(PlaceSuggestion suggestion) {
    if (suggestion.latitude != null && suggestion.longitude != null) {
      if (!_recentSearches.contains(suggestion.mainText)) {
        _recentSearches.insert(0, suggestion.mainText);
        if (_recentSearches.length > 5) {
          _recentSearches.removeLast();
        }
      }

      Navigator.pop(context, {
        'location': LatLng(suggestion.latitude!, suggestion.longitude!),
        'address': suggestion.description,
        'name': suggestion.mainText,
      });
    }
  }
}

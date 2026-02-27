import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/features/maps/presentation/bloc/maps/bloc.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/shared/widgets/custom_button.dart';
import 'package:psga_app/shared/widgets/loading_widget.dart';

/// Widget لتنزيل منطقة خريطة للاستخدام الأوفلاين
class OfflineMapsDownloadWidget extends StatefulWidget {
  final double defaultRadiusKm;
  final Location center;

  const OfflineMapsDownloadWidget({
    required this.center,
    super.key,
    this.defaultRadiusKm = 5.0,
  });

  @override
  State<OfflineMapsDownloadWidget> createState() => _OfflineMapsDownloadWidgetState();
}

class _OfflineMapsDownloadWidgetState extends State<OfflineMapsDownloadWidget> {
  late double _radiusKm;
  final List<int> _selectedZoomLevels = [12, 13, 14];

  @override
  void initState() {
    super.initState();
    _radiusKm = widget.defaultRadiusKm;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MapsBloc, MapsState>(
      listener: (context, state) {
        if (state is MapsDownloaded) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else if (state is MapsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is DownloadingMaps) {
          return _buildDownloadingView(state);
        }

        return _buildConfigureView();
      },
    );
  }

  Widget _buildConfigureView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'تنزيل خريطة أوفلاين',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // نصف القطر
          Text('${AppLocalizations.of(context)!.radius}: ${_radiusKm.toStringAsFixed(1)} ${AppLocalizations.of(context)!.km}'),
          Slider(
            value: _radiusKm,
            min: 1.0,
            max: 20.0,
            divisions: 19,
            label: '${_radiusKm.toStringAsFixed(1)} كم',
            onChanged: (value) {
              setState(() {
                _radiusKm = value;
              });
            },
          ),
          
          const SizedBox(height: 16),
          
          // مستويات التكبير
          const Text(
            'مستويات التكبير:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          
          Wrap(
            spacing: 8,
            children: [12, 13, 14, 15].map((zoom) {
              final isSelected = _selectedZoomLevels.contains(zoom);
              return FilterChip(
                label: Text('$zoom'),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedZoomLevels.add(zoom);
                    } else {
                      _selectedZoomLevels.remove(zoom);
                    }
                    _selectedZoomLevels.sort();
                  });
                },
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          
          // معلومات التقدير
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تقدير:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('${AppLocalizations.of(context)!.downloadArea}: ~${(_radiusKm * _radiusKm * 3.14).toStringAsFixed(1)} km²'),
                Text('${AppLocalizations.of(context)!.zoomLevels}: ${_selectedZoomLevels.length}'),
                Text('${AppLocalizations.of(context)!.estimatedSize}: ${_estimateSize()} MB'),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // أزرار
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  text: 'تنزيل',
                  onPressed: _selectedZoomLevels.isEmpty ? null : _startDownload,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadingView(DownloadingMaps state) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'جاري التنزيل...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          LoadingWidget(
            message: state.status,
          ),
          
          const SizedBox(height: 16),
          
          LinearProgressIndicator(
            value: state.progress,
            minHeight: 8,
          ),
          
          const SizedBox(height: 8),
          
          Text(
            '${(state.progress * 100).toStringAsFixed(1)}%',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _estimateSize() {
    // تقدير تقريبي بناءً على عدد البلاطات
    final tilesPerZoom = (_radiusKm * 2) * (_radiusKm * 2);
    final totalTiles = tilesPerZoom * _selectedZoomLevels.length;
    final sizeInMB = (totalTiles * 20) / 1024; // ~20KB per tile
    
    if (sizeInMB < 1) {
      return '<1';
    } else if (sizeInMB > 100) {
      return '>${(sizeInMB / 100).toStringAsFixed(0)}00';
    }
    
    return sizeInMB.toStringAsFixed(0);
  }

  void _startDownload() {
    context.read<MapsBloc>().add(
          DownloadMapRegionEvent(
            center: widget.center,
            radiusKm: _radiusKm,
            zoomLevels: _selectedZoomLevels,
          ),
        );
  }
}

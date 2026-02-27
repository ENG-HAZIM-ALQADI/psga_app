import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/core/utils/extensions.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';
import 'package:psga_app/features/trips/presentation/bloc/bloc.dart';
import 'package:psga_app/features/trips/presentation/pages/trip_detail_page.dart';
import 'package:psga_app/shared/widgets/empty_state_widget.dart';
import 'package:psga_app/shared/widgets/error_widget.dart' as custom;
import 'package:psga_app/shared/widgets/loading_widget.dart';
import 'package:psga_app/shared/widgets/sync_indicator.dart';

class TripHistoryPage extends StatefulWidget {
  final String userId;

  const TripHistoryPage({
    required this.userId,
    super.key,
  });

  @override
  State<TripHistoryPage> createState() => _TripHistoryPageState();
}

class _TripHistoryPageState extends State<TripHistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  TripStatus? _selectedFilter;
  List<TripEntity> _cachedTrips = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadHistory() {
    context.read<TripBloc>().add(
          LoadTripHistoryEvent(userId: widget.userId),
        );
  }

  List<TripEntity> _filterTrips(List<TripEntity> trips) {
    var filtered = trips;
    if (_selectedFilter != null) {
      filtered = filtered.where((t) => t.status == _selectedFilter).toList();
    }
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered =
          filtered.where((t) => t.route.name.toLowerCase().contains(query)).toList();
    }
    return filtered;
  }

  // ── حذف رحلة واحدة ──────────────────────────────────────
  Future<bool> _confirmDeleteTrip(BuildContext ctx, TripEntity trip) async {
    final l10n = AppLocalizations.of(ctx)!;
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_outline,
                color: Theme.of(ctx).colorScheme.error, size: 26),
            const SizedBox(width: 10),
            Text(l10n.deleteTripTitle,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          l10n.deleteTripConfirm,
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete, size: 18),
            label: Text(l10n.delete),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _deleteTrip(TripEntity trip) {
    AppLogger.info('[TripHistory] حذف رحلة: ${trip.id}');
    context.read<TripBloc>().add(DeleteTripEvent(tripId: trip.id));
    // حذف فوري من القائمة المحلية
    setState(() {
      _cachedTrips.removeWhere((t) => t.id == trip.id);
    });
  }

  // ── مسح جميع الرحلات ──────────────────────────────────────
  void _showClearAllDialog() {
    final l10n = AppLocalizations.of(context)!;
    final count = _cachedTrips.length;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_sweep,
                color: Theme.of(context).colorScheme.error, size: 26),
            const SizedBox(width: 10),
            Text(l10n.clearAllTripsTitle,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.clearAllTripsConfirm(count.toString()),
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.deleteAccountWarning2,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_sweep, size: 18),
            label: Text(l10n.clearAllBtn),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<TripBloc>().add(
                    ClearAllTripsEvent(userId: widget.userId),
                  );
              setState(() => _cachedTrips.clear());
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trips),
        actions: [
          const SyncIndicator(showPendingCount: true),
          const SizedBox(width: 4),
          // ── زر Clear All ──────────────────────
          if (_cachedTrips.isNotEmpty)
            Tooltip(
              message: l10n.deleteAllTripsTooltip,
              child: IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                color: Theme.of(context).colorScheme.error,
                onPressed: _showClearAllDialog,
              ),
            ),
          const SizedBox(width: 4),
          // ── فلتر الحالة ──────────────────────
          PopupMenuButton<TripStatus?>(
            icon: const Icon(Icons.filter_list),
            tooltip: l10n.filterTooltip,
            onSelected: (status) => setState(() => _selectedFilter = status),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: null,
                child: Text(l10n.allTrips),
              ),
              PopupMenuItem(
                value: TripStatus.completed,
                child: Row(children: [
                  const Icon(Icons.check_circle,
                      color: AppColors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(l10n.completedTrips),
                ]),
              ),
              PopupMenuItem(
                value: TripStatus.cancelled,
                child: Row(children: [
                  const Icon(Icons.cancel, color: AppColors.red, size: 20),
                  const SizedBox(width: 8),
                  Text(l10n.cancelledTrips),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: BlocConsumer<TripBloc, TripState>(
        buildWhen: (previous, current) =>
            current is TripHistoryLoaded ||
            current is TripLoading ||
            current is TripError ||
            current is TripCompleted ||
            current is TripDeleted ||
            current is TripHistoryCleared,
        listener: (context, state) {
          if (state is TripHistoryLoaded) {
            setState(() {
              _cachedTrips = state.trips;
              _isLoading = false;
              _errorMessage = null;
            });
          } else if (state is TripDeleted) {
            // ✅ تم الحذف بنجاح
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.tripDeletedSuccess),
                backgroundColor: AppColors.green,
              ),
            );
          } else if (state is TripHistoryCleared) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.allTripsCleared),
                backgroundColor: AppColors.green,
              ),
            );
            setState(() => _cachedTrips.clear());
          } else if (state is TripCompleted) {
            AppLogger.info('[TripHistory] رحلة منتهية - إعادة التحميل');
            context.read<TripBloc>().add(
                  LoadTripHistoryEvent(userId: widget.userId),
                );
          } else if (state is TripLoading) {
            if (_cachedTrips.isEmpty) setState(() => _isLoading = true);
          } else if (state is TripError) {
            setState(() {
              _isLoading = false;
              _errorMessage = state.message;
            });
          }
        },
        builder: (context, state) {
          if (_isLoading && _cachedTrips.isEmpty) {
            return LoadingWidget(message: l10n.loadingTripHistory);
          }

          if (_errorMessage != null && _cachedTrips.isEmpty) {
            return custom.ErrorDisplayWidget(
              message: _errorMessage!,
              onRetry: () {
                setState(() => _errorMessage = null);
                _loadHistory();
              },
            );
          }

          final filteredTrips = _filterTrips(_cachedTrips);

          return Column(
            children: [
              // ── حقل البحث ──────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l10n.searchTripsHint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () =>
                                setState(() => _searchController.clear()),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withOpacity(0.4),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),

              // ── شريط الفلتر النشط ──────────────────────────
              if (_selectedFilter != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Chip(
                        label: Text(_getFilterText(_selectedFilter!)),
                        avatar: Icon(_getStatusIcon(_selectedFilter!), size: 16),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () =>
                            setState(() => _selectedFilter = null),
                      ),
                      const Spacer(),
                      Text(
                        l10n.tripFilterCount(
                          filteredTrips.length.toString(),
                          _cachedTrips.length.toString(),
                        ),
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

              // ── القائمة ──────────────────────────────────
              if (filteredTrips.isEmpty)
                Expanded(
                  child: EmptyStateWidget(
                    icon: _cachedTrips.isEmpty
                        ? Icons.history_toggle_off
                        : Icons.search_off,
                    message: _cachedTrips.isEmpty
                        ? l10n.noTripHistory
                        : l10n.noResultsLabel,
                  ),
                )
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => _loadHistory(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: filteredTrips.length,
                      itemBuilder: (context, index) {
                        final trip = filteredTrips[index];
                        return _TripHistoryCard(
                          trip: trip,
                          onDelete: () async {
                            final ok =
                                await _confirmDeleteTrip(context, trip);
                            if (ok && context.mounted) {
                              _deleteTrip(trip);
                            }
                          },
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TripDetailPage(tripId: trip.id),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  IconData _getStatusIcon(TripStatus status) {
    switch (status) {
      case TripStatus.completed:
        return Icons.check_circle;
      case TripStatus.cancelled:
        return Icons.cancel;
      default:
        return Icons.route;
    }
  }

  String _getFilterText(TripStatus status) {
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case TripStatus.completed:
        return l10n.completedStatusLabel;
      case TripStatus.cancelled:
        return l10n.cancelledStatusLabel;
      default:
        return '';
    }
  }

}

// ── بطاقة رحلة مع Swipe-to-delete ──────────────────────────
class _TripHistoryCard extends StatelessWidget {
  final TripEntity trip;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _TripHistoryCard({
    required this.trip,
    required this.onDelete,
    required this.onTap,
  });

  Color _getStatusColor(BuildContext context, TripStatus status) {
    switch (status) {
      case TripStatus.completed:
        return AppColors.green;
      case TripStatus.cancelled:
        return AppColors.red;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData _getStatusIcon(TripStatus status) {
    switch (status) {
      case TripStatus.completed:
        return Icons.check_circle;
      case TripStatus.cancelled:
        return Icons.cancel;
      default:
        return Icons.route;
    }
  }

  String _formatDuration(BuildContext context, Duration duration) {
    final l10n = AppLocalizations.of(context)!;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return l10n.durationHoursMinutes(hours.toString(), minutes.toString());
    }
    return l10n.durationMinutesOnly(minutes.toString());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dismissible(
      key: Key('trip_${trip.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete, color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(
              l10n.delete,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // نمنع Dismissible من إزالة البطاقة (نتحكم نحن)
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // أيقونة الحالة
                CircleAvatar(
                  backgroundColor:
                      _getStatusColor(context, trip.status).withOpacity(0.15),
                  child: Icon(
                    _getStatusIcon(trip.status),
                    color: _getStatusColor(context, trip.status),
                  ),
                ),
                const SizedBox(width: 12),
                // معلومات الرحلة
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.route.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trip.startTime.formatDateTime(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _StatChip(
                            icon: Icons.straighten,
                            text:
                                '${trip.distanceTraveled.toStringAsFixed(1)} ${l10n.distanceKmUnit}',
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            icon: Icons.timer,
                            text: _formatDuration(context, trip.actualDuration),
                          ),
                          if (trip.totalDeviations > 0) ...[
                            const SizedBox(width: 8),
                            _StatChip(
                              icon: Icons.warning_amber_rounded,
                              text: '${trip.totalDeviations}',
                              color: AppColors.deviationOrange,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // أزرار الإجراءات
                Column(
                  children: [
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withOpacity(0.4),
                    ),
                    const SizedBox(height: 8),
                    // زر حذف صريح
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onDelete,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Theme.of(context)
                              .colorScheme
                              .error
                              .withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// شريحة إحصائية صغيرة
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _StatChip({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 12, color: c)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/core/services/sync_manager.dart';
import 'package:psga_app/core/services/sync_service.dart';

/// مؤشر صغير لحالة المزامنة (للاستخدام في AppBar)
class SyncIndicator extends StatefulWidget {
  final bool showPendingCount;
  final VoidCallback? onTap;

  const SyncIndicator({
    super.key,
    this.showPendingCount = true,
    this.onTap,
  });

  @override
  State<SyncIndicator> createState() => _SyncIndicatorState();
}

class _SyncIndicatorState extends State<SyncIndicator>
    with SingleTickerProviderStateMixin {
  final SyncManager _syncManager = SyncManager.instance;
  
  SyncStatus _currentStatus = SyncStatus.idle;
  int _pendingCount = 0;
  
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();

    _currentStatus = _syncManager.currentStatus;
    _pendingCount = _syncManager.pendingOperations;

    // تهيئة أنيميشن الدوران
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // بدء الدوران إذا كانت جاري المزامنة
    if (_currentStatus == SyncStatus.syncing) {
      _rotationController.repeat();
    }

    // الاستماع لتغييرات الحالة
    _syncManager.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
          _pendingCount = _syncManager.pendingOperations;
        });

        if (status == SyncStatus.syncing) {
          _rotationController.repeat();
        } else {
          _rotationController.stop();
          _rotationController.reset();
        }
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(),
            if (widget.showPendingCount && _pendingCount > 0) ...[
              const SizedBox(width: 4),
              _buildBadge(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData icon;
    Color color;

    switch (_currentStatus) {
      case SyncStatus.idle:
        icon = Icons.cloud_done;
        color = AppColors.textSecondary;
        break;
      case SyncStatus.syncing:
        icon = Icons.sync;
        color = AppColors.primary;
        break;
      case SyncStatus.success:
        icon = Icons.check_circle;
        color = AppColors.success;
        break;
      case SyncStatus.error:
        icon = Icons.error_outline;
        color = AppColors.error;
        break;
      case SyncStatus.pending:
        icon = Icons.pending;
        color = AppColors.warning;
        break;
    }

    Widget iconWidget = Icon(icon, color: color, size: 20);

    // إضافة دوران إذا كانت جاري المزامنة
    if (_currentStatus == SyncStatus.syncing) {
      iconWidget = RotationTransition(
        turns: _rotationController,
        child: iconWidget,
      );
    }

    return iconWidget;
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getBadgeColor(),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _pendingCount > 99 ? '99+' : '$_pendingCount',
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getBadgeColor() {
    switch (_currentStatus) {
      case SyncStatus.error:
        return AppColors.error;
      case SyncStatus.pending:
        return AppColors.warning;
      case SyncStatus.syncing:
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }
}

/// مؤشر مزامنة موسع مع نص
class SyncIndicatorExpanded extends StatefulWidget {
  final VoidCallback? onTap;

  const SyncIndicatorExpanded({
    super.key,
    this.onTap,
  });

  @override
  State<SyncIndicatorExpanded> createState() => _SyncIndicatorExpandedState();
}

class _SyncIndicatorExpandedState extends State<SyncIndicatorExpanded> {
  final SyncManager _syncManager = SyncManager.instance;
  SyncStatus _currentStatus = SyncStatus.idle;

  @override
  void initState() {
    super.initState();
    _currentStatus = _syncManager.currentStatus;

    _syncManager.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _getBackgroundColor().withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _getBackgroundColor().withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SyncIndicator(
              showPendingCount: true,
              onTap: widget.onTap,
            ),
            const SizedBox(width: 4),
            Text(
              _getStatusText(context),
              style: TextStyle(
                color: _getBackgroundColor(),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (_currentStatus) {
      case SyncStatus.idle:
        return AppColors.textSecondary;
      case SyncStatus.syncing:
        return AppColors.primary;
      case SyncStatus.success:
        return AppColors.success;
      case SyncStatus.error:
        return AppColors.error;
      case SyncStatus.pending:
        return AppColors.warning;
    }
  }

  String _getStatusText(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (_currentStatus) {
      case SyncStatus.idle:
        return l10n.idle;
      case SyncStatus.syncing:
        return l10n.syncing;
      case SyncStatus.success:
        return l10n.synced;
      case SyncStatus.error:
        return l10n.error;
      case SyncStatus.pending:
        return l10n.pendingSync('');
    }
  }
}

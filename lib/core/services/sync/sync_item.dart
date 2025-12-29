import 'package:hive/hive.dart';
import 'package:equatable/equatable.dart';

part 'sync_item.g.dart';

/// أنواع العناصر القابلة للمزامنة
enum SyncItemType {
  user,
  route,
  trip,
  alert,
  contact,
  alertConfig,
}

/// إجراءات المزامنة
enum SyncAction {
  create,
  update,
  delete,
}

/// حالات المزامنة
enum SyncItemStatus {
  pending,    // في الانتظار
  syncing,    // جاري المزامنة
  synced,     // تمت المزامنة
  failed,     // فشلت المزامنة
}

/// عنصر في قائمة المزامنة
@HiveType(typeId: 7)
class SyncItem extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final SyncItemType type;

  @HiveField(2)
  final SyncAction action;

  @HiveField(3)
  final Map<String, dynamic> data;

  @HiveField(4)
  final String localId;

  @HiveField(5)
  final String? remoteId;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final int attempts;

  @HiveField(8)
  final DateTime? lastAttempt;

  @HiveField(9)
  final String? error;

  @HiveField(10)
  final SyncItemStatus status;

  SyncItem({
    String? id,
    required this.type,
    required this.action,
    required this.data,
    required this.localId,
    this.remoteId,
    required this.createdAt,
    this.attempts = 0,
    this.lastAttempt,
    this.error,
    this.status = SyncItemStatus.pending,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  SyncItem copyWith({
    String? id,
    SyncItemType? type,
    SyncAction? action,
    Map<String, dynamic>? data,
    String? localId,
    String? remoteId,
    DateTime? createdAt,
    int? attempts,
    DateTime? lastAttempt,
    String? error,
    SyncItemStatus? status,
  }) {
    return SyncItem(
      id: id ?? this.id,
      type: type ?? this.type,
      action: action ?? this.action,
      data: data ?? this.data,
      localId: localId ?? this.localId,
      remoteId: remoteId ?? this.remoteId,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      lastAttempt: lastAttempt ?? this.lastAttempt,
      error: error ?? this.error,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        action,
        data,
        localId,
        remoteId,
        createdAt,
        attempts,
        lastAttempt,
        error,
        status,
      ];
}

/// نتيجة المزامنة
class SyncResult {
  final bool success;
  final String? error;
  final String? remoteId;

  const SyncResult({
    required this.success,
    this.error,
    this.remoteId,
  });

  factory SyncResult.success({String? remoteId}) {
    return SyncResult(
      success: true,
      remoteId: remoteId,
    );
  }

  factory SyncResult.failure(String error) {
    return SyncResult(
      success: false,
      error: error,
    );
  }
}

/// حالة المزامنة للعرض في الـ UI
class SyncStatus {
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final int pendingCount;
  final String? lastError;
  final double progress; // 0.0 - 1.0

  const SyncStatus({
    required this.isSyncing,
    this.lastSyncTime,
    required this.pendingCount,
    this.lastError,
    this.progress = 0.0,
  });

  bool get hasError => lastError != null;
  bool get hasPendingItems => pendingCount > 0;
  bool get isFullySynced => !isSyncing && pendingCount == 0 && !hasError;

  SyncStatus copyWith({
    bool? isSyncing,
    DateTime? lastSyncTime,
    int? pendingCount,
    String? lastError,
    double? progress,
  }) {
    return SyncStatus(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      pendingCount: pendingCount ?? this.pendingCount,
      lastError: lastError ?? this.lastError,
      progress: progress ?? this.progress,
    );
  }
}

/// واجهة للكيانات القابلة للمزامنة
abstract class SyncableEntity {
  String get id;
  DateTime get updatedAt;
  bool get isDeleted => false;
}

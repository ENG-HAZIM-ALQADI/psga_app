import 'package:flutter/foundation.dart';
import 'sync_item.dart';

/// محلل التعارضات - Singleton
/// يحل التعارضات بين البيانات المحلية والسحابية
/// القاعدة: الأحدث يفوز (Last-Write-Wins)
class ConflictResolver {
  ConflictResolver._();

  static final ConflictResolver _instance = ConflictResolver._();
  static ConflictResolver get instance => _instance;

  /// حل تعارض بين نسختين من الكيان
  /// القاعدة: الأحدث يفوز (مقارنة updatedAt)
  T resolve<T extends SyncableEntity>(T local, T remote) {
    try {
      debugPrint('⚠️ [Conflict] جاري حل التعارض...');
      debugPrint('⚠️ [Conflict] Local updatedAt: ${local.updatedAt}');
      debugPrint('⚠️ [Conflict] Remote updatedAt: ${remote.updatedAt}');

      // إذا كان أحدهما محذوف، استخدم الآخر
      if (local.isDeleted && !remote.isDeleted) {
        debugPrint('⚠️ [Conflict] النسخة المحلية محذوفة - استخدام البعيدة');
        return remote;
      }
      if (!local.isDeleted && remote.isDeleted) {
        debugPrint('⚠️ [Conflict] النسخة البعيدة محذوفة - استخدام المحلية');
        return local;
      }

      // مقارنة الأوقات
      if (local.updatedAt.isAfter(remote.updatedAt)) {
        debugPrint('⚠️ [Conflict] ✅ استخدام النسخة المحلية (أحدث)');
        return local;
      } else if (remote.updatedAt.isAfter(local.updatedAt)) {
        debugPrint('⚠️ [Conflict] ✅ استخدام النسخة البعيدة (أحدث)');
        return remote;
      } else {
        // نفس الوقت - تفضيل البعيدة
        debugPrint('⚠️ [Conflict] ⚖️ نفس الوقت - استخدام النسخة البعيدة');
        return remote;
      }
    } catch (e) {
      debugPrint('⚠️ [Conflict] ❌ خطأ في حل التعارض: $e');
      // في حالة الخطأ، نفضل البعيدة كخيار آمن
      return remote;
    }
  }

  /// دمج قائمتين من الكيانات مع حل التعارضات
  List<T> mergeList<T extends SyncableEntity>(
    List<T> localList,
    List<T> remoteList,
  ) {
    try {
      debugPrint('⚠️ [Conflict] دمج القوائم...');
      debugPrint('⚠️ [Conflict] Local: ${localList.length} عنصر');
      debugPrint('⚠️ [Conflict] Remote: ${remoteList.length} عنصر');

      final Map<String, T> mergedMap = {};

      // إضافة العناصر المحلية
      for (final item in localList) {
        if (!item.isDeleted) {
          mergedMap[item.id] = item;
        }
      }

      // دمج العناصر البعيدة
      for (final remoteItem in remoteList) {
        if (mergedMap.containsKey(remoteItem.id)) {
          // تعارض - حل باستخدام resolve
          final localItem = mergedMap[remoteItem.id]!;
          mergedMap[remoteItem.id] = resolve(localItem, remoteItem);
        } else {
          // عنصر جديد من البعيد
          if (!remoteItem.isDeleted) {
            mergedMap[remoteItem.id] = remoteItem;
          }
        }
      }

      final merged = mergedMap.values.toList();
      debugPrint('⚠️ [Conflict] ✅ النتيجة: ${merged.length} عنصر');

      return merged;
    } catch (e) {
      debugPrint('⚠️ [Conflict] ❌ خطأ في الدمج: $e');
      // في حالة الخطأ، نعيد البعيدة
      return remoteList;
    }
  }

  /// دمج JSON objects
  Map<String, dynamic> mergeJson(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    try {
      final localUpdated = local['updatedAt'] as String?;
      final remoteUpdated = remote['updatedAt'] as String?;

      if (localUpdated == null && remoteUpdated == null) {
        // لا توجد أوقات - استخدام البعيدة
        return remote;
      }

      if (localUpdated == null) return remote;
      if (remoteUpdated == null) return local;

      final localTime = DateTime.parse(localUpdated);
      final remoteTime = DateTime.parse(remoteUpdated);

      if (localTime.isAfter(remoteTime)) {
        debugPrint('⚠️ [Conflict] JSON: استخدام المحلية');
        return local;
      } else {
        debugPrint('⚠️ [Conflict] JSON: استخدام البعيدة');
        return remote;
      }
    } catch (e) {
      debugPrint('⚠️ [Conflict] ❌ خطأ في دمج JSON: $e');
      return remote;
    }
  }

  /// فحص وجود تعارض
  bool hasConflict<T extends SyncableEntity>(T local, T remote) {
    // تعارض إذا كان كلاهما محدث بعد الـ sync الأخير
    // وليس لهما نفس الوقت
    return local.updatedAt != remote.updatedAt;
  }

  /// حل تعارض بناءً على استراتيجية معينة
  T resolveWithStrategy<T extends SyncableEntity>(
    T local,
    T remote, {
    ConflictStrategy strategy = ConflictStrategy.lastWriteWins,
  }) {
    switch (strategy) {
      case ConflictStrategy.lastWriteWins:
        return resolve(local, remote);

      case ConflictStrategy.localWins:
        debugPrint('⚠️ [Conflict] استراتيجية: المحلية تفوز');
        return local;

      case ConflictStrategy.remoteWins:
        debugPrint('⚠️ [Conflict] استراتيجية: البعيدة تفوز');
        return remote;

      case ConflictStrategy.merge:
        // استراتيجية الدمج تحتاج تطبيق مخصص لكل نوع
        debugPrint('⚠️ [Conflict] استراتيجية: دمج (غير مطبق - استخدام lastWriteWins)');
        return resolve(local, remote);
    }
  }

  /// إحصائيات التعارضات
  ConflictStats getConflictStats<T extends SyncableEntity>(
    List<T> localList,
    List<T> remoteList,
  ) {
    int conflicts = 0;
    int localWins = 0;
    int remoteWins = 0;
    int identical = 0;

    final localMap = {for (var item in localList) item.id: item};
    final remoteMap = {for (var item in remoteList) item.id: item};

    for (final id in localMap.keys) {
      if (remoteMap.containsKey(id)) {
        final local = localMap[id]!;
        final remote = remoteMap[id]!;

        if (local.updatedAt == remote.updatedAt) {
          identical++;
        } else {
          conflicts++;
          if (local.updatedAt.isAfter(remote.updatedAt)) {
            localWins++;
          } else {
            remoteWins++;
          }
        }
      }
    }

    return ConflictStats(
      totalConflicts: conflicts,
      localWins: localWins,
      remoteWins: remoteWins,
      identical: identical,
    );
  }

  /// طباعة تقرير التعارضات
  void printConflictReport<T extends SyncableEntity>(
    List<T> localList,
    List<T> remoteList,
  ) {
    final stats = getConflictStats(localList, remoteList);

    debugPrint('⚠️ [Conflict] ═══════════════════════════════════');
    debugPrint('⚠️ [Conflict] تقرير التعارضات:');
    debugPrint('⚠️ [Conflict] إجمالي التعارضات: ${stats.totalConflicts}');
    debugPrint('⚠️ [Conflict] المحلية فازت: ${stats.localWins}');
    debugPrint('⚠️ [Conflict] البعيدة فازت: ${stats.remoteWins}');
    debugPrint('⚠️ [Conflict] متطابقة: ${stats.identical}');
    debugPrint('⚠️ [Conflict] ═══════════════════════════════════');
  }
}

/// استراتيجيات حل التعارضات
enum ConflictStrategy {
  lastWriteWins,  // الأحدث يفوز (افتراضي)
  localWins,      // المحلية تفوز دائماً
  remoteWins,     // البعيدة تفوز دائماً
  merge,          // دمج ذكي
}

/// إحصائيات التعارضات
class ConflictStats {
  final int totalConflicts;
  final int localWins;
  final int remoteWins;
  final int identical;

  const ConflictStats({
    required this.totalConflicts,
    required this.localWins,
    required this.remoteWins,
    required this.identical,
  });

  @override
  String toString() {
    return 'ConflictStats(total: $totalConflicts, local: $localWins, remote: $remoteWins, identical: $identical)';
  }
}
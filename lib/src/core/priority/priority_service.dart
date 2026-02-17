import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'priority_model.dart';

/// Priority Service
///
/// Alarm öncelik seviyelerini yönetir.
/// Priorities tablosu: id, name, code, color, level, description
class PriorityService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  List<Priority> _priorities = [];

  final _prioritiesController = StreamController<List<Priority>>.broadcast();

  PriorityService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  // ============================================
  // GETTERS
  // ============================================

  Stream<List<Priority>> get prioritiesStream => _prioritiesController.stream;
  List<Priority> get priorities => List.unmodifiable(_priorities);

  // ============================================
  // OPERATIONS
  // ============================================

  /// Tüm öncelikleri getir
  Future<List<Priority>> getAll({bool forceRefresh = false}) async {
    const cacheKey = 'priorities_all';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        _priorities = cached
            .map((e) => Priority.fromJson(e as Map<String, dynamic>))
            .toList();
        _prioritiesController.add(_priorities);
        return _priorities;
      }
    }

    try {
      // NOT: DB'de active alanı NULL olabilir, bu yüzden
      // active=false olanları hariç tut (NULL ve true dahil)
      final response = await _supabase
          .from('priorities')
          .select()
          .or('active.eq.true,active.is.null')
          .order('level');

      _priorities = (response as List)
          .map((e) => Priority.fromJson(e as Map<String, dynamic>))
          .toList();

      await _cacheManager.set(
        cacheKey,
        _priorities.map((e) => e.toJson()).toList(),
        ttl: const Duration(hours: 1),
      );

      _prioritiesController.add(_priorities);
      return _priorities;
    } catch (e, stackTrace) {
      Logger.error('Failed to get priorities', e, stackTrace);
      return _priorities;
    }
  }

  /// ID ile priority getir
  Priority? getById(String id) {
    return _priorities.where((p) => p.id == id).firstOrNull;
  }

  void dispose() {
    _prioritiesController.close();
  }
}

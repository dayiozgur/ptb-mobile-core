import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'models/form_template.dart';

/// Form Template Service
///
/// Low-code builder tarafından tasarlanan form şablonlarını, tüm ağacıyla
/// (bölümler → alanlar + kurallar) tek bir nested PostgREST select ile yükler.
class FormTemplateService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  FormTemplateService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  static const Duration _ttl = Duration(minutes: 10);

  /// Tüm ağacı çeken nested select ifadesi.
  ///
  /// FK-hint adları PostgREST embed sözdizimine göre verilir; kural
  /// tablosunda aynı hedef tabloya (form_fields) iki ayrı FK olduğu için
  /// `!<fk_column>` disambiguation gerekir.
  static const String _treeSelect =
      '*, form_sections(*, form_fields(*)), '
      'form_field_rules(*, '
      'source_field:form_fields!source_field_id(code), '
      'target_field:form_fields!target_field_id(code))';

  /// ID ile form şablonunu (tüm ağacıyla) getir.
  Future<FormTemplate?> getById(String id, {bool forceRefresh = false}) async {
    final cacheKey = 'form_template_$id';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        try {
          return FormTemplate.fromJson(cached);
        } catch (cacheError) {
          Logger.warning('Failed to parse form template from cache: $cacheError');
          await _cacheManager.delete(cacheKey);
        }
      }
    }

    try {
      final response = await _supabase
          .from('form_templates')
          .select(_treeSelect)
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      await _cacheManager.set(cacheKey, response, ttl: _ttl);
      return FormTemplate.fromJson(response);
    } catch (e) {
      Logger.error('Error fetching form template by id: $e');
      rethrow;
    }
  }

  /// Entity tipine göre yayınlanmış en yüksek versiyonlu şablonu getir.
  ///
  /// [code] verilirse ek olarak şablon koduna göre filtrelenir.
  Future<FormTemplate?> getByEntityType(
    String entityType, {
    String? code,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'form_template_entity_${entityType}_${code ?? 'any'}';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        try {
          return FormTemplate.fromJson(cached);
        } catch (cacheError) {
          Logger.warning('Failed to parse form template from cache: $cacheError');
          await _cacheManager.delete(cacheKey);
        }
      }
    }

    try {
      var query = _supabase
          .from('form_templates')
          .select(_treeSelect)
          .eq('entity_type', entityType)
          .eq('is_published', true);

      if (code != null) {
        query = query.eq('code', code);
      }

      final response =
          await query.order('version', ascending: false).limit(1);
      final responseList = response as List;

      if (responseList.isEmpty) return null;

      final row = responseList.first as Map<String, dynamic>;
      await _cacheManager.set(cacheKey, row, ttl: _ttl);
      return FormTemplate.fromJson(row);
    } catch (e) {
      Logger.error('Error fetching form template by entity type: $e');
      rethrow;
    }
  }

  /// Cache'i temizle (belirli bir id ya da tümü).
  Future<void> invalidateCache([String? id]) async {
    if (id != null) {
      await _cacheManager.delete('form_template_$id');
    } else {
      await _cacheManager.deleteWhere((key) => key.startsWith('form_template_'));
    }
  }
}

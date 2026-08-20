import 'package:supabase_flutter/supabase_flutter.dart';

import '../platform/platform_context.dart';
import '../utils/logger.dart';
import '../../presentation/report_viewer/models/report_template.dart';

/// Web builder'ında tasarlanan rapor şablonlarını (`dr_report_templates`) ve
/// bunlara bağlı widget'ları (`dr_report_widgets`) yükleyen servis.
///
/// Şablon + widget'lar **tek select** ile nested olarak çekilir
/// (`'*, dr_report_widgets(*)'`). Widget verileri burada ÇÖZÜLMEZ — her widget
/// kendi `data_source_id` + `query_config` değerleriyle viewer tarafında
/// `ReportQueryService.runWidget(...)` üzerinden bağımsız çözülür.
///
/// Örnek kullanım:
/// ```dart
/// final template = await sl<ReportService>().getByCode('alarm_ozet');
/// // template.widgets → grid'e render edilir
/// ```
class ReportService {
  final SupabaseClient _supabase;
  final PlatformContext? _platformContext;

  static const String _table = 'dr_report_templates';
  static const String _select = '*, dr_report_widgets(*)';

  ReportService(this._supabase, {PlatformContext? platformContext})
      : _platformContext = platformContext;

  /// Şablonu `code` üzerinden yükler.
  ///
  /// `active = true` + `is_published = true` zorunlu; aktif platform
  /// çözülebiliyorsa `platform_id` de eşleştirilir (RLS ile birlikte kapsam
  /// doğru daraltılır). Bulunamazsa `null` döner.
  Future<ReportTemplate?> getByCode(String code) async {
    try {
      var query = _supabase
          .from(_table)
          .select(_select)
          .eq('code', code)
          .eq('active', true)
          .eq('is_published', true);

      final platformId = _platformContext?.activePlatformId;
      if (platformId != null && platformId.isNotEmpty) {
        query = query.eq('platform_id', platformId);
      }

      final rows = await query.limit(1);
      if (rows.isEmpty) {
        Logger.warning('ReportService.getByCode: şablon bulunamadı (code=$code)');
        return null;
      }
      return ReportTemplate.fromJson(Map<String, dynamic>.from(rows.first));
    } catch (e) {
      Logger.error('ReportService.getByCode başarısız (code=$code)', e);
      rethrow;
    }
  }

  /// Şablonu `id` üzerinden yükler. `active = true` zorunlu.
  /// Bulunamazsa `null` döner.
  Future<ReportTemplate?> getById(String id) async {
    try {
      final rows = await _supabase
          .from(_table)
          .select(_select)
          .eq('id', id)
          .eq('active', true)
          .limit(1);

      if (rows.isEmpty) {
        Logger.warning('ReportService.getById: şablon bulunamadı (id=$id)');
        return null;
      }
      return ReportTemplate.fromJson(Map<String, dynamic>.from(rows.first));
    } catch (e) {
      Logger.error('ReportService.getById başarısız (id=$id)', e);
      rethrow;
    }
  }
}

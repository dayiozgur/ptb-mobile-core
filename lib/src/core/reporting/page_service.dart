import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';
import '../../presentation/page_viewer/models/page_template.dart';

/// Web builder'da tasarlanmış dashboard sayfalarını (`pb_page_templates`)
/// koda göre yükler.
///
/// İç içe `pb_page_widgets` satırlarıyla birlikte tek sorguda çeker; RLS
/// çağıranın tenant'ına göre kapsar. Yalnız yayınlanmış (`is_published`) ve
/// aktif (`active`) şablonlar döner. Platform verilmişse, o platforma ait ya
/// da paylaşımlı (`platform_id IS NULL`) şablonlar filtrelenir.
class PageService {
  final SupabaseClient _supabase;

  static const String _table = 'pb_page_templates';

  /// İç içe widget'lar dâhil tam seçim.
  static const String _selectColumns = '*, pb_page_widgets(*)';

  PageService(this._supabase);

  /// [code] koduna sahip yayınlanmış sayfa şablonunu (widget'larıyla) döner.
  ///
  /// Bulunamazsa `null` döner. [platformId] verilirse platform (veya
  /// paylaşımlı) filtresi uygulanır. Hata durumunda loglayıp yeniden fırlatır.
  Future<PageTemplate?> getByCode(String code, {String? platformId}) async {
    try {
      var query = _supabase
          .from(_table)
          .select(_selectColumns)
          .eq('code', code)
          .eq('active', true)
          .eq('is_published', true);

      if (platformId != null && platformId.isNotEmpty) {
        // O platforma ait ya da tüm platformlarda paylaşımlı (null) şablonlar.
        query = query.or('platform_id.eq.$platformId,platform_id.is.null');
      }

      final row = await query.limit(1).maybeSingle();

      if (row == null) {
        Logger.warning('PageService.getByCode: sayfa bulunamadı (code=$code)');
        return null;
      }

      return PageTemplate.fromJson(Map<String, dynamic>.from(row));
    } catch (e) {
      Logger.error('PageService.getByCode başarısız (code=$code)', e);
      rethrow;
    }
  }
}

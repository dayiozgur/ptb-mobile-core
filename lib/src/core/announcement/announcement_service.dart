import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../tenant/tenant_service.dart';
import '../utils/logger.dart';
import 'announcement_model.dart';

export 'announcement_model.dart';

/// Duyuru (announcement) salt-okuma servisi — `public.announcements`.
///
/// Web `PtbPageService.fetchNewsFeed` ile aynı okuma sözleşmesi + tekil detay.
/// Yazma admin-only'dir ve web arayüzünden yapılır (RLS). Liste hata durumunda
/// UI'a fırlatmaz ([]); detay rethrow eder (ekran hatayı gösterir).
class AnnouncementService {
  final SupabaseClient _supabase;

  AnnouncementService({required SupabaseClient supabase}) : _supabase = supabase;

  static const String _cols =
      'id, title, body, category, image_url, publish_date, published';

  /// Yayınlanmış duyurular (yeni → eski), tenant-scoped.
  Future<List<Announcement>> list({int limit = 50}) async {
    try {
      var q = _supabase
          .from('announcements')
          .select(_cols)
          .eq('published', true);
      final tenantId = sl<TenantService>().currentTenantId;
      if (tenantId != null) q = q.eq('tenant_id', tenantId);
      final res =
          await q.order('publish_date', ascending: false).limit(limit);
      return (res as List)
          .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('Duyurular yüklenemedi', e);
      return const [];
    }
  }

  /// Tekil duyuru (detay). Bulunamazsa null.
  Future<Announcement?> getById(String id) async {
    try {
      final res = await _supabase
          .from('announcements')
          .select(_cols)
          .eq('id', id)
          .maybeSingle();
      return res == null ? null : Announcement.fromJson(res);
    } catch (e) {
      Logger.error('Duyuru detayı yüklenemedi ($id)', e);
      rethrow;
    }
  }
}

/// Convenience getter — çekirdek servis-locator'dan çözer.
AnnouncementService get announcementService => sl<AnnouncementService>();

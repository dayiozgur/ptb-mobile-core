import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';

/// Bir zorunlu/isteğe bağlı yasal belge (`consent_documents`, global — tenant
/// veya platform kapsamı YOK; her platform aynı katalogu kullanır).
/// `version` artışı yeniden onay zorlar.
class ConsentDoc {
  /// `consent_documents.scope`: uygulama-geneli kapı yalnız 'platform'
  /// belgelerini ister ('team_chat*' = sohbet paneli bildirimleri).
  static const String scopePlatform = 'platform';

  final String code;
  final String title;
  final String version;
  final String? url;
  final bool mandatory;
  final int sortOrder;
  final String scope;

  const ConsentDoc({
    required this.code,
    required this.title,
    required this.version,
    this.url,
    this.mandatory = true,
    this.sortOrder = 0,
    this.scope = scopePlatform,
  });

  /// Web `ConsentService.mapDoc` ile aynı: `scope` yoksa 'platform'.
  factory ConsentDoc.fromRow(Map<String, dynamic> r) {
    final so = r['sort_order'];
    return ConsentDoc(
      code: r['code'] as String,
      title: (r['title'] as String?) ?? (r['code'] as String),
      version: (r['version'] ?? '').toString(),
      url: r['url'] as String?,
      mandatory: r['mandatory'] == true,
      sortOrder: so is num ? so.toInt() : 0,
      scope: (r['scope'] as String?) ?? scopePlatform,
    );
  }

  /// Başlığın i18n anahtarı (web `consentDocTitleKey`):
  /// `consent.document.<code>.title`.
  String get titleKey => 'consent.document.$code.title';
}

/// Kaydedilecek tek onay kararı (belge kodu + onaylanan sürüm).
class ConsentDecision {
  final String code;
  final String version;
  const ConsentDecision({required this.code, required this.version});
}

/// Yasal onay (KVKK/consent) servisi — web
/// `libs/core/services/src/consent.service.ts` mobil eşleniği.
///
/// Okuma/yazma web ile AYNI tablolar ve AYNI sorgular (RPC yok):
///  - `consent_documents` (RLS: authenticated, `active = true`),
///    `select('*')` + istemci tarafında `scope == 'platform'` filtresi;
///  - `platform_consents` (RLS: kendi satırını insert/select/update;
///    `user_id = auth.uid()`), aktif onay = `accepted = true AND revoked_at IS NULL`.
///
/// Kapı kuralı (web `consentActiveGuard`): aktif + zorunlu platform belgelerinin
/// HER BİRİ kullanıcının GÜNCEL sürümdeki onayına sahip olmalı; sürüm farkı =
/// eksik. Belgeler platforma göre AYRIŞMAZ (katalog global).
class ConsentService {
  ConsentService({required SupabaseClient supabase}) : _supabase = supabase;

  final SupabaseClient _supabase;

  /// Mobil yazımların `platform_consents.source` değeri (web 'web' yazar;
  /// kolonda CHECK yok — denetim izinde kaynak ayrımı için).
  static const String source = 'mobile';

  /// Aktif + zorunlu PLATFORM belgeleri (kapı), görüntü sırasıyla.
  Future<List<ConsentDoc>> getMandatoryDocuments() async {
    final data = await _supabase
        .from('consent_documents')
        .select('*')
        .eq('active', true)
        .eq('mandatory', true)
        .order('sort_order', ascending: true);
    return _platformDocs(data);
  }

  /// Tüm aktif PLATFORM belgeleri (zorunlu + isteğe bağlı çerez/depolama).
  Future<List<ConsentDoc>> getAllActiveDocuments() async {
    final data = await _supabase
        .from('consent_documents')
        .select('*')
        .eq('active', true)
        .order('sort_order', ascending: true);
    return _platformDocs(data);
  }

  /// Kullanıcının geçerli onayları: `document_code → onaylanan sürüm`.
  Future<Map<String, String>> getUserConsents(String userId) async {
    final map = <String, String>{};
    if (userId.isEmpty) return map;
    final data = await _supabase
        .from('platform_consents')
        .select('document_code,version,accepted,revoked_at')
        .eq('user_id', userId)
        .eq('accepted', true)
        .isFilter('revoked_at', null);
    for (final r in (data as List)) {
      final m = Map<String, dynamic>.from(r as Map);
      map[m['document_code'] as String] = (m['version'] ?? '').toString();
    }
    return map;
  }

  /// Kullanıcının GÜNCEL sürümde onaylamadığı zorunlu belgeler. Boş ⇒ kapı açık.
  Future<List<ConsentDoc>> getMissingMandatory(String userId) async {
    final results = await Future.wait<Object>([
      getMandatoryDocuments(),
      getUserConsents(userId),
    ]);
    return missingFrom(
      results[0] as List<ConsentDoc>,
      results[1] as Map<String, String>,
    );
  }

  /// Saf kural (test edilebilir): sürümü eşleşmeyen/eksik zorunlu belgeler.
  static List<ConsentDoc> missingFrom(
    List<ConsentDoc> mandatoryDocs,
    Map<String, String> accepted,
  ) =>
      mandatoryDocs.where((d) => accepted[d.code] != d.version).toList();

  /// Her karar için bir `platform_consents` satırı yazar (web `recordConsents`
  /// ile aynı şekil; `source='mobile'`). tenant_id null olabilir.
  Future<void> recordConsents({
    required String userId,
    String? tenantId,
    required List<ConsentDecision> decisions,
    String? userAgent,
  }) async {
    if (userId.isEmpty || decisions.isEmpty) return;
    await _supabase
        .from('platform_consents')
        .insert(buildConsentRows(
          userId: userId,
          tenantId: tenantId,
          decisions: decisions,
          userAgent: userAgent,
        ));
  }

  /// Insert satırları (saf — test için ayrı).
  static List<Map<String, dynamic>> buildConsentRows({
    required String userId,
    String? tenantId,
    required List<ConsentDecision> decisions,
    String? userAgent,
    DateTime? now,
  }) {
    final ts = (now ?? DateTime.now()).toUtc().toIso8601String();
    return [
      for (final d in decisions)
        {
          'user_id': userId,
          'tenant_id': tenantId,
          'document_code': d.code,
          'version': d.version,
          'accepted': true,
          'accepted_at': ts,
          'revoked_at': null,
          'ip': null,
          'user_agent': userAgent,
          'source': source,
        },
    ];
  }

  /// Aktif platformun web taban adresi (`platforms.app_base_url`) — belge
  /// bağlantıları göreli (`/legal/kvkk`) olduğundan mobilde mutlak yapılır.
  /// Hata/boş → null.
  Future<String?> getAppBaseUrl(String? platformId) async {
    if (platformId == null || platformId.isEmpty) return null;
    try {
      final row = await _supabase
          .from('platforms')
          .select('app_base_url')
          .eq('id', platformId)
          .maybeSingle();
      final v = row?['app_base_url'] as String?;
      return (v == null || v.trim().isEmpty) ? null : v.trim();
    } catch (e) {
      Logger.warning('Consent: app_base_url lookup failed: $e');
      return null;
    }
  }

  /// Belge bağlantısını mutlak yap: mutlak ise aynen; göreli ise [baseUrl]
  /// ile birleştir; taban yoksa null (bağlantı gösterilmez).
  static String? resolveDocumentUrl(String? url, String? baseUrl) {
    if (url == null || url.trim().isEmpty) return null;
    final u = url.trim();
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    if (baseUrl == null || baseUrl.isEmpty) return null;
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return u.startsWith('/') ? '$base$u' : '$base/$u';
  }

  static List<ConsentDoc> _platformDocs(dynamic data) => (data as List)
      .map((e) => ConsentDoc.fromRow(Map<String, dynamic>.from(e as Map)))
      .where((d) => d.scope == ConsentDoc.scopePlatform)
      .toList();
}

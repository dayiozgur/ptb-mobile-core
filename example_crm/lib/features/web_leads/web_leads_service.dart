import 'package:protoolbag_core/protoolbag_core.dart';

import '../shared/crm_backend.dart';

/// Web-form başvurusu (`crm_web_leads`, `fn_crm_web_leads_list` satırı).
class WebLead {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? company;
  final String? message;
  final String? source;

  /// `new` | `converted` | `spam` (crm_web_leads kuyruk durumu; entity
  /// status_definitions DEĞİL — web de sabit üç filtre + anahtar kullanır).
  final String status;
  final DateTime? createdAt;
  final String? convertedLeadId;

  /// `metadata.form_type` — `contact` | `demo` | `meeting` (bilinmeyen →
  /// `contact`, web `parseFormType`).
  final String formType;

  const WebLead({
    required this.id,
    this.name = '',
    this.email,
    this.phone,
    this.company,
    this.message,
    this.source,
    this.status = 'new',
    this.createdAt,
    this.convertedLeadId,
    this.formType = 'contact',
  });

  factory WebLead.fromRow(Map<String, dynamic> r) {
    final meta = r['metadata'];
    final ft = meta is Map ? meta['form_type'] : null;
    return WebLead(
      id: r['id']?.toString() ?? '',
      name: (r['name'] as String?) ?? '',
      email: r['email'] as String?,
      phone: r['phone'] as String?,
      company: r['company'] as String?,
      message: r['message'] as String?,
      source: r['source'] as String?,
      status: (r['status'] as String?) ?? 'new',
      createdAt: r['created_at'] != null
          ? DateTime.tryParse(r['created_at'].toString())
          : null,
      convertedLeadId: r['converted_lead_id'] as String?,
      formType: (ft == 'demo' || ft == 'meeting') ? ft as String : 'contact',
    );
  }

  String get displayName {
    if (name.trim().isNotEmpty) return name.trim();
    if ((email ?? '').trim().isNotEmpty) return email!.trim();
    return '—';
  }
}

/// Web başvuru kuyruğunun filtre değerleri (web `filter` segmenti).
enum WebLeadFilter { newLeads, converted, spam }

extension WebLeadFilterCode on WebLeadFilter {
  String get code => switch (this) {
        WebLeadFilter.newLeads => 'new',
        WebLeadFilter.converted => 'converted',
        WebLeadFilter.spam => 'spam',
      };
}

/// **Web potansiyelleri servisi** — web `WebLeadService` ile aynı RPC'ler:
///   • `fn_crm_web_leads_list(p_status)` — SECDEF, admin-kapılı, tenant-scoped
///   • `fn_crm_convert_web_lead(p_id) → uuid` — yeni `lead` form_submission
///   • `fn_crm_web_lead_set_status(p_id, p_status)` — spam / yeniden aç
class WebLeadsService {
  WebLeadsService({CrmBackend? backend})
      : _backend = backend ?? SupabaseCrmBackend();

  final CrmBackend _backend;

  /// Kuyruğu listele (hata fırlatır → ekran hata durumunu gösterir; yetkisiz
  /// kullanıcıda RPC `not authorized` fırlatır).
  Future<List<WebLead>> list(WebLeadFilter filter) async {
    final rows = await _backend
        .rpcRows('fn_crm_web_leads_list', {'p_status': filter.code});
    return rows.map(WebLead.fromRow).where((w) => w.id.isNotEmpty).toList();
  }

  /// Dönüştür → yeni potansiyelin id'si. **Online-only, bilinçli**: yeni kayıt
  /// üretir (offline replay çift dönüşüm riski). Hata fırlatır.
  Future<String?> convert(String id) async {
    final res = await _backend.rpc('fn_crm_convert_web_lead', {'p_id': id});
    return res?.toString();
  }

  /// Durum ata (`spam` / `new`) — web `setStatus`. Hata fırlatır.
  Future<void> setStatus(String id, String status) async {
    await _backend
        .rpc('fn_crm_web_lead_set_status', {'p_id': id, 'p_status': status});
  }

  /// Yetki hatası mı? (RPC `not authorized` — admin olmayan kullanıcı).
  static bool isNotAuthorized(Object e) =>
      e.toString().toLowerCase().contains('not authorized');

  /// Hata ayrıntısı (log için).
  static void log(String ctx, Object e) => Logger.error('crm web leads $ctx', e);
}

import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bir CRM kişisi (`public.contacts` satırı).
class Contact {
  final String id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? title;
  final String? companyId;
  final String? notes;

  const Contact({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.email,
    this.phone,
    this.title,
    this.companyId,
    this.notes,
  });

  String get displayName {
    final n = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    return n.isNotEmpty ? n : (email ?? '—');
  }

  factory Contact.fromJson(Map<String, dynamic> j) => Contact(
        id: j['id'] as String,
        firstName: j['first_name'] as String? ?? '',
        lastName: j['last_name'] as String? ?? '',
        email: j['email'] as String?,
        phone: j['phone'] as String?,
        title: j['title'] as String?,
        companyId: j['company_id'] as String?,
        notes: j['notes'] as String?,
      );
}

/// Bir aktivite feed satırı (`fn_crm_activity_feed`).
class CrmActivity {
  final String id;
  final String? type;
  final String subject;
  final DateTime? occurredAt;
  final String? outcome;
  final String? notes;

  const CrmActivity({
    required this.id,
    required this.subject,
    this.type,
    this.occurredAt,
    this.outcome,
    this.notes,
  });

  factory CrmActivity.fromJson(Map<String, dynamic> j) => CrmActivity(
        id: j['activity_id']?.toString() ?? '',
        type: j['activity_type'] as String?,
        subject: j['subject'] as String? ?? '—',
        occurredAt: j['occurred_at'] != null
            ? DateTime.tryParse(j['occurred_at'].toString())
            : null,
        outcome: j['outcome'] as String?,
        notes: j['notes'] as String?,
      );
}

/// **CRM Contacts servisi** — `public.contacts` (tenant-scoped, RLS) üzerinde
/// ara/listele/gör/ekle + kişiye bağlı aktivite feed'i (`fn_crm_activity_feed`)
/// ve aktivite loglama (`fn_crm_log_activity`). CRM'e özgü (gerçek FK tablosu,
/// entity-engine dışı).
class ContactsService {
  SupabaseClient get _sb => sl<SupabaseClient>();
  String? get _tenantId => sl<TenantService>().currentTenantId;

  /// Kişileri listele (isteğe bağlı arama: ad/soyad/e-posta/telefon).
  Future<List<Contact>> list({String? query, int limit = 100}) async {
    try {
      var q = _sb
          .from('contacts')
          .select('id, first_name, last_name, email, phone, title, '
              'company_id, notes')
          .eq('active', true);
      final t = _tenantId;
      if (t != null) q = q.eq('tenant_id', t);
      final search = query?.trim();
      if (search != null && search.isNotEmpty) {
        q = q.or('first_name.ilike.%$search%,last_name.ilike.%$search%,'
            'email.ilike.%$search%,phone.ilike.%$search%');
      }
      final res =
          await q.order('first_name', ascending: true).limit(limit);
      return (res as List)
          .map((e) => Contact.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      Logger.error('contacts list hata', e);
      return [];
    }
  }

  Future<Contact?> get(String id) async {
    try {
      final res = await _sb
          .from('contacts')
          .select('id, first_name, last_name, email, phone, title, '
              'company_id, notes')
          .eq('id', id)
          .maybeSingle();
      if (res == null) return null;
      return Contact.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      Logger.error('contact get hata', e);
      return null;
    }
  }

  /// Yeni kişi ekle. Başarılıysa id döner.
  Future<String?> create({
    required String firstName,
    String? lastName,
    String? email,
    String? phone,
    String? title,
  }) async {
    try {
      final uid = _sb.auth.currentUser?.id;
      final res = await _sb
          .from('contacts')
          .insert({
            'tenant_id': _tenantId,
            'organization_id':
                sl<OrganizationService>().currentOrganizationId,
            'first_name': firstName.trim(),
            if (lastName != null && lastName.trim().isNotEmpty)
              'last_name': lastName.trim(),
            if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
            if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
            if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
            // Tenant-geneli görünür: aksi halde DB default 'organization' +
            // select-RLS ('tenant' şubesi) yüzünden manager-altı roller / null
            // org'da oluşturulan kişi GÖRÜNMÜYORDU.
            'visibility': 'tenant',
            'active': true,
            'created_by': uid,
          })
          .select('id')
          .single();
      return (res as Map)['id'] as String?;
    } catch (e) {
      Logger.error('contact create hata', e);
      return null;
    }
  }

  /// Kişiye bağlı aktivite feed'i (`fn_crm_activity_feed(p_entity_id)`).
  Future<List<CrmActivity>> activityFeed(String contactId) async {
    try {
      final res =
          await _sb.rpc('fn_crm_activity_feed', params: {'p_entity_id': contactId});
      return ((res as List?) ?? const [])
          .map((e) => CrmActivity.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      Logger.error('activity feed hata', e);
      return [];
    }
  }

  /// Kişiye aktivite logla (`fn_crm_log_activity`).
  Future<bool> logActivity({
    required String subject,
    String activityType = 'call',
    String? notes,
    String? contactId,
    String? contactName,
  }) async {
    try {
      await _sb.rpc('fn_crm_log_activity', params: {
        'p_subject': subject.trim(),
        'p_activity_type': activityType,
        if (notes != null && notes.trim().isNotEmpty) 'p_notes': notes.trim(),
        if (contactId != null) 'p_related_contact_id': contactId,
        if (contactName != null) 'p_related_contact_name': contactName,
      });
      return true;
    } catch (e) {
      Logger.error('log activity hata', e);
      return false;
    }
  }
}

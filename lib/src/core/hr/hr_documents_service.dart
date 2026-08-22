import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../storage/file_storage_service.dart';
import '../tenant/tenant_service.dart';
import '../utils/logger.dart';
import 'models/kvkk_models.dart';
import 'models/my_hr_document.dart';

// Modelleri barrel'a (protoolbag_core) taşı — bu dosya export edildiğinden
// re-export transitif olarak aktarılır.
export 'models/kvkk_models.dart';
export 'models/my_hr_document.dart';

/// HR "Belgelerim / Verilerim / KVKK" self-servis veri katmanı.
///
/// PHR mobil ESS'in üç salt-okuma ekranını besler:
///  - `myDocuments()`     → RPC `fn_hr_my_documents` (zimmet/sözleşme/eğitim).
///  - `myConsents()`      → `kvkk_consent_types` + `kvkk_consents` birleşimi.
///  - `myDataOverview()`  → rıza satırlarından KVKK kişisel-veri özeti.
///
/// Web `EssService.getMyDocuments` + `KvkkService` ile birebir DB/RPC sözleşmesi.
/// Tüm metodlar hata durumunda **rethrow** eder (ekran gerçek hatayı gösterir);
/// staff `hrEssService.currentStaffId()` ile çözülür.
class HrDocumentsService {
  final SupabaseClient _supabase;

  HrDocumentsService({required SupabaseClient supabase}) : _supabase = supabase;

  TenantService get _tenant => sl<TenantService>();

  FileStorageService? get _storageOrNull =>
      sl.isRegistered<FileStorageService>() ? sl<FileStorageService>() : null;

  // ============================================
  // BELGELERİM (Documents)
  // ============================================

  /// Çalışanın kendi atanmış İK belgeleri — RPC `fn_hr_my_documents`.
  ///
  /// SECDEF + `auth.uid()`-kapsamlı olduğundan (generic entity listeleri
  /// org-kapsamlıdır ve gizleyebilir) doğrudan RPC çağrılır. Satırlar entity
  /// kayıtlarıdır; storage-path taşımaz → indirme değil, salt-görüntüleme.
  Future<List<MyHrDocument>> myDocuments() async {
    try {
      final response = await _supabase.rpc('fn_hr_my_documents');
      final list = (response as List?) ?? const [];
      return list
          .map((e) => MyHrDocument.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('Error fetching my documents: $e');
      rethrow;
    }
  }

  // ============================================
  // KVKK RIZALARI (Consents)
  // ============================================

  /// Rıza kataloğu + kullanıcının kendi kararlarını birleştirir (salt-okuma).
  /// Web `KvkkConsentComponent.merge` ile aynı: her kategori için `state`
  /// (`granted` / `revoked` / `none`).
  Future<List<KvkkConsentRow>> myConsents() async {
    try {
      final types = await _fetchConsentTypes();
      final consents = await _fetchMyConsents();

      final byType = <String, KvkkConsent>{};
      for (final c in consents) {
        byType[c.consentTypeId] = c;
      }

      return types.map((type) {
        final consent = byType[type.id];
        final state = consent == null
            ? ConsentState.none
            : (consent.granted ? ConsentState.granted : ConsentState.revoked);
        return KvkkConsentRow(type: type, consent: consent, state: state);
      }).toList();
    } catch (e) {
      Logger.error('Error fetching my consents: $e');
      rethrow;
    }
  }

  /// "Verilerim" (KVKK kişisel-veri) genel bakışı — rıza satırlarından türetilen
  /// salt-okuma özet + kategori listesi.
  Future<MyDataOverview> myDataOverview() async {
    try {
      final rows = await myConsents();
      return MyDataOverview.fromRows(rows);
    } catch (e) {
      Logger.error('Error building my-data overview: $e');
      rethrow;
    }
  }

  /// Aktif rıza tipleri (global `tenant_id=null` VEYA bu tenant'ın satırları).
  Future<List<KvkkConsentType>> _fetchConsentTypes() async {
    var query = _supabase
        .from('kvkk_consent_types')
        .select('id,tenant_id,code,name,description,required,version,active')
        .eq('active', true);

    final tenantId = _tenant.currentTenantId;
    if (tenantId != null) {
      query = query.or('tenant_id.is.null,tenant_id.eq.$tenantId');
    }

    final response =
        await query.order('required', ascending: false).order('name');
    return (response as List)
        .map((e) => KvkkConsentType.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Kullanıcının kendi rıza kayıtları (`staff_id` = benim staff'ım).
  Future<List<KvkkConsent>> _fetchMyConsents() async {
    final staffId = await hrEssService.currentStaffId();
    if (staffId == null) return const [];

    var query = _supabase
        .from('kvkk_consents')
        .select('id,consent_type_id,granted,granted_at,revoked_at,version')
        .eq('staff_id', staffId);

    final tenantId = _tenant.currentTenantId;
    if (tenantId != null) {
      query = query.eq('tenant_id', tenantId);
    }

    // created_at ASC — myConsents byType[]=c overwrite'ında EN YENİ satır kalsın
    // (kvkk_consents append-audit; tip başına birden fazla satır olabilir).
    final response = await query.order('created_at', ascending: true);
    return (response as List)
        .map((e) => KvkkConsent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// **KVKK rıza ver / geri al** — yeni bir `kvkk_consents` satırı ekler
  /// (audit-append; read en-yeni satırı gösterir). `source='mobile'`.
  /// RLS own-staff'a izin verir. Başarıda `true`.
  Future<bool> setConsent({
    required String consentTypeId,
    required bool granted,
  }) async {
    final staffId = await hrEssService.currentStaffId();
    if (staffId == null) return false;
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    try {
      await _supabase.from('kvkk_consents').insert({
        'tenant_id': _tenant.currentTenantId,
        'staff_id': staffId,
        'consent_type_id': consentTypeId,
        'granted': granted,
        if (granted) 'granted_at': nowUtc else 'revoked_at': nowUtc,
        'source': 'mobile',
      });
      return true;
    } catch (e) {
      Logger.error('setConsent hata', e);
      return false;
    }
  }

  // ============================================
  // STORAGE (opsiyonel — imzalı URL)
  // ============================================

  /// Bir storage-path için imzalı URL üret (çekirdek [FileStorageService]).
  ///
  /// `fn_hr_my_documents` şu an dosya-path taşımaz; ileride belge dosyaları
  /// bağlanırsa hazır dursun diye çekirdek servis yeniden kullanılır. Servis
  /// kayıtlı değilse (ya da hata) `null` döner.
  Future<String?> signedUrl(
    String path, {
    String bucket = StorageBuckets.platformPrivate,
  }) async {
    final storage = _storageOrNull;
    if (storage == null) {
      Logger.warning('signedUrl: FileStorageService not registered');
      return null;
    }
    return storage.getSignedUrl(bucket: bucket, path: path);
  }
}

/// Convenience getter — çekirdek servis-locator'dan çözer.
HrDocumentsService get hrDocumentsService => sl<HrDocumentsService>();

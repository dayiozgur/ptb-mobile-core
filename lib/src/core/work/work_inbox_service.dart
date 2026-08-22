import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';

/// "Bana atanan iş" listesindeki tek öğe — platform-nötr, generic.
class WorkInboxItem {
  final String id;
  final String title;
  final String? subtitle;
  final String? group; // gruplama başlığı (ör. bucket: overdue/today/stale)
  final String? status;
  final String? entityType; // /entities/<entityType>/<id> navigasyonu için
  final DateTime? dueDate;
  final String? trailing; // sağ-üst rozet (ör. tutar / story points)

  const WorkInboxItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.group,
    this.status,
    this.entityType,
    this.dueDate,
    this.trailing,
  });
}

/// Bir satırı [WorkInboxItem]'a çeviren platform-özel eşleyici.
typedef WorkInboxMapper = WorkInboxItem Function(Map<String, dynamic> row);

/// Bir "My Work" kaynağı: hangi RPC, hangi parametre, satırlar nasıl eşlenir.
/// Platform ince-app'i tanımlar (ör. CRM `fn_crm_my_work`, PPM `fn_ppm_my_work`).
class WorkInboxSource {
  final String title;
  final String rpcName;
  final Map<String, dynamic>? params;
  final WorkInboxMapper mapper;

  const WorkInboxSource({
    required this.title,
    required this.rpcName,
    required this.mapper,
    this.params,
  });
}

/// **Generic "Bana atanan iş" servisi** — bir RPC'yi çağırıp satırları
/// [WorkInboxItem]'a eşler. CRM/PPM (ve gelecekteki platformlar) aynı ekranı
/// farklı [WorkInboxSource] ile kullanır → çekirdek yeniden-kullanım.
class WorkInboxService {
  final SupabaseClient _supabase;

  WorkInboxService({required SupabaseClient supabase}) : _supabase = supabase;

  /// Kaynağın RPC'sini çağır + eşle. Hata → boş liste (UI'a fırlatmaz).
  Future<List<WorkInboxItem>> load(WorkInboxSource source) async {
    try {
      final res = source.params != null
          ? await _supabase.rpc(source.rpcName, params: source.params)
          : await _supabase.rpc(source.rpcName);
      final rows = (res as List?)?.cast<Map<String, dynamic>>() ?? const [];
      return rows.map(source.mapper).toList();
    } catch (e) {
      Logger.error('WorkInbox load (${source.rpcName}) hata', e);
      return [];
    }
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../entity/entity_data_service.dart';
import '../entity/entity_status_labels.dart';
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
      return await _withStatusNames(rows.map(source.mapper).toList());
    } catch (e) {
      Logger.error('WorkInbox load (${source.rpcName}) hata', e);
      return [];
    }
  }

  /// Ham durum KODU yerine görünen ad (status_definitions; sistem durumları
  /// `status.<code>` ile çevrili). Tanım yoksa humanize — ham kod gösterilmez.
  Future<List<WorkInboxItem>> _withStatusNames(List<WorkInboxItem> items) async {
    final types = {
      for (final it in items)
        if (it.entityType != null && (it.status ?? '').isNotEmpty) it.entityType!
    };
    final labels = <String, Map<String, EntityStatusLabel>>{};
    if (types.isNotEmpty && sl.isRegistered<EntityDataService>()) {
      final svc = sl<EntityDataService>();
      for (final t in types) {
        try {
          labels[t] = await svc.statusLabels(t);
        } catch (_) {
          labels[t] = const {};
        }
      }
    }
    return items.map((it) {
      final s = it.status;
      if (s == null || s.isEmpty) return it;
      final name = EntityStatusLabels.nameOf(s, labels[it.entityType] ?? const {});
      if (name == s) return it;
      return WorkInboxItem(
        id: it.id,
        title: it.title,
        subtitle: it.subtitle,
        group: it.group,
        status: name,
        entityType: it.entityType,
        dueDate: it.dueDate,
        trailing: it.trailing,
      );
    }).toList();
  }
}

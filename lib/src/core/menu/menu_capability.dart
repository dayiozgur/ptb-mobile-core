import 'menu_item.dart';

/// Menü yetenek (capability) filtresi — web eşleniği:
/// `libs/core/services/src/integration-capability.service.ts`
/// (`INTEGRATION_CAPABILITY_SCOPES`, `connectionHasCapability`, `state()`) +
/// `libs/core/services/src/menu/ptb-menu.service.ts`
/// (`collectCapabilities`, `filterByCapabilitiesRecursive`).
///
/// `platform_menu_items.requires_capability` (örn. `files`, `mail.read`,
/// `calendar`) bir bağlı-uygulama (M365) özelliğidir. Web varsayılan resolver'ı
/// yeteneği kullanıcının KENDİ `integration_connections` satırlarına (RLS:
/// tenant_id = get_my_tenant_id() AND user_id = auth.uid()) karşı çözer:
/// desteklenen sağlayıcının `status='connected'` bir bağlantısı, yetenek için
/// listelenen kapsamlardan (scope) BİRİNİ taşıyorsa yetenek verilir. Boş/null
/// scopes = eski satır → izinli. Durum bilinmiyorsa (yükleme hatası) yetenek
/// VERİLMEZ — öğe gizli kalır (web ile aynı).
class MenuCapabilities {
  MenuCapabilities._();

  /// Sağlayıcı başına yetenek → kabul edilen kapsamlar (web ile birebir).
  static const Map<String, Map<String, List<String>>> scopesByProvider = {
    'microsoft': {
      'mail.read': ['Mail.Read', 'Mail.ReadWrite'],
      'mail.send': ['Mail.Send'],
      'mail.write': ['Mail.ReadWrite', 'Mail.ReadWrite.Shared'],
      'calendar': ['Calendars.ReadWrite'],
      'contacts': [
        'Contacts.Read',
        'Contacts.ReadWrite',
        'People.Read',
        'People.Read.All',
      ],
      'files': [
        'Files.Read',
        'Files.ReadWrite',
        'Files.Read.All',
        'Files.ReadWrite.All',
        'Sites.Read.All',
        'Sites.ReadWrite.All',
      ],
      'teams.post': ['ChannelMessage.Send'],
      'teams.chat': ['Chat.ReadWrite'],
      'meetings': ['OnlineMeetings.ReadWrite'],
      'tasks': ['Tasks.ReadWrite', 'Tasks.ReadWrite.All'],
    },
  };

  /// Web `getConnections()` ile aynı kolonlar (token YOK).
  static const String connectionColumns =
      'id, provider, account_email, scopes, status, expires_at, updated_at, sync_enabled';

  /// `https://graph.microsoft.com/Files.Read` → `files.read` (web `normalizeScope`).
  static String normalizeScope(String scope) {
    final s = scope.trim().toLowerCase();
    final slash = s.lastIndexOf('/');
    return slash >= 0 ? s.substring(slash + 1) : s;
  }

  /// Bağlantı yeteneği veriyor mu? (web `connectionHasCapability`).
  static bool connectionHasCapability(
    Map<String, dynamic> conn,
    String capability,
  ) {
    final provider = conn['provider']?.toString();
    final required = scopesByProvider[provider]?[capability];
    if (required == null) return false;
    final raw = conn['scopes'];
    final granted = <String>[
      if (raw is List)
        for (final s in raw)
          if (s is String && s.trim().isNotEmpty) s,
    ];
    if (granted.isEmpty) return true;
    final set = granted.map(normalizeScope).toSet();
    return required.any((r) => set.contains(r.toLowerCase()));
  }

  /// [capabilities] içinden [connections] ile verilenler (web `state().available`).
  static Set<String> granted(
    Iterable<String> capabilities,
    List<Map<String, dynamic>> connections,
  ) {
    final out = <String>{};
    for (final cap in capabilities) {
      for (final provider in scopesByProvider.keys) {
        final ok = connections.any((c) =>
            c['provider']?.toString() == provider &&
            c['status']?.toString() == 'connected' &&
            connectionHasCapability(c, cap));
        if (ok) {
          out.add(cap);
          break;
        }
      }
    }
    return out;
  }

  /// Ağaçta geçen yetenek kodları (web `collectCapabilities`).
  static Set<String> collect(List<MenuItem> items, [Set<String>? out]) {
    final acc = out ?? <String>{};
    for (final item in items) {
      final cap = item.requiresCapability;
      if (cap != null && cap.isNotEmpty) acc.add(cap);
      if (item.children.isNotEmpty) collect(item.children, acc);
    }
    return acc;
  }

  /// Verilmeyen yetenekli öğeleri düşür; tüm çocukları düşen yolsuz grup da
  /// düşer (web `filterByCapabilitiesRecursive`).
  static List<MenuItem> filter(List<MenuItem> items, Set<String> granted) {
    final out = <MenuItem>[];
    for (final item in items) {
      final cap = item.requiresCapability;
      if (cap != null && cap.isNotEmpty && !granted.contains(cap)) continue;
      if (item.children.isNotEmpty) {
        final kids = filter(item.children, granted);
        if (kids.isEmpty && !item.hasPath) continue;
        out.add(item.copyWith(children: kids));
      } else {
        out.add(item);
      }
    }
    return out;
  }
}

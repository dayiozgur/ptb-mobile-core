/// Menü öğesi modeli — `platform_menu_items` satırının mobil karşılığı.
///
/// Web `platform_menu_items` şeması ile birebir hizalıdır (2026-08). Menü
/// tamamen DB-tabanlıdır: `.menu.ts` dosyaları ETKİSİZDİR — menü kaynağı
/// yalnızca `platform_menu_items` (menu_source='db').
///
/// Nesting: `itemKey` ↔ `parentItemKey`. Ağaç, child.parentItemKey ==
/// parent.itemKey eşleşmesiyle kurulur (null parentItemKey = üst seviye).
class MenuItem {
  /// Benzersiz anahtar (platform içinde UNIQUE) — `item_key`.
  final String itemKey;

  /// Üst öğe anahtarı — `parent_item_key` (null = üst seviye).
  final String? parentItemKey;

  /// Başlık — i18n ANAHTARI (`title`), örn. `nav.dashboard` / `header.my_space`.
  /// LocalizationService.translate() ile çözülür; eşleşme yoksa anahtar gösterilir.
  final String title;

  /// İkon — bootstrap-icons sınıfı (`icon`), örn. `bi-speedometer`.
  /// BootstrapIconMap ile Flutter IconData'ya çevrilir.
  final String? icon;

  /// Web rotası (`path`), örn. `/dashboard`, `/alarm`. Mobil ekrana
  /// route eşlemesi için kullanılır (bkz. example_pms router).
  final String? path;

  /// Görünürlük rolleri (`roles` text[]). null/boş = herkese açık;
  /// aksi halde kullanıcının coarse rolü bu listede olmalı.
  final List<String> roles;

  /// Fine-grained izinler (`permission` text[]). Çoğunlukla null.
  /// TODO(perm): permission[] tabanlı gating — şimdilik yalnız roles gate'lenir.
  final List<String> permission;

  /// Modül grubu (`module`).
  final String? module;

  /// Devre dışı mı? (`disabled`) — görünür ama tıklanamaz.
  final bool disabled;

  /// Sıralama (`sort_order`).
  final int sortOrder;

  /// Alt öğeler (ağaç kurulumundan sonra doldurulur).
  final List<MenuItem> children;

  const MenuItem({
    required this.itemKey,
    this.parentItemKey,
    required this.title,
    this.icon,
    this.path,
    this.roles = const [],
    this.permission = const [],
    this.module,
    this.disabled = false,
    this.sortOrder = 0,
    this.children = const [],
  });

  /// Üst seviye mi? (parentItemKey null/boş)
  bool get isTopLevel => parentItemKey == null || parentItemKey!.isEmpty;

  /// Alt öğesi var mı?
  bool get hasChildren => children.isNotEmpty;

  /// Bir hedef (route) var mı?
  bool get hasPath => path != null && path!.isNotEmpty;

  /// Bu öğe verilen coarse rol için görünür mü?
  ///
  /// Web filtre semantiği: roles null/boş ise herkese açık; aksi halde
  /// kullanıcının coarse rolü listede olmalı.
  bool isVisibleForRole(String? coarseRole) {
    if (roles.isEmpty) return true;
    if (coarseRole == null) return false;
    return roles.contains(coarseRole);
    // TODO(perm): permission[] varsa ek gate uygula.
  }

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    List<String> asStringList(dynamic v) {
      if (v == null) return const [];
      if (v is List) {
        return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      }
      return const [];
    }

    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return MenuItem(
      itemKey: json['item_key'] as String,
      parentItemKey: json['parent_item_key'] as String?,
      title: (json['title'] as String?) ?? (json['item_key'] as String),
      icon: json['icon'] as String?,
      path: json['path'] as String?,
      roles: asStringList(json['roles']),
      permission: asStringList(json['permission']),
      module: json['module'] as String?,
      disabled: json['disabled'] as bool? ?? false,
      sortOrder: asInt(json['sort_order']),
      children: const [],
    );
  }

  MenuItem copyWith({List<MenuItem>? children}) {
    return MenuItem(
      itemKey: itemKey,
      parentItemKey: parentItemKey,
      title: title,
      icon: icon,
      path: path,
      roles: roles,
      permission: permission,
      module: module,
      disabled: disabled,
      sortOrder: sortOrder,
      children: children ?? this.children,
    );
  }

  @override
  String toString() =>
      'MenuItem($itemKey, title=$title, path=$path, children=${children.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MenuItem && itemKey == other.itemKey;

  @override
  int get hashCode => itemKey.hashCode;
}

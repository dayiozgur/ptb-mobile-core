import 'package:flutter/material.dart';

/// bootstrap-icons (`bi-*`) → Flutter [IconData] eşlemesi.
///
/// `platform_menu_items.icon` bootstrap-icons sınıfı taşır (örn. `bi-speedometer`).
/// Mobil tarafta karşılık gelen Material ikonuna (yaklaşık) çeviririz.
/// Eşleşme yoksa [fallback] döner.
class BootstrapIconMap {
  BootstrapIconMap._();

  /// Bilinmeyen `bi-*` sınıfları için varsayılan.
  static const IconData fallback = Icons.circle_outlined;

  static const Map<String, IconData> _map = {
    // Dashboard / genel bakış
    'bi-speedometer': Icons.speed,
    'bi-speedometer2': Icons.speed,
    'bi-grid': Icons.grid_view,
    'bi-grid-fill': Icons.grid_view,
    'bi-grid-1x2': Icons.dashboard_outlined,
    'bi-grid-1x2-fill': Icons.dashboard,
    'bi-grid-3x3': Icons.grid_on,
    'bi-columns-gap': Icons.dashboard_customize,
    'bi-house': Icons.home_outlined,
    'bi-house-fill': Icons.home,
    'bi-house-door': Icons.home_outlined,

    // Alarmlar / bildirimler
    'bi-bell': Icons.notifications_none,
    'bi-bell-fill': Icons.notifications,
    'bi-exclamation-triangle': Icons.warning_amber,
    'bi-exclamation-triangle-fill': Icons.warning,
    'bi-exclamation-circle': Icons.error_outline,
    'bi-exclamation-octagon': Icons.report_problem_outlined,
    'bi-shield-exclamation': Icons.gpp_maybe,

    // Konum / harita / site
    'bi-geo-alt': Icons.place,
    'bi-geo-alt-fill': Icons.place,
    'bi-geo': Icons.my_location,
    'bi-map': Icons.map_outlined,
    'bi-map-fill': Icons.map,
    'bi-pin-map': Icons.pin_drop_outlined,
    'bi-globe': Icons.public,
    'bi-globe2': Icons.public,

    // Bina / organizasyon
    'bi-building': Icons.apartment,
    'bi-buildings': Icons.location_city,
    'bi-bank': Icons.account_balance,
    'bi-diagram-3': Icons.account_tree_outlined,
    'bi-diagram-2': Icons.account_tree_outlined,
    'bi-people': Icons.people_outline,
    'bi-people-fill': Icons.people,
    'bi-person': Icons.person_outline,
    'bi-person-fill': Icons.person,
    'bi-person-badge': Icons.badge_outlined,
    'bi-person-circle': Icons.account_circle,

    // Cihaz / IoT / controller
    'bi-display': Icons.desktop_windows,
    'bi-display-fill': Icons.desktop_windows,
    'bi-cpu': Icons.memory,
    'bi-cpu-fill': Icons.memory,
    'bi-motherboard': Icons.developer_board,
    'bi-hdd': Icons.storage,
    'bi-hdd-stack': Icons.dns_outlined,
    'bi-router': Icons.router,
    'bi-device-hdd': Icons.storage,
    'bi-thermometer': Icons.thermostat,
    'bi-thermometer-half': Icons.thermostat,
    'bi-usb-drive': Icons.usb,
    'bi-plug': Icons.power,
    'bi-lightning': Icons.bolt,
    'bi-lightning-charge': Icons.bolt,

    // Değişkenler / veri / raporlar
    'bi-braces': Icons.data_object,
    'bi-code-square': Icons.code,
    'bi-database': Icons.dataset_outlined,
    'bi-database-fill': Icons.dataset,
    'bi-table': Icons.table_chart_outlined,
    'bi-list': Icons.list,
    'bi-list-ul': Icons.format_list_bulleted,
    'bi-list-check': Icons.checklist,
    'bi-card-list': Icons.view_list_outlined,
    'bi-clipboard': Icons.assignment_outlined,
    'bi-clipboard-data': Icons.assignment_outlined,
    'bi-clipboard-check': Icons.assignment_turned_in_outlined,
    'bi-journal-text': Icons.article_outlined,
    'bi-file-earmark-text': Icons.description_outlined,
    'bi-file-text': Icons.description_outlined,
    'bi-files': Icons.folder_copy_outlined,
    'bi-folder': Icons.folder_outlined,
    'bi-folder2-open': Icons.folder_open,

    // Grafikler / analitik
    'bi-graph-up': Icons.trending_up,
    'bi-graph-up-arrow': Icons.show_chart,
    'bi-graph-down': Icons.trending_down,
    'bi-bar-chart': Icons.bar_chart,
    'bi-bar-chart-line': Icons.stacked_line_chart,
    'bi-pie-chart': Icons.pie_chart_outline,
    'bi-pie-chart-fill': Icons.pie_chart,
    'bi-activity': Icons.monitor_heart_outlined,

    // Ayarlar / araçlar
    'bi-gear': Icons.settings,
    'bi-gear-fill': Icons.settings,
    'bi-gear-wide': Icons.settings_suggest_outlined,
    'bi-sliders': Icons.tune,
    'bi-tools': Icons.build_outlined,
    'bi-wrench': Icons.build_outlined,
    'bi-wrench-adjustable': Icons.handyman_outlined,
    'bi-toggles': Icons.toggle_on_outlined,

    // Kullanıcı / hesap / güvenlik
    'bi-shield': Icons.shield_outlined,
    'bi-shield-check': Icons.verified_user_outlined,
    'bi-shield-lock': Icons.security,
    'bi-key': Icons.vpn_key_outlined,
    'bi-lock': Icons.lock_outline,
    'bi-unlock': Icons.lock_open,
    'bi-box-arrow-right': Icons.logout,
    'bi-box-arrow-in-right': Icons.login,

    // İletişim / mesaj
    'bi-envelope': Icons.mail_outline,
    'bi-envelope-fill': Icons.mail,
    'bi-chat': Icons.chat_bubble_outline,
    'bi-chat-dots': Icons.forum_outlined,
    'bi-telephone': Icons.phone_outlined,

    // Takvim / zaman
    'bi-calendar': Icons.calendar_today_outlined,
    'bi-calendar-event': Icons.event_outlined,
    'bi-calendar-check': Icons.event_available_outlined,
    'bi-clock': Icons.access_time,
    'bi-clock-history': Icons.history,
    'bi-hourglass': Icons.hourglass_empty,

    // İş / görev
    'bi-briefcase': Icons.work_outline,
    'bi-briefcase-fill': Icons.work,
    'bi-kanban': Icons.view_kanban_outlined,
    'bi-check2-square': Icons.check_box_outlined,
    'bi-check-circle': Icons.check_circle_outline,
    'bi-flag': Icons.flag_outlined,
    'bi-bookmark': Icons.bookmark_border,
    'bi-tag': Icons.label_outline,
    'bi-tags': Icons.label_outline,

    // Ticaret / finans
    'bi-cart': Icons.shopping_cart_outlined,
    'bi-bag': Icons.shopping_bag_outlined,
    'bi-credit-card': Icons.credit_card,
    'bi-cash': Icons.payments_outlined,
    'bi-cash-stack': Icons.account_balance_wallet_outlined,
    'bi-receipt': Icons.receipt_long_outlined,
    'bi-wallet': Icons.account_balance_wallet_outlined,
    'bi-currency-dollar': Icons.attach_money,
    'bi-percent': Icons.percent,

    // Çeşitli
    'bi-search': Icons.search,
    'bi-funnel': Icons.filter_alt_outlined,
    'bi-filter': Icons.filter_list,
    'bi-star': Icons.star_border,
    'bi-star-fill': Icons.star,
    'bi-heart': Icons.favorite_border,
    'bi-info-circle': Icons.info_outline,
    'bi-question-circle': Icons.help_outline,
    'bi-eye': Icons.visibility_outlined,
    'bi-camera': Icons.camera_alt_outlined,
    'bi-camera-video': Icons.videocam_outlined,
    'bi-image': Icons.image_outlined,
    'bi-printer': Icons.print_outlined,
    'bi-download': Icons.download,
    'bi-upload': Icons.upload,
    'bi-cloud': Icons.cloud_outlined,
    'bi-cloud-arrow-up': Icons.cloud_upload_outlined,
    'bi-arrow-repeat': Icons.sync,
    'bi-lightbulb': Icons.lightbulb_outline,
    'bi-boxes': Icons.inventory_2_outlined,
    'bi-box': Icons.inventory_2_outlined,
    'bi-box-seam': Icons.inventory_2_outlined,
    'bi-truck': Icons.local_shipping_outlined,
    'bi-basket': Icons.shopping_basket_outlined,
    'bi-headset': Icons.headset_mic_outlined,
    'bi-life-preserver': Icons.support_outlined,
    'bi-app-indicator': Icons.apps,
    'bi-app': Icons.apps,
    'bi-window': Icons.web_asset,
    'bi-layers': Icons.layers_outlined,
    'bi-collection': Icons.collections_bookmark_outlined,
  };

  /// [resolve] için okunur takma ad (auth-branding feature ikonları için).
  static IconData iconFor(String? biClass) => resolve(biClass);

  /// `bi-*` sınıfını [IconData]'ya çevir. Eşleşme yoksa [fallback].
  static IconData resolve(String? biClass) {
    if (biClass == null || biClass.isEmpty) return fallback;
    // Normalize: bazı kayıtlar birden fazla sınıf ("bi bi-bell") taşıyabilir.
    final tokens =
        biClass.split(' ').map((t) => t.trim()).where((t) => t.isNotEmpty);
    for (final t in tokens) {
      final key = t.startsWith('bi-') ? t : (t == 'bi' ? null : 'bi-$t');
      if (key != null && _map.containsKey(key)) return _map[key]!;
    }
    return fallback;
  }
}

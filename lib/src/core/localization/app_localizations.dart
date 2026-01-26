import 'localization_service.dart';

/// Uygulama çevirileri
///
/// Tüm desteklenen diller için çeviri stringlerini içerir.
class AppLocalizations {
  AppLocalizations._();

  /// Belirli bir dil için çevirileri döndür
  static Map<String, String> getTranslations(AppLocale locale) {
    switch (locale) {
      case AppLocale.turkish:
        return _turkishTranslations;
      case AppLocale.english:
        return _englishTranslations;
      case AppLocale.german:
        return _germanTranslations;
    }
  }

  // ============================================
  // TURKISH TRANSLATIONS
  // ============================================

  static const Map<String, String> _turkishTranslations = {
    // Common
    'common.ok': 'Tamam',
    'common.cancel': 'İptal',
    'common.save': 'Kaydet',
    'common.delete': 'Sil',
    'common.edit': 'Düzenle',
    'common.add': 'Ekle',
    'common.search': 'Ara',
    'common.filter': 'Filtrele',
    'common.sort': 'Sırala',
    'common.refresh': 'Yenile',
    'common.loading': 'Yükleniyor...',
    'common.error': 'Hata',
    'common.success': 'Başarılı',
    'common.warning': 'Uyarı',
    'common.info': 'Bilgi',
    'common.yes': 'Evet',
    'common.no': 'Hayır',
    'common.close': 'Kapat',
    'common.back': 'Geri',
    'common.next': 'İleri',
    'common.previous': 'Önceki',
    'common.done': 'Tamamlandı',
    'common.retry': 'Tekrar Dene',
    'common.select': 'Seç',
    'common.all': 'Tümü',
    'common.none': 'Hiçbiri',
    'common.more': 'Daha Fazla',
    'common.less': 'Daha Az',
    'common.show': 'Göster',
    'common.hide': 'Gizle',
    'common.required': 'Zorunlu',
    'common.optional': 'İsteğe Bağlı',
    'common.name': 'Ad',
    'common.description': 'Açıklama',
    'common.code': 'Kod',
    'common.status': 'Durum',
    'common.type': 'Tür',
    'common.date': 'Tarih',
    'common.time': 'Saat',
    'common.active': 'Aktif',
    'common.inactive': 'Pasif',
    'common.enabled': 'Etkin',
    'common.disabled': 'Devre Dışı',

    // Auth
    'auth.login': 'Giriş Yap',
    'auth.logout': 'Çıkış Yap',
    'auth.register': 'Kayıt Ol',
    'auth.email': 'E-posta',
    'auth.password': 'Şifre',
    'auth.confirm_password': 'Şifre Tekrar',
    'auth.forgot_password': 'Şifremi Unuttum',
    'auth.reset_password': 'Şifre Sıfırla',
    'auth.change_password': 'Şifre Değiştir',
    'auth.login_success': 'Giriş başarılı',
    'auth.login_failed': 'Giriş başarısız',
    'auth.logout_success': 'Çıkış yapıldı',
    'auth.invalid_email': 'Geçersiz e-posta adresi',
    'auth.invalid_password': 'Şifre en az 6 karakter olmalıdır',
    'auth.passwords_not_match': 'Şifreler eşleşmiyor',
    'auth.biometric_login': 'Biyometrik ile giriş',
    'auth.use_biometrics': 'Biyometrik kullan',

    // Navigation
    'nav.home': 'Ana Sayfa',
    'nav.dashboard': 'Panel',
    'nav.organizations': 'Organizasyonlar',
    'nav.sites': 'Tesisler',
    'nav.units': 'Üniteler',
    'nav.activities': 'Aktiviteler',
    'nav.notifications': 'Bildirimler',
    'nav.settings': 'Ayarlar',
    'nav.profile': 'Profil',
    'nav.help': 'Yardım',
    'nav.about': 'Hakkında',

    // Organizations
    'org.title': 'Organizasyonlar',
    'org.add': 'Organizasyon Ekle',
    'org.edit': 'Organizasyon Düzenle',
    'org.delete': 'Organizasyon Sil',
    'org.detail': 'Organizasyon Detayı',
    'org.name': 'Organizasyon Adı',
    'org.code': 'Organizasyon Kodu',
    'org.no_organizations': 'Henüz organizasyon yok',
    'org.delete_confirm': 'Bu organizasyonu silmek istediğinize emin misiniz?',

    // Sites
    'site.title': 'Tesisler',
    'site.add': 'Tesis Ekle',
    'site.edit': 'Tesis Düzenle',
    'site.delete': 'Tesis Sil',
    'site.detail': 'Tesis Detayı',
    'site.name': 'Tesis Adı',
    'site.code': 'Tesis Kodu',
    'site.address': 'Adres',
    'site.city': 'Şehir',
    'site.country': 'Ülke',
    'site.no_sites': 'Henüz tesis yok',
    'site.delete_confirm': 'Bu tesisi silmek istediğinize emin misiniz?',

    // Units
    'unit.title': 'Üniteler',
    'unit.add': 'Ünite Ekle',
    'unit.edit': 'Ünite Düzenle',
    'unit.delete': 'Ünite Sil',
    'unit.detail': 'Ünite Detayı',
    'unit.name': 'Ünite Adı',
    'unit.code': 'Ünite Kodu',
    'unit.no_units': 'Henüz ünite yok',
    'unit.delete_confirm': 'Bu üniteyi silmek istediğinize emin misiniz?',

    // Activities
    'activity.title': 'Aktiviteler',
    'activity.recent': 'Son Aktiviteler',
    'activity.all': 'Tüm Aktiviteler',
    'activity.no_activities': 'Henüz aktivite yok',
    'activity.created': '{user} tarafından oluşturuldu',
    'activity.updated': '{user} tarafından güncellendi',
    'activity.deleted': '{user} tarafından silindi',

    // Notifications
    'notification.title': 'Bildirimler',
    'notification.mark_read': 'Okundu İşaretle',
    'notification.mark_all_read': 'Tümünü Okundu İşaretle',
    'notification.delete_all': 'Tümünü Sil',
    'notification.no_notifications': 'Bildirim yok',
    'notification.new_notification': 'Yeni bildirim',

    // Settings
    'settings.title': 'Ayarlar',
    'settings.general': 'Genel',
    'settings.appearance': 'Görünüm',
    'settings.theme': 'Tema',
    'settings.theme_light': 'Açık',
    'settings.theme_dark': 'Koyu',
    'settings.theme_system': 'Sistem',
    'settings.language': 'Dil',
    'settings.notifications': 'Bildirimler',
    'settings.privacy': 'Gizlilik',
    'settings.security': 'Güvenlik',
    'settings.account': 'Hesap',
    'settings.about': 'Hakkında',
    'settings.version': 'Versiyon',
    'settings.clear_cache': 'Önbelleği Temizle',
    'settings.clear_cache_success': 'Önbellek temizlendi',

    // Profile
    'profile.title': 'Profil',
    'profile.edit': 'Profili Düzenle',
    'profile.first_name': 'Ad',
    'profile.last_name': 'Soyad',
    'profile.phone': 'Telefon',
    'profile.avatar': 'Profil Fotoğrafı',
    'profile.change_avatar': 'Fotoğrafı Değiştir',

    // Errors
    'error.generic': 'Bir hata oluştu',
    'error.network': 'İnternet bağlantısı yok',
    'error.server': 'Sunucu hatası',
    'error.timeout': 'İstek zaman aşımına uğradı',
    'error.unauthorized': 'Yetkisiz erişim',
    'error.not_found': 'Bulunamadı',
    'error.validation': 'Doğrulama hatası',
    'error.required_field': 'Bu alan zorunludur',
    'error.invalid_format': 'Geçersiz format',
    'error.try_again': 'Lütfen tekrar deneyin',

    // Empty states
    'empty.no_data': 'Veri bulunamadı',
    'empty.no_results': 'Sonuç bulunamadı',
    'empty.no_items': 'Henüz öğe yok',

    // Search
    'search.title': 'Ara',
    'search.placeholder': 'Ara...',
    'search.no_results': 'Sonuç bulunamadı',
    'search.recent': 'Son Aramalar',
    'search.suggestions': 'Öneriler',
    'search.clear_history': 'Geçmişi Temizle',

    // Offline
    'offline.title': 'Çevrimdışı',
    'offline.message': 'İnternet bağlantısı yok',
    'offline.retry': 'Tekrar Dene',
    'offline.connected': 'Bağlantı kuruldu',
    'offline.pending_sync': '{count} işlem bekliyor',

    // Confirmation
    'confirm.delete': 'Silmek istediğinize emin misiniz?',
    'confirm.discard': 'Değişiklikleri iptal etmek istediğinize emin misiniz?',
    'confirm.logout': 'Çıkış yapmak istediğinize emin misiniz?',

    // Success messages
    'success.saved': 'Başarıyla kaydedildi',
    'success.deleted': 'Başarıyla silindi',
    'success.updated': 'Başarıyla güncellendi',
    'success.created': 'Başarıyla oluşturuldu',

    // Time
    'time.now': 'Şimdi',
    'time.today': 'Bugün',
    'time.yesterday': 'Dün',
    'time.tomorrow': 'Yarın',
    'time.this_week': 'Bu Hafta',
    'time.last_week': 'Geçen Hafta',
    'time.this_month': 'Bu Ay',
    'time.last_month': 'Geçen Ay',
    'time.minutes_ago': '{count} dakika önce',
    'time.hours_ago': '{count} saat önce',
    'time.days_ago': '{count} gün önce',
  };

  // ============================================
  // ENGLISH TRANSLATIONS
  // ============================================

  static const Map<String, String> _englishTranslations = {
    // Common
    'common.ok': 'OK',
    'common.cancel': 'Cancel',
    'common.save': 'Save',
    'common.delete': 'Delete',
    'common.edit': 'Edit',
    'common.add': 'Add',
    'common.search': 'Search',
    'common.filter': 'Filter',
    'common.sort': 'Sort',
    'common.refresh': 'Refresh',
    'common.loading': 'Loading...',
    'common.error': 'Error',
    'common.success': 'Success',
    'common.warning': 'Warning',
    'common.info': 'Info',
    'common.yes': 'Yes',
    'common.no': 'No',
    'common.close': 'Close',
    'common.back': 'Back',
    'common.next': 'Next',
    'common.previous': 'Previous',
    'common.done': 'Done',
    'common.retry': 'Retry',
    'common.select': 'Select',
    'common.all': 'All',
    'common.none': 'None',
    'common.more': 'More',
    'common.less': 'Less',
    'common.show': 'Show',
    'common.hide': 'Hide',
    'common.required': 'Required',
    'common.optional': 'Optional',
    'common.name': 'Name',
    'common.description': 'Description',
    'common.code': 'Code',
    'common.status': 'Status',
    'common.type': 'Type',
    'common.date': 'Date',
    'common.time': 'Time',
    'common.active': 'Active',
    'common.inactive': 'Inactive',
    'common.enabled': 'Enabled',
    'common.disabled': 'Disabled',

    // Auth
    'auth.login': 'Login',
    'auth.logout': 'Logout',
    'auth.register': 'Register',
    'auth.email': 'Email',
    'auth.password': 'Password',
    'auth.confirm_password': 'Confirm Password',
    'auth.forgot_password': 'Forgot Password',
    'auth.reset_password': 'Reset Password',
    'auth.change_password': 'Change Password',
    'auth.login_success': 'Login successful',
    'auth.login_failed': 'Login failed',
    'auth.logout_success': 'Logged out',
    'auth.invalid_email': 'Invalid email address',
    'auth.invalid_password': 'Password must be at least 6 characters',
    'auth.passwords_not_match': 'Passwords do not match',
    'auth.biometric_login': 'Biometric login',
    'auth.use_biometrics': 'Use biometrics',

    // Navigation
    'nav.home': 'Home',
    'nav.dashboard': 'Dashboard',
    'nav.organizations': 'Organizations',
    'nav.sites': 'Sites',
    'nav.units': 'Units',
    'nav.activities': 'Activities',
    'nav.notifications': 'Notifications',
    'nav.settings': 'Settings',
    'nav.profile': 'Profile',
    'nav.help': 'Help',
    'nav.about': 'About',

    // Organizations
    'org.title': 'Organizations',
    'org.add': 'Add Organization',
    'org.edit': 'Edit Organization',
    'org.delete': 'Delete Organization',
    'org.detail': 'Organization Details',
    'org.name': 'Organization Name',
    'org.code': 'Organization Code',
    'org.no_organizations': 'No organizations yet',
    'org.delete_confirm': 'Are you sure you want to delete this organization?',

    // Sites
    'site.title': 'Sites',
    'site.add': 'Add Site',
    'site.edit': 'Edit Site',
    'site.delete': 'Delete Site',
    'site.detail': 'Site Details',
    'site.name': 'Site Name',
    'site.code': 'Site Code',
    'site.address': 'Address',
    'site.city': 'City',
    'site.country': 'Country',
    'site.no_sites': 'No sites yet',
    'site.delete_confirm': 'Are you sure you want to delete this site?',

    // Units
    'unit.title': 'Units',
    'unit.add': 'Add Unit',
    'unit.edit': 'Edit Unit',
    'unit.delete': 'Delete Unit',
    'unit.detail': 'Unit Details',
    'unit.name': 'Unit Name',
    'unit.code': 'Unit Code',
    'unit.no_units': 'No units yet',
    'unit.delete_confirm': 'Are you sure you want to delete this unit?',

    // Activities
    'activity.title': 'Activities',
    'activity.recent': 'Recent Activities',
    'activity.all': 'All Activities',
    'activity.no_activities': 'No activities yet',
    'activity.created': 'Created by {user}',
    'activity.updated': 'Updated by {user}',
    'activity.deleted': 'Deleted by {user}',

    // Notifications
    'notification.title': 'Notifications',
    'notification.mark_read': 'Mark as Read',
    'notification.mark_all_read': 'Mark All as Read',
    'notification.delete_all': 'Delete All',
    'notification.no_notifications': 'No notifications',
    'notification.new_notification': 'New notification',

    // Settings
    'settings.title': 'Settings',
    'settings.general': 'General',
    'settings.appearance': 'Appearance',
    'settings.theme': 'Theme',
    'settings.theme_light': 'Light',
    'settings.theme_dark': 'Dark',
    'settings.theme_system': 'System',
    'settings.language': 'Language',
    'settings.notifications': 'Notifications',
    'settings.privacy': 'Privacy',
    'settings.security': 'Security',
    'settings.account': 'Account',
    'settings.about': 'About',
    'settings.version': 'Version',
    'settings.clear_cache': 'Clear Cache',
    'settings.clear_cache_success': 'Cache cleared',

    // Profile
    'profile.title': 'Profile',
    'profile.edit': 'Edit Profile',
    'profile.first_name': 'First Name',
    'profile.last_name': 'Last Name',
    'profile.phone': 'Phone',
    'profile.avatar': 'Profile Picture',
    'profile.change_avatar': 'Change Picture',

    // Errors
    'error.generic': 'An error occurred',
    'error.network': 'No internet connection',
    'error.server': 'Server error',
    'error.timeout': 'Request timed out',
    'error.unauthorized': 'Unauthorized access',
    'error.not_found': 'Not found',
    'error.validation': 'Validation error',
    'error.required_field': 'This field is required',
    'error.invalid_format': 'Invalid format',
    'error.try_again': 'Please try again',

    // Empty states
    'empty.no_data': 'No data found',
    'empty.no_results': 'No results found',
    'empty.no_items': 'No items yet',

    // Search
    'search.title': 'Search',
    'search.placeholder': 'Search...',
    'search.no_results': 'No results found',
    'search.recent': 'Recent Searches',
    'search.suggestions': 'Suggestions',
    'search.clear_history': 'Clear History',

    // Offline
    'offline.title': 'Offline',
    'offline.message': 'No internet connection',
    'offline.retry': 'Retry',
    'offline.connected': 'Connected',
    'offline.pending_sync': '{count} operations pending',

    // Confirmation
    'confirm.delete': 'Are you sure you want to delete?',
    'confirm.discard': 'Are you sure you want to discard changes?',
    'confirm.logout': 'Are you sure you want to logout?',

    // Success messages
    'success.saved': 'Successfully saved',
    'success.deleted': 'Successfully deleted',
    'success.updated': 'Successfully updated',
    'success.created': 'Successfully created',

    // Time
    'time.now': 'Now',
    'time.today': 'Today',
    'time.yesterday': 'Yesterday',
    'time.tomorrow': 'Tomorrow',
    'time.this_week': 'This Week',
    'time.last_week': 'Last Week',
    'time.this_month': 'This Month',
    'time.last_month': 'Last Month',
    'time.minutes_ago': '{count} minutes ago',
    'time.hours_ago': '{count} hours ago',
    'time.days_ago': '{count} days ago',
  };

  // ============================================
  // GERMAN TRANSLATIONS
  // ============================================

  static const Map<String, String> _germanTranslations = {
    // Common
    'common.ok': 'OK',
    'common.cancel': 'Abbrechen',
    'common.save': 'Speichern',
    'common.delete': 'Löschen',
    'common.edit': 'Bearbeiten',
    'common.add': 'Hinzufügen',
    'common.search': 'Suchen',
    'common.filter': 'Filtern',
    'common.sort': 'Sortieren',
    'common.refresh': 'Aktualisieren',
    'common.loading': 'Wird geladen...',
    'common.error': 'Fehler',
    'common.success': 'Erfolg',
    'common.warning': 'Warnung',
    'common.info': 'Info',
    'common.yes': 'Ja',
    'common.no': 'Nein',
    'common.close': 'Schließen',
    'common.back': 'Zurück',
    'common.next': 'Weiter',
    'common.previous': 'Zurück',
    'common.done': 'Fertig',
    'common.retry': 'Wiederholen',
    'common.select': 'Auswählen',
    'common.all': 'Alle',
    'common.none': 'Keine',
    'common.more': 'Mehr',
    'common.less': 'Weniger',
    'common.show': 'Anzeigen',
    'common.hide': 'Ausblenden',
    'common.required': 'Erforderlich',
    'common.optional': 'Optional',
    'common.name': 'Name',
    'common.description': 'Beschreibung',
    'common.code': 'Code',
    'common.status': 'Status',
    'common.type': 'Typ',
    'common.date': 'Datum',
    'common.time': 'Zeit',
    'common.active': 'Aktiv',
    'common.inactive': 'Inaktiv',
    'common.enabled': 'Aktiviert',
    'common.disabled': 'Deaktiviert',

    // Auth
    'auth.login': 'Anmelden',
    'auth.logout': 'Abmelden',
    'auth.register': 'Registrieren',
    'auth.email': 'E-Mail',
    'auth.password': 'Passwort',
    'auth.confirm_password': 'Passwort bestätigen',
    'auth.forgot_password': 'Passwort vergessen',
    'auth.reset_password': 'Passwort zurücksetzen',
    'auth.change_password': 'Passwort ändern',
    'auth.login_success': 'Anmeldung erfolgreich',
    'auth.login_failed': 'Anmeldung fehlgeschlagen',
    'auth.logout_success': 'Abgemeldet',
    'auth.invalid_email': 'Ungültige E-Mail-Adresse',
    'auth.invalid_password': 'Passwort muss mindestens 6 Zeichen haben',
    'auth.passwords_not_match': 'Passwörter stimmen nicht überein',
    'auth.biometric_login': 'Biometrische Anmeldung',
    'auth.use_biometrics': 'Biometrie verwenden',

    // Navigation
    'nav.home': 'Startseite',
    'nav.dashboard': 'Dashboard',
    'nav.organizations': 'Organisationen',
    'nav.sites': 'Standorte',
    'nav.units': 'Einheiten',
    'nav.activities': 'Aktivitäten',
    'nav.notifications': 'Benachrichtigungen',
    'nav.settings': 'Einstellungen',
    'nav.profile': 'Profil',
    'nav.help': 'Hilfe',
    'nav.about': 'Über',

    // Organizations
    'org.title': 'Organisationen',
    'org.add': 'Organisation hinzufügen',
    'org.edit': 'Organisation bearbeiten',
    'org.delete': 'Organisation löschen',
    'org.detail': 'Organisationsdetails',
    'org.name': 'Organisationsname',
    'org.code': 'Organisationscode',
    'org.no_organizations': 'Noch keine Organisationen',
    'org.delete_confirm': 'Möchten Sie diese Organisation wirklich löschen?',

    // Sites
    'site.title': 'Standorte',
    'site.add': 'Standort hinzufügen',
    'site.edit': 'Standort bearbeiten',
    'site.delete': 'Standort löschen',
    'site.detail': 'Standortdetails',
    'site.name': 'Standortname',
    'site.code': 'Standortcode',
    'site.address': 'Adresse',
    'site.city': 'Stadt',
    'site.country': 'Land',
    'site.no_sites': 'Noch keine Standorte',
    'site.delete_confirm': 'Möchten Sie diesen Standort wirklich löschen?',

    // Units
    'unit.title': 'Einheiten',
    'unit.add': 'Einheit hinzufügen',
    'unit.edit': 'Einheit bearbeiten',
    'unit.delete': 'Einheit löschen',
    'unit.detail': 'Einheitendetails',
    'unit.name': 'Einheitenname',
    'unit.code': 'Einheitencode',
    'unit.no_units': 'Noch keine Einheiten',
    'unit.delete_confirm': 'Möchten Sie diese Einheit wirklich löschen?',

    // Activities
    'activity.title': 'Aktivitäten',
    'activity.recent': 'Letzte Aktivitäten',
    'activity.all': 'Alle Aktivitäten',
    'activity.no_activities': 'Noch keine Aktivitäten',
    'activity.created': 'Erstellt von {user}',
    'activity.updated': 'Aktualisiert von {user}',
    'activity.deleted': 'Gelöscht von {user}',

    // Notifications
    'notification.title': 'Benachrichtigungen',
    'notification.mark_read': 'Als gelesen markieren',
    'notification.mark_all_read': 'Alle als gelesen markieren',
    'notification.delete_all': 'Alle löschen',
    'notification.no_notifications': 'Keine Benachrichtigungen',
    'notification.new_notification': 'Neue Benachrichtigung',

    // Settings
    'settings.title': 'Einstellungen',
    'settings.general': 'Allgemein',
    'settings.appearance': 'Erscheinungsbild',
    'settings.theme': 'Thema',
    'settings.theme_light': 'Hell',
    'settings.theme_dark': 'Dunkel',
    'settings.theme_system': 'System',
    'settings.language': 'Sprache',
    'settings.notifications': 'Benachrichtigungen',
    'settings.privacy': 'Datenschutz',
    'settings.security': 'Sicherheit',
    'settings.account': 'Konto',
    'settings.about': 'Über',
    'settings.version': 'Version',
    'settings.clear_cache': 'Cache leeren',
    'settings.clear_cache_success': 'Cache geleert',

    // Profile
    'profile.title': 'Profil',
    'profile.edit': 'Profil bearbeiten',
    'profile.first_name': 'Vorname',
    'profile.last_name': 'Nachname',
    'profile.phone': 'Telefon',
    'profile.avatar': 'Profilbild',
    'profile.change_avatar': 'Bild ändern',

    // Errors
    'error.generic': 'Ein Fehler ist aufgetreten',
    'error.network': 'Keine Internetverbindung',
    'error.server': 'Serverfehler',
    'error.timeout': 'Zeitüberschreitung',
    'error.unauthorized': 'Nicht autorisiert',
    'error.not_found': 'Nicht gefunden',
    'error.validation': 'Validierungsfehler',
    'error.required_field': 'Dieses Feld ist erforderlich',
    'error.invalid_format': 'Ungültiges Format',
    'error.try_again': 'Bitte versuchen Sie es erneut',

    // Empty states
    'empty.no_data': 'Keine Daten gefunden',
    'empty.no_results': 'Keine Ergebnisse gefunden',
    'empty.no_items': 'Noch keine Elemente',

    // Search
    'search.title': 'Suchen',
    'search.placeholder': 'Suchen...',
    'search.no_results': 'Keine Ergebnisse gefunden',
    'search.recent': 'Letzte Suchen',
    'search.suggestions': 'Vorschläge',
    'search.clear_history': 'Verlauf löschen',

    // Offline
    'offline.title': 'Offline',
    'offline.message': 'Keine Internetverbindung',
    'offline.retry': 'Wiederholen',
    'offline.connected': 'Verbunden',
    'offline.pending_sync': '{count} Vorgänge ausstehend',

    // Confirmation
    'confirm.delete': 'Möchten Sie wirklich löschen?',
    'confirm.discard': 'Möchten Sie die Änderungen wirklich verwerfen?',
    'confirm.logout': 'Möchten Sie sich wirklich abmelden?',

    // Success messages
    'success.saved': 'Erfolgreich gespeichert',
    'success.deleted': 'Erfolgreich gelöscht',
    'success.updated': 'Erfolgreich aktualisiert',
    'success.created': 'Erfolgreich erstellt',

    // Time
    'time.now': 'Jetzt',
    'time.today': 'Heute',
    'time.yesterday': 'Gestern',
    'time.tomorrow': 'Morgen',
    'time.this_week': 'Diese Woche',
    'time.last_week': 'Letzte Woche',
    'time.this_month': 'Diesen Monat',
    'time.last_month': 'Letzten Monat',
    'time.minutes_ago': 'vor {count} Minuten',
    'time.hours_ago': 'vor {count} Stunden',
    'time.days_ago': 'vor {count} Tagen',
  };
}

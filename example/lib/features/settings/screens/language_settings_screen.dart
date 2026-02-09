import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Dil Ayarları Ekranı
///
/// Kullanıcının uygulama dilini değiştirmesine olanak tanır.
class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  late AppLocale _selectedLocale;
  bool _useSystemLanguage = false;

  @override
  void initState() {
    super.initState();
    _selectedLocale = localizationService.currentLocale;
    _checkSystemLanguage();
  }

  void _checkSystemLanguage() async {
    // Check if current locale matches system locale
    // This is a simplified check
    _useSystemLanguage = false;
  }

  Future<void> _changeLanguage(AppLocale locale) async {
    if (_selectedLocale == locale) return;

    setState(() {
      _selectedLocale = locale;
      _useSystemLanguage = false;
    });

    await localizationService.setLocale(locale);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dil ${locale.displayName} olarak değiştirildi'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _useSystemLocale() async {
    setState(() => _useSystemLanguage = true);
    await localizationService.useSystemLocale();
    setState(() {
      _selectedLocale = localizationService.currentLocale;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sistem dili kullanılıyor'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dil Ayarları'),
      ),
      body: ListView(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.language,
                  size: 48,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Uygulama Dili',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Uygulamada kullanılacak dili seçin. Değişiklik anında uygulanacaktır.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // System Language Option
          ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.phone_android),
            ),
            title: const Text('Sistem Dilini Kullan'),
            subtitle: const Text('Cihazınızın dil ayarını kullanır'),
            trailing: _useSystemLanguage
                ? Icon(
                    Icons.check_circle,
                    color: Theme.of(context).primaryColor,
                  )
                : null,
            onTap: _useSystemLocale,
          ),

          const Divider(height: 1),

          // Language Options
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Dil Seçin',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
            ),
          ),

          ...AppLocale.values.map((locale) => _buildLanguageItem(locale)),

          const SizedBox(height: 24),

          // Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: Colors.blue.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue[700],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Dil değişikliği yapıldığında tüm metinler seçilen dilde görüntülenecektir. Bazı içerikler (kullanıcı tarafından oluşturulan veriler) çevrilmeyecektir.',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLanguageItem(AppLocale locale) {
    final isSelected = _selectedLocale == locale && !_useSystemLanguage;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isSelected
            ? Theme.of(context).primaryColor
            : Colors.grey.withOpacity(0.1),
        child: Text(
          _getFlagEmoji(locale),
          style: const TextStyle(fontSize: 20),
        ),
      ),
      title: Text(
        locale.displayName,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(_getLanguageNativeName(locale)),
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).primaryColor,
            )
          : const Icon(
              Icons.circle_outlined,
              color: Colors.grey,
            ),
      onTap: () => _changeLanguage(locale),
    );
  }

  String _getFlagEmoji(AppLocale locale) {
    switch (locale) {
      case AppLocale.turkish:
        return '🇹🇷';
      case AppLocale.english:
        return '🇺🇸';
      case AppLocale.german:
        return '🇩🇪';
    }
  }

  String _getLanguageNativeName(AppLocale locale) {
    switch (locale) {
      case AppLocale.turkish:
        return 'Türkiye';
      case AppLocale.english:
        return 'United States';
      case AppLocale.german:
        return 'Deutschland';
    }
  }
}

/// Dil değiştirme widget'ı
///
/// Herhangi bir ekranda kullanılabilir.
class LanguageSwitcher extends StatelessWidget {
  final bool showLabel;
  final bool compact;

  const LanguageSwitcher({
    super.key,
    this.showLabel = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return LocalizationBuilder(
      localizationService: localizationService,
      builder: (context, currentLocale) {
        if (compact) {
          return PopupMenuButton<AppLocale>(
            initialValue: currentLocale,
            onSelected: (locale) => localizationService.setLocale(locale),
            itemBuilder: (context) => AppLocale.values.map((locale) {
              return PopupMenuItem<AppLocale>(
                value: locale,
                child: Row(
                  children: [
                    Text(_getFlagEmoji(locale)),
                    const SizedBox(width: 8),
                    Text(locale.displayName),
                    if (locale == currentLocale) ...[
                      const Spacer(),
                      Icon(
                        Icons.check,
                        size: 18,
                        color: Theme.of(context).primaryColor,
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getFlagEmoji(currentLocale),
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 20),
                ],
              ),
            ),
          );
        }

        return InkWell(
          onTap: () => _showLanguageSelector(context, currentLocale),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getFlagEmoji(currentLocale),
                  style: const TextStyle(fontSize: 20),
                ),
                if (showLabel) ...[
                  const SizedBox(width: 8),
                  Text(currentLocale.displayName),
                ],
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLanguageSelector(BuildContext context, AppLocale currentLocale) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Dil Seçin',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            ...AppLocale.values.map((locale) {
              final isSelected = locale == currentLocale;
              return ListTile(
                leading: Text(
                  _getFlagEmoji(locale),
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(
                  locale.displayName,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).primaryColor,
                      )
                    : null,
                onTap: () {
                  localizationService.setLocale(locale);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _getFlagEmoji(AppLocale locale) {
    switch (locale) {
      case AppLocale.turkish:
        return '🇹🇷';
      case AppLocale.english:
        return '🇺🇸';
      case AppLocale.german:
        return '🇩🇪';
    }
  }
}

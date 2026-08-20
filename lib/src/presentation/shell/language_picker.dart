import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/localization/language_service.dart';
import '../../core/localization/localization_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../widgets/lists/app_list_tile.dart';
import '../widgets/navigation/app_bottom_sheet.dart';

/// Dil seçiciyi modal bottom sheet olarak açar.
///
/// `LanguageService.availableLanguages()` ile aktif platformun sunduğu dilleri
/// yükler (yüklenirken spinner gösterir), her satır ana-dilde ad + mevcut
/// locale için tik gösterir. Bir dile dokununca `LocalizationService.setLocale`
/// çağrılır (tercih kalıcı + stream'e yayınlanır → uygulama canlı yeniden çizer)
/// ve sheet kapanır.
/// 2-harfli ülke kodunu (ör. 'TR') bölgesel-gösterge bayrak emojisine çevirir
/// (🇹🇷). Geçersiz/eksik kodda boş string döner.
String flagEmoji(String? countryCode) {
  final cc = countryCode?.trim().toUpperCase();
  if (cc == null || cc.length != 2) return '';
  const base = 0x1F1E6; // regional indicator 'A'
  final a = cc.codeUnitAt(0);
  final b = cc.codeUnitAt(1);
  if (a < 0x41 || a > 0x5A || b < 0x41 || b > 0x5A) return '';
  return String.fromCharCode(base + (a - 0x41)) +
      String.fromCharCode(base + (b - 0x41));
}

Future<void> showLanguagePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LanguagePickerSheet(),
  );
}

class _LanguagePickerSheet extends StatefulWidget {
  const _LanguagePickerSheet();

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  late final Future<List<LanguageOption>> _future;

  @override
  void initState() {
    super.initState();
    _future = sl<LanguageService>().availableLanguages();
  }

  String _t(String key, String fallback) {
    final value = sl<LocalizationService>().translate(key);
    return value == key ? fallback : value;
  }

  Future<void> _select(LanguageOption option) async {
    await sl<LocalizationService>().setLocale(option.locale);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final current = sl<LocalizationService>().currentLocale;

    return AppBottomSheet(
      title: _t('settings.language', 'Dil / Language'),
      child: FutureBuilder<List<LanguageOption>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator.adaptive()),
            );
          }

          final options = snapshot.data ?? const <LanguageOption>[];
          if (options.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Text(
                  _t('common.no_records', 'Kayıt yok'),
                  style: TextStyle(color: AppColors.secondaryLabel(context)),
                ),
              ),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, color: AppColors.separator(context)),
                _LanguageRow(
                  option: options[i],
                  isSelected: options[i].locale == current,
                  onTap: () => _select(options[i]),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
            ],
          );
        },
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  final LanguageOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageRow({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final flag = flagEmoji(option.locale.countryCode);
    return AppListTile(
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: (isSelected ? AppColors.primary : Colors.grey)
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: flag.isEmpty
            ? Icon(
                Icons.language,
                color: isSelected ? AppColors.primary : Colors.grey,
              )
            : Text(flag, style: const TextStyle(fontSize: 24)),
      ),
      title: option.nativeName,
      subtitle: option.code,
      trailing:
          isSelected ? Icon(Icons.check, color: AppColors.primary) : null,
      onTap: onTap,
    );
  }
}

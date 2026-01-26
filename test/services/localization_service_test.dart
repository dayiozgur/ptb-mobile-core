import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class MockSecureStorage extends Mock implements SecureStorage {}

void main() {
  late LocalizationService localizationService;
  late MockSecureStorage mockStorage;

  setUp(() {
    mockStorage = MockSecureStorage();
    localizationService = LocalizationService(storage: mockStorage);
  });

  tearDown(() {
    localizationService.dispose();
  });

  group('AppLocale', () {
    test('has correct values', () {
      expect(AppLocale.turkish.languageCode, 'tr');
      expect(AppLocale.english.languageCode, 'en');
      expect(AppLocale.german.languageCode, 'de');
    });

    test('has correct display names', () {
      expect(AppLocale.turkish.displayName, 'Türkçe');
      expect(AppLocale.english.displayName, 'English');
      expect(AppLocale.german.displayName, 'Deutsch');
    });

    test('has correct country codes', () {
      expect(AppLocale.turkish.countryCode, 'TR');
      expect(AppLocale.english.countryCode, 'US');
      expect(AppLocale.german.countryCode, 'DE');
    });

    test('toLocale returns correct Locale', () {
      final locale = AppLocale.turkish.toLocale();
      expect(locale.languageCode, 'tr');
      expect(locale.countryCode, 'TR');
    });

    test('fromLanguageCode returns correct locale', () {
      expect(AppLocale.fromLanguageCode('tr'), AppLocale.turkish);
      expect(AppLocale.fromLanguageCode('en'), AppLocale.english);
      expect(AppLocale.fromLanguageCode('de'), AppLocale.german);
    });

    test('fromLanguageCode returns turkish for invalid code', () {
      expect(AppLocale.fromLanguageCode('fr'), AppLocale.turkish);
      expect(AppLocale.fromLanguageCode(null), AppLocale.turkish);
      expect(AppLocale.fromLanguageCode(''), AppLocale.turkish);
    });
  });

  group('LocalizationService - Initialization', () {
    test('initializes with default locale when no saved preference', () async {
      when(() => mockStorage.read(any())).thenAnswer((_) async => null);

      await localizationService.initialize();

      expect(localizationService.isInitialized, true);
      // Default locale should be based on system or turkish
    });

    test('initializes with saved locale preference', () async {
      when(() => mockStorage.read(any())).thenAnswer((_) async => 'en');

      await localizationService.initialize();

      expect(localizationService.isInitialized, true);
      expect(localizationService.currentLocale, AppLocale.english);
    });

    test('initialize is idempotent', () async {
      when(() => mockStorage.read(any())).thenAnswer((_) async => 'en');

      await localizationService.initialize();
      await localizationService.initialize();

      verify(() => mockStorage.read(any())).called(1);
    });
  });

  group('LocalizationService - Locale Management', () {
    setUp(() async {
      when(() => mockStorage.read(any())).thenAnswer((_) async => 'tr');
      when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});
      await localizationService.initialize();
    });

    test('setLocale changes current locale', () async {
      await localizationService.setLocale(AppLocale.english);

      expect(localizationService.currentLocale, AppLocale.english);
      verify(() => mockStorage.write(key: any(named: 'key'), value: 'en')).called(1);
    });

    test('setLocale does not change if same locale', () async {
      localizationService = LocalizationService(storage: mockStorage);
      when(() => mockStorage.read(any())).thenAnswer((_) async => 'en');
      await localizationService.initialize();

      await localizationService.setLocale(AppLocale.english);

      verifyNever(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')));
    });

    test('supportedLocales returns all locales', () {
      expect(localizationService.supportedLocales, AppLocale.values);
    });

    test('supportedFlutterLocales returns Flutter Locales', () {
      final locales = localizationService.supportedFlutterLocales;

      expect(locales.length, 3);
      expect(locales.any((l) => l.languageCode == 'tr'), true);
      expect(locales.any((l) => l.languageCode == 'en'), true);
      expect(locales.any((l) => l.languageCode == 'de'), true);
    });

    test('locale getter returns Flutter Locale', () {
      expect(localizationService.locale.languageCode, 'tr');
    });
  });

  group('LocalizationService - Translations', () {
    setUp(() async {
      when(() => mockStorage.read(any())).thenAnswer((_) async => 'tr');
      when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});
      await localizationService.initialize();
    });

    test('translate returns correct translation', () {
      final result = localizationService.translate('common.save');
      expect(result, 'Kaydet');
    });

    test('translate returns key when translation not found', () {
      final result = localizationService.translate('non.existent.key');
      expect(result, 'non.existent.key');
    });

    test('translate with parameters replaces placeholders', () {
      final result = localizationService.translate(
        'validation.min_length',
        params: {'min': 8},
      );
      expect(result.contains('8'), true);
    });

    test('tr shorthand works correctly', () {
      final result = localizationService.tr('common.cancel');
      expect(result, 'İptal');
    });

    test('plural returns correct form for count 1', () {
      // Assuming there's a plural key defined
      final result = localizationService.plural('common.item', 1);
      expect(result, isNotEmpty);
    });

    test('plural returns correct form for count > 1', () {
      final result = localizationService.plural('common.item', 5);
      expect(result, isNotEmpty);
    });
  });

  group('LocalizationService - Formatters', () {
    setUp(() async {
      when(() => mockStorage.read(any())).thenAnswer((_) async => 'tr');
      when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});
      await localizationService.initialize();
    });

    group('formatDate', () {
      test('formats date in Turkish format', () async {
        final date = DateTime(2024, 3, 15);
        final result = localizationService.formatDate(date);
        expect(result, '15.03.2024');
      });

      test('formats date in English format', () async {
        await localizationService.setLocale(AppLocale.english);
        final date = DateTime(2024, 3, 15);
        final result = localizationService.formatDate(date);
        expect(result, '03/15/2024');
      });

      test('formats date in German format', () async {
        await localizationService.setLocale(AppLocale.german);
        final date = DateTime(2024, 3, 15);
        final result = localizationService.formatDate(date);
        expect(result, '15.03.2024');
      });
    });

    group('formatTime', () {
      test('formats time in 24-hour format', () {
        final time = DateTime(2024, 1, 1, 14, 30);
        final result = localizationService.formatTime(time, use24Hour: true);
        expect(result, '14:30');
      });

      test('formats time in 12-hour format', () {
        final time = DateTime(2024, 1, 1, 14, 30);
        final result = localizationService.formatTime(time, use24Hour: false);
        expect(result, '2:30 PM');
      });

      test('formats morning time in 12-hour format', () {
        final time = DateTime(2024, 1, 1, 9, 15);
        final result = localizationService.formatTime(time, use24Hour: false);
        expect(result, '9:15 AM');
      });

      test('formats midnight correctly', () {
        final time = DateTime(2024, 1, 1, 0, 0);
        final result = localizationService.formatTime(time, use24Hour: false);
        expect(result, '12:00 AM');
      });
    });

    group('formatNumber', () {
      test('formats number with Turkish separators', () async {
        final result = localizationService.formatNumber(1234567);
        expect(result, '1.234.567');
      });

      test('formats number with decimals', () async {
        final result = localizationService.formatNumber(1234.56, decimals: 2);
        expect(result, '1.234,56');
      });

      test('formats number with English separators', () async {
        await localizationService.setLocale(AppLocale.english);
        final result = localizationService.formatNumber(1234567);
        expect(result, '1,234,567');
      });

      test('formats number with English decimals', () async {
        await localizationService.setLocale(AppLocale.english);
        final result = localizationService.formatNumber(1234.56, decimals: 2);
        expect(result, '1,234.56');
      });
    });

    group('formatCurrency', () {
      test('formats currency in Turkish format', () async {
        final result = localizationService.formatCurrency(1234.50);
        expect(result.contains('₺'), true);
        expect(result.contains('1.234'), true);
      });

      test('formats currency in English format', () async {
        await localizationService.setLocale(AppLocale.english);
        final result = localizationService.formatCurrency(1234.50);
        expect(result.contains('\$'), true);
      });

      test('formats currency in German format', () async {
        await localizationService.setLocale(AppLocale.german);
        final result = localizationService.formatCurrency(1234.50);
        expect(result.contains('€'), true);
      });

      test('formats currency with custom symbol', () async {
        final result = localizationService.formatCurrency(100, symbol: '£');
        expect(result.contains('£'), true);
      });
    });
  });

  group('LocalizationService - Stream', () {
    setUp(() async {
      when(() => mockStorage.read(any())).thenAnswer((_) async => 'tr');
      when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});
      await localizationService.initialize();
    });

    test('localeStream emits on locale change', () async {
      final emissions = <AppLocale>[];
      final subscription = localizationService.localeStream.listen(emissions.add);

      await localizationService.setLocale(AppLocale.english);
      await localizationService.setLocale(AppLocale.german);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(emissions, [AppLocale.english, AppLocale.german]);

      await subscription.cancel();
    });
  });
}

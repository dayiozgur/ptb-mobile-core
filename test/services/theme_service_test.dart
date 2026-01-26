import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class MockSecureStorage extends Mock implements SecureStorage {}

void main() {
  late ThemeService themeService;
  late MockSecureStorage mockStorage;

  setUp(() {
    mockStorage = MockSecureStorage();
    themeService = ThemeService(storage: mockStorage);
  });

  tearDown(() {
    themeService.dispose();
  });

  group('AppThemeMode', () {
    test('has correct values', () {
      expect(AppThemeMode.system.value, 'system');
      expect(AppThemeMode.light.value, 'light');
      expect(AppThemeMode.dark.value, 'dark');
    });

    test('has correct labels', () {
      expect(AppThemeMode.system.label, 'Sistem');
      expect(AppThemeMode.light.label, 'Açık');
      expect(AppThemeMode.dark.label, 'Koyu');
    });

    test('fromValue returns correct mode', () {
      expect(AppThemeMode.fromValue('system'), AppThemeMode.system);
      expect(AppThemeMode.fromValue('light'), AppThemeMode.light);
      expect(AppThemeMode.fromValue('dark'), AppThemeMode.dark);
    });

    test('fromValue returns system for invalid value', () {
      expect(AppThemeMode.fromValue('invalid'), AppThemeMode.system);
      expect(AppThemeMode.fromValue(null), AppThemeMode.system);
      expect(AppThemeMode.fromValue(''), AppThemeMode.system);
    });
  });

  group('ThemeService - Initialization', () {
    test('initializes with default settings when no saved preference', () async {
      when(() => mockStorage.read(any())).thenAnswer((_) async => null);

      await themeService.initialize();

      expect(themeService.isInitialized, true);
      expect(themeService.themeMode, AppThemeMode.system);
    });

    test('initializes with saved theme preference', () async {
      when(() => mockStorage.read(any())).thenAnswer((_) async => '{"themeMode":"dark"}');

      await themeService.initialize();

      expect(themeService.isInitialized, true);
      expect(themeService.themeMode, AppThemeMode.dark);
    });

    test('initialize is idempotent', () async {
      when(() => mockStorage.read(any())).thenAnswer((_) async => null);

      await themeService.initialize();
      await themeService.initialize();

      verify(() => mockStorage.read(any())).called(1);
    });
  });

  group('ThemeService - Theme Mode Management', () {
    setUp(() async {
      when(() => mockStorage.read(any())).thenAnswer((_) async => null);
      when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});
      await themeService.initialize();
    });

    test('setThemeMode changes current mode', () async {
      await themeService.setThemeMode(AppThemeMode.dark);

      expect(themeService.themeMode, AppThemeMode.dark);
      verify(() => mockStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).called(1);
    });

    test('setThemeMode does not save if same mode', () async {
      // Default is system
      await themeService.setThemeMode(AppThemeMode.system);

      verifyNever(() => mockStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ));
    });

    test('toggleTheme cycles through modes', () async {
      expect(themeService.themeMode, AppThemeMode.system);

      await themeService.toggleTheme();
      expect(themeService.themeMode, AppThemeMode.light);

      await themeService.toggleTheme();
      expect(themeService.themeMode, AppThemeMode.dark);

      await themeService.toggleTheme();
      expect(themeService.themeMode, AppThemeMode.system);
    });
  });

  group('ThemeService - Theme Data', () {
    setUp(() async {
      when(() => mockStorage.read(any())).thenAnswer((_) async => null);
      when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});
      await themeService.initialize();
    });

    test('lightTheme returns valid ThemeData', () {
      final theme = themeService.lightTheme;

      expect(theme, isA<ThemeData>());
      expect(theme.brightness, Brightness.light);
    });

    test('darkTheme returns valid ThemeData', () {
      final theme = themeService.darkTheme;

      expect(theme, isA<ThemeData>());
      expect(theme.brightness, Brightness.dark);
    });

    test('currentTheme returns correct theme based on mode', () async {
      await themeService.setThemeMode(AppThemeMode.light);
      expect(themeService.currentTheme.brightness, Brightness.light);

      await themeService.setThemeMode(AppThemeMode.dark);
      expect(themeService.currentTheme.brightness, Brightness.dark);
    });
  });

  group('ThemeService - Brightness', () {
    setUp(() async {
      when(() => mockStorage.read(any())).thenAnswer((_) async => null);
      when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});
      await themeService.initialize();
    });

    test('isDarkMode returns correct value', () async {
      await themeService.setThemeMode(AppThemeMode.dark);
      expect(themeService.isDarkMode, true);

      await themeService.setThemeMode(AppThemeMode.light);
      expect(themeService.isDarkMode, false);
    });

    test('isLightMode returns correct value', () async {
      await themeService.setThemeMode(AppThemeMode.light);
      expect(themeService.isLightMode, true);

      await themeService.setThemeMode(AppThemeMode.dark);
      expect(themeService.isLightMode, false);
    });

    test('isSystemMode returns correct value', () async {
      expect(themeService.isSystemMode, true);

      await themeService.setThemeMode(AppThemeMode.light);
      expect(themeService.isSystemMode, false);

      await themeService.setThemeMode(AppThemeMode.system);
      expect(themeService.isSystemMode, true);
    });
  });

  group('ThemeService - Stream', () {
    setUp(() async {
      when(() => mockStorage.read(any())).thenAnswer((_) async => null);
      when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});
      await themeService.initialize();
    });

    test('themeModeStream emits on mode change', () async {
      final emissions = <AppThemeMode>[];
      final subscription = themeService.themeModeStream.listen(emissions.add);

      await themeService.setThemeMode(AppThemeMode.light);
      await themeService.setThemeMode(AppThemeMode.dark);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(emissions, [AppThemeMode.light, AppThemeMode.dark]);

      await subscription.cancel();
    });
  });

  group('ThemeSettings', () {
    test('toJson serializes correctly', () {
      final settings = ThemeSettings(themeMode: AppThemeMode.dark);
      final json = settings.toJson();

      expect(json['themeMode'], 'dark');
    });

    test('fromJson deserializes correctly', () {
      final json = {'themeMode': 'dark'};
      final settings = ThemeSettings.fromJson(json);

      expect(settings.themeMode, AppThemeMode.dark);
    });

    test('copyWith creates correct copy', () {
      final settings = ThemeSettings(themeMode: AppThemeMode.light);
      final copy = settings.copyWith(themeMode: AppThemeMode.dark);

      expect(copy.themeMode, AppThemeMode.dark);
    });

    test('default settings uses system mode', () {
      final settings = ThemeSettings.defaultSettings();

      expect(settings.themeMode, AppThemeMode.system);
    });
  });
}

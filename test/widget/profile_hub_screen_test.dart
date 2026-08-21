import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../helpers/widget_test_helpers.dart';

/// Widget tests for [ProfileHubScreen] header.
///
/// `initState` → `_load()` fetches identity via `profileService.getProfileBundle`
/// and resolves the avatar via `fileStorageService.getAvatarUrl`. We fake both
/// and assert the LinkedIn-style header renders name + role from the profile.
void main() {
  late MockProfileService profiles;
  late MockFileStorageService storage;

  setUp(() async {
    await sl.reset();

    profiles = MockProfileService();
    storage = MockFileStorageService();

    // No avatar path → getAvatarUrl returns null (header shows initials).
    when(() => storage.getAvatarUrl(any())).thenAnswer((_) async => null);

    registerFake<ProfileService>(profiles);
    registerFake<FileStorageService>(storage);
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('shows a spinner while the profile bundle is loading',
      (tester) async {
    final completer = Completer<UserProfile?>();
    when(() => profiles.getProfileBundle(
        forceRefresh: any(named: 'forceRefresh'))).thenAnswer(
      (_) => completer.future,
    );

    await tester.pumpWidget(const MaterialApp(home: ProfileHubScreen()));
    await tester.pump(); // future still pending

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('renders name and role in the header when a profile loads',
      (tester) async {
    when(() => profiles.getProfileBundle(
            forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer(
      (_) async => const UserProfile(
        id: 'p-1',
        email: 'ozgur@protoolbag.com',
        fullName: 'Özgür Dayı',
        coarseRole: 'ROLE_ADMIN',
        tenantName: 'Protoolbag',
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: ProfileHubScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Özgür Dayı'), findsOneWidget);
    // coarseRole ROLE_ADMIN → Turkish role label "Yönetici" (role chip in the
    // header, also echoed in the account card).
    expect(find.text('Yönetici'), findsWidgets);
    // Email is used as the headline under the name (also shown in the
    // contact card, so at least one occurrence).
    expect(find.text('ozgur@protoolbag.com'), findsWidgets);
  });

  testWidgets('shows the error state when the profile fails to load',
      (tester) async {
    when(() => profiles.getProfileBundle(
            forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => null);

    await tester.pumpWidget(const MaterialApp(home: ProfileHubScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Profil yüklenemedi'), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
  });
}

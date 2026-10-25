import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Legacy `avatars` bucket is PRIVATE since 2026-10-25 (CRA A-11): any old
/// value must be resolved via a signed URL, never a public URL.
void main() {
  group('FileStorageService.legacyAvatarPath', () {
    test('public object URL → bucket-relative path', () {
      expect(
        FileStorageService.legacyAvatarPath(
            'https://x.supabase.co/storage/v1/object/public/avatars/u1/a%20b.png'),
        'u1/a b.png',
      );
    });

    test('signed URL (query stripped) and bare avatars/ path', () {
      expect(
        FileStorageService.legacyAvatarPath(
            'https://x.supabase.co/storage/v1/object/sign/avatars/u1/p.png?token=t'),
        'u1/p.png',
      );
      expect(FileStorageService.legacyAvatarPath('avatars/u2/p.jpg'), 'u2/p.jpg');
    });

    test('tenant-scoped protected paths and other URLs are not legacy', () {
      expect(
          FileStorageService.legacyAvatarPath(
              'PHR/9cc08c7d/protected/profile/u1/avatar/x.png'),
          isNull);
      expect(FileStorageService.legacyAvatarPath('https://cdn.example.com/a.png'),
          isNull);
      expect(FileStorageService.legacyAvatarPath('avatars/'), isNull);
    });

    test('avatars bucket is treated as private', () {
      expect(StorageBuckets.isPrivate(StorageBuckets.legacyAvatars), isTrue);
    });
  });
}

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../platform/platform_context.dart';
import '../tenant/tenant_service.dart';
import '../user/profile_service.dart';
import '../user/user_profile.dart';
import '../utils/logger.dart';

/// Storage yükleme bağlamı — çözülmüş `platformCode`/`tenant`/`org`.
class _StorageContext {
  final String platformCode;
  final String? tenantId;
  final String? organizationId;

  const _StorageContext({
    required this.platformCode,
    required this.tenantId,
    required this.organizationId,
  });
}

/// Dosya türleri
enum FileType {
  /// Resim dosyaları
  image('image', ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg']),

  /// Doküman dosyaları
  document('document', ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt']),

  /// Video dosyaları
  video('video', ['mp4', 'mov', 'avi', 'wmv', 'webm']),

  /// Ses dosyaları
  audio('audio', ['mp3', 'wav', 'aac', 'm4a']),

  /// Diğer dosyalar
  other('other', []);

  final String value;
  final List<String> extensions;

  const FileType(this.value, this.extensions);

  /// Uzantıdan dosya türü bul
  static FileType fromExtension(String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    for (final type in FileType.values) {
      if (type.extensions.contains(ext)) {
        return type;
      }
    }
    return FileType.other;
  }

  /// MIME türünü al
  String getMimeType(String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    switch (this) {
      case FileType.image:
        switch (ext) {
          case 'jpg':
          case 'jpeg':
            return 'image/jpeg';
          case 'png':
            return 'image/png';
          case 'gif':
            return 'image/gif';
          case 'webp':
            return 'image/webp';
          case 'svg':
            return 'image/svg+xml';
          default:
            return 'image/*';
        }
      case FileType.document:
        switch (ext) {
          case 'pdf':
            return 'application/pdf';
          case 'doc':
            return 'application/msword';
          case 'docx':
            return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
          case 'xls':
            return 'application/vnd.ms-excel';
          case 'xlsx':
            return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          case 'txt':
            return 'text/plain';
          default:
            return 'application/octet-stream';
        }
      case FileType.video:
        switch (ext) {
          case 'mp4':
            return 'video/mp4';
          case 'mov':
            return 'video/quicktime';
          case 'webm':
            return 'video/webm';
          default:
            return 'video/*';
        }
      case FileType.audio:
        switch (ext) {
          case 'mp3':
            return 'audio/mpeg';
          case 'wav':
            return 'audio/wav';
          case 'm4a':
            return 'audio/mp4';
          default:
            return 'audio/*';
        }
      case FileType.other:
        return 'application/octet-stream';
    }
  }
}

/// Yükleme ilerlemesi
class UploadProgress {
  /// Yüklenen byte
  final int bytesUploaded;

  /// Toplam byte
  final int totalBytes;

  /// İlerleme yüzdesi (0-100)
  double get percentage =>
      totalBytes > 0 ? (bytesUploaded / totalBytes * 100) : 0;

  /// Tamamlandı mı?
  bool get isComplete => bytesUploaded >= totalBytes;

  const UploadProgress({
    required this.bytesUploaded,
    required this.totalBytes,
  });

  @override
  String toString() =>
      'UploadProgress(${percentage.toStringAsFixed(1)}%, $bytesUploaded/$totalBytes)';
}

/// Dosya meta bilgisi
class StorageFileInfo {
  /// Dosya adı
  final String name;

  /// Tam yol
  final String path;

  /// Bucket adı
  final String bucket;

  /// Dosya boyutu (byte)
  final int? size;

  /// MIME türü
  final String? mimeType;

  /// Oluşturulma zamanı
  final DateTime? createdAt;

  /// Güncellenme zamanı
  final DateTime? updatedAt;

  /// Public URL
  final String? publicUrl;

  /// Dosya türü
  FileType get fileType {
    final extension = name.split('.').last;
    return FileType.fromExtension(extension);
  }

  /// Dosya uzantısı
  String get extension => name.split('.').last.toLowerCase();

  StorageFileInfo({
    required this.name,
    required this.path,
    required this.bucket,
    this.size,
    this.mimeType,
    this.createdAt,
    this.updatedAt,
    this.publicUrl,
  });

  factory StorageFileInfo.fromSupabase(FileObject file, String bucket) {
    return StorageFileInfo(
      name: file.name,
      path: file.name,
      bucket: bucket,
      size: file.metadata?['size'] as int?,
      mimeType: file.metadata?['mimetype'] as String?,
      createdAt: file.createdAt != null ? DateTime.parse(file.createdAt!) : null,
      updatedAt: file.updatedAt != null ? DateTime.parse(file.updatedAt!) : null,
    );
  }

  /// Boyutu formatla
  String get formattedSize {
    if (size == null) return '-';
    if (size! < 1024) return '$size B';
    if (size! < 1024 * 1024) return '${(size! / 1024).toStringAsFixed(1)} KB';
    if (size! < 1024 * 1024 * 1024) {
      return '${(size! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size! / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  String toString() => 'StorageFileInfo(name: $name, path: $path, size: $formattedSize)';
}

/// Yükleme sonucu
class UploadResult {
  /// Başarılı mı?
  final bool success;

  /// Dosya yolu
  final String? path;

  /// Public URL
  final String? publicUrl;

  /// Signed URL
  final String? signedUrl;

  /// Hata mesajı
  final String? error;

  /// Dosya bilgisi
  final StorageFileInfo? fileInfo;

  const UploadResult({
    required this.success,
    this.path,
    this.publicUrl,
    this.signedUrl,
    this.error,
    this.fileInfo,
  });

  factory UploadResult.success({
    required String path,
    String? publicUrl,
    String? signedUrl,
    StorageFileInfo? fileInfo,
  }) {
    return UploadResult(
      success: true,
      path: path,
      publicUrl: publicUrl,
      signedUrl: signedUrl,
      fileInfo: fileInfo,
    );
  }

  factory UploadResult.failure(String error) {
    return UploadResult(
      success: false,
      error: error,
    );
  }
}

/// Storage erişim düzeyi (web `StorageAccessLevel` ile birebir).
///
/// Her düzey tek bir GERÇEK bucket'a ve bir yol şemasına eşlenir:
/// - [public]    → `platform-public`    (CDN, `getPublicUrl`)
/// - [protected] → `platform-protected` (authenticated, `createSignedUrl`)
/// - [private]   → `platform-private`   (tenant/org-scoped, `createSignedUrl`)
enum StorageAccessLevel {
  /// Herkese açık — `platform-public`, imzasız CDN URL.
  public,

  /// Oturum açmış kullanıcı — `platform-protected`, imzalı URL.
  protected,

  /// Tenant/org-scoped — `platform-private`, imzalı URL.
  private,
}

/// Storage kategorisi (web `StorageCategory` union'ı ile BİREBİR string'ler).
///
/// Yol şemalarındaki `{category}` segmenti bu [value]'lardan gelir. Web ile
/// aynı string set → platformlar arası dosya organizasyonu tutarlı.
enum StorageCategory {
  bugReport('bug-report'),
  avatar('avatar'),
  platformAsset('platform-asset'),
  document('document'),
  image('image'),
  logo('logo'),
  banner('banner'),
  icon('icon'),
  firmware('firmware'),
  datasheet('datasheet'),
  certificate('certificate'),
  manual('manual'),
  formAttachment('form-attachment');

  /// Yol segmentinde kullanılan ham string (web ile aynı).
  final String value;

  const StorageCategory(this.value);
}

/// Supabase Storage Bucket'ları — CANLI web kontratı (3 gerçek bucket).
///
/// Web uygulaması TÜM yeni yüklemeleri bu üç bucket'a yazar
/// (`libs/core/services/.../storage.service.ts` → `StorageBucket` union'ı):
/// `platform-public` (public), `platform-protected` + `platform-private`
/// (ikisi de `public=false` → imzalı URL gerektirir).
///
/// NOT: CANLI `storage.buckets` tablosunda legacy public bucket'lar (`avatars`,
/// `site-images`, …) hâlâ vardır ama web'in AKTİF yazım hedefi bu üçüdür; mobil
/// de aynı hedeflere yazar ki dosyalar platformlar arası okunabilsin.
class StorageBuckets {
  /// Public CDN bucket — imzasız `getPublicUrl`.
  static const String platformPublic = 'platform-public';

  /// Protected bucket — web'in avatar/protected asset'leri burada
  /// (`<PLATFORM>/protected/<category>/…`), signed-URL ile okunur.
  static const String platformProtected = 'platform-protected';

  /// Private bucket — tenant/org hiyerarşisi
  /// (`<PLATFORM>/<tenant>/<org>/<category>/…`), signed-URL ile okunur.
  static const String platformPrivate = 'platform-private';

  /// İmzalı URL gerektiren (private) bucket'lar — `getPublicUrl` bunlarda 403.
  static const Set<String> private = {
    platformProtected,
    platformPrivate,
  };

  /// Bu bucket imzalı URL mi gerektiriyor?
  static bool isPrivate(String bucket) => private.contains(bucket);

  /// Erişim düzeyi → gerçek bucket adı.
  static String forAccess(StorageAccessLevel access) {
    switch (access) {
      case StorageAccessLevel.public:
        return platformPublic;
      case StorageAccessLevel.protected:
        return platformProtected;
      case StorageAccessLevel.private:
        return platformPrivate;
    }
  }
}

/// Dosya Depolama Servisi
///
/// Supabase Storage ile dosya yükleme/indirme işlemleri. Yüklemeler CANLI web
/// kontratının 3-bucket modeline (`platform-public`/`protected`/`private`) ve
/// web `StorageService` yol şemalarına hizalanmıştır → mobilde yüklenen dosya
/// web'de, web'de yüklenen dosya mobilde okunabilir.
///
/// `platformCode`/`tenant`/`org` bağlamı DI ile enjekte edilen
/// [PlatformContext] / [TenantService] / [ProfileService]'ten ÇÖZÜLÜR — çağıran
/// bunları geçmez.
///
/// Örnek kullanım:
/// ```dart
/// final storageService = sl<FileStorageService>();
///
/// // Avatar yükle (protected + category:avatar)
/// final result = await storageService.uploadAvatar(
///   userId: currentUserId,
///   file: imageFile,
/// );
///
/// // Genel dosya yükle (kategori + görünürlük ile)
/// final doc = await storageService.uploadFile(
///   file: pdfFile,
///   category: StorageCategory.document,
///   access: StorageAccessLevel.private,
/// );
///
/// if (result.success) {
///   // protected/private → signedUrl; public → publicUrl
///   print('URL: ${result.signedUrl ?? result.publicUrl}');
/// }
/// ```
class FileStorageService {
  final SupabaseClient _supabase;

  /// Aktif platform kodu kaynağı (PMS/CRM/…). null → varsayılan `PMS`.
  final PlatformContext? _platformContext;

  /// Aktif tenant kaynağı (private yol hiyerarşisi için).
  final TenantService? _tenantService;

  /// Aktif organizasyon kaynağı (private yol hiyerarşisi için) — profilden.
  final ProfileService? _profileService;

  // Varsayılan ayarlar
  static const int maxFileSizeMB = 50;
  static const Duration signedUrlExpiry = Duration(hours: 1);

  /// Platform kodu çözülemezse kullanılacak varsayılan (tek tam-kurulu platform).
  static const String _defaultPlatformCode = 'PMS';

  /// PMS platform UUID — `PlatformContext.activePlatformId` yoksa
  /// `storage_objects.platform_id` için fallback.
  static const String _pmsPlatformId = 'f0113c6e-8000-4298-a07c-0fd90e406a7a';

  /// Registry tablosu — protected/private SELECT RLS bunu metadata olarak
  /// kontrol eder; kayıt olmadan `createSignedUrl` 403 döner.
  static const String _registryTable = 'storage_objects';

  FileStorageService({
    required SupabaseClient supabase,
    PlatformContext? platformContext,
    TenantService? tenantService,
    ProfileService? profileService,
  })  : _supabase = supabase,
        _platformContext = platformContext,
        _tenantService = tenantService,
        _profileService = profileService;

  // ============================================
  // CONTEXT RESOLUTION (platformCode / tenant / org)
  // ============================================

  /// `platformCode`/`tenantId`/`organizationId` bağlamını enjekte edilen
  /// kaynaklardan çöz. Web `StorageService` `ctx` ile aynı üç değer.
  ///
  /// - platformCode: [PlatformContext.activePlatformCode] (null → `PMS`).
  /// - tenantId: [TenantService.currentTenantId] → yoksa profilin `tenantId`'si.
  /// - organizationId: profilin `organizationId`'si (staffs'tan türetilmiş).
  Future<_StorageContext> _resolveContext() async {
    final platformCode =
        _platformContext?.activePlatformCode ?? _defaultPlatformCode;

    UserProfile? profile;
    if (_profileService != null) {
      try {
        profile = await _profileService.getCurrentProfile();
      } catch (e) {
        Logger.debug('Storage context: profile resolve failed: $e');
      }
    }

    final tenantId = _tenantService?.currentTenantId ?? profile?.tenantId;
    final organizationId = profile?.organizationId;

    return _StorageContext(
      platformCode: platformCode,
      tenantId: tenantId,
      organizationId: organizationId,
    );
  }

  // ============================================
  // PATH BUILDERS (web `StorageService` ile birebir)
  // ============================================

  /// Rastgele benzersiz token (web `generateUUID` — v4). Yol `{unique}` segmenti.
  static final Random _rnd = Random();
  String _generateUnique() {
    const hex = '0123456789abcdef';
    final b = StringBuffer();
    for (var i = 0; i < 32; i++) {
      // 13. konum '4', 17. konum 8-b (v4 varyantı) — web ile aynı desen.
      if (i == 12) {
        b.write('4');
      } else if (i == 16) {
        b.write(hex[8 + _rnd.nextInt(4)]);
      } else {
        b.write(hex[_rnd.nextInt(16)]);
      }
      if (i == 7 || i == 11 || i == 15 || i == 19) b.write('-');
    }
    return b.toString();
  }

  /// Web `safeName` — güvensiz karakterleri `_` yap (`[^a-zA-Z0-9._-]`).
  String _safeName(String fileName) =>
      fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

  /// public: `{platformCode}/assets/{category}/{unique}-{safeName}`
  String buildPublicPath({
    required String fileName,
    required StorageCategory category,
    required String platformCode,
  }) {
    return '$platformCode/assets/${category.value}/${_generateUnique()}-${_safeName(fileName)}';
  }

  /// protected: `{platformCode}/{tenant}/protected/{category}/{unique}-{safeName}`
  /// (entity scoping ile:
  /// `{platformCode}/{tenant}/protected/{entityType}/{entityId}/{category}/…`)
  ///
  /// CANLI `profiles.avatar_url` örneklerinden doğrulanan kanonik şema tenant
  /// segmentini İÇERİR (tenant-less biçim yalnız eski PTB satırlarında). tenant
  /// fallback `_unknown`. Okuma `getAvatarUrl`/`isStoragePath` ile uyumlu
  /// (regex'teki opsiyonel `(?:[^/]+/)?` = tenant segmenti).
  String buildProtectedPath({
    required String fileName,
    required StorageCategory category,
    required String platformCode,
    String? tenantId,
    String? entityType,
    String? entityId,
  }) {
    final tenant = (tenantId != null && tenantId.isNotEmpty)
        ? tenantId
        : '_unknown';
    final unique = _generateUnique();
    final safe = _safeName(fileName);
    if (entityType != null &&
        entityType.isNotEmpty &&
        entityId != null &&
        entityId.isNotEmpty) {
      return '$platformCode/$tenant/protected/$entityType/$entityId/${category.value}/$unique-$safe';
    }
    return '$platformCode/$tenant/protected/${category.value}/$unique-$safe';
  }

  /// private: `{platformCode}/{tenant}/{org}/{category}/{unique}-{safeName}`
  /// (tenant fallback `_unknown`, org fallback `_tenant` — web ile birebir)
  String buildPrivatePath({
    required String fileName,
    required StorageCategory category,
    required String platformCode,
    String? tenantId,
    String? organizationId,
  }) {
    final tenant = (tenantId != null && tenantId.isNotEmpty)
        ? tenantId
        : '_unknown';
    final org = (organizationId != null && organizationId.isNotEmpty)
        ? organizationId
        : '_tenant';
    return '$platformCode/$tenant/$org/${category.value}/${_generateUnique()}-${_safeName(fileName)}';
  }

  /// Erişim düzeyine göre yol kur (bağlam çözülmüş olmalı).
  String _pathFor({
    required StorageAccessLevel access,
    required StorageCategory category,
    required String fileName,
    required _StorageContext ctx,
    String? tenantId,
    String? organizationId,
    String? entityType,
    String? entityId,
  }) {
    switch (access) {
      case StorageAccessLevel.public:
        return buildPublicPath(
          fileName: fileName,
          category: category,
          platformCode: ctx.platformCode,
        );
      case StorageAccessLevel.protected:
        return buildProtectedPath(
          fileName: fileName,
          category: category,
          platformCode: ctx.platformCode,
          tenantId: tenantId ?? ctx.tenantId,
          entityType: entityType,
          entityId: entityId,
        );
      case StorageAccessLevel.private:
        return buildPrivatePath(
          fileName: fileName,
          category: category,
          platformCode: ctx.platformCode,
          tenantId: tenantId ?? ctx.tenantId,
          organizationId: organizationId ?? ctx.organizationId,
        );
    }
  }

  /// Yüklenen yol için okuma URL'i (public → publicUrl; aksi → signedUrl).
  Future<UploadResult> _resultFor({
    required String bucket,
    required String storedPath,
    required StorageAccessLevel access,
  }) async {
    if (access == StorageAccessLevel.public) {
      final url = _supabase.storage.from(bucket).getPublicUrl(storedPath);
      return UploadResult.success(path: storedPath, publicUrl: url);
    }
    final signed = await getSignedUrl(bucket: bucket, path: storedPath);
    return UploadResult.success(path: storedPath, signedUrl: signed);
  }

  /// `storage_objects` registry satırı ekle (web `StorageService.recordObject`
  /// ile birebir). protected/private SELECT RLS bu tabloyu kontrol eder →
  /// KAYIT ŞART; aksi halde `createSignedUrl` yükleyen için bile 403 döner.
  ///
  /// Başarısız olursa fırlatır (obje yüklendi ama okunamaz = orphan) — çağıran
  /// upload metodu yakalayıp [UploadResult.failure] döndürür (web throw davranışı).
  Future<void> _recordObject({
    required String bucket,
    required String storagePath,
    required String fileName,
    required int fileSize,
    required String? mimeType,
    required StorageCategory category,
    required StorageAccessLevel access,
    required String? tenantId,
    required String? organizationId,
    String? entityType,
    String? entityId,
    String? siteId,
    String? providerId,
    String? controllerId,
  }) async {
    final isPublic = access == StorageAccessLevel.public;
    final row = <String, dynamic>{
      'platform_id': _platformContext?.activePlatformId ?? _pmsPlatformId,
      'tenant_id': tenantId,
      'organization_id': organizationId,
      'site_id': siteId,
      'provider_id': providerId,
      'controller_id': controllerId,
      // RLS okumasının geçmesi için ŞART (so.uploaded_by = auth.uid()).
      'uploaded_by': _supabase.auth.currentUser?.id,
      'bucket': bucket,
      'storage_path': storagePath,
      'public_url':
          isPublic ? _supabase.storage.from(bucket).getPublicUrl(storagePath) : null,
      'file_name': fileName,
      'file_size': fileSize,
      'mime_type': mimeType,
      'category': category.value,
      'entity_type': entityType,
      'entity_id': entityId,
      'access_level': access.name, // 'public' | 'protected' | 'private'
      'is_public': isPublic,
    };

    await _supabase.from(_registryTable).insert(row).select('id').single();
    Logger.info('Storage object registered: $bucket/$storagePath');
  }

  // ============================================
  // UPLOAD
  // ============================================

  /// Dosya yükle (File) — kategori + görünürlük ile 3-bucket modeline yönlendirir.
  ///
  /// Bucket ve yol, [access]/[category] + enjekte edilen bağlamdan türetilir;
  /// çağıran ham bucket/path geçmez (web `StorageService.upload*` ile aynı model).
  Future<UploadResult> uploadFile({
    required File file,
    required StorageCategory category,
    StorageAccessLevel access = StorageAccessLevel.private,
    String? fileName,
    String? contentType,
    String? tenantId,
    String? organizationId,
    String? entityType,
    String? entityId,
    String? siteId,
    String? providerId,
    String? controllerId,
  }) async {
    try {
      final fileSize = await file.length();
      if (fileSize > maxFileSizeMB * 1024 * 1024) {
        return UploadResult.failure(
          'Dosya boyutu ${maxFileSizeMB}MB\'dan büyük olamaz',
        );
      }

      final name = fileName ?? file.path.split('/').last;
      final extension = name.split('.').last;
      final mimeType =
          contentType ?? FileType.fromExtension(extension).getMimeType(extension);

      final ctx = await _resolveContext();
      final effTenant = tenantId ?? ctx.tenantId;
      final effOrg = organizationId ?? ctx.organizationId;
      final bucket = StorageBuckets.forAccess(access);
      final path = _pathFor(
        access: access,
        category: category,
        fileName: name,
        ctx: ctx,
        tenantId: effTenant,
        organizationId: effOrg,
        entityType: entityType,
        entityId: entityId,
      );

      // TODO(storage-quota): web upload öncesi tenant depolama kotasını RPC ile
      // REZERVE eder (+ hata halinde serbest bırakır). Mobil yüklemeler şu an bu
      // rezervasyonu ATLIYOR → tenant storage-budget gate'i bypass ediliyor.
      await _supabase.storage.from(bucket).upload(
            path,
            file,
            fileOptions: FileOptions(contentType: mimeType, upsert: true),
          );
      Logger.info('File uploaded: $bucket/$path');

      return _registerOrCleanup(
        bucket: bucket,
        path: path,
        fileName: name,
        fileSize: fileSize,
        mimeType: mimeType,
        category: category,
        access: access,
        tenantId: effTenant,
        organizationId: effOrg,
        entityType: entityType,
        entityId: entityId,
        siteId: siteId,
        providerId: providerId,
        controllerId: controllerId,
      );
    } catch (e) {
      Logger.error('Failed to upload file: $e');
      return UploadResult.failure(e.toString());
    }
  }

  /// Yüklenen objeyi registry'e kaydet; başarısız olursa orphan objeyi
  /// best-effort sil ve [UploadResult.failure] döndür (obje okunamaz olurdu).
  Future<UploadResult> _registerOrCleanup({
    required String bucket,
    required String path,
    required String fileName,
    required int fileSize,
    required String? mimeType,
    required StorageCategory category,
    required StorageAccessLevel access,
    required String? tenantId,
    required String? organizationId,
    String? entityType,
    String? entityId,
    String? siteId,
    String? providerId,
    String? controllerId,
  }) async {
    try {
      await _recordObject(
        bucket: bucket,
        storagePath: path,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
        category: category,
        access: access,
        tenantId: tenantId,
        organizationId: organizationId,
        entityType: entityType,
        entityId: entityId,
        siteId: siteId,
        providerId: providerId,
        controllerId: controllerId,
      );
    } catch (e) {
      Logger.error('Storage registry insert failed → removing orphan object: $e');
      try {
        await _supabase.storage.from(bucket).remove([path]);
      } catch (_) {}
      return UploadResult.failure('Storage registry insert failed: $e');
    }
    return _resultFor(bucket: bucket, storedPath: path, access: access);
  }

  /// Dosya yükle (Bytes) — kategori + görünürlük ile 3-bucket modeline yönlendirir.
  Future<UploadResult> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    required StorageCategory category,
    StorageAccessLevel access = StorageAccessLevel.private,
    String? contentType,
    String? tenantId,
    String? organizationId,
    String? entityType,
    String? entityId,
    String? siteId,
    String? providerId,
    String? controllerId,
  }) async {
    try {
      if (bytes.length > maxFileSizeMB * 1024 * 1024) {
        return UploadResult.failure(
          'Dosya boyutu ${maxFileSizeMB}MB\'dan büyük olamaz',
        );
      }

      final extension = fileName.split('.').last;
      final mimeType =
          contentType ?? FileType.fromExtension(extension).getMimeType(extension);

      final ctx = await _resolveContext();
      final effTenant = tenantId ?? ctx.tenantId;
      final effOrg = organizationId ?? ctx.organizationId;
      final bucket = StorageBuckets.forAccess(access);
      final path = _pathFor(
        access: access,
        category: category,
        fileName: fileName,
        ctx: ctx,
        tenantId: effTenant,
        organizationId: effOrg,
        entityType: entityType,
        entityId: entityId,
      );

      // TODO(storage-quota): mobil yüklemeler tenant storage-budget rezervasyonunu
      // (web upload-öncesi RPC) ATLIYOR — bkz. uploadFile.
      await _supabase.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: true),
          );
      Logger.info('File uploaded (bytes): $bucket/$path');

      return _registerOrCleanup(
        bucket: bucket,
        path: path,
        fileName: fileName,
        fileSize: bytes.length,
        mimeType: mimeType,
        category: category,
        access: access,
        tenantId: effTenant,
        organizationId: effOrg,
        entityType: entityType,
        entityId: entityId,
        siteId: siteId,
        providerId: providerId,
        controllerId: controllerId,
      );
    } catch (e) {
      Logger.error('Failed to upload bytes: $e');
      return UploadResult.failure(e.toString());
    }
  }

  /// Avatar yükle → PROTECTED bucket, kategori `avatar`, entity-scoped:
  /// `{platformCode}/{tenant}/protected/profile/{userId}/avatar/{unique}-{file}`.
  ///
  /// CANLI `profiles.avatar_url` örneklerinden doğrulanan kanonik web şeması ile
  /// birebir (entity_type=`profile`, entity_id=`userId`) → foto web↔mobil
  /// karşılıklı okunabilir. Dönen [UploadResult.path]'i `profiles.avatar_url`
  /// olarak sakla; okumak için [getAvatarUrl] kullan.
  Future<UploadResult> uploadAvatar({
    required String userId,
    required File file,
  }) async {
    return uploadFile(
      file: file,
      category: StorageCategory.avatar,
      access: StorageAccessLevel.protected,
      entityType: 'profile',
      entityId: userId,
    );
  }

  /// Organizasyon dosyası yükle → PRIVATE bucket, kategori `document`
  /// (`{platformCode}/{tenant}/{organizationId}/document/{unique}-{file}`).
  ///
  /// [organizationId] açıkça geçilir ve private yol hiyerarşisinin org
  /// segmentini geçersiz kılar (çözülen bağlam yerine).
  Future<UploadResult> uploadOrganizationFile({
    required String organizationId,
    required String fileName,
    required File file,
  }) async {
    // TODO(storage): web'de org-belgeleri için ayrı bir kategori yok →
    // en yakın eşleşme `document`. Bir resim yükleniyorsa çağıran
    // `uploadFile(category: StorageCategory.image, ...)` tercih edebilir.
    return uploadFile(
      file: file,
      category: StorageCategory.document,
      access: StorageAccessLevel.private,
      fileName: fileName,
      organizationId: organizationId,
    );
  }

  // ============================================
  // DOWNLOAD
  // ============================================

  /// Dosya indir (Bytes)
  Future<Uint8List?> downloadFile({
    required String bucket,
    required String path,
  }) async {
    try {
      final response = await _supabase.storage.from(bucket).download(path);
      Logger.info('File downloaded: $bucket/$path');
      return response;
    } catch (e) {
      Logger.error('Failed to download file: $e');
      return null;
    }
  }

  /// Dosyayı locale kaydet
  Future<File?> downloadToFile({
    required String bucket,
    required String path,
    required String localPath,
  }) async {
    try {
      final bytes = await downloadFile(bucket: bucket, path: path);
      if (bytes == null) return null;

      final file = File(localPath);
      await file.writeAsBytes(bytes);

      Logger.info('File saved: $localPath');
      return file;
    } catch (e) {
      Logger.error('Failed to save file: $e');
      return null;
    }
  }

  // ============================================
  // URLs
  // ============================================

  /// Public URL al
  String getPublicUrl({
    required String bucket,
    required String path,
  }) {
    return _supabase.storage.from(bucket).getPublicUrl(path);
  }

  /// Web `profiles.avatar_url` değeri PLATFORM-PROTECTED bir storage path'idir
  /// (`<PLATFORM>/<tenant>/protected/avatars/…`). `getPublicUrl` 403 döner →
  /// `platform-protected` bucket'ından signed-URL üretilir. Web
  /// `ProfileService.getAvatarUrl` + `StorageService.getProtectedUrl` ile birebir
  /// aynı davranış (platformlar arası foto tutarlılığı için ŞART).
  ///
  /// [raw] `profiles.avatar_url` değeri. null/boş → null; tam http(s) URL ya da
  /// storage-path olmayan bir değer → aynen döner.
  /// Avatar signed-URL oturum-içi memo cache (raw path → url + üretim zamanı).
  /// Liste ekranlarında aynı kişi onlarca satırda tekrar eder; her satır için
  /// yeniden imzalamayı önler. ~50dk sonra yeniden imzalanır (1h expiry öncesi).
  final Map<String, ({String url, DateTime at})> _avatarUrlCache = {};

  Future<String?> getAvatarUrl(
    String? raw, {
    Duration expiry = signedUrlExpiry,
  }) async {
    if (raw == null || raw.isEmpty) return null;
    // Storage path değilse (tam URL ya da düz değer) olduğu gibi döndür — web
    // isStoragePath ile aynı: PLATFORM/(<tenant>/)?(protected|assets|private)/…
    if (!_isStoragePath(raw)) return raw;

    final cached = _avatarUrlCache[raw];
    if (cached != null &&
        DateTime.now().difference(cached.at) < const Duration(minutes: 50)) {
      return cached.url;
    }

    final signed = await getSignedUrl(
      bucket: StorageBuckets.platformProtected,
      path: raw,
      expiry: expiry,
    );
    if (signed != null && signed.isNotEmpty) {
      _avatarUrlCache[raw] = (url: signed, at: DateTime.now());
    }
    return signed;
  }

  /// Web `StorageService.isStoragePath` ile birebir: değer platform-protected
  /// bir storage path'i mi? (http(s) URL değil + `PLATFORM/(<tenant>/)?scheme/`)
  static final RegExp _storagePathRe =
      RegExp(r'^[A-Z]{2,10}\/(?:[^/]+\/)?(?:protected|assets|private)\/');
  bool _isStoragePath(String value) {
    if (value.isEmpty) return false;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return false;
    }
    return _storagePathRe.hasMatch(value);
  }

  /// Signed URL al (geçici erişim)
  Future<String?> getSignedUrl({
    required String bucket,
    required String path,
    Duration expiry = signedUrlExpiry,
  }) async {
    try {
      final response = await _supabase.storage.from(bucket).createSignedUrl(
            path,
            expiry.inSeconds,
          );
      return response;
    } catch (e) {
      Logger.error('Failed to get signed URL: $e');
      return null;
    }
  }

  /// Birden fazla signed URL al
  Future<List<SignedUrl>> getSignedUrls({
    required String bucket,
    required List<String> paths,
    Duration expiry = signedUrlExpiry,
  }) async {
    try {
      final response = await _supabase.storage.from(bucket).createSignedUrls(
            paths,
            expiry.inSeconds,
          );
      return response;
    } catch (e) {
      Logger.error('Failed to get signed URLs: $e');
      return [];
    }
  }

  // ============================================
  // DELETE
  // ============================================

  /// Dosya sil
  Future<bool> deleteFile({
    required String bucket,
    required String path,
  }) async {
    try {
      await _supabase.storage.from(bucket).remove([path]);
      Logger.info('File deleted: $bucket/$path');
      return true;
    } catch (e) {
      Logger.error('Failed to delete file: $e');
      return false;
    }
  }

  /// Birden fazla dosya sil
  Future<bool> deleteFiles({
    required String bucket,
    required List<String> paths,
  }) async {
    try {
      await _supabase.storage.from(bucket).remove(paths);
      Logger.info('Files deleted: $bucket (${paths.length} files)');
      return true;
    } catch (e) {
      Logger.error('Failed to delete files: $e');
      return false;
    }
  }

  /// Klasör sil (tüm içeriğiyle)
  Future<bool> deleteFolder({
    required String bucket,
    required String folderPath,
  }) async {
    try {
      // Klasördeki dosyaları listele
      final files = await listFiles(bucket: bucket, path: folderPath);

      if (files.isEmpty) return true;

      // Tüm dosyaları sil
      final paths = files.map((f) => '$folderPath/${f.name}').toList();
      return await deleteFiles(bucket: bucket, paths: paths);
    } catch (e) {
      Logger.error('Failed to delete folder: $e');
      return false;
    }
  }

  // ============================================
  // LIST
  // ============================================

  /// Dosyaları listele
  Future<List<StorageFileInfo>> listFiles({
    required String bucket,
    String path = '',
    int? limit,
    int? offset,
    SortBy? sortBy,
  }) async {
    try {
      final response = await _supabase.storage.from(bucket).list(
            path: path,
            searchOptions: SearchOptions(
              limit: limit,
              offset: offset,
              sortBy: sortBy,
            ),
          );

      return response
          .where((f) => f.name != '.emptyFolderPlaceholder')
          .map((f) => StorageFileInfo.fromSupabase(f, bucket))
          .toList();
    } catch (e) {
      Logger.error('Failed to list files: $e');
      return [];
    }
  }

  /// Klasörleri listele
  Future<List<String>> listFolders({
    required String bucket,
    String path = '',
  }) async {
    try {
      final response = await _supabase.storage.from(bucket).list(path: path);

      return response
          .where((f) => f.id == null) // Klasörler ID'ye sahip değil
          .map((f) => f.name)
          .toList();
    } catch (e) {
      Logger.error('Failed to list folders: $e');
      return [];
    }
  }

  // ============================================
  // MOVE & COPY
  // ============================================

  /// Dosyayı taşı
  Future<bool> moveFile({
    required String bucket,
    required String fromPath,
    required String toPath,
  }) async {
    try {
      await _supabase.storage.from(bucket).move(fromPath, toPath);
      Logger.info('File moved: $fromPath -> $toPath');
      return true;
    } catch (e) {
      Logger.error('Failed to move file: $e');
      return false;
    }
  }

  /// Dosyayı kopyala
  Future<bool> copyFile({
    required String bucket,
    required String fromPath,
    required String toPath,
  }) async {
    try {
      await _supabase.storage.from(bucket).copy(fromPath, toPath);
      Logger.info('File copied: $fromPath -> $toPath');
      return true;
    } catch (e) {
      Logger.error('Failed to copy file: $e');
      return false;
    }
  }

  // ============================================
  // HELPERS
  // ============================================

  /// Dosya var mı kontrol et
  Future<bool> fileExists({
    required String bucket,
    required String path,
  }) async {
    try {
      // Dosyayı indirmeye çalış (HEAD request yok)
      final folderPath = path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : '';
      final fileName = path.contains('/') ? path.substring(path.lastIndexOf('/') + 1) : path;

      final files = await listFiles(bucket: bucket, path: folderPath);
      return files.any((f) => f.name == fileName);
    } catch (e) {
      return false;
    }
  }

  /// Benzersiz dosya adı oluştur
  String generateUniqueFileName(String originalName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = originalName.split('.').last;
    final baseName = originalName.replaceAll('.$extension', '');
    return '${baseName}_$timestamp.$extension';
  }

  /// Dosya adını temizle
  String sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[^\w\s\-\.]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }
}

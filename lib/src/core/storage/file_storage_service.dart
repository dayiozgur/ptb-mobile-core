import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';

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

/// Supabase Storage Bucket'ları
class StorageBuckets {
  /// Avatar resimleri
  static const String avatars = 'avatars';

  /// Organizasyon dosyaları
  static const String organizations = 'organization-files';

  /// Site dosyaları
  static const String sites = 'site-files';

  /// Unit dosyaları
  static const String units = 'unit-files';

  /// Dokümanlar
  static const String documents = 'documents';

  /// Geçici dosyalar
  static const String temp = 'temp';
}

/// Dosya Depolama Servisi
///
/// Supabase Storage ile dosya yükleme/indirme işlemleri.
///
/// Örnek kullanım:
/// ```dart
/// final storageService = FileStorageService(supabase: Supabase.instance.client);
///
/// // Dosya yükle
/// final result = await storageService.uploadFile(
///   bucket: StorageBuckets.avatars,
///   path: 'user-123/avatar.png',
///   file: imageFile,
/// );
///
/// if (result.success) {
///   print('URL: ${result.publicUrl}');
/// }
///
/// // Dosya indir
/// final bytes = await storageService.downloadFile(
///   bucket: StorageBuckets.avatars,
///   path: 'user-123/avatar.png',
/// );
/// ```
class FileStorageService {
  final SupabaseClient _supabase;

  // Varsayılan ayarlar
  static const int maxFileSizeMB = 50;
  static const Duration signedUrlExpiry = Duration(hours: 1);

  FileStorageService({
    required SupabaseClient supabase,
  }) : _supabase = supabase;

  // ============================================
  // UPLOAD
  // ============================================

  /// Dosya yükle (File)
  Future<UploadResult> uploadFile({
    required String bucket,
    required String path,
    required File file,
    String? contentType,
    bool upsert = true,
    void Function(UploadProgress)? onProgress,
  }) async {
    try {
      // Dosya boyutu kontrolü
      final fileSize = await file.length();
      if (fileSize > maxFileSizeMB * 1024 * 1024) {
        return UploadResult.failure(
          'Dosya boyutu ${maxFileSizeMB}MB\'dan büyük olamaz',
        );
      }

      // Uzantıdan MIME type al
      final extension = path.split('.').last;
      final fileType = FileType.fromExtension(extension);
      final mimeType = contentType ?? fileType.getMimeType(extension);

      // Yükle
      final response = await _supabase.storage.from(bucket).upload(
            path,
            file,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: upsert,
            ),
          );

      // Public URL al
      final publicUrl = _supabase.storage.from(bucket).getPublicUrl(path);

      Logger.info('File uploaded: $bucket/$path');

      return UploadResult.success(
        path: response,
        publicUrl: publicUrl,
      );
    } catch (e) {
      Logger.error('Failed to upload file: $e');
      return UploadResult.failure(e.toString());
    }
  }

  /// Dosya yükle (Bytes)
  Future<UploadResult> uploadBytes({
    required String bucket,
    required String path,
    required Uint8List bytes,
    String? contentType,
    bool upsert = true,
  }) async {
    try {
      // Boyut kontrolü
      if (bytes.length > maxFileSizeMB * 1024 * 1024) {
        return UploadResult.failure(
          'Dosya boyutu ${maxFileSizeMB}MB\'dan büyük olamaz',
        );
      }

      // Uzantıdan MIME type al
      final extension = path.split('.').last;
      final fileType = FileType.fromExtension(extension);
      final mimeType = contentType ?? fileType.getMimeType(extension);

      // Yükle
      final response = await _supabase.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: upsert,
            ),
          );

      // Public URL al
      final publicUrl = _supabase.storage.from(bucket).getPublicUrl(path);

      Logger.info('File uploaded (bytes): $bucket/$path');

      return UploadResult.success(
        path: response,
        publicUrl: publicUrl,
      );
    } catch (e) {
      Logger.error('Failed to upload bytes: $e');
      return UploadResult.failure(e.toString());
    }
  }

  /// Avatar yükle
  Future<UploadResult> uploadAvatar({
    required String userId,
    required File file,
  }) async {
    final extension = file.path.split('.').last;
    final path = '$userId/avatar.$extension';

    return uploadFile(
      bucket: StorageBuckets.avatars,
      path: path,
      file: file,
      upsert: true,
    );
  }

  /// Organizasyon dosyası yükle
  Future<UploadResult> uploadOrganizationFile({
    required String organizationId,
    required String fileName,
    required File file,
  }) async {
    final path = '$organizationId/$fileName';

    return uploadFile(
      bucket: StorageBuckets.organizations,
      path: path,
      file: file,
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

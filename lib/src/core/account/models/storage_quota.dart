/// Depolama kotası görüntü-modeli (salt-okuma).
///
/// Web `StorageService.getQuotaInfo()` ile aynı `get_storage_quota_info` RPC
/// çıktısını aynalar. Tüm alanlar bayt cinsinden `num`.
class StorageQuota {
  final num usedBytes;
  final num limitBytes;
  final num maxFileBytes;
  final num? perUserLimitBytes;
  final num perUserUsedBytes;

  const StorageQuota({
    this.usedBytes = 0,
    this.limitBytes = 0,
    this.maxFileBytes = 0,
    this.perUserLimitBytes,
    this.perUserUsedBytes = 0,
  });

  static num _n(dynamic v) => (v is num) ? v : (num.tryParse('${v ?? ''}') ?? 0);

  /// 0..1 kullanım oranı (limit > 0 ise). Aksi halde null.
  double? get usageFraction {
    if (limitBytes <= 0) return null;
    final f = usedBytes / limitBytes;
    return f < 0 ? 0 : (f > 1 ? 1 : f.toDouble());
  }

  factory StorageQuota.fromJson(Map<String, dynamic> json) {
    return StorageQuota(
      usedBytes: _n(json['used_bytes']),
      limitBytes: _n(json['limit_bytes']),
      maxFileBytes: _n(json['max_file_bytes']),
      perUserLimitBytes:
          json['per_user_limit_bytes'] == null ? null : _n(json['per_user_limit_bytes']),
      perUserUsedBytes: _n(json['per_user_used_bytes']),
    );
  }
}

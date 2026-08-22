import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/storage/file_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// **Ham storage-path'li avatar** — `profiles.avatar_url` gibi imzalanmamış bir
/// path'i signed-URL'e çevirip ([FileStorageService.getAvatarUrl]; raw=403)
/// gösterir; path yoksa/çözülemezse baş-harf rozetine düşer.
///
/// entity liste (küçük) + detay (orta) + kişi kartları için ORTAK. Önceden
/// `entity_list_screen._miniAvatar` ve `entity_detail_screen._assigneeAvatar`
/// olarak iki kez kopya edilmişti — tek çekirdek widget.
class AppStorageAvatar extends StatelessWidget {
  final String? rawPath;
  final String name;
  final double radius;

  const AppStorageAvatar({
    super.key,
    required this.rawPath,
    required this.name,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final path = rawPath;
    if (path == null || path.isEmpty) return _fallback(context);
    return FutureBuilder<String?>(
      future: sl<FileStorageService>().getAvatarUrl(path),
      builder: (context, snap) {
        final url = snap.data;
        if (url == null || url.isEmpty) return _fallback(context);
        return CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          foregroundImage: NetworkImage(url),
          child: radius >= 9 ? _initialText() : null,
        );
      },
    );
  }

  Widget _fallback(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        child: _initialText(),
      );

  Widget _initialText() {
    final initial =
        (name.trim().isNotEmpty ? name.trim().characters.first : '?')
            .toUpperCase();
    return Text(
      initial,
      style: AppTypography.caption2.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
        fontSize: radius < 9 ? 8 : null,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/map/map_models.dart';
import '../../../core/theme/app_colors.dart';

/// Site harita marker widget'ı
///
/// Site durumunu (online/offline) ve alarm badge'ini gösterir.
/// Seçili durumda büyütülmüş boyutta görünür.
class SiteMapMarker extends StatelessWidget {
  final MapMarkerData marker;
  final int alarmCount;
  final bool isSelected;
  final VoidCallback? onTap;

  const SiteMapMarker({
    super.key,
    required this.marker,
    this.alarmCount = 0,
    this.isSelected = false,
    this.onTap,
  });

  Color _statusColor() {
    switch (marker.status) {
      case MapMarkerStatus.normal:
        return AppColors.success;
      case MapMarkerStatus.warning:
        return AppColors.warning;
      case MapMarkerStatus.critical:
        return AppColors.error;
      case MapMarkerStatus.offline:
        return AppColors.systemGray;
      case MapMarkerStatus.inactive:
        return AppColors.systemGray3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = isSelected ? 44.0 : 36.0;
    final color = _statusColor();

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Marker gövdesi
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: isSelected ? 8 : 4,
                  spreadRadius: isSelected ? 2 : 0,
                ),
              ],
            ),
            child: Icon(
              Icons.location_city_rounded,
              color: Colors.white,
              size: isSelected ? 22 : 18,
            ),
          ),
          // Alarm badge
          if (alarmCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 18),
                child: Text(
                  alarmCount > 99 ? '99+' : '$alarmCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Cluster marker widget'ı
///
/// Birden fazla marker'ın tek noktada gösteriminde kullanılır.
/// Alarm varsa kırmızı ring gösterir.
class ClusterMapMarker extends StatelessWidget {
  final int count;
  final bool hasAlarms;
  final MapMarkerStatus worstStatus;

  const ClusterMapMarker({
    super.key,
    required this.count,
    this.hasAlarms = false,
    this.worstStatus = MapMarkerStatus.normal,
  });

  Color _clusterColor() {
    if (hasAlarms) return AppColors.error;
    switch (worstStatus) {
      case MapMarkerStatus.critical:
        return AppColors.error;
      case MapMarkerStatus.warning:
        return AppColors.warning;
      case MapMarkerStatus.offline:
        return AppColors.systemGray;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _clusterColor();
    final size = count > 50 ? 52.0 : (count > 10 ? 44.0 : 38.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          count > 999 ? '999+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Kullanıcı konum marker widget'ı
///
/// Mavi dot + pulsating ring animasyonu ile kullanıcı konumunu gösterir.
class UserLocationMarker extends StatefulWidget {
  const UserLocationMarker({super.key});

  @override
  State<UserLocationMarker> createState() => _UserLocationMarkerState();
}

class _UserLocationMarkerState extends State<UserLocationMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsating ring
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // Center dot
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

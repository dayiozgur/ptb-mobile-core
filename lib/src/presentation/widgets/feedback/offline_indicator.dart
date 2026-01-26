import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Offline göstergesi widget'ı
///
/// Uygulama offline olduğunda banner gösterir.
///
/// Örnek kullanım:
/// ```dart
/// OfflineIndicator(
///   connectivityService: connectivityService,
///   child: MyApp(),
/// )
/// ```
class OfflineIndicator extends StatefulWidget {
  /// Alt widget
  final Widget child;

  /// Bağlantı servisi
  final ConnectivityService connectivityService;

  /// Banner pozisyonu
  final OfflineBannerPosition position;

  /// Banner gösterimi
  final bool showBanner;

  /// Özel mesaj
  final String? message;

  /// Online olduğunda geri bildirim göster
  final bool showOnlineMessage;

  const OfflineIndicator({
    super.key,
    required this.child,
    required this.connectivityService,
    this.position = OfflineBannerPosition.top,
    this.showBanner = true,
    this.message,
    this.showOnlineMessage = true,
  });

  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  StreamSubscription? _subscription;
  bool _isOffline = false;
  bool _showingOnlineMessage = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _isOffline = widget.connectivityService.isOffline;
    if (_isOffline) {
      _controller.value = 1.0;
    }

    _subscription = widget.connectivityService.statusStream.listen((info) {
      if (mounted) {
        final wasOffline = _isOffline;
        setState(() {
          _isOffline = info.isOffline;
        });

        if (_isOffline) {
          _controller.forward();
        } else {
          if (wasOffline && widget.showOnlineMessage) {
            setState(() {
              _showingOnlineMessage = true;
            });
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                setState(() {
                  _showingOnlineMessage = false;
                });
                _controller.reverse();
              }
            });
          } else {
            _controller.reverse();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showBanner) {
      return widget.child;
    }

    final banner = SizeTransition(
      sizeFactor: _animation,
      axisAlignment: widget.position == OfflineBannerPosition.top ? 1.0 : -1.0,
      child: _OfflineBanner(
        isOffline: _isOffline,
        showingOnlineMessage: _showingOnlineMessage,
        message: widget.message,
        onRetry: () => widget.connectivityService.checkConnectivity(),
      ),
    );

    return Column(
      children: [
        if (widget.position == OfflineBannerPosition.top) banner,
        Expanded(child: widget.child),
        if (widget.position == OfflineBannerPosition.bottom) banner,
      ],
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final bool isOffline;
  final bool showingOnlineMessage;
  final String? message;
  final VoidCallback onRetry;

  const _OfflineBanner({
    required this.isOffline,
    required this.showingOnlineMessage,
    this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = showingOnlineMessage
        ? AppColors.success
        : AppColors.warning;

    final text = showingOnlineMessage
        ? 'Bağlantı kuruldu'
        : message ?? 'İnternet bağlantısı yok';

    final icon = showingOnlineMessage
        ? Icons.wifi
        : Icons.wifi_off;

    return Material(
      color: backgroundColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: AppTypography.footnote.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isOffline && !showingOnlineMessage)
                GestureDetector(
                  onTap: onRetry,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      'Tekrar Dene',
                      style: AppTypography.footnote.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Banner pozisyonu
enum OfflineBannerPosition {
  top,
  bottom,
}

/// Offline durumu için küçük ikon göstergesi
///
/// App bar veya başka bir yerde kullanılabilir.
class OfflineStatusIcon extends StatelessWidget {
  final ConnectivityService connectivityService;
  final double size;
  final Color? onlineColor;
  final Color? offlineColor;

  const OfflineStatusIcon({
    super.key,
    required this.connectivityService,
    this.size = 16,
    this.onlineColor,
    this.offlineColor,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectivityInfo>(
      stream: connectivityService.statusStream,
      initialData: connectivityService.currentInfo,
      builder: (context, snapshot) {
        final isOnline = snapshot.data?.isOnline ?? true;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            isOnline ? Icons.wifi : Icons.wifi_off,
            key: ValueKey(isOnline),
            size: size,
            color: isOnline
                ? (onlineColor ?? AppColors.success)
                : (offlineColor ?? AppColors.warning),
          ),
        );
      },
    );
  }
}

/// Senkronizasyon durumu göstergesi
///
/// Bekleyen işlem sayısını ve senkronizasyon durumunu gösterir.
class SyncStatusIndicator extends StatelessWidget {
  final int pendingCount;
  final bool isSyncing;
  final VoidCallback? onTap;

  const SyncStatusIndicator({
    super.key,
    required this.pendingCount,
    this.isSyncing = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (pendingCount == 0 && !isSyncing) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSyncing)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.warning),
                ),
              )
            else
              Icon(
                Icons.cloud_upload_outlined,
                size: 14,
                color: AppColors.warning,
              ),
            const SizedBox(width: 4),
            Text(
              isSyncing ? 'Senkronize ediliyor...' : '$pendingCount bekliyor',
              style: AppTypography.caption2.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

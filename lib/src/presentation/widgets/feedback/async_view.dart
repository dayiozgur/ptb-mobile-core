import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/localization/localization_service.dart';
import 'app_empty_state.dart';
import 'app_error_view.dart';
import 'app_loading_indicator.dart';

String _t(String key) => sl.isRegistered<LocalizationService>()
    ? sl<LocalizationService>().translate(key)
    : key;

/// [AsyncView]'i dışarıdan (ör. app-bar "yenile" aksiyonu) tazelemek için.
class AsyncViewController {
  VoidCallback? _reload;
  void reload() => _reload?.call();
}

/// **Async gövde sarmalayıcı** — bir `Future` yükler ve yükleme/hata/boş/veri
/// durumlarını tek yerde yönetir (opsiyonel pull-to-refresh). Onlarca ekran
/// bu `_isLoading/_error/setState/try-catch` kalıbını elle tekrarlıyordu;
/// tek çekirdek primitif. Ekran AppScaffold'unu + app-bar'ını korur, yalnız
/// gövdeyi [AsyncView] ile sarar.
///
/// ```dart
/// AsyncView<HrSummary>(
///   controller: _ctrl,           // app-bar yenile → _ctrl.reload()
///   load: () => service.fetch(),
///   builder: (ctx, data) => _content(data),
/// )
/// ```
class AsyncView<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;

  /// Veri boş mu? (opsiyonel) → true ise [emptyBuilder] / varsayılan boş-durum.
  final bool Function(T data)? isEmpty;
  final WidgetBuilder? emptyBuilder;
  final String? emptyTitle;
  final IconData emptyIcon;

  /// Boş-durum mesajı (ör. "İlk kaydı oluşturun").
  final String? emptyMessage;

  /// Boş-durum aksiyonu ("İlk … oluştur" CTA — web empty-state parity).
  /// [onEmptyAction] verilirse buton gösterilir.
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  /// Hata metni (verilmezse `common.load_error` çevirisi).
  final String? errorFallback;

  /// Pull-to-refresh sarmalasın mı (builder'ın kaydırılabilir olması gerekir).
  final bool pullToRefresh;

  /// Yüklenirken satır-iskeleti (skeleton) göster. Verilmezse
  /// [pullToRefresh] ile aynı (tam ekran, kaydırılabilir liste bağlamı);
  /// gömülü/kısa görünümlerde spinner kalır.
  final bool? skeleton;

  final AsyncViewController? controller;

  const AsyncView({
    super.key,
    required this.load,
    required this.builder,
    this.isEmpty,
    this.emptyBuilder,
    this.emptyTitle,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyMessage,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.errorFallback,
    this.pullToRefresh = true,
    this.skeleton,
    this.controller,
  });

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  bool _loading = true;
  Object? _error;
  T? _data;

  @override
  void initState() {
    super.initState();
    widget.controller?._reload = _load;
    _load();
  }

  @override
  void dispose() {
    if (widget.controller?._reload == _load) widget.controller?._reload = null;
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
      _loading = true;
      _error = null;
    });
    }
    try {
      final d = await widget.load();
      if (mounted) {
        setState(() {
          _data = d;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return (widget.skeleton ?? widget.pullToRefresh)
          ? const AppListSkeleton()
          : const Center(child: AppLoadingIndicator());
    }
    if (_error != null) {
      return Center(
        child: AppErrorView(
          message: widget.errorFallback ?? _t('common.load_error'),
          onRetry: _load,
        ),
      );
    }
    final data = _data as T;

    final isEmpty = widget.isEmpty?.call(data) ?? false;
    final Widget body = isEmpty
        ? (widget.emptyBuilder?.call(context) ??
            Center(
              child: AppEmptyState(
                icon: widget.emptyIcon,
                title: widget.emptyTitle ?? _t('common.no_records'),
                message: widget.emptyMessage,
                actionLabel: widget.onEmptyAction != null
                    ? (widget.emptyActionLabel ?? _t('common.create'))
                    : null,
                onAction: widget.onEmptyAction,
              ),
            ))
        : widget.builder(context, data);

    if (!widget.pullToRefresh) return body;
    return RefreshIndicator(onRefresh: () => _load(silent: true), child: body);
  }
}

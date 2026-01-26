import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Protoolbag Scaffold Widget
///
/// Apple HIG uyumlu, özelleştirilebilir scaffold komponenti.
///
/// Örnek kullanım:
/// ```dart
/// AppScaffold(
///   title: 'Home',
///   child: ListView(...),
/// )
/// ```
class AppScaffold extends StatelessWidget {
  /// Sayfa başlığı
  final String? title;

  /// Özel başlık widget'ı
  final Widget? titleWidget;

  /// İçerik
  final Widget child;

  /// AppBar göster
  final bool showAppBar;

  /// AppBar leading widget
  final Widget? leading;

  /// AppBar actions
  final List<Widget>? actions;

  /// Back button göster
  final bool showBackButton;

  /// Back button callback
  final VoidCallback? onBack;

  /// Floating action button
  final Widget? floatingActionButton;

  /// FAB location
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// Bottom navigation bar
  final Widget? bottomNavigationBar;

  /// Bottom sheet
  final Widget? bottomSheet;

  /// Drawer
  final Widget? drawer;

  /// End drawer
  final Widget? endDrawer;

  /// Background color
  final Color? backgroundColor;

  /// AppBar background color
  final Color? appBarBackgroundColor;

  /// Safe area - bottom
  final bool safeAreaBottom;

  /// Safe area - top (AppBar zaten handle eder)
  final bool safeAreaTop;

  /// Resizable to avoid bottom inset (keyboard)
  final bool resizeToAvoidBottomInset;

  /// Large title style (iOS gibi)
  final bool useLargeTitle;

  /// AppBar elevation
  final double? appBarElevation;

  /// AppBar center title
  final bool centerTitle;

  const AppScaffold({
    super.key,
    this.title,
    this.titleWidget,
    required this.child,
    this.showAppBar = true,
    this.leading,
    this.actions,
    this.showBackButton = true,
    this.onBack,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.drawer,
    this.endDrawer,
    this.backgroundColor,
    this.appBarBackgroundColor,
    this.safeAreaBottom = true,
    this.safeAreaTop = false,
    this.resizeToAvoidBottomInset = true,
    this.useLargeTitle = false,
    this.appBarElevation,
    this.centerTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.background(brightness),
      appBar: showAppBar ? _buildAppBar(context, brightness) : null,
      body: safeAreaBottom || safeAreaTop
          ? SafeArea(
              top: safeAreaTop,
              bottom: safeAreaBottom,
              child: child,
            )
          : child,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
      drawer: drawer,
      endDrawer: endDrawer,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, Brightness brightness) {
    final canPop = Navigator.of(context).canPop();
    final showBack = showBackButton && canPop;

    return AppBar(
      backgroundColor:
          appBarBackgroundColor ?? AppColors.surface(brightness),
      elevation: appBarElevation ?? 0,
      scrolledUnderElevation: 0.5,
      centerTitle: centerTitle,
      systemOverlayStyle: brightness == Brightness.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      leading: leading ??
          (showBack
              ? IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  onPressed: onBack ?? () => Navigator.of(context).pop(),
                )
              : null),
      title: titleWidget ??
          (title != null
              ? Text(
                  title!,
                  style: AppTypography.headline.copyWith(
                    color: AppColors.textPrimary(brightness),
                  ),
                )
              : null),
      actions: actions,
    );
  }
}

/// Sliver AppBar ile Scaffold
class AppSliverScaffold extends StatelessWidget {
  /// Başlık
  final String title;

  /// Sliver içerikleri
  final List<Widget> slivers;

  /// Expanded height
  final double expandedHeight;

  /// Floating
  final bool floating;

  /// Pinned
  final bool pinned;

  /// Snap
  final bool snap;

  /// FlexibleSpaceBar background
  final Widget? background;

  /// Actions
  final List<Widget>? actions;

  /// Bottom navigation bar
  final Widget? bottomNavigationBar;

  /// FAB
  final Widget? floatingActionButton;

  const AppSliverScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.expandedHeight = 120,
    this.floating = false,
    this.pinned = true,
    this.snap = false,
    this.background,
    this.actions,
    this.bottomNavigationBar,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppColors.background(brightness),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: expandedHeight,
            floating: floating,
            pinned: pinned,
            snap: snap,
            backgroundColor: AppColors.surface(brightness),
            foregroundColor: AppColors.textPrimary(brightness),
            actions: actions,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                title,
                style: AppTypography.headline.copyWith(
                  color: AppColors.textPrimary(brightness),
                ),
              ),
              background: background,
              centerTitle: true,
              titlePadding: const EdgeInsets.only(bottom: 16),
            ),
          ),
          ...slivers,
        ],
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Tab ile Scaffold
class AppTabScaffold extends StatelessWidget {
  /// Başlık
  final String? title;

  /// Tab'lar
  final List<Tab> tabs;

  /// Tab içerikleri
  final List<Widget> tabViews;

  /// Initial index
  final int initialIndex;

  /// Tab değiştiğinde
  final ValueChanged<int>? onTabChanged;

  /// Actions
  final List<Widget>? actions;

  /// Bottom navigation bar
  final Widget? bottomNavigationBar;

  const AppTabScaffold({
    super.key,
    this.title,
    required this.tabs,
    required this.tabViews,
    this.initialIndex = 0,
    this.onTabChanged,
    this.actions,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return DefaultTabController(
      length: tabs.length,
      initialIndex: initialIndex,
      child: Scaffold(
        backgroundColor: AppColors.background(brightness),
        appBar: AppBar(
          backgroundColor: AppColors.surface(brightness),
          elevation: 0,
          centerTitle: true,
          title: title != null
              ? Text(
                  title!,
                  style: AppTypography.headline.copyWith(
                    color: AppColors.textPrimary(brightness),
                  ),
                )
              : null,
          actions: actions,
          bottom: TabBar(
            tabs: tabs,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary(brightness),
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            labelStyle: AppTypography.subhead.copyWith(
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: AppTypography.subhead,
            onTap: onTabChanged,
          ),
        ),
        body: TabBarView(children: tabViews),
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}

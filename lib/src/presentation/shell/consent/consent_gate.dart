import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/consent/consent_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/url_actions.dart';
import '../../widgets/buttons/app_button.dart';
import '../../widgets/feedback/app_snackbar.dart';

/// Çeviri fonksiyonu (shell `LocalizationService.translate`; testte sahte).
typedef ConsentTranslate = String Function(String key);

/// Kapının kullandığı çeviri anahtarları — hepsi `keywords` tablosunda web
/// `ConsentGateComponent` ile ORTAK (yeni anahtar yok).
class ConsentKeys {
  ConsentKeys._();

  static const title = 'consent.title';
  static const lead = 'consent.lead';
  static const transferNotice = 'consent.transfer_notice';
  static const acceptPrefix = 'consent.accept_prefix';
  static const optional = 'consent.optional';
  static const acceptAll = 'consent.accept_all';
  static const submit = 'consent.submit';
  static const submitting = 'consent.submitting';
  static const reject = 'consent.reject';
  static const saveError = 'consent.save_error';
  static const loading = 'common.loading';
}

/// Belge başlığı UI dilinde (web `consentDocTitle`): `consent.document.<code>.title`
/// çevirisi varsa o, yoksa saklı `consent_documents.title`.
String consentDocTitle(ConsentTranslate translate, ConsentDoc doc) {
  final key = doc.titleKey;
  final t = translate(key);
  return (t.isNotEmpty && t != key) ? t : doc.title;
}

/// Yasal onay kapısı — web `consentActiveGuard` + `ConsentGateComponent`
/// mobil eşleniği. Giriş sonrası shell içeriğini ([child]) ancak kullanıcı
/// aktif zorunlu platform belgelerini GÜNCEL sürümde onaylamışsa gösterir.
///
/// Davranış (web ile birebir):
///  - Eksik zorunlu onay → onay ekranı (tüm aktif platform belgeleri; zorunlular
///    işaretlenmeden "Onayla ve Devam Et" kapalı; isteğe bağlı çerez belgesi ayrı).
///  - Onay → işaretli her belge için `platform_consents` satırı (sürümüyle).
///  - Reddet → çıkış ([onSignOut]).
///  - FAIL-OPEN: kullanıcı yok / sorgu hatası / zaman aşımı → [child] (kapı bir
///    uyum dürtüsüdür, güvenlik sınırı değil; kontrol hatası kimseyi kilitlemez).
class ConsentGate extends StatefulWidget {
  const ConsentGate({
    super.key,
    required this.service,
    required this.userId,
    required this.translate,
    required this.child,
    this.tenantId,
    this.platformId,
    this.onSignOut,
    this.checkTimeout = const Duration(seconds: 8),
  });

  final ConsentService service;

  /// Giriş yapmış kullanıcının id'si (`auth.uid()`); null → kapı açık.
  final String? Function() userId;

  /// Onay satırına yazılacak tenant (null olabilir — web ile aynı).
  final String? Function()? tenantId;

  /// Göreli belge bağlantılarını çözmek için aktif platform (app_base_url).
  final String? Function()? platformId;

  final ConsentTranslate translate;
  final Future<void> Function()? onSignOut;
  final Duration checkTimeout;
  final Widget child;

  /// Bu oturumda kapıyı geçmiş kullanıcılar — shell yeniden kurulunca (tema,
  /// platform değişimi) tekrar sorgu/spinner yok. Çıkış/başka kullanıcı → yeni id.
  static final Set<String> _passedUsers = <String>{};

  /// Test/çıkış için önbelleği temizle.
  @visibleForTesting
  static void resetSession() => _passedUsers.clear();

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

enum _GatePhase { checking, required, passed }

class _ConsentGateState extends State<ConsentGate> {
  _GatePhase _phase = _GatePhase.checking;
  List<ConsentDoc> _docs = const [];
  String? _baseUrl;

  @override
  void initState() {
    super.initState();
    final uid = widget.userId();
    if (uid == null || uid.isEmpty || ConsentGate._passedUsers.contains(uid)) {
      _phase = _GatePhase.passed;
    } else {
      unawaited(_check(uid));
    }
  }

  Future<void> _check(String uid) async {
    try {
      final missing = await widget.service
          .getMissingMandatory(uid)
          .timeout(widget.checkTimeout);
      if (missing.isEmpty) {
        ConsentGate._passedUsers.add(uid);
        _set(_GatePhase.passed);
        return;
      }
      // Ekran: tüm aktif platform belgeleri (zorunlu + isteğe bağlı) — web gibi.
      final docs = await widget.service
          .getAllActiveDocuments()
          .timeout(widget.checkTimeout);
      final base = await widget.service.getAppBaseUrl(widget.platformId?.call());
      if (!mounted) return;
      setState(() {
        _docs = docs.isNotEmpty ? docs : missing;
        _baseUrl = base;
        _phase = _GatePhase.required;
      });
    } catch (e) {
      // FAIL-OPEN (web guard ile aynı).
      Logger.warning('Consent gate check failed (fail-open): $e');
      _set(_GatePhase.passed);
    }
  }

  void _set(_GatePhase p) {
    if (mounted) setState(() => _phase = p);
  }

  Future<void> _accept(List<ConsentDecision> decisions) async {
    final uid = widget.userId();
    if (uid == null || uid.isEmpty) throw StateError('no-user');
    await widget.service.recordConsents(
      userId: uid,
      tenantId: widget.tenantId?.call(),
      decisions: decisions,
      userAgent: 'protoolbag-mobile',
    );
    ConsentGate._passedUsers.add(uid);
    _set(_GatePhase.passed);
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _GatePhase.passed:
        return widget.child;
      case _GatePhase.checking:
        return Scaffold(
          key: const Key('consent-gate-checking'),
          body: Center(
            child: Semantics(
              label: widget.translate(ConsentKeys.loading),
              child: const CircularProgressIndicator(),
            ),
          ),
        );
      case _GatePhase.required:
        return ConsentGateView(
          docs: _docs,
          translate: widget.translate,
          resolveUrl: (u) => ConsentService.resolveDocumentUrl(u, _baseUrl),
          onAccept: _accept,
          onReject: widget.onSignOut,
        );
    }
  }
}

/// Onay ekranı (saf görünüm; durum yalnız işaretler + gönderim).
class ConsentGateView extends StatefulWidget {
  const ConsentGateView({
    super.key,
    required this.docs,
    required this.translate,
    required this.onAccept,
    this.onReject,
    this.resolveUrl,
    this.onOpenUrl,
  });

  final List<ConsentDoc> docs;
  final ConsentTranslate translate;

  /// İşaretli belgeler için çağrılır; fırlatırsa `consent.save_error` gösterilir.
  final Future<void> Function(List<ConsentDecision> decisions) onAccept;
  final Future<void> Function()? onReject;

  /// Belge bağlantısını mutlak yapar (null → bağlantı gösterilmez).
  final String? Function(String? url)? resolveUrl;

  /// Bağlantı açıcı (varsayılan: harici tarayıcı).
  final Future<void> Function(String url)? onOpenUrl;

  @override
  State<ConsentGateView> createState() => _ConsentGateViewState();
}

class _ConsentGateViewState extends State<ConsentGateView> {
  final Set<String> _checked = <String>{};
  bool _submitting = false;

  List<ConsentDoc> get _mandatory =>
      widget.docs.where((d) => d.mandatory).toList();
  List<ConsentDoc> get _optional =>
      widget.docs.where((d) => !d.mandatory).toList();

  bool get _allMandatoryChecked {
    final m = _mandatory;
    return m.isNotEmpty && m.every((d) => _checked.contains(d.code));
  }

  bool get _allChecked =>
      widget.docs.isNotEmpty &&
      widget.docs.every((d) => _checked.contains(d.code));

  void _toggle(String code, bool on) => setState(() {
        if (on) {
          _checked.add(code);
        } else {
          _checked.remove(code);
        }
      });

  void _toggleAll(bool on) => setState(() {
        _checked.clear();
        if (on) _checked.addAll(widget.docs.map((d) => d.code));
      });

  Future<void> _submit() async {
    if (!_allMandatoryChecked || _submitting) return;
    setState(() => _submitting = true);
    final decisions = [
      for (final d in widget.docs)
        if (_checked.contains(d.code))
          ConsentDecision(code: d.code, version: d.version),
    ];
    try {
      await widget.onAccept(decisions);
    } catch (e) {
      Logger.error('Consent record failed', e);
      if (!mounted) return;
      setState(() => _submitting = false);
      AppSnackbar.showError(context,
          message: widget.translate(ConsentKeys.saveError));
    }
  }

  Future<void> _open(String url) async {
    final opener = widget.onOpenUrl;
    if (opener != null) {
      await opener(url);
      return;
    }
    await UrlActions.openUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.translate;
    final brightness = Theme.of(context).brightness;
    final secondary = AppColors.textSecondary(brightness);
    return Scaffold(
      key: const Key('consent-gate-view'),
      backgroundColor: AppColors.background(brightness),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Icon(Icons.verified_user_outlined,
                size: 44, color: AppColors.primary),
            const SizedBox(height: AppSpacing.sm),
            Text(t(ConsentKeys.title),
                textAlign: TextAlign.center,
                style: AppTypography.title2
                    .copyWith(color: AppColors.textPrimary(brightness))),
            const SizedBox(height: AppSpacing.xs),
            Text(t(ConsentKeys.lead),
                textAlign: TextAlign.center,
                style: AppTypography.subhead.copyWith(color: secondary)),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surface(brightness),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(t(ConsentKeys.transferNotice),
                  style: AppTypography.footnote.copyWith(color: secondary)),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final d in _mandatory) _docTile(d, prefix: true),
            if (_optional.isNotEmpty) ...[
              Divider(color: AppColors.divider(brightness)),
              for (final d in _optional) _docTile(d, prefix: false),
            ],
            Divider(color: AppColors.divider(brightness)),
            CheckboxListTile(
              key: const Key('consent-accept-all'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _allChecked,
              onChanged:
                  _submitting ? null : (v) => _toggleAll(v ?? false),
              title: Text(t(ConsentKeys.acceptAll),
                  style: AppTypography.body
                      .copyWith(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              key: const Key('consent-submit'),
              label: _submitting
                  ? t(ConsentKeys.submitting)
                  : t(ConsentKeys.submit),
              isLoading: _submitting,
              onPressed: _allMandatoryChecked ? _submit : null,
            ),
            const SizedBox(height: AppSpacing.buttonSpacing),
            AppButton(
              key: const Key('consent-reject'),
              label: t(ConsentKeys.reject),
              variant: AppButtonVariant.secondary,
              onPressed: (_submitting || widget.onReject == null)
                  ? null
                  : () => widget.onReject!(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _docTile(ConsentDoc d, {required bool prefix}) {
    final t = widget.translate;
    final title = consentDocTitle(t, d);
    final url = widget.resolveUrl?.call(d.url);
    final label = prefix ? '${t(ConsentKeys.acceptPrefix)} $title' : title;
    return CheckboxListTile(
      key: Key('consent-doc-${d.code}'),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: _checked.contains(d.code),
      onChanged: _submitting ? null : (v) => _toggle(d.code, v ?? false),
      title: Text(label, style: AppTypography.subhead),
      subtitle: d.mandatory
          ? null
          : Text(t(ConsentKeys.optional), style: AppTypography.caption1),
      secondary: url == null
          ? null
          : IconButton(
              key: Key('consent-open-${d.code}'),
              icon: const Icon(Icons.open_in_new, size: 20),
              tooltip: title,
              onPressed: () => _open(url),
            ),
    );
  }
}

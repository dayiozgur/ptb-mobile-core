import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Tek ekran, iki mod: [id] null ise CREATE, dolu ise EDIT.
///
/// Config + form şablonu çözülür (düzenlemede kayıt da yüklenip
/// `initialValues` sağlar); gövde [DynamicFormWidget]'ı `viewMode:false` ile
/// sarar. Submit [EntityDataService.submitEntity] ile portala yazılır.
class EntityFormScreen extends StatefulWidget {
  final String typeCode;
  final String? id;

  /// CREATE modunda formu ön-dolduran değerler (ör. fiş/fatura OCR taraması).
  /// EDIT modunda yok sayılır (kaydın kendi değerleri kullanılır).
  final Map<String, dynamic>? seedValues;

  /// Form üstünde gösterilecek uyarı/bilgi notları (ör. OCR aritmetik
  /// çapraz-kontrol uyarıları — "KDV toplamı tutmuyor"). Boşsa banner çıkmaz.
  final List<String> notices;

  const EntityFormScreen({
    super.key,
    required this.typeCode,
    this.id,
    this.seedValues,
    this.notices = const [],
  });

  @override
  State<EntityFormScreen> createState() => _EntityFormScreenState();
}

class _EntityFormScreenState extends State<EntityFormScreen> {
  bool _isLoading = true;
  bool _submitting = false;
  String? _errorMessage;

  EntityTypeConfig? _config;
  GenericEntity? _entity;
  FormTemplate? _template;

  bool get _isCreate => widget.id == null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _t(String key, String fallback) {
    final v = sl<LocalizationService>().translate(key);
    return v == key ? fallback : v;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final config = await sl<EntityConfigService>().getByCode(widget.typeCode);
      if (config == null) {
        if (mounted) {
          setState(() {
            _config = null;
            _entity = null;
            _template = null;
            _isLoading = false;
          });
        }
        return;
      }

      final tenantId = sl<TenantService>().currentTenantId;
      final dataService = sl<EntityDataService>();
      if (tenantId != null) {
        dataService.setTenant(tenantId);
      }

      GenericEntity? entity;
      if (!_isCreate) {
        entity = await dataService.getEntity(config, widget.id!);
      }

      final template = await _resolveTemplate(config, entity);

      if (mounted) {
        setState(() {
          _config = config;
          _entity = entity;
          _template = template;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load entity form (${widget.typeCode})', e);
      if (mounted) {
        setState(() {
          _errorMessage =
              '${sl<LocalizationService>().translate('common.error')}: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Sırayla: kaydın `formTemplateId`'si → config'in varsayılanı → entity-type
  /// üzerinden ilk uygun şablon.
  Future<FormTemplate?> _resolveTemplate(
    EntityTypeConfig config,
    GenericEntity? entity,
  ) async {
    final service = sl<FormTemplateService>();

    final entityTemplateId = entity?.formTemplateId;
    if (entityTemplateId != null && entityTemplateId.isNotEmpty) {
      final t = await service.getById(entityTemplateId);
      if (t != null) return t;
    }

    final defaultId = config.defaultFormTemplateId;
    if (defaultId != null && defaultId.isNotEmpty) {
      final t = await service.getById(defaultId);
      if (t != null) return t;
    }

    return service.getByEntityType(config.code);
  }

  Future<void> _submit(Map<String, dynamic> values) async {
    final config = _config;
    final template = _template;
    if (config == null || template == null || _submitting) return;

    setState(() => _submitting = true);

    try {
      await sl<EntityDataService>().submitEntity(
        templateId: template.id,
        values: values,
        entityType: config.code,
        entityId: widget.id,
        submissionId: widget.id,
        asDraft: false,
      );

      if (!mounted) return;
      AppSnackbar.success(
        context,
        message: _t('entity.saved', 'Kayıt başarıyla kaydedildi'),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/entities/${widget.typeCode}');
      }
    } catch (e) {
      Logger.error('Failed to submit entity (${widget.typeCode})', e);
      if (!mounted) return;
      AppSnackbar.error(
        context,
        message:
            '${_t('entity.save_failed', 'Kayıt kaydedilemedi')}: $e',
      );
      setState(() => _submitting = false);
    }
  }

  String get _title {
    final config = _config;
    final lang = sl<LocalizationService>().currentLocale.languageCode;
    final name = config != null ? config.localizedName(lang) : widget.typeCode;
    if (_isCreate) {
      final tpl = _t('entity.create_title', 'Yeni {name}');
      return tpl.replaceAll('{name}', name);
    }
    final tpl = _t('entity.edit_title', '{name} Düzenle');
    return tpl.replaceAll('{name}', name);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _title,
      onBack: () => context.pop(),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: AppLoadingIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: AppErrorView(
          message: _errorMessage!,
          onRetry: _loadData,
        ),
      );
    }

    if (_config == null) {
      return Center(
        child: AppEmptyState(
          icon: Icons.inbox_outlined,
          title: _t('common.no_records', 'Kayıt bulunamadı'),
        ),
      );
    }

    final template = _template;
    if (template == null) {
      return Center(
        child: AppEmptyState(
          icon: Icons.description_outlined,
          title: _t('entity.no_form', 'Bu tip için form tanımlı değil'),
        ),
      );
    }

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isCreate && widget.notices.isNotEmpty) ...[
            _NoticeBanner(notices: widget.notices),
            const SizedBox(height: AppSpacing.md),
          ],
          DynamicFormWidget(
            template: template,
            initialValues: _isCreate ? widget.seedValues : _entity?.fieldValues,
            viewMode: false,
            submitting: _submitting,
            submitLabelKey: 'common.save',
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

/// OCR/doğrulama uyarılarını form üstünde gösteren amber banner.
class _NoticeBanner extends StatelessWidget {
  final List<String> notices;
  const _NoticeBanner({required this.notices});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 20, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final n in notices)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(n, style: AppTypography.footnote),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

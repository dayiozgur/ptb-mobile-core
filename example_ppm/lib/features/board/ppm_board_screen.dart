import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// PPM proje-scope hedefi.
enum PpmScopeTarget { board, backlog }

/// PPM **Board/Backlog** girişi — önce proje seçtirir, sonra o projenin
/// **alt-ağacına kapsamlı** kanban'ı ([EntityKanbanScreen]) veya backlog'unu
/// ([BacklogScreen]) `ancestorId: projectId` ile açar.
///
/// Aksi halde generic ekranlar tüm-tenant kayıtlarını gösteriyordu (proje
/// ayrımı yok + sessiz limit). Jira-benzeri proje-scope.
class PpmBoardScreen extends StatefulWidget {
  final PpmScopeTarget target;
  const PpmBoardScreen({super.key, this.target = PpmScopeTarget.board});

  @override
  State<PpmBoardScreen> createState() => _PpmBoardScreenState();
}

class _PpmBoardScreenState extends State<PpmBoardScreen> {
  bool _loading = true;
  String? _error;
  List<GenericEntity> _projects = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await sl<EntityConfigService>().getByCode('project');
      if (config == null) {
        setState(() {
          _projects = [];
          _loading = false;
        });
        return;
      }
      final tenantId = sl<TenantService>().currentTenantId;
      final ds = sl<EntityDataService>();
      if (tenantId != null) ds.setTenant(tenantId);
      final projects = await ds.listEntities(config, limit: 100);
      if (mounted) {
        setState(() {
          _projects = projects;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  void _openBoard(GenericEntity project) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => widget.target == PpmScopeTarget.backlog
          ? BacklogScreen(
              typeCode: 'story',
              ancestorId: project.id,
              title: project.displayTitle,
            )
          : EntityKanbanScreen(
              typeCode: 'task',
              ancestorId: project.id,
              title: project.displayTitle,
            ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title:
          '${widget.target == PpmScopeTarget.backlog ? 'Backlog' : 'Board'} — Proje seç',
      onBack: () => context.pop(),
      actions: [AppIconButton(icon: Icons.refresh, onPressed: _load)],
      child: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: AppLoadingIndicator());
    if (_error != null) {
      return Center(child: AppErrorView(message: _error!, onRetry: _load));
    }
    if (_projects.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          Center(
            child: AppEmptyState(
                icon: Icons.folder_off_outlined, title: 'Proje bulunamadı'),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _projects.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) {
        final p = _projects[i];
        return AppCard(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openBoard(p),
            child: Padding(
              padding: AppSpacing.cardInsets,
              child: Row(
                children: [
                  Icon(Icons.folder_outlined, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.displayTitle, style: AppTypography.subhead),
                        if (p.code != null && p.code!.isNotEmpty)
                          Text(p.code!,
                              style: AppTypography.caption1.copyWith(
                                  color: AppColors.secondaryLabel(context))),
                      ],
                    ),
                  ),
                  if (p.status != null && p.status!.isNotEmpty)
                    AppBadge(
                        label: p.status!,
                        variant: AppBadgeVariant.neutral,
                        size: AppBadgeSize.small),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/entity/entity_data_service.dart';
import '../../../core/entity/entity_status_labels.dart';
import 'app_badge.dart';

/// Badge for an entity status CODE that renders the status NAME and colour
/// from `status_definitions` (platform-scoped, system statuses translated via
/// `status.<code>`) — never the raw code (`needs_service`). Labels are
/// memoised per platform + entity type by [EntityDataService.statusLabels];
/// until they load (or when no definition exists) the humanized code is shown.
class EntityStatusBadge extends StatefulWidget {
  final String? entityType;
  final String status;
  final AppBadgeVariant variant;
  final AppBadgeSize size;

  const EntityStatusBadge({
    super.key,
    required this.entityType,
    required this.status,
    this.variant = AppBadgeVariant.neutral,
    this.size = AppBadgeSize.small,
  });

  @override
  State<EntityStatusBadge> createState() => _EntityStatusBadgeState();
}

class _EntityStatusBadgeState extends State<EntityStatusBadge> {
  Map<String, EntityStatusLabel> _labels = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EntityStatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entityType != widget.entityType) _load();
  }

  Future<void> _load() async {
    final type = widget.entityType;
    if (type == null || type.isEmpty || !sl.isRegistered<EntityDataService>()) {
      return;
    }
    try {
      final labels = await sl<EntityDataService>().statusLabels(type);
      if (mounted) setState(() => _labels = labels);
    } catch (_) {
      // Non-fatal: humanized code stays.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      label: EntityStatusLabels.nameOf(widget.status, _labels),
      variant: widget.variant,
      color: _labels[widget.status]?.color,
      size: widget.size,
    );
  }
}

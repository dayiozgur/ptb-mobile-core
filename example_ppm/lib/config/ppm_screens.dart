import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

import '../features/board/ppm_board_screen.dart';

/// PPM "İşlerim" kaynağı — `fn_ppm_my_work` satırlarını generic [WorkInboxItem]'a
/// eşler (bana atanan epic/story/task/sub_task, tüm projeler).
final WorkInboxSource ppmMyWorkSource = WorkInboxSource(
  title: 'İşlerim',
  rpcName: 'fn_ppm_my_work',
  mapper: (r) => WorkInboxItem(
    id: r['id']?.toString() ?? '',
    title: r['subject']?.toString() ?? '—',
    subtitle: [r['project_name'], r['sprint_name']]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' · '),
    status: r['status']?.toString(),
    entityType: r['entity_type']?.toString(), // epic | story | task | sub_task
    dueDate: r['due_date'] != null
        ? DateTime.tryParse(r['due_date'].toString())
        : null,
    trailing: r['story_points'] != null
        ? '${(r['story_points'] as num).toStringAsFixed(0)} sp'
        : null,
  ),
);

/// PPM domain ekran çözümleyicisi.
///
/// PPM entity tipleri (project/epic/story/task/sub_task) menüde değil
/// (`show_in_menu=0`) — giriş `İşlerim` (fn_ppm_my_work) + proje-listesi/board/
/// backlog. Entity detay/form çekirdek entity-engine ile gelir; yorum/durum
/// paylaşılan çekirdek primitiflerinden.
Widget? ppmResolve(MenuItem item) {
  final path = item.path;
  if (path == null || path.isEmpty) return null;
  final p = path.toLowerCase();

  if (p == '/projects/my-work' || p == '/my-work' || p == '/ppm/my-work') {
    return WorkInboxScreen(source: ppmMyWorkSource);
  }
  if (p == '/projects' || p == '/projects/list' || p == '/ppm/projects') {
    return const EntityListScreen(typeCode: 'project');
  }
  if (p == '/projects/board' || p == '/ppm/board') {
    // Proje-scope board: önce proje seç → o projenin alt-ağacına kapsamlı kanban.
    return const PpmBoardScreen();
  }
  if (p == '/projects/backlog' || p == '/ppm/backlog') {
    // Proje-scope backlog: proje seç → o projenin story backlog'u.
    return const PpmBoardScreen(target: PpmScopeTarget.backlog);
  }
  return null;
}

bool _done = false;

/// PPM domain ekranlarını çekirdek [ScreenResolver]'a kaydet (bir kez).
void registerPpmScreens() {
  if (_done) return;
  ScreenResolver.addResolver(ppmResolve);
  _done = true;
}

import 'job_application_row.dart';

/// İşe alım hattının (pipeline) tek bir aşaması ve o aşamadaki başvurular.
///
/// `job_applications` satırları `stage` kolonuna göre gruplanır; her grup bir
/// aşamayı (`applied` → `hired`/`rejected`) temsil eder. v1 salt-okuma: sürükle-
/// bırak kanban değil, aşama başına sayı + basit kart listesi. Web PHR ATS
/// pipeline aşama sırasıyla (`ApplicationStage`) aynı kanonik sıradadır.
class PipelineStageGroup {
  /// Aşama kodu: `applied` | `screening` | `interview` | `offer` | `hired` |
  /// `rejected`.
  final String stage;

  /// Bu aşamadaki başvurular (başvuru tarihine göre, en yeni önce).
  final List<JobApplicationRow> applications;

  const PipelineStageGroup({
    required this.stage,
    required this.applications,
  });

  int get count => applications.length;
}

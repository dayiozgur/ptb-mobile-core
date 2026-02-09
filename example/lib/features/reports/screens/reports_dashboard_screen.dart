import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Raporlama Dashboard Ekranı
///
/// Özet metrikler, grafikler ve raporlama araçlarını içerir.
class ReportsDashboardScreen extends StatefulWidget {
  const ReportsDashboardScreen({super.key});

  @override
  State<ReportsDashboardScreen> createState() => _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState extends State<ReportsDashboardScreen> {
  bool _isLoading = true;
  ReportPeriod _selectedPeriod = ReportPeriod.thisMonth;
  DashboardSummary? _summary;

  // Stats
  int _organizationCount = 0;
  int _siteCount = 0;
  int _unitCount = 0;
  int _userCount = 0;
  int _activityCount = 0;
  int _workRequestCount = 0;
  int _calendarEventCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final tenantId = tenantService.currentTenantId;
      if (tenantId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Load counts in parallel
      await Future.wait([
        _loadOrganizationCount(tenantId),
        _loadSiteCount(),
        _loadUnitCount(),
        _loadUserCount(tenantId),
        _loadActivityCount(tenantId),
        _loadWorkRequestStats(),
        _loadCalendarStats(),
      ]);

      setState(() => _isLoading = false);
    } catch (e) {
      Logger.error('Failed to load dashboard data', e);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOrganizationCount(String tenantId) async {
    try {
      final orgs = await organizationService.getOrganizations(tenantId);
      setState(() => _organizationCount = orgs.length);
    } catch (_) {}
  }

  Future<void> _loadSiteCount() async {
    try {
      final orgId = organizationService.currentOrganizationId;
      if (orgId != null) {
        final sites = await siteService.getSites(orgId);
        setState(() => _siteCount = sites.length);
      }
    } catch (_) {}
  }

  Future<void> _loadUnitCount() async {
    try {
      final siteId = siteService.currentSiteId;
      if (siteId != null) {
        final units = await unitService.getUnits(siteId);
        setState(() => _unitCount = units.length);
      }
    } catch (_) {}
  }

  Future<void> _loadUserCount(String tenantId) async {
    try {
      // Approximate from member count
      setState(() => _userCount = 0);
    } catch (_) {}
  }

  Future<void> _loadActivityCount(String tenantId) async {
    try {
      final activities = await activityService.getRecentActivities(
        tenantId,
        limit: 100,
      );
      setState(() => _activityCount = activities.length);
    } catch (_) {}
  }

  Future<void> _loadWorkRequestStats() async {
    try {
      // Work request stats would be loaded here
      setState(() => _workRequestCount = 0);
    } catch (_) {}
  }

  Future<void> _loadCalendarStats() async {
    try {
      // Calendar stats would be loaded here
      setState(() => _calendarEventCount = 0);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporlar'),
        actions: [
          // Period Selector
          PopupMenuButton<ReportPeriod>(
            initialValue: _selectedPeriod,
            onSelected: (period) {
              setState(() => _selectedPeriod = period);
              _loadDashboardData();
            },
            itemBuilder: (context) => ReportPeriod.values
                .where((p) => p != ReportPeriod.custom)
                .map((period) => PopupMenuItem(
                      value: period,
                      child: Text(period.label),
                    ))
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text(
                    _selectedPeriod.label,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Cards
                    _buildSummarySection(),
                    const SizedBox(height: 24),

                    // Charts Section
                    _buildChartsSection(),
                    const SizedBox(height: 24),

                    // Quick Reports
                    _buildQuickReportsSection(),
                    const SizedBox(height: 24),

                    // Recent Activities
                    _buildRecentActivitiesSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Özet',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildMetricCard(
              title: 'Organizasyonlar',
              value: _organizationCount.toString(),
              icon: Icons.business,
              color: Colors.blue,
            ),
            _buildMetricCard(
              title: 'Tesisler',
              value: _siteCount.toString(),
              icon: Icons.location_city,
              color: Colors.green,
            ),
            _buildMetricCard(
              title: 'Üniteler',
              value: _unitCount.toString(),
              icon: Icons.widgets,
              color: Colors.orange,
            ),
            _buildMetricCard(
              title: 'Aktiviteler',
              value: _activityCount.toString(),
              icon: Icons.timeline,
              color: Colors.purple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    TrendData? trend,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                if (trend != null)
                  _buildTrendIndicator(trend),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendIndicator(TrendData trend) {
    final isUp = trend.direction == TrendDirection.up;
    final color = isUp ? Colors.green : Colors.red;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isUp ? Icons.trending_up : Icons.trending_down,
          color: color,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          '${trend.changePercent.toStringAsFixed(1)}%',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildChartsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analiz',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),

        // Activity Chart
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aktivite Trendi',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: _buildActivityChart(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Distribution Chart
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Varlık Dağılımı',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: _buildDistributionChart(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityChart() {
    // Sample data - in real app, this would come from the service
    final spots = [
      const FlSpot(0, 3),
      const FlSpot(1, 5),
      const FlSpot(2, 4),
      const FlSpot(3, 7),
      const FlSpot(4, 6),
      const FlSpot(5, 8),
      const FlSpot(6, 9),
    ];

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withOpacity(0.2),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
                if (value.toInt() >= 0 && value.toInt() < days.length) {
                  return Text(
                    days[value.toInt()],
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).primaryColor,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).primaryColor.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionChart() {
    final total = _organizationCount + _siteCount + _unitCount;
    if (total == 0) {
      return Center(
        child: Text(
          'Veri yok',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: [
                PieChartSectionData(
                  value: _organizationCount.toDouble(),
                  color: Colors.blue,
                  title: '',
                  radius: 50,
                ),
                PieChartSectionData(
                  value: _siteCount.toDouble(),
                  color: Colors.green,
                  title: '',
                  radius: 50,
                ),
                PieChartSectionData(
                  value: _unitCount.toDouble(),
                  color: Colors.orange,
                  title: '',
                  radius: 50,
                ),
              ],
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLegendItem('Organizasyonlar', Colors.blue, _organizationCount),
            const SizedBox(height: 8),
            _buildLegendItem('Tesisler', Colors.green, _siteCount),
            const SizedBox(height: 8),
            _buildLegendItem('Üniteler', Colors.orange, _unitCount),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label ($count)',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildQuickReportsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hızlı Raporlar',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        _buildReportTile(
          icon: Icons.summarize,
          title: 'Özet Rapor',
          subtitle: 'Genel sistem özeti',
          onTap: () => _generateReport(ReportType.summary),
        ),
        _buildReportTile(
          icon: Icons.timeline,
          title: 'Aktivite Raporu',
          subtitle: 'Kullanıcı aktiviteleri',
          onTap: () => _generateReport(ReportType.activity),
        ),
        _buildReportTile(
          icon: Icons.inventory,
          title: 'Envanter Raporu',
          subtitle: 'Varlık listesi',
          onTap: () => _generateReport(ReportType.inventory),
        ),
        _buildReportTile(
          icon: Icons.speed,
          title: 'Performans Raporu',
          subtitle: 'Sistem performansı',
          onTap: () => _generateReport(ReportType.performance),
        ),
      ],
    );
  }

  Widget _buildReportTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  void _generateReport(ReportType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ReportGeneratorSheet(
        type: type,
        period: _selectedPeriod,
      ),
    );
  }

  Widget _buildRecentActivitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Son Aktiviteler',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to activity log
              },
              child: const Text('Tümünü Gör'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _activityCount > 0
                ? const Text('Aktiviteler yükleniyor...')
                : Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Henüz aktivite yok',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Report Generator Sheet
class _ReportGeneratorSheet extends StatefulWidget {
  final ReportType type;
  final ReportPeriod period;

  const _ReportGeneratorSheet({
    required this.type,
    required this.period,
  });

  @override
  State<_ReportGeneratorSheet> createState() => _ReportGeneratorSheetState();
}

class _ReportGeneratorSheetState extends State<_ReportGeneratorSheet> {
  late ReportPeriod _selectedPeriod;
  ReportFormat _selectedFormat = ReportFormat.pdf;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.period;
  }

  Future<void> _generate() async {
    setState(() => _isGenerating = true);

    try {
      // Simulate report generation
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.type.label} oluşturuldu'),
            action: SnackBarAction(
              label: 'İndir',
              onPressed: () {
                // Download report
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rapor oluşturulamadı')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.type.label,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),

          // Period Selection
          Text(
            'Dönem',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ReportPeriod.thisWeek,
              ReportPeriod.thisMonth,
              ReportPeriod.thisQuarter,
              ReportPeriod.thisYear,
            ].map((period) {
              final isSelected = _selectedPeriod == period;
              return ChoiceChip(
                label: Text(period.label),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedPeriod = period);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Format Selection
          Text(
            'Format',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ReportFormat.values.map((format) {
              final isSelected = _selectedFormat == format;
              return ChoiceChip(
                label: Text(format.label),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedFormat = format);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Generate Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isGenerating ? null : _generate,
              child: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Rapor Oluştur'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

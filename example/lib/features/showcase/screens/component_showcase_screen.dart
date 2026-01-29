import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Tum tasarim sistemi bilesenlerini gosteren katalog ekrani
class ComponentShowcaseScreen extends StatefulWidget {
  const ComponentShowcaseScreen({super.key});

  @override
  State<ComponentShowcaseScreen> createState() =>
      _ComponentShowcaseScreenState();
}

class _ComponentShowcaseScreenState extends State<ComponentShowcaseScreen> {
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Bilesen Katalogu',
      onBack: () => context.go('/home'),
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================
            // BUTTONS
            // ==================
            AppSectionHeader(title: 'Butonlar'),
            const SizedBox(height: AppSpacing.sm),
            _ButtonsShowcase(),

            const SizedBox(height: AppSpacing.xl),

            // ==================
            // TEXT FIELDS
            // ==================
            AppSectionHeader(title: 'Metin Alanlari'),
            const SizedBox(height: AppSpacing.sm),
            _TextFieldsShowcase(),

            const SizedBox(height: AppSpacing.xl),

            // ==================
            // DATE PICKERS
            // ==================
            AppSectionHeader(title: 'Tarih Seciciler'),
            const SizedBox(height: AppSpacing.sm),
            _DatePickerShowcase(),

            const SizedBox(height: AppSpacing.xl),

            // ==================
            // DROPDOWN
            // ==================
            AppSectionHeader(title: 'Acilir Menuler'),
            const SizedBox(height: AppSpacing.sm),
            _DropdownShowcase(),

            const SizedBox(height: AppSpacing.xl),

            // ==================
            // CARDS
            // ==================
            AppSectionHeader(title: 'Kartlar'),
            const SizedBox(height: AppSpacing.sm),
            _CardsShowcase(),

            const SizedBox(height: AppSpacing.xl),

            // ==================
            // METRIC CARDS
            // ==================
            AppSectionHeader(title: 'Metrik Kartlar'),
            const SizedBox(height: AppSpacing.sm),
            _MetricCardsShowcase(),

            const SizedBox(height: AppSpacing.xl),

            // ==================
            // CHIPS
            // ==================
            AppSectionHeader(title: 'Chip / Etiketler'),
            const SizedBox(height: AppSpacing.sm),
            _ChipsShowcase(),

            const SizedBox(height: AppSpacing.xl),

            // ==================
            // BADGES
            // ==================
            AppSectionHeader(title: 'Rozetler (Badge)'),
            const SizedBox(height: AppSpacing.sm),
            _BadgesShowcase(),

            const SizedBox(height: AppSpacing.xl),

            // ==================
            // PROGRESS BARS
            // ==================
            AppSectionHeader(title: 'Ilerleme Cubugu'),
            const SizedBox(height: AppSpacing.sm),
            _ProgressShowcase(),

            const SizedBox(height: AppSpacing.xl),

            // ==================
            // AVATARS
            // ==================
            AppSectionHeader(title: 'Avatar'),
            const SizedBox(height: AppSpacing.sm),
            _AvatarShowcase(),

            const SizedBox(height: AppSpacing.xl),

            // ==================
            // LIST TILES
            // ==================
            AppSectionHeader(title: 'Liste Ogeleri'),
            const SizedBox(height: AppSpacing.sm),
            _ListTileShowcase(),

            const SizedBox(height: AppSpacing.xl),

            // ==================
            // FEEDBACK
            // ==================
            AppSectionHeader(title: 'Geri Bildirim'),
            const SizedBox(height: AppSpacing.sm),
            _FeedbackShowcase(),

            const SizedBox(height: AppSpacing.xl),

            // ==================
            // SEARCH BAR
            // ==================
            AppSectionHeader(title: 'Arama Cubugu'),
            const SizedBox(height: AppSpacing.sm),
            _SearchBarShowcase(),

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// BUTTONS SHOWCASE
// ============================================================================
class _ButtonsShowcase extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Varyantlar', style: AppTypography.caption1.copyWith(
              color: AppColors.secondaryLabel(context),
              fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Primary Buton',
              onPressed: () {},
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Secondary Buton',
              variant: AppButtonVariant.secondary,
              onPressed: () {},
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Tertiary Buton',
              variant: AppButtonVariant.tertiary,
              onPressed: () {},
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Destructive Buton',
              variant: AppButtonVariant.destructive,
              onPressed: () {},
            ),
            const SizedBox(height: AppSpacing.lg),

            Text('Durumlar', style: AppTypography.caption1.copyWith(
              color: AppColors.secondaryLabel(context),
              fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Yukleniyor...',
              isLoading: true,
              onPressed: () {},
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Devre Disi',
              onPressed: null,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Ikonlu Buton',
              icon: Icons.add,
              onPressed: () {},
            ),
            const SizedBox(height: AppSpacing.lg),

            Text('Boyutlar', style: AppTypography.caption1.copyWith(
              color: AppColors.secondaryLabel(context),
              fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Kucuk Buton',
              size: AppButtonSize.small,
              onPressed: () {},
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Orta Buton',
              size: AppButtonSize.medium,
              onPressed: () {},
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Buyuk Buton',
              size: AppButtonSize.large,
              onPressed: () {},
            ),
            const SizedBox(height: AppSpacing.lg),

            Text('Ikon Butonlar', style: AppTypography.caption1.copyWith(
              color: AppColors.secondaryLabel(context),
              fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                AppIconButton(
                  icon: Icons.settings,
                  onPressed: () {},
                ),
                const SizedBox(width: AppSpacing.md),
                AppIconButton(
                  icon: Icons.edit,
                  onPressed: () {},
                ),
                const SizedBox(width: AppSpacing.md),
                AppIconButton(
                  icon: Icons.delete,
                  onPressed: () {},
                ),
                const SizedBox(width: AppSpacing.md),
                AppIconButton(
                  icon: Icons.share,
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TEXT FIELDS SHOWCASE
// ============================================================================
class _TextFieldsShowcase extends StatefulWidget {
  @override
  State<_TextFieldsShowcase> createState() => _TextFieldsShowcaseState();
}

class _TextFieldsShowcaseState extends State<_TextFieldsShowcase> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _multilineController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _multilineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'Ad Soyad',
              placeholder: 'Adinizi girin',
              controller: _nameController,
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: AppSpacing.md),
            AppEmailField(
              controller: _emailController,
            ),
            const SizedBox(height: AppSpacing.md),
            AppPasswordField(
              controller: _passwordController,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Aciklama',
              placeholder: 'Aciklamanizi girin...',
              controller: _multilineController,
              maxLines: 3,
              prefixIcon: Icons.description_outlined,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Hatali Alan',
              placeholder: 'Bu alan hatali',
              errorText: 'Bu alan zorunludur',
              prefixIcon: Icons.error_outline,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Devre Disi Alan',
              placeholder: 'Duzenlenemez',
              enabled: false,
              prefixIcon: Icons.lock_outline,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DATE PICKER SHOWCASE
// ============================================================================
class _DatePickerShowcase extends StatefulWidget {
  @override
  State<_DatePickerShowcase> createState() => _DatePickerShowcaseState();
}

class _DatePickerShowcaseState extends State<_DatePickerShowcase> {
  DateTime? _selectedDate;
  DateTime? _selectedTime;
  DateTime? _selectedDateTime;
  DateTimeRange? _selectedRange;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDatePicker(
              label: 'Tarih Sec',
              placeholder: 'Tarih secin',
              value: _selectedDate,
              onChanged: (date) => setState(() => _selectedDate = date),
            ),
            const SizedBox(height: AppSpacing.md),
            AppDatePicker(
              label: 'Saat Sec',
              placeholder: 'Saat secin',
              mode: AppDatePickerMode.time,
              value: _selectedTime,
              onChanged: (time) => setState(() => _selectedTime = time),
            ),
            const SizedBox(height: AppSpacing.md),
            AppDatePicker(
              label: 'Tarih ve Saat',
              placeholder: 'Tarih ve saat secin',
              mode: AppDatePickerMode.dateTime,
              value: _selectedDateTime,
              onChanged: (dt) => setState(() => _selectedDateTime = dt),
            ),
            const SizedBox(height: AppSpacing.md),
            AppDateRangePicker(
              label: 'Tarih Araligi',
              placeholder: 'Aralik secin',
              value: _selectedRange,
              onChanged: (range) => setState(() => _selectedRange = range),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DROPDOWN SHOWCASE
// ============================================================================
class _DropdownShowcase extends StatefulWidget {
  @override
  State<_DropdownShowcase> createState() => _DropdownShowcaseState();
}

class _DropdownShowcaseState extends State<_DropdownShowcase> {
  String? _selectedCity;
  String? _selectedRole;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDropdown<String>(
              label: 'Sehir',
              placeholder: 'Sehir secin',
              value: _selectedCity,
              items: const [
                DropdownMenuItem(value: 'istanbul', child: Text('Istanbul')),
                DropdownMenuItem(value: 'ankara', child: Text('Ankara')),
                DropdownMenuItem(value: 'izmir', child: Text('Izmir')),
                DropdownMenuItem(value: 'bursa', child: Text('Bursa')),
              ],
              onChanged: (val) => setState(() => _selectedCity = val),
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdown<String>(
              label: 'Rol',
              placeholder: 'Rol secin',
              value: _selectedRole,
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                DropdownMenuItem(value: 'editor', child: Text('Editor')),
                DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
              ],
              onChanged: (val) => setState(() => _selectedRole = val),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CARDS SHOWCASE
// ============================================================================
class _CardsShowcase extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppCard(
          child: Padding(
            padding: AppSpacing.cardInsets,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Standart Kart', style: AppTypography.headline),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Varsayilan kart stili. Golge ve kenarlikli.',
                  style: AppTypography.subheadline.copyWith(
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          variant: AppCardVariant.filled,
          child: Padding(
            padding: AppSpacing.cardInsets,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dolgulu Kart', style: AppTypography.headline),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Arka plan renkli kart. Vurgu alanlari icin.',
                  style: AppTypography.subheadline.copyWith(
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          onTap: () {},
          child: Padding(
            padding: AppSpacing.cardInsets,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.touch_app, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tiklanabilir Kart', style: AppTypography.headline),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Tiklayarak bir aksiyon tetikler',
                        style: AppTypography.subheadline.copyWith(
                          color: AppColors.secondaryLabel(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.tertiaryLabel(context)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// METRIC CARDS SHOWCASE
// ============================================================================
class _MetricCardsShowcase extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MetricCard(
                title: 'Toplam Gelir',
                value: '\$12,450',
                icon: Icons.attach_money,
                color: AppColors.success,
                trend: MetricTrend.up,
                trendValue: '+12%',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MetricCard(
                title: 'Aktif Kullanici',
                value: '2,845',
                icon: Icons.people,
                color: AppColors.info,
                trend: MetricTrend.up,
                trendValue: '+5%',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                title: 'Hata Orani',
                value: '0.8%',
                icon: Icons.bug_report,
                color: AppColors.error,
                trend: MetricTrend.down,
                trendValue: '-3%',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MetricCard(
                title: 'Uptime',
                value: '99.9%',
                icon: Icons.speed,
                color: AppColors.warning,
                trend: MetricTrend.neutral,
                trendValue: '0%',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Kompakt Metrik Kart', style: AppTypography.caption1.copyWith(
          color: AppColors.secondaryLabel(context),
          fontWeight: FontWeight.w600,
        )),
        const SizedBox(height: AppSpacing.sm),
        MetricCard(
          title: 'Sunucu Yuku',
          value: '45%',
          subtitle: 'Son 1 saatteki ortalama',
          icon: Icons.memory,
          color: AppColors.primary,
          trend: MetricTrend.up,
          trendValue: '+8%',
          compact: true,
        ),
      ],
    );
  }
}

// ============================================================================
// CHIPS SHOWCASE
// ============================================================================
class _ChipsShowcase extends StatefulWidget {
  @override
  State<_ChipsShowcase> createState() => _ChipsShowcaseState();
}

class _ChipsShowcaseState extends State<_ChipsShowcase> {
  String? _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tonal Chip', style: AppTypography.caption1.copyWith(
              color: AppColors.secondaryLabel(context),
              fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AppChip(label: 'Flutter', color: Colors.blue),
                AppChip(label: 'Dart', color: Colors.teal),
                AppChip(label: 'Firebase', color: Colors.orange),
                AppChip(
                  label: 'Silinebilir',
                  color: Colors.red,
                  onDelete: () {},
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            Text('Outlined Chip', style: AppTypography.caption1.copyWith(
              color: AppColors.secondaryLabel(context),
              fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AppChip(
                  label: 'Aktif',
                  variant: AppChipVariant.outlined,
                  color: AppColors.success,
                  icon: Icons.check_circle,
                ),
                AppChip(
                  label: 'Beklemede',
                  variant: AppChipVariant.outlined,
                  color: AppColors.warning,
                  icon: Icons.schedule,
                ),
                AppChip(
                  label: 'Hata',
                  variant: AppChipVariant.outlined,
                  color: AppColors.error,
                  icon: Icons.error,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            Text('Filled Chip', style: AppTypography.caption1.copyWith(
              color: AppColors.secondaryLabel(context),
              fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AppChip(
                  label: 'Yeni',
                  variant: AppChipVariant.filled,
                  color: AppColors.primary,
                ),
                AppChip(
                  label: 'Populer',
                  variant: AppChipVariant.filled,
                  color: AppColors.error,
                ),
                AppChip(
                  label: 'Onerilir',
                  variant: AppChipVariant.filled,
                  color: AppColors.success,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            Text('Secim Chip Grubu', style: AppTypography.caption1.copyWith(
              color: AppColors.secondaryLabel(context),
              fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: AppSpacing.sm),
            AppChoiceChips<String>(
              selectedValue: _selectedFilter,
              onSelected: (val) => setState(() => _selectedFilter = val),
              items: const [
                AppChoiceChipItem(value: 'all', label: 'Tumunu'),
                AppChoiceChipItem(value: 'active', label: 'Aktif'),
                AppChoiceChipItem(value: 'inactive', label: 'Pasif'),
                AppChoiceChipItem(value: 'pending', label: 'Beklemede'),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            Text('Tag Etiketler', style: AppTypography.caption1.copyWith(
              color: AppColors.secondaryLabel(context),
              fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AppTag(label: 'IoT', color: Colors.blue),
                AppTag(label: 'SCADA', color: Colors.green),
                AppTag(label: 'PLC', color: Colors.orange),
                AppTag(label: 'Modbus', color: Colors.purple),
                AppTag(label: 'OPC-UA', color: Colors.teal),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// BADGES SHOWCASE
// ============================================================================
class _BadgesShowcase extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Varyantlar', style: AppTypography.caption1.copyWith(
              color: AppColors.secondaryLabel(context),
              fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AppBadge(label: 'Primary', variant: AppBadgeVariant.primary),
                AppBadge(label: 'Secondary', variant: AppBadgeVariant.secondary),
                AppBadge(label: 'Success', variant: AppBadgeVariant.success),
                AppBadge(label: 'Warning', variant: AppBadgeVariant.warning),
                AppBadge(label: 'Error', variant: AppBadgeVariant.error),
                AppBadge(label: 'Info', variant: AppBadgeVariant.info),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Boyutlar', style: AppTypography.caption1.copyWith(
              color: AppColors.secondaryLabel(context),
              fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AppBadge(
                  label: 'Kucuk',
                  variant: AppBadgeVariant.primary,
                  size: AppBadgeSize.small,
                ),
                AppBadge(
                  label: 'Normal',
                  variant: AppBadgeVariant.success,
                  size: AppBadgeSize.medium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PROGRESS SHOWCASE
// ============================================================================
class _ProgressShowcase extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lineer Ilerleme', style: AppTypography.caption1.copyWith(
              color: AppColors.secondaryLabel(context),
              fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: AppSpacing.sm),
            AppProgressBar(
              value: 0.75,
              label: 'Yukleme',
              showPercentage: true,
            ),
            const SizedBox(height: AppSpacing.md),
            AppProgressBar(
              value: 0.45,
              label: 'Disk Kullanimi',
              showPercentage: true,
              color: AppColors.warning,
            ),
            const SizedBox(height: AppSpacing.md),
            AppProgressBar(
              value: 0.92,
              label: 'Bellek',
              showPercentage: true,
              color: AppColors.error,
              height: 8,
            ),

            const SizedBox(height: AppSpacing.xl),
            Text('Dairesel Ilerleme', style: AppTypography.caption1.copyWith(
              color: AppColors.secondaryLabel(context),
              fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                AppCircularProgress(
                  value: 0.35,
                  showPercentage: true,
                  color: AppColors.info,
                ),
                AppCircularProgress(
                  value: 0.65,
                  showPercentage: true,
                  color: AppColors.success,
                ),
                AppCircularProgress(
                  value: 0.90,
                  showPercentage: true,
                  color: AppColors.error,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),
            Text('Segmentli Ilerleme', style: AppTypography.caption1.copyWith(
              color: AppColors.secondaryLabel(context),
              fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: AppSpacing.sm),
            AppSegmentedProgress(
              height: 12,
              segments: [
                AppProgressSegment(value: 0.4, color: AppColors.success),
                AppProgressSegment(value: 0.3, color: AppColors.warning),
                AppProgressSegment(value: 0.2, color: AppColors.error),
                AppProgressSegment(value: 0.1, color: AppColors.systemGray),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                _LegendDot(color: AppColors.success, label: 'Basarili %40'),
                const SizedBox(width: AppSpacing.md),
                _LegendDot(color: AppColors.warning, label: 'Uyari %30'),
                const SizedBox(width: AppSpacing.md),
                _LegendDot(color: AppColors.error, label: 'Hata %20'),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),
            Text('Adim Gostergesi', style: AppTypography.caption1.copyWith(
              color: AppColors.secondaryLabel(context),
              fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: AppSpacing.sm),
            AppStepProgress(
              totalSteps: 4,
              currentStep: 3,
              stepLabels: const ['Bilgi', 'Adres', 'Odeme', 'Onay'],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.caption2.copyWith(
            color: AppColors.secondaryLabel(context),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// AVATAR SHOWCASE
// ============================================================================
class _AvatarShowcase extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Boyutlar', style: AppTypography.caption1.copyWith(
              color: AppColors.secondaryLabel(context),
              fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                AppAvatar(
                  name: 'Ahmet Yilmaz',
                  size: AppAvatarSize.small,
                ),
                const SizedBox(width: AppSpacing.md),
                AppAvatar(
                  name: 'Mehmet Demir',
                  size: AppAvatarSize.medium,
                ),
                const SizedBox(width: AppSpacing.md),
                AppAvatar(
                  name: 'Ayse Kaya',
                  size: AppAvatarSize.large,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Avatar Grubu', style: AppTypography.caption1.copyWith(
              color: AppColors.secondaryLabel(context),
              fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                AppAvatar(name: 'Ali Can'),
                const SizedBox(width: AppSpacing.sm),
                AppAvatar(name: 'Veli Oz'),
                const SizedBox(width: AppSpacing.sm),
                AppAvatar(name: 'Fatma Su'),
                const SizedBox(width: AppSpacing.sm),
                AppAvatar(name: 'Zeynep Ak'),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.systemGray5,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '+3',
                      style: AppTypography.caption1.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LIST TILE SHOWCASE
// ============================================================================
class _ListTileShowcase extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          AppListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person, color: Colors.blue),
            ),
            title: 'Profil Bilgileri',
            subtitle: 'Kisisel bilgilerinizi duzenleyin',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          Divider(height: 1, color: AppColors.separator(context)),
          AppListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.security, color: Colors.green),
            ),
            title: 'Guvenlik',
            subtitle: 'Sifre ve biyometrik ayarlar',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          Divider(height: 1, color: AppColors.separator(context)),
          AppListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.notifications, color: Colors.orange),
            ),
            title: 'Bildirimler',
            subtitle: 'Bildirim tercihlerinizi yonetin',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBadge(
                  label: '3',
                  variant: AppBadgeVariant.error,
                  size: AppBadgeSize.small,
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () {},
          ),
          Divider(height: 1, color: AppColors.separator(context)),
          AppListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.palette, color: Colors.purple),
            ),
            title: 'Tema',
            subtitle: 'Acik / Koyu / Sistem',
            trailing: Switch(
              value: true,
              onChanged: (v) {},
              activeColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FEEDBACK SHOWCASE
// ============================================================================
class _FeedbackShowcase extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppCard(
          child: Padding(
            padding: AppSpacing.cardInsets,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Snackbar Bildirimleri', style: AppTypography.caption1.copyWith(
                  color: AppColors.secondaryLabel(context),
                  fontWeight: FontWeight.w600,
                )),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    AppButton(
                      label: 'Basari',
                      size: AppButtonSize.small,
                      onPressed: () {
                        AppSnackbar.showSuccess(
                          context,
                          message: 'Islem basariyla tamamlandi!',
                        );
                      },
                    ),
                    AppButton(
                      label: 'Hata',
                      size: AppButtonSize.small,
                      variant: AppButtonVariant.destructive,
                      onPressed: () {
                        AppSnackbar.showError(
                          context,
                          message: 'Bir hata olustu!',
                        );
                      },
                    ),
                    AppButton(
                      label: 'Bilgi',
                      size: AppButtonSize.small,
                      variant: AppButtonVariant.secondary,
                      onPressed: () {
                        AppSnackbar.showInfo(
                          context,
                          message: 'Bu bir bilgi mesajidir.',
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Empty State
        AppCard(
          child: Padding(
            padding: AppSpacing.cardInsets,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bos Durum', style: AppTypography.caption1.copyWith(
                  color: AppColors.secondaryLabel(context),
                  fontWeight: FontWeight.w600,
                )),
                const SizedBox(height: AppSpacing.sm),
                AppEmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Veri Bulunamadi',
                  message: 'Henuz kayit eklenmemis. Yeni bir kayit olusturmak icin butona tiklayin.',
                  actionLabel: 'Yeni Ekle',
                  onAction: () {},
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Loading Indicators
        AppCard(
          child: Padding(
            padding: AppSpacing.cardInsets,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yukleme Gostergeleri', style: AppTypography.caption1.copyWith(
                  color: AppColors.secondaryLabel(context),
                  fontWeight: FontWeight.w600,
                )),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        const AppLoadingIndicator(),
                        const SizedBox(height: AppSpacing.xs),
                        Text('Varsayilan', style: AppTypography.caption2),
                      ],
                    ),
                    Column(
                      children: [
                        const AppLoadingIndicator(size: AppLoadingSize.small),
                        const SizedBox(height: AppSpacing.xs),
                        Text('Kucuk', style: AppTypography.caption2),
                      ],
                    ),
                    Column(
                      children: [
                        const AppLoadingIndicator(size: AppLoadingSize.large),
                        const SizedBox(height: AppSpacing.xs),
                        Text('Buyuk', style: AppTypography.caption2),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SEARCH BAR SHOWCASE
// ============================================================================
class _SearchBarShowcase extends StatefulWidget {
  @override
  State<_SearchBarShowcase> createState() => _SearchBarShowcaseState();
}

class _SearchBarShowcaseState extends State<_SearchBarShowcase> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSearchBar(
              hint: 'Bilesen ara...',
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Aranan: "$_searchQuery"',
                style: AppTypography.caption1.copyWith(
                  color: AppColors.secondaryLabel(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

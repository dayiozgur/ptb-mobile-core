import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Yapılacak Form Ekranı
///
/// Yeni yapılacak oluşturma ve mevcut yapılacakları düzenleme formu.
class TodoFormScreen extends StatefulWidget {
  final String? todoId;

  const TodoFormScreen({
    super.key,
    this.todoId,
  });

  bool get isEditing => todoId != null;

  @override
  State<TodoFormScreen> createState() => _TodoFormScreenState();
}

class _TodoFormScreenState extends State<TodoFormScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isLoadingStaff = false;
  String? _errorMessage;

  // Form fields
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  TodoPriority _selectedPriority = TodoPriority.medium;
  DateTime? _dueDate;
  String? _selectedAssignedTo;
  String? _selectedAssignedToName;

  List<Staff> _staffList = [];
  TodoItem? _existingTodo;

  @override
  void initState() {
    super.initState();
    _loadStaff();
    if (widget.isEditing) {
      _loadExistingTodo();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    setState(() => _isLoadingStaff = true);

    final tenantId = tenantService.currentTenantId;
    if (tenantId != null) {
      staffService.setTenant(tenantId);
    }

    try {
      final staffs = await staffService.getStaffs();

      if (mounted) {
        setState(() {
          _staffList = staffs.where((s) => s.isActive).toList();
          _isLoadingStaff = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load staff', e);
      if (mounted) {
        setState(() => _isLoadingStaff = false);
      }
    }
  }

  Future<void> _loadExistingTodo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final tenantId = tenantService.currentTenantId;
    if (tenantId != null) {
      todoService.setTenant(tenantId);
    }

    final userId = authService.currentUser?.id;
    if (userId != null) {
      todoService.setUser(userId);
    }

    try {
      final todo = await todoService.getTodo(widget.todoId!);

      if (todo != null && mounted) {
        setState(() {
          _existingTodo = todo;
          _titleController.text = todo.title;
          _descriptionController.text = todo.description ?? '';
          _selectedPriority = todo.priority;
          _dueDate = todo.dueDate;
          _selectedAssignedTo = todo.assignedTo;
          _selectedAssignedToName = todo.assignedToName;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load todo', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Yapılacak yüklenirken hata oluştu';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final tenantId = tenantService.currentTenantId;
      if (tenantId == null) {
        throw Exception('Tenant seçili değil');
      }

      final userId = authService.currentUser?.id;
      if (userId == null) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      todoService.setTenant(tenantId);
      todoService.setUser(userId);

      if (widget.isEditing && _existingTodo != null) {
        // Güncelleme
        await todoService.updateTodo(
          widget.todoId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          priority: _selectedPriority,
          dueDate: _dueDate,
          assignedTo: _selectedAssignedTo,
        );

        if (mounted) {
          AppSnackbar.success(context, message: 'Yapılacak güncellendi');
          context.go('/todos/${widget.todoId}');
        }
      } else {
        // Yeni oluştur
        final todo = await todoService.createTodo(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          priority: _selectedPriority,
          dueDate: _dueDate,
          assignedTo: _selectedAssignedTo,
        );

        if (mounted) {
          AppSnackbar.success(context, message: 'Yapılacak oluşturuldu');
          context.go('/todos/${todo.id}');
        }
      }
    } catch (e) {
      Logger.error('Failed to save todo', e);
      if (mounted) {
        AppSnackbar.error(context, message: 'Yapılacak kaydedilemedi');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _dueDate = date;
      });
    }
  }

  Color _getPriorityColor(TodoPriority priority) {
    switch (priority) {
      case TodoPriority.low:
        return AppColors.systemGray;
      case TodoPriority.medium:
        return AppColors.info;
      case TodoPriority.high:
        return AppColors.warning;
      case TodoPriority.urgent:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AppScaffold(
      title: widget.isEditing ? 'Yapılacağı Düzenle' : 'Yeni Yapılacak',
      onBack: () => widget.isEditing
          ? context.go('/todos/${widget.todoId}')
          : context.go('/todos'),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _errorMessage != null
              ? Center(
                  child: AppErrorView(
                    message: _errorMessage!,
                    onRetry: _loadExistingTodo,
                  ),
                )
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: AppSpacing.screenPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Temel Bilgiler
                        _buildSectionHeader('Temel Bilgiler', brightness),
                        const SizedBox(height: AppSpacing.sm),
                        _buildBasicInfoSection(brightness),

                        const SizedBox(height: AppSpacing.lg),

                        // Öncelik
                        _buildSectionHeader('Öncelik', brightness),
                        const SizedBox(height: AppSpacing.sm),
                        _buildPrioritySection(brightness),

                        const SizedBox(height: AppSpacing.lg),

                        // Zamanlama ve Atama
                        _buildSectionHeader('Zamanlama ve Atama', brightness),
                        const SizedBox(height: AppSpacing.sm),
                        _buildScheduleSection(brightness),

                        const SizedBox(height: AppSpacing.xl),

                        // Kaydet butonu
                        AppButton(
                          label: widget.isEditing ? 'Güncelle' : 'Oluştur',
                          icon: widget.isEditing ? Icons.save : Icons.add,
                          isLoading: _isSaving,
                          onPressed: _save,
                        ),

                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(String title, Brightness brightness) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary(brightness),
      ),
    );
  }

  Widget _buildBasicInfoSection(Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          children: [
            // Başlık
            AppTextField(
              controller: _titleController,
              label: 'Başlık',
              placeholder: 'Yapılacak başlığını girin',
              prefixIcon: Icons.title,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Başlık zorunludur';
                }
                if (value.trim().length < 3) {
                  return 'Başlık en az 3 karakter olmalıdır';
                }
                return null;
              },
            ),

            const SizedBox(height: AppSpacing.md),

            // Açıklama
            AppTextField(
              controller: _descriptionController,
              label: 'Açıklama',
              placeholder: 'Detayları açıklayın...',
              prefixIcon: Icons.description_outlined,
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrioritySection(Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Öncelik Seviyesi',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(brightness),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: TodoPriority.values.map((priority) {
                final isSelected = _selectedPriority == priority;
                final color = _getPriorityColor(priority);

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPriority = priority),
                    child: Container(
                      margin: EdgeInsets.only(
                        right: priority != TodoPriority.urgent
                            ? AppSpacing.xs
                            : 0,
                      ),
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.15)
                            : AppColors.systemGray6,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(
                          color: isSelected ? color : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            priority.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? color
                                  : AppColors.textSecondary(brightness),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSection(Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          children: [
            // Bitiş Tarihi
            InkWell(
              onTap: _selectDueDate,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.systemGray6,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      color: _dueDate != null
                          ? AppColors.primary
                          : AppColors.textSecondary(brightness),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bitiş Tarihi',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(brightness),
                            ),
                          ),
                          Text(
                            _dueDate != null
                                ? '${_dueDate!.day.toString().padLeft(2, '0')}/${_dueDate!.month.toString().padLeft(2, '0')}/${_dueDate!.year}'
                                : 'Tarih seçin',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: _dueDate != null
                                  ? AppColors.textPrimary(brightness)
                                  : AppColors.textSecondary(brightness),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_dueDate != null)
                      IconButton(
                        icon: Icon(Icons.clear, color: AppColors.systemGray),
                        onPressed: () => setState(() => _dueDate = null),
                      )
                    else
                      Icon(Icons.chevron_right, color: AppColors.systemGray),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Atanan Kişi
            InkWell(
              onTap: _showStaffPicker,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.systemGray6,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_add_outlined,
                      color: _selectedAssignedTo != null
                          ? AppColors.primary
                          : AppColors.textSecondary(brightness),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Atanan Kişi',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(brightness),
                            ),
                          ),
                          _isLoadingStaff
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator.adaptive(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _selectedAssignedToName ?? 'Kişi seçin',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: _selectedAssignedTo != null
                                        ? AppColors.textPrimary(brightness)
                                        : AppColors.textSecondary(brightness),
                                  ),
                                ),
                        ],
                      ),
                    ),
                    if (_selectedAssignedTo != null)
                      IconButton(
                        icon: Icon(Icons.clear, color: AppColors.systemGray),
                        onPressed: () => setState(() {
                          _selectedAssignedTo = null;
                          _selectedAssignedToName = null;
                        }),
                      )
                    else
                      Icon(Icons.chevron_right, color: AppColors.systemGray),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStaffPicker() {
    if (_staffList.isEmpty) {
      AppSnackbar.error(context, message: 'Personel listesi yüklenemedi');
      return;
    }

    final brightness = Theme.of(context).brightness;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.systemGray4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Kişi Seçin',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                ],
              ),
            ),

            // Personel listesi
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal),
                itemCount: _staffList.length,
                separatorBuilder: (_, __) => Divider(
                  color: AppColors.separator(context),
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final staff = _staffList[index];
                  final isSelected = _selectedAssignedTo == staff.id;

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : AppColors.systemGray6,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.person,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary(brightness),
                      ),
                    ),
                    title: Text(
                      staff.fullName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary(brightness),
                      ),
                    ),
                    subtitle: staff.email != null
                        ? Text(
                            staff.email!,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(brightness),
                            ),
                          )
                        : null,
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: AppColors.primary)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedAssignedTo = staff.id;
                        _selectedAssignedToName = staff.fullName;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

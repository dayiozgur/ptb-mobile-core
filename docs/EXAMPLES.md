# 💡 Code Examples

Real-world usage examples and patterns.

## İçindekiler

1. [Authentication Flow](#authentication-flow)
2. [API Integration](#api-integration)
3. [Form Handling](#form-handling)
4. [List Management](#list-management)
5. [Real-time Data](#real-time-data)
6. [Offline Support](#offline-support)
7. [Multi-Tenant](#multi-tenant)

## 🔐 Authentication Flow

### Complete Login Implementation
```dart
// login_screen.dart

class LoginScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    
    final authService = ref.read(authServiceProvider);
    
    final result = await authService.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
    
    if (!mounted) return;
    
    result.when(
      success: (user) {
        Navigator.pushReplacementNamed(context, '/home');
      },
      failure: (error) {
        AppSnackbar.show(
          context: context,
          message: error,
          type: SnackbarType.error,
        );
      },
      requiresTenantSelection: (tenants) {
        _showTenantSelector(tenants);
      },
    );
  }
  
  void _showTenantSelector(List<Tenant> tenants) {
    AppBottomSheet.show(
      context: context,
      title: 'Select Organization',
      child: TenantSelector(
        tenants: tenants,
        onSelected: (tenant) async {
          await ref.read(tenantServiceProvider).setTenant(tenant.id);
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        },
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    
    return AppScaffold(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Spacer(),
                
                // Logo
                Image.asset(
                  'assets/logo.png',
                  height: 80,
                ),
                
                SizedBox(height: AppSpacing.xl),
                
                Text(
                  'Welcome Back',
                  style: AppTypography.largeTitle,
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: AppSpacing.xxl),
                
                // Email
                AppTextField(
                  label: 'Email',
                  placeholder: 'you@example.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                  prefixIcon: Icon(CupertinoIcons.mail),
                ),
                
                SizedBox(height: AppSpacing.md),
                
                // Password
                AppTextField(
                  label: 'Password',
                  placeholder: 'Enter your password',
                  controller: _passwordController,
                  obscureText: true,
                  validator: Validators.required,
                  prefixIcon: Icon(CupertinoIcons.lock),
                ),
                
                SizedBox(height: AppSpacing.sm),
                
                // Remember me
                Row(
                  children: [
                    CupertinoSwitch(
                      value: _rememberMe,
                      onChanged: (value) {
                        setState(() => _rememberMe = value);
                      },
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Text('Remember me', style: AppTypography.body),
                    Spacer(),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                      child: Text(
                        'Forgot?',
                        style: AppTypography.footnote.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: AppSpacing.lg),
                
                // Login button
                AppButton(
                  label: 'Sign In',
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.large,
                  isFullWidth: true,
                  isLoading: authState.isLoading,
                  onPressed: _handleLogin,
                ),
                
                SizedBox(height: AppSpacing.md),
                
                // Biometric login
                if (_biometricAvailable)
                  AppButton(
                    label: 'Sign in with Face ID',
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.large,
                    isFullWidth: true,
                    icon: CupertinoIcons.person_crop_circle,
                    onPressed: _handleBiometricLogin,
                  ),
                
                Spacer(),
                
                // Sign up
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Don\'t have an account? ', style: AppTypography.footnote),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pushNamed(context, '/signup'),
                      child: Text(
                        'Sign Up',
                        style: AppTypography.footnote.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## 🌐 API Integration

### Complete CRUD Example
```dart
// device_repository.dart

class DeviceRepository {
  final ApiClient _apiClient;
  final CacheManager _cache;
  
  DeviceRepository(this._apiClient, this._cache);
  
  // GET all devices
  Future<List<Device>> getDevices({
    String? status,
    int? limit,
  }) async {
    return await _cache.getCached(
      key: 'devices_${status ?? 'all'}',
      fetchFn: () async {
        final devices = await _apiClient.querySupabase<Device>(
          table: 'devices',
          fromJson: (json) => Device.fromJson(json),
          filter: (query) {
            var q = query.eq('tenant_id', currentTenantId);
            if (status != null) {
              q = q.eq('status', status);
            }
            if (limit != null) {
              q = q.limit(limit);
            }
            return q.order('created_at', ascending: false);
          },
        );
        return devices;
      },
      fromJson: (json) => Device.fromJson(json),
      ttl: Duration(minutes: 5),
    );
  }
  
  // GET single device
  Future<Device> getDevice(String id) async {
    return await _cache.getCached(
      key: 'device_$id',
      fetchFn: () async {
        final devices = await _apiClient.querySupabase<Device>(
          table: 'devices',
          fromJson: (json) => Device.fromJson(json),
          filter: (query) => query.eq('id', id).single(),
        );
        return devices.first;
      },
      fromJson: (json) => Device.fromJson(json),
      ttl: Duration(minutes: 10),
    );
  }
  
  // POST create device
  Future<Device> createDevice(Device device) async {
    final response = await _apiClient.post<Device>(
      '/api/devices',
      data: device.toJson(),
      fromJson: (json) => Device.fromJson(json),
    );
    
    return response.when(
      success: (device) async {
        // Invalidate list cache
        await _cache.invalidate('devices_all');
        return device;
      },
      failure: (error) => throw Exception(error.message),
    );
  }
  
  // PUT update device
  Future<Device> updateDevice(String id, Device device) async {
    final response = await _apiClient.put<Device>(
      '/api/devices/$id',
      data: device.toJson(),
      fromJson: (json) => Device.fromJson(json),
    );
    
    return response.when(
      success: (device) async {
        // Invalidate caches
        await _cache.invalidate('device_$id');
        await _cache.invalidate('devices_all');
        return device;
      },
      failure: (error) => throw Exception(error.message),
    );
  }
  
  // DELETE device
  Future<void> deleteDevice(String id) async {
    final response = await _apiClient.delete(
      '/api/devices/$id',
    );
    
    return response.when(
      success: (_) async {
        await _cache.invalidate('device_$id');
        await _cache.invalidate('devices_all');
      },
      failure: (error) => throw Exception(error.message),
    );
  }
}

// Provider
final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepository(
    ref.watch(apiClientProvider),
    ref.watch(cacheManagerProvider),
  );
});

// State notifier
class DevicesNotifier extends StateNotifier<AsyncValue<List<Device>>> {
  final DeviceRepository repository;
  
  DevicesNotifier(this.repository) : super(AsyncValue.loading()) {
    loadDevices();
  }
  
  Future<void> loadDevices() async {
    state = AsyncValue.loading();
    
    try {
      final devices = await repository.getDevices();
      state = AsyncValue.data(devices);
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }
  
  Future<void> addDevice(Device device) async {
    try {
      await repository.createDevice(device);
      await loadDevices();  // Reload
    } catch (error) {
      rethrow;
    }
  }
  
  Future<void> removeDevice(String id) async {
    try {
      await repository.deleteDevice(id);
      await loadDevices();  // Reload
    } catch (error) {
      rethrow;
    }
  }
}

final devicesProvider = StateNotifierProvider<DevicesNotifier, AsyncValue<List<Device>>>((ref) {
  return DevicesNotifier(ref.watch(deviceRepositoryProvider));
});

---

## 📝 Form Handling

### Complete Form with Validation
```dart
// add_device_form.dart

class AddDeviceForm extends ConsumerStatefulWidget {
  @override
  ConsumerState<AddDeviceForm> createState() => _AddDeviceFormState();
}

class _AddDeviceFormState extends ConsumerState<AddDeviceForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _serialController = TextEditingController();
  final _notesController = TextEditingController();
  
  String? _selectedType;
  String? _selectedLocation;
  bool _isActive = true;
  bool _isSubmitting = false;
  
  @override
  void dispose() {
    _nameController.dispose();
    _serialController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSubmitting = true);
    
    try {
      final device = Device(
        id: '',
        name: _nameController.text,
        serialNumber: _serialController.text,
        type: _selectedType!,
        location: _selectedLocation,
        notes: _notesController.text,
        isActive: _isActive,
        tenantId: currentTenantId,
      );
      
      await ref.read(devicesProvider.notifier).addDevice(device);
      
      if (!mounted) return;
      
      AppSnackbar.show(
        context: context,
        message: 'Device added successfully',
        type: SnackbarType.success,
      );
      
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      
      AppSnackbar.show(
        context: context,
        message: 'Failed to add device',
        type: SnackbarType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Add Device',
      child: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(AppSpacing.screenHorizontal),
          children: [
            // Device Name
            AppTextField(
              label: 'Device Name',
              placeholder: 'e.g., Main Gateway',
              controller: _nameController,
              validator: Validators.required,
              prefixIcon: Icon(CupertinoIcons.device_phone_portrait),
            ),
            
            SizedBox(height: AppSpacing.md),
            
            // Serial Number
            AppTextField(
              label: 'Serial Number',
              placeholder: 'e.g., SN123456',
              controller: _serialController,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Serial number is required';
                }
                if (value.length < 6) {
                  return 'Must be at least 6 characters';
                }
                return null;
              },
              prefixIcon: Icon(CupertinoIcons.barcode),
            ),
            
            SizedBox(height: AppSpacing.md),
            
            // Device Type
            AppDropdown<String>(
              label: 'Device Type',
              value: _selectedType,
              placeholder: 'Select type',
              items: [
                DropdownItem(value: 'gateway', label: 'Gateway'),
                DropdownItem(value: 'sensor', label: 'Sensor'),
                DropdownItem(value: 'controller', label: 'Controller'),
              ],
              onChanged: (value) {
                setState(() => _selectedType = value);
              },
              validator: (value) {
                if (value == null) return 'Please select a type';
                return null;
              },
            ),
            
            SizedBox(height: AppSpacing.md),
            
            // Location
            AppDropdown<String>(
              label: 'Location',
              value: _selectedLocation,
              placeholder: 'Select location (optional)',
              items: [
                DropdownItem(value: 'building_a', label: 'Building A'),
                DropdownItem(value: 'building_b', label: 'Building B'),
                DropdownItem(value: 'warehouse', label: 'Warehouse'),
              ],
              onChanged: (value) {
                setState(() => _selectedLocation = value);
              },
            ),
            
            SizedBox(height: AppSpacing.md),
            
            // Notes
            AppTextField(
              label: 'Notes',
              placeholder: 'Additional information (optional)',
              controller: _notesController,
              maxLines: 4,
            ),
            
            SizedBox(height: AppSpacing.md),
            
            // Active Toggle
            AppListTile(
              title: 'Active',
              subtitle: 'Device will be monitored',
              leading: Icon(CupertinoIcons.power),
              trailing: CupertinoSwitch(
                value: _isActive,
                onChanged: (value) {
                  setState(() => _isActive = value);
                },
              ),
              showDivider: false,
            ),
            
            SizedBox(height: AppSpacing.xl),
            
            // Submit Button
            AppButton(
              label: 'Add Device',
              variant: AppButtonVariant.primary,
              size: AppButtonSize.large,
              isFullWidth: true,
              isLoading: _isSubmitting,
              onPressed: _handleSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 📱 List Management

### Infinite Scroll List
```dart
// device_list_screen.dart

class DeviceListScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends ConsumerState<DeviceListScreen> {
  final _scrollController = ScrollController();
  String _searchQuery = '';
  String? _filterStatus;
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      // Load more when 80% scrolled
      ref.read(devicesProvider.notifier).loadMore();
    }
  }
  
  List<Device> _getFilteredDevices(List<Device> devices) {
    return devices.where((device) {
      // Search filter
      if (_searchQuery.isNotEmpty &&
          !device.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      
      // Status filter
      if (_filterStatus != null && device.status != _filterStatus) {
        return false;
      }
      
      return true;
    }).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);
    
    return AppScaffold(
      title: 'Devices',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIconButton(
            icon: CupertinoIcons.search,
            onPressed: () => _showSearch(),
          ),
          AppIconButton(
            icon: CupertinoIcons.add,
            onPressed: () => Navigator.pushNamed(context, '/add-device'),
          ),
        ],
      ),
      child: devicesAsync.when(
        data: (devices) {
          final filtered = _getFilteredDevices(devices);
          
          if (filtered.isEmpty) {
            return AppEmptyState(
              icon: _searchQuery.isNotEmpty 
                ? CupertinoIcons.search 
                : CupertinoIcons.tray,
              title: _searchQuery.isNotEmpty 
                ? 'No Results' 
                : 'No Devices',
              message: _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Add your first device to get started',
              actionLabel: _searchQuery.isEmpty ? 'Add Device' : null,
              onAction: _searchQuery.isEmpty 
                ? () => Navigator.pushNamed(context, '/add-device')
                : null,
            );
          }
          
          return Column(
            children: [
              // Filters
              _buildFilters(),
              
              // List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.refresh(devicesProvider.future),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: filtered.length + 1,
                    itemBuilder: (context, index) {
                      if (index == filtered.length) {
                        // Load more indicator
                        if (devices.hasMore) {
                          return Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: AppLoadingIndicator(),
                          );
                        }
                        return SizedBox.shrink();
                      }
                      
                      final device = filtered[index];
                      return _buildDeviceCard(device);
                    },
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => AppLoadingIndicator(),
        error: (error, stack) => AppErrorView(
          error: error,
          onRetry: () => ref.refresh(devicesProvider),
        ),
      ),
    );
  }
  
  Widget _buildFilters() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoSegmentedControl<String?>(
              children: {
                null: Text('All'),
                'online': Text('Online'),
                'offline': Text('Offline'),
              },
              groupValue: _filterStatus,
              onValueChanged: (value) {
                setState(() => _filterStatus = value);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDeviceCard(Device device) {
    return Dismissible(
      key: Key(device.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: AppSpacing.md),
        color: AppColors.error,
        child: Icon(
          CupertinoIcons.delete,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text('Delete Device'),
            content: Text('Are you sure you want to delete ${device.name}?'),
            actions: [
              CupertinoDialogAction(
                child: Text('Cancel'),
                onPressed: () => Navigator.pop(context, false),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                child: Text('Delete'),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        ref.read(devicesProvider.notifier).removeDevice(device.id);
        AppSnackbar.show(
          context: context,
          message: 'Device deleted',
          type: SnackbarType.info,
        );
      },
      child: AppCard(
        onTap: () => Navigator.pushNamed(
          context,
          '/device-detail',
          arguments: device.id,
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: device.isOnline 
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.gray5,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                CupertinoIcons.device_phone_portrait,
                color: device.isOnline 
                  ? AppColors.success 
                  : AppColors.gray,
              ),
            ),
            
            SizedBox(width: AppSpacing.md),
            
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: AppTypography.headline,
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${device.type} • ${device.location ?? 'No location'}',
                    style: AppTypography.footnote.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            
            // Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppBadge(
                  label: device.status,
                  color: device.isOnline 
                    ? AppColors.success 
                    : AppColors.gray,
                ),
                SizedBox(height: 4),
                Text(
                  Formatters.relativeTime(device.lastSeen),
                  style: AppTypography.caption1.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _showSearch() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 120,
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        child: SafeArea(
          child: CupertinoSearchTextField(
            placeholder: 'Search devices',
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
        ),
      ),
    );
  }
}
```

---

## ⚡ Real-time Data

### Supabase Realtime Subscription
```dart
// realtime_devices_provider.dart

class RealtimeDevicesNotifier extends StateNotifier<AsyncValue<List<Device>>> {
  final SupabaseClient supabase;
  RealtimeChannel? _channel;
  
  RealtimeDevicesNotifier(this.supabase) : super(AsyncValue.loading()) {
    _initialize();
  }
  
  Future<void> _initialize() async {
    try {
      // Load initial data
      final devices = await _loadDevices();
      state = AsyncValue.data(devices);
      
      // Subscribe to changes
      _subscribeToChanges();
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }
  
  Future<List<Device>> _loadDevices() async {
    final response = await supabase
      .from('devices')
      .select()
      .eq('tenant_id', currentTenantId);
    
    return (response as List)
      .map((json) => Device.fromJson(json))
      .toList();
  }
  
  void _subscribeToChanges() {
    _channel = supabase
      .channel('devices')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'devices',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'tenant_id',
          value: currentTenantId,
        ),
        callback: (payload) {
          _handleRealtimeEvent(payload);
        },
      )
      .subscribe();
  }
  
  void _handleRealtimeEvent(PostgresChangePayload payload) {
    state.whenData((devices) {
      final newDevices = [...devices];
      
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
          final newDevice = Device.fromJson(payload.newRecord);
          newDevices.add(newDevice);
          break;
          
        case PostgresChangeEvent.update:
          final updatedDevice = Device.fromJson(payload.newRecord);
          final index = newDevices.indexWhere((d) => d.id == updatedDevice.id);
          if (index != -1) {
            newDevices[index] = updatedDevice;
          }
          break;
          
        case PostgresChangeEvent.delete:
          final deletedId = payload.oldRecord['id'];
          newDevices.removeWhere((d) => d.id == deletedId);
          break;
      }
      
      state = AsyncValue.data(newDevices);
    });
  }
  
  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final realtimeDevicesProvider = StateNotifierProvider<RealtimeDevicesNotifier, AsyncValue<List<Device>>>((ref) {
  return RealtimeDevicesNotifier(ref.watch(supabaseProvider));
});

// Usage in widget
class DeviceMonitorScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(realtimeDevicesProvider);
    
    return devicesAsync.when(
      data: (devices) => DeviceList(devices: devices),
      loading: () => AppLoadingIndicator(),
      error: (error, stack) => AppErrorView(error: error),
    );
  }
}
```

---

## 💾 Offline Support

### Offline-First Repository
```dart
// offline_device_repository.dart

class OfflineDeviceRepository {
  final ApiClient apiClient;
  final LocalDatabase localDb;
  final ConnectivityService connectivity;
  
  OfflineDeviceRepository({
    required this.apiClient,
    required this.localDb,
    required this.connectivity,
  });
  
  // Get devices (offline-first)
  Future<List<Device>> getDevices() async {
    // Try local first
    final localDevices = await localDb.getDevices();
    
    if (await connectivity.isOnline) {
      try {
        // Fetch from server
        final serverDevices = await apiClient.querySupabase<Device>(
          table: 'devices',
          fromJson: (json) => Device.fromJson(json),
        );
        
        // Update local database
        await localDb.replaceDevices(serverDevices);
        
        return serverDevices;
      } catch (error) {
        // Return cached data on error
        return localDevices;
      }
    } else {
      // Offline, return cached
      return localDevices;
    }
  }
  
  // Create device (with offline queue)
  Future<Device> createDevice(Device device) async {
    if (await connectivity.isOnline) {
      try {
        // Create on server
        final created = await apiClient.post<Device>(
          '/api/devices',
          data: device.toJson(),
          fromJson: (json) => Device.fromJson(json),
        );
        
        return created.when(
          success: (device) async {
            // Save locally
            await localDb.insertDevice(device);
            return device;
          },
          failure: (error) => throw Exception(error.message),
        );
      } catch (error) {
        // Queue for later
        await _queueForSync('create', device);
        rethrow;
      }
    } else {
      // Queue for sync
      await _queueForSync('create', device);
      
      // Save locally with temp ID
      final tempDevice = device.copyWith(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        isPending: true,
      );
      await localDb.insertDevice(tempDevice);
      
      return tempDevice;
    }
  }
  
  // Update device
  Future<Device> updateDevice(Device device) async {
    // Update local immediately (optimistic update)
    await localDb.updateDevice(device);
    
    if (await connectivity.isOnline) {
      try {
        final updated = await apiClient.put<Device>(
          '/api/devices/${device.id}',
          data: device.toJson(),
          fromJson: (json) => Device.fromJson(json),
        );
        
        return updated.when(
          success: (device) => device,
          failure: (error) {
            // Revert on error
            // (would need to store previous state)
            throw Exception(error.message);
          },
        );
      } catch (error) {
        await _queueForSync('update', device);
        rethrow;
      }
    } else {
      await _queueForSync('update', device);
      return device;
    }
  }
  
  // Delete device
  Future<void> deleteDevice(String id) async {
    // Delete locally immediately
    await localDb.deleteDevice(id);
    
    if (await connectivity.isOnline) {
      try {
        await apiClient.delete('/api/devices/$id');
      } catch (error) {
        await _queueForSync('delete', Device(id: id));
        rethrow;
      }
    } else {
      await _queueForSync('delete', Device(id: id));
    }
  }
  
  // Sync queued operations
  Future<void> syncPendingChanges() async {
    if (!await connectivity.isOnline) return;
    
    final pendingOps = await localDb.getPendingOperations();
    
    for (final op in pendingOps) {
      try {
        switch (op.operation) {
          case 'create':
            await apiClient.post('/api/devices', data: op.data);
            break;
          case 'update':
            await apiClient.put('/api/devices/${op.data['id']}', data: op.data);
            break;
          case 'delete':
            await apiClient.delete('/api/devices/${op.data['id']}');
            break;
        }
        
        // Remove from queue
        await localDb.removePendingOperation(op.id);
      } catch (error) {
        Logger.error('Sync failed for operation ${op.id}', error);
        // Keep in queue for retry
      }
    }
  }
  
  Future<void> _queueForSync(String operation, Device device) async {
    await localDb.queueForSync(
      table: 'devices',
      operation: operation,
      data: device.toJson(),
    );
  }
}

// Connectivity service
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  
  Stream<bool> get onlineStream {
    return _connectivity.onConnectivityChanged.map((result) {
      return result != ConnectivityResult.none;
    });
  }
  
  Future<bool> get isOnline async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }
}

// Auto-sync on reconnect
class AutoSyncService {
  final OfflineDeviceRepository repository;
  final ConnectivityService connectivity;
  StreamSubscription? _subscription;
  
  AutoSyncService(this.repository, this.connectivity);
  
  void startAutoSync() {
    _subscription = connectivity.onlineStream.listen((isOnline) {
      if (isOnline) {
        repository.syncPendingChanges();
      }
    });
  }
  
  void stopAutoSync() {
    _subscription?.cancel();
  }
}
```

---

## 🏢 Multi-Tenant

### Tenant Management
```dart
// tenant_service.dart

class TenantService {
  final SupabaseClient supabase;
  final SecureStorage storage;
  
  String? _currentTenantId;
  
  TenantService(this.supabase, this.storage);
  
  String? get currentTenantId => _currentTenantId;
  
  // Get user's tenants
  Future<List<Tenant>> getUserTenants(String userId) async {
    final response = await supabase
      .from('user_tenants')
      .select('*, tenant:tenants(*)')
      .eq('user_id', userId);
    
    return (response as List)
      .map((json) => Tenant.fromJson(json['tenant']))
      .toList();
  }
  
  // Set active tenant
  Future<void> setTenant(String tenantId) async {
    _currentTenantId = tenantId;
    
    // Save to storage
    await storage.write(
      key: 'current_tenant_id',
      value: tenantId,
    );
    
    // Set Supabase RLS context
    await supabase.rpc('set_tenant', params: {
      'tenant_id': tenantId,
    });
  }
  
  // Switch tenant
  Future<void> switchTenant(String newTenantId) async {
    await setTenant(newTenantId);
    
    // Clear cache for old tenant
    await getIt<CacheManager>().clearAll();
    
    // Reload app data
    // (trigger providers to refresh)
  }
  
  // Load saved tenant
  Future<void> loadSavedTenant() async {
    final savedId = await storage.read('current_tenant_id');
    if (savedId != null) {
      _currentTenantId = savedId;
      await supabase.rpc('set_tenant', params: {
        'tenant_id': savedId,
      });
    }
  }
}

// Tenant selector widget
class TenantSelector extends ConsumerWidget {
  final List<Tenant> tenants;
  final ValueChanged<Tenant> onSelected;
  
  const TenantSelector({
    required this.tenants,
    required this.onSelected,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 400,
      child: ListView.builder(
        itemCount: tenants.length,
        itemBuilder: (context, index) {
          final tenant = tenants[index];
          
          return AppListTile(
            title: tenant.name,
            subtitle: '${tenant.memberCount} members',
            leading: CircleAvatar(
              backgroundImage: tenant.logoUrl != null
                ? CachedNetworkImageProvider(tenant.logoUrl!)
                : null,
              child: tenant.logoUrl == null
                ? Text(tenant.name[0].toUpperCase())
                : null,
            ),
            trailing: Icon(CupertinoIcons.chevron_right),
            onTap: () {
              Navigator.pop(context);
              onSelected(tenant);
            },
          );
        },
      ),
    );
  }
}

// Tenant switcher in app
class TenantSwitcher extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTenant = ref.watch(currentTenantProvider);
    
    return GestureDetector(
      onTap: () => _showTenantSelector(context, ref),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.gray6,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundImage: currentTenant.logoUrl != null
                ? CachedNetworkImageProvider(currentTenant.logoUrl!)
                : null,
              child: currentTenant.logoUrl == null
                ? Text(
                    currentTenant.name[0].toUpperCase(),
                    style: TextStyle(fontSize: 10),
                  )
                : null,
            ),
            SizedBox(width: AppSpacing.xs),
            Text(
              currentTenant.name,
              style: AppTypography.footnote.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(
              CupertinoIcons.chevron_down,
              size: 12,
            ),
          ],
        ),
      ),
    );
  }
  
  void _showTenantSelector(BuildContext context, WidgetRef ref) async {
    final tenants = await ref.read(userTenantsProvider.future);
    
    if (!context.mounted) return;
    
    AppBottomSheet.show(
      context: context,
      title: 'Switch Organization',
      child: TenantSelector(
        tenants: tenants,
        onSelected: (tenant) {
          ref.read(tenantServiceProvider).switchTenant(tenant.id);
        },
      ),
    );
  }
}
```

---

**Sonraki:** [Contributing →](../CONTRIBUTING.md)

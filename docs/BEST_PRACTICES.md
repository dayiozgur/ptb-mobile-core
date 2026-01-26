# 🎯 Best Practices

## İçindekiler

1. [Code Organization](#code-organization)
2. [State Management](#state-management)
3. [Performance](#performance)
4. [Security](#security)
5. [Error Handling](#error-handling)
6. [Testing](#testing)
7. [Accessibility](#accessibility)
8. [Common Pitfalls](#common-pitfalls)

## 📁 Code Organization

### Feature-First Structure

**✅ DOĞRU:**
```dart
lib/
├── features/
│   ├── devices/
│   │   ├── presentation/
│   │   │   ├── device_list_screen.dart
│   │   │   ├── device_detail_screen.dart
│   │   │   └── widgets/
│   │   ├── data/
│   │   │   └── device_repository.dart
│   │   └── domain/
│   │       └── device_entity.dart
│   └── analytics/
│       ├── presentation/
│       ├── data/
│       └── domain/
```

**❌ YANLIŞ:**
```dart
lib/
├── screens/  // Mixed features
│   ├── device_list.dart
│   ├── analytics_page.dart
│   └── profile_screen.dart
├── widgets/  // All widgets together
└── services/ // All services together
```

### Import Organization

**✅ DOĞRU:**
```dart
// Dart imports
import 'dart:async';
import 'dart:convert';

// Flutter imports
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// Package imports
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:riverpod/riverpod.dart';

// Relative imports
import '../data/device_repository.dart';
import '../domain/device_entity.dart';
import 'widgets/device_card.dart';
```

**❌ YANLIŞ:**
```dart
import '../data/device_repository.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:riverpod/riverpod.dart';
// Random order, hard to read
```

### File Naming

**✅ DOĞRU:**
```
device_list_screen.dart
auth_service.dart
app_button.dart
```

**❌ YANLIŞ:**
```
DeviceList.dart          // PascalCase
devicelistscreen.dart    // No separator
device-list-screen.dart  // Kebab case
```

---

## 🔄 State Management

### Provider Naming

**✅ DOĞRU:**
```dart
// Services
final authServiceProvider = Provider<AuthService>((ref) => ...);

// State notifiers
final devicesProvider = StateNotifierProvider<DevicesNotifier, AsyncValue<List<Device>>>(...);

// Future providers
final userProvider = FutureProvider<User?>((ref) async => ...);

// Stream providers
final authStateProvider = StreamProvider<AuthState>((ref) => ...);
```

### State Scope

**✅ DOĞRU - Global state:**
```dart
// In providers file
final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

// Usage anywhere
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    // ...
  }
}
```

**✅ DOĞRU - Local state:**
```dart
class DeviceDetailScreen extends StatefulWidget {
  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  bool _isExpanded = false;  // Local UI state
  
  @override
  Widget build(BuildContext context) {
    // Only affects this widget
  }
}
```

**❌ YANLIŞ - Using provider for local UI state:**
```dart
final isExpandedProvider = StateProvider<bool>((ref) => false);

// This creates unnecessary global state
```

### Avoiding Unnecessary Rebuilds

**✅ DOĞRU - Select specific data:**
```dart
// Only rebuilds when user name changes
final userName = ref.watch(userProvider.select((user) => user?.name));

Text(userName ?? 'Guest');
```

**❌ YANLIŞ - Watch entire object:**
```dart
// Rebuilds on ANY user change
final user = ref.watch(userProvider);

Text(user?.name ?? 'Guest');
```

---

## ⚡ Performance

### Image Optimization

**✅ DOĞRU:**
```dart
CachedNetworkImage(
  imageUrl: device.imageUrl,
  cacheKey: 'device_${device.id}',
  memCacheWidth: 400,  // Resize for display
  placeholder: (context, url) => ShimmerPlaceholder(),
  errorWidget: (context, url, error) => Icon(Icons.error),
)
```

**❌ YANLIŞ:**
```dart
Image.network(
  device.imageUrl,  // No caching, no optimization
)
```

### List Performance

**✅ DOĞRU - ListView.builder for long lists:**
```dart
ListView.builder(
  itemCount: devices.length,
  itemBuilder: (context, index) {
    final device = devices[index];
    return DeviceCard(device: device);
  },
)
```

**❌ YANLIŞ - Column for long lists:**
```dart
Column(
  children: devices.map((device) => DeviceCard(device: device)).toList(),
  // All items built at once, memory intensive
)
```

### Const Widgets

**✅ DOĞRU:**
```dart
const SizedBox(height: 16)
const Padding(padding: EdgeInsets.all(8.0))
const Divider()

// Reused, not rebuilt
```

**❌ YANLIŞ:**
```dart
SizedBox(height: 16)  // Rebuilt every time
```

### Lazy Loading

**✅ DOĞRU:**
```dart
class DeviceListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesProvider);
    
    return ListView.builder(
      itemCount: devices.length + 1,
      itemBuilder: (context, index) {
        if (index == devices.length) {
          // Load more trigger
          if (devices.hasMore) {
            ref.read(devicesProvider.notifier).loadMore();
            return AppLoadingIndicator();
          }
          return SizedBox.shrink();
        }
        
        return DeviceCard(device: devices[index]);
      },
    );
  }
}
```

---

## 🔒 Security

### Sensitive Data Storage

**✅ DOĞRU:**
```dart
final secureStorage = getIt<SecureStorage>();

// Store securely
await secureStorage.write(
  key: 'access_token',
  value: token,
);

// Read securely
final token = await secureStorage.read('access_token');
```

**❌ YANLIŞ:**
```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setString('access_token', token);
// Stored in plain text!
```

### API Keys

**✅ DOĞRU:**
```dart
// In environment config
class Environment {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseKey = String.fromEnvironment('SUPABASE_KEY');
}

// In build command
flutter build apk --dart-define=SUPABASE_URL=xxx --dart-define=SUPABASE_KEY=xxx
```

**❌ YANLIŞ:**
```dart
// Hardcoded in code
const supabaseUrl = 'https://xxx.supabase.co';
const supabaseKey = 'eyJxxx...';  // Exposed in source!
```

### Input Validation

**✅ DOĞRU - Server-side validation:**
```dart
// Client validation
if (!Validators.email(email)) {
  showError('Invalid email');
  return;
}

// Still validate on server!
final result = await apiClient.post('/register', data: {
  'email': email,  // Server validates again
});
```

**❌ YANLIŞ - Only client validation:**
```dart
if (Validators.email(email)) {
  // Send to server assuming it's valid
  // Attacker can bypass client validation!
}
```

### SQL Injection Prevention

**✅ DOĞRU - Use parameterized queries:**
```dart
// Supabase automatically handles this
await supabase
  .from('devices')
  .select()
  .eq('name', userInput);  // Safe
```

**❌ YANLIŞ - String concatenation:**
```dart
// Never do this!
final query = "SELECT * FROM devices WHERE name = '$userInput'";
// SQL injection vulnerable!
```

---

## 🚨 Error Handling

### Graceful Degradation

**✅ DOĞRU:**
```dart
class DeviceListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesProvider);
    
    return devicesAsync.when(
      data: (devices) => devices.isEmpty
        ? AppEmptyState(
            title: 'No Devices',
            message: 'Add your first device',
            onAction: () => _addDevice(),
          )
        : DeviceList(devices: devices),
      loading: () => AppLoadingIndicator(),
      error: (error, stack) => AppErrorView(
        error: error,
        onRetry: () => ref.refresh(devicesProvider),
      ),
    );
  }
}
```

**❌ YANLIŞ - Show raw error:**
```dart
error: (error, stack) => Text(error.toString())
// Unfriendly, no recovery option
```

### Try-Catch Best Practices

**✅ DOĞRU:**
```dart
Future<void> saveDevice(Device device) async {
  try {
    await deviceRepository.save(device);
    AppSnackbar.show(
      context: context,
      message: 'Device saved',
      type: SnackbarType.success,
    );
  } on NetworkException catch (e) {
    AppSnackbar.show(
      context: context,
      message: 'No internet connection',
      type: SnackbarType.error,
    );
    Logger.error('Network error', e);
  } on ValidationException catch (e) {
    AppSnackbar.show(
      context: context,
      message: e.message,
      type: SnackbarType.warning,
    );
  } catch (e, stack) {
    AppSnackbar.show(
      context: context,
      message: 'An error occurred',
      type: SnackbarType.error,
    );
    Logger.error('Unexpected error', e, stack);
  }
}
```

**❌ YANLIŞ - Generic catch:**
```dart
try {
  await deviceRepository.save(device);
} catch (e) {
  print(e);  // No user feedback, no logging
}
```

---

## 🧪 Testing

### Widget Test Coverage

**✅ DOĞRU:**
```dart
group('AppButton', () {
  testWidgets('renders correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppButton(
          label: 'Test',
          onPressed: () {},
        ),
      ),
    );
    
    expect(find.text('Test'), findsOneWidget);
  });
  
  testWidgets('calls onPressed when tapped', (tester) async {
    var pressed = false;
    
    await tester.pumpWidget(
      MaterialApp(
        home: AppButton(
          label: 'Test',
          onPressed: () => pressed = true,
        ),
      ),
    );
    
    await tester.tap(find.byType(AppButton));
    expect(pressed, isTrue);
  });
  
  testWidgets('shows loading when isLoading', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppButton(
          label: 'Test',
          isLoading: true,
        ),
      ),
    );
    
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
  
  testWidgets('is disabled when onPressed is null', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppButton(
          label: 'Test',
          onPressed: null,
        ),
      ),
    );
    
    final button = tester.widget<CupertinoButton>(
      find.byType(CupertinoButton),
    );
    expect(button.enabled, isFalse);
  });
});
```

### Mock Data

**✅ DOĞRU:**
```dart
class MockDeviceRepository extends Mock implements DeviceRepository {}

void main() {
  late MockDeviceRepository mockRepository;
  
  setUp(() {
    mockRepository = MockDeviceRepository();
  });
  
  test('loads devices successfully', () async {
    when(() => mockRepository.getDevices()).thenAnswer(
      (_) async => [Device(id: '1', name: 'Test Device')],
    );
    
    final service = DeviceService(mockRepository);
    final devices = await service.loadDevices();
    
    expect(devices.length, 1);
    expect(devices.first.name, 'Test Device');
  });
}
```

---

## ♿ Accessibility

### Semantic Labels

**✅ DOĞRU:**
```dart
Semantics(
  label: 'Add new device',
  button: true,
  child: AppIconButton(
    icon: CupertinoIcons.add,
    onPressed: () => _addDevice(),
  ),
)
```

**❌ YANLIŞ:**
```dart
AppIconButton(
  icon: CupertinoIcons.add,
  onPressed: () => _addDevice(),
)
// Screen reader says "button" but not what it does
```

### Text Contrast

**✅ DOĞRU:**
```dart
// 4.5:1 contrast ratio
Text(
  'Important Text',
  style: TextStyle(
    color: AppColors.textPrimaryLight,  // High contrast
  ),
)
```

**❌ YANLIŞ:**
```dart
Text(
  'Important Text',
  style: TextStyle(
    color: AppColors.gray3,  // Low contrast, hard to read
  ),
)
```

### Touch Targets

**✅ DOĞRU:**
```dart
Container(
  constraints: BoxConstraints(
    minHeight: 44,  // iOS minimum
    minWidth: 44,
  ),
  child: TextButton(
    onPressed: () {},
    child: Text('Tap'),
  ),
)
```

---

## ⚠️ Common Pitfalls

### 1. Memory Leaks

**❌ YANLIŞ:**
```dart
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  late StreamSubscription subscription;
  
  @override
  void initState() {
    super.initState();
    subscription = stream.listen((data) {
      setState(() {});
    });
    // Never disposed!
  }
}
```

**✅ DOĞRU:**
```dart
class _MyScreenState extends State<MyScreen> {
  late StreamSubscription subscription;
  
  @override
  void initState() {
    super.initState();
    subscription = stream.listen((data) {
      setState(() {});
    });
  }
  
  @override
  void dispose() {
    subscription.cancel();  // Clean up
    super.dispose();
  }
}
```

### 2. BuildContext After Async

**❌ YANLIŞ:**
```dart
Future<void> _submit() async {
  await api.submit();
  Navigator.pop(context);  // Context might be invalid!
}
```

**✅ DOĞRU:**
```dart
Future<void> _submit() async {
  await api.submit();
  if (!mounted) return;
  Navigator.pop(context);  // Check if still mounted
}
```

### 3. setState After Dispose

**❌ YANLIŠ:**
```dart
Future<void> _loadData() async {
  final data = await api.getData();
  setState(() {
    _data = data;  // Might be disposed!
  });
}
```

**✅ DOĞRU:**
```dart
Future<void> _loadData() async {
  final data = await api.getData();
  if (!mounted) return;
  setState(() {
    _data = data;
  });
}
```

### 4. Infinite Loops

**❌ YANLIŞ:**
```dart
@override
Widget build(BuildContext context) {
  ref.read(counterProvider.notifier).increment();  // Infinite loop!
  return Text('${ref.watch(counterProvider)}');
}
```

**✅ DOĞRU:**
```dart
@override
Widget build(BuildContext context) {
  useEffect(() {
    ref.read(counterProvider.notifier).increment();
    return null;
  }, []);  // Only once
  
  return Text('${ref.watch(counterProvider)}');
}
```

### 5. Blocking UI

**❌ YANLIŞ:**
```dart
AppButton(
  label: 'Submit',
  onPressed: () async {
    // UI freezes during this
    await heavyComputation();
  },
)
```

**✅ DOĞRU:**
```dart
AppButton(
  label: 'Submit',
  onPressed: () async {
    setState(() => _isLoading = true);
    
    // Run in isolate
    await compute(heavyComputation, data);
    
    setState(() => _isLoading = false);
  },
)
```

---

**Sonraki:** [Migration Guide →](MIGRATION_GUIDE.md)
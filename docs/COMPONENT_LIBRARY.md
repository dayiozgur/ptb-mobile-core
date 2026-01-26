# 🧩 Component Library

Visual component catalog with usage examples.

## İçindekiler

1. [Buttons](#buttons)
2. [Inputs](#inputs)
3. [Cards & Containers](#cards--containers)
4. [Lists](#lists)
5. [Navigation](#navigation)
6. [Feedback](#feedback)
7. [Data Display](#data-display)

## 🔘 Buttons

### AppButton

Primary button with multiple variants.

**Variants:**
- `primary`: Filled, prominent (default)
- `secondary`: Outlined
- `tertiary`: Text only
- `destructive`: Red, dangerous actions

**Sizes:**
- `small`: 36px height
- `medium`: 44px height (default)
- `large`: 52px height

**Props:**
| Prop | Type | Default | Description |
|------|------|---------|-------------|
| label | String | required | Button text |
| onPressed | VoidCallback? | null | Tap callback |
| variant | AppButtonVariant | primary | Button style |
| size | AppButtonSize | medium | Button size |
| isLoading | bool | false | Show loading |
| isFullWidth | bool | false | Full width |
| icon | IconData? | null | Leading icon |

**Example:**
```dart
// Primary button
AppButton(
  label: 'Continue',
  onPressed: () => _handleContinue(),
)

// Secondary with icon
AppButton(
  label: 'Add Device',
  variant: AppButtonVariant.secondary,
  icon: CupertinoIcons.add,
  onPressed: () => _showAddDevice(),
)

// Loading state
AppButton(
  label: 'Submitting...',
  isLoading: true,
)

// Destructive
AppButton(
  label: 'Delete Account',
  variant: AppButtonVariant.destructive,
  onPressed: () => _confirmDelete(),
)

// Full width
AppButton(
  label: 'Sign In',
  isFullWidth: true,
  onPressed: () => _signIn(),
)
```

**Preview:**
```
┌─────────────────────┐
│     Continue        │  ← Primary
└─────────────────────┘

┌─────────────────────┐
│  ⊕  Add Device      │  ← Secondary with icon
└─────────────────────┘

┌─────────────────────┐
│    ⟳ Loading...     │  ← Loading
└─────────────────────┘
```

### AppIconButton

Icon-only button.

**Props:**
| Prop | Type | Default | Description |
|------|------|---------|-------------|
| icon | IconData | required | Icon to show |
| onPressed | VoidCallback? | null | Tap callback |
| size | double | 44.0 | Button size |
| color | Color? | null | Icon color |
| backgroundColor | Color? | null | Background |
| isLoading | bool | false | Show loading |

**Example:**
```dart
// Simple icon button
AppIconButton(
  icon: CupertinoIcons.heart,
  onPressed: () => _toggleFavorite(),
)

// With background
AppIconButton(
  icon: CupertinoIcons.add,
  backgroundColor: AppColors.primary,
  color: Colors.white,
  onPressed: () => _add(),
)

// Custom size
AppIconButton(
  icon: CupertinoIcons.settings,
  size: 32,
  onPressed: () => _showSettings(),
)
```

---

## ✏️ Inputs

### AppTextField

Text input with label and validation.

**Props:**
| Prop | Type | Default | Description |
|------|------|---------|-------------|
| label | String? | null | Field label |
| placeholder | String? | null | Placeholder text |
| controller | TextEditingController? | null | Text controller |
| validator | FormFieldValidator? | null | Validation function |
| obscureText | bool | false | Hide text (password) |
| keyboardType | TextInputType? | null | Keyboard type |
| maxLines | int? | 1 | Max lines |
| prefixIcon | Widget? | null | Leading icon |
| suffixIcon | Widget? | null | Trailing icon |
| enabled | bool | true | Enabled state |
| helperText | String? | null | Helper text |
| errorText | String? | null | Error message |

**Example:**
```dart
// Basic text field
AppTextField(
  label: 'Full Name',
  placeholder: 'Enter your name',
  controller: _nameController,
)

// Email with validation
AppTextField(
  label: 'Email',
  placeholder: 'you@example.com',
  keyboardType: TextInputType.emailAddress,
  validator: Validators.email,
  prefixIcon: Icon(CupertinoIcons.mail),
)

// Password field
AppTextField(
  label: 'Password',
  placeholder: 'Enter password',
  obscureText: true,
  validator: Validators.password,
  prefixIcon: Icon(CupertinoIcons.lock),
  suffixIcon: IconButton(
    icon: Icon(CupertinoIcons.eye),
    onPressed: () => _togglePassword(),
  ),
)

// Multiline
AppTextField(
  label: 'Description',
  placeholder: 'Enter description',
  maxLines: 4,
)

// With error
AppTextField(
  label: 'Email',
  errorText: 'Invalid email format',
)
```

### AppDropdown

Dropdown selection field.

**Props:**
| Prop | Type | Default | Description |
|------|------|---------|-------------|
| label | String? | null | Field label |
| value | T? | null | Selected value |
| items | List<DropdownItem<T>> | required | Dropdown items |
| onChanged | ValueChanged<T?>? | null | Change callback |
| placeholder | String? | null | Placeholder |

**Example:**
```dart
AppDropdown<String>(
  label: 'Country',
  value: selectedCountry,
  placeholder: 'Select country',
  items: [
    DropdownItem(value: 'tr', label: 'Turkey'),
    DropdownItem(value: 'us', label: 'United States'),
    DropdownItem(value: 'uk', label: 'United Kingdom'),
  ],
  onChanged: (value) => setState(() => selectedCountry = value),
)
```

### AppDatePicker

Date picker field.

**Example:**
```dart
AppDatePicker(
  label: 'Birth Date',
  value: birthDate,
  onChanged: (date) => setState(() => birthDate = date),
  minimumDate: DateTime(1900),
  maximumDate: DateTime.now(),
)
```

---

## 🎴 Cards & Containers

### AppCard

Elevated card container.

**Props:**
| Prop | Type | Default | Description |
|------|------|---------|-------------|
| child | Widget | required | Card content |
| onTap | VoidCallback? | null | Tap callback |
| padding | EdgeInsets? | 16.0 all | Inner padding |
| backgroundColor | Color? | null | Background color |
| showShadow | bool | true | Show shadow |
| showBorder | bool | false | Show border |

**Example:**
```dart
// Basic card
AppCard(
  child: Column(
    children: [
      Text('Device Status', style: AppTypography.title3),
      SizedBox(height: 8),
      Text('Online', style: AppTypography.body),
    ],
  ),
)

// Tappable card
AppCard(
  onTap: () => _viewDetails(),
  child: ListTile(
    title: Text('Device #1'),
    subtitle: Text('Last seen: 2 min ago'),
  ),
)

// Custom styling
AppCard(
  backgroundColor: AppColors.primary.withOpacity(0.1),
  showShadow: false,
  showBorder: true,
  child: Text('Info'),
)
```

### MetricCard

Card for displaying metrics.

**Example:**
```dart
MetricCard(
  title: 'Energy Usage',
  value: '1,234 kWh',
  subtitle: 'This month',
  icon: CupertinoIcons.bolt,
  color: AppColors.primary,
  trend: 12.5,  // % change
)
```

**Preview:**
```
┌─────────────────────────┐
│  ⚡  Energy Usage        │
│                         │
│  1,234 kWh             │
│  This month     ↗ 12.5%│
└─────────────────────────┘
```

---

## 📋 Lists

### AppListTile

List item with iOS styling.

**Props:**
| Prop | Type | Default | Description |
|------|------|---------|-------------|
| title | String | required | Main text |
| subtitle | String? | null | Secondary text |
| leading | Widget? | null | Leading widget |
| trailing | Widget? | null | Trailing widget |
| onTap | VoidCallback? | null | Tap callback |
| showDivider | bool | true | Show divider |
| showChevron | bool | false | Show chevron |

**Example:**
```dart
// Basic list tile
AppListTile(
  title: 'Settings',
  leading: Icon(CupertinoIcons.settings),
  showChevron: true,
  onTap: () => _openSettings(),
)

// With subtitle
AppListTile(
  title: 'Device #1',
  subtitle: 'Online • Battery 87%',
  leading: CircleAvatar(
    child: Icon(CupertinoIcons.device_phone_portrait),
  ),
  trailing: AppBadge(
    label: 'Active',
    color: AppColors.success,
  ),
  onTap: () => _viewDevice(),
)

// Toggle
AppListTile(
  title: 'Notifications',
  leading: Icon(CupertinoIcons.bell),
  trailing: CupertinoSwitch(
    value: notificationsEnabled,
    onChanged: (value) => _toggleNotifications(value),
  ),
)
```

### AppSectionHeader

Section header for lists.

**Example:**
```dart
AppSectionHeader(
  title: 'Devices',
  trailing: TextButton(
    onPressed: () => _seeAll(),
    child: Text('See All'),
  ),
)
```

---

## 🧭 Navigation

### AppScaffold

Page scaffold with navigation bar.

**Props:**
| Prop | Type | Default | Description |
|------|------|---------|-------------|
| title | String? | null | Page title |
| child | Widget | required | Page content |
| leading | Widget? | null | Leading widget |
| trailing | Widget? | null | Trailing widget |
| showBackButton | bool | true | Show back |
| backgroundColor | Color? | null | Background |

**Example:**
```dart
AppScaffold(
  title: 'Devices',
  trailing: AppIconButton(
    icon: CupertinoIcons.add,
    onPressed: () => _addDevice(),
  ),
  child: DeviceList(),
)
```

### AppTabBar

Bottom tab navigation.

**Example:**
```dart
AppTabBar(
  currentIndex: selectedTab,
  onTap: (index) => setState(() => selectedTab = index),
  items: [
    AppTabItem(
      icon: CupertinoIcons.home,
      label: 'Home',
    ),
    AppTabItem(
      icon: CupertinoIcons.search,
      label: 'Search',
    ),
    AppTabItem(
      icon: CupertinoIcons.person,
      label: 'Profile',
    ),
  ],
)
```

### AppBottomSheet

Modal bottom sheet.

**Example:**
```dart
AppBottomSheet.show(
  context: context,
  title: 'Select Device',
  child: DeviceSelector(),
);

// Custom height
AppBottomSheet.show(
  context: context,
  builder: (context) => Container(
    height: 400,
    child: Content(),
  ),
);
```

---

## 💬 Feedback

### AppLoadingIndicator

Loading spinner.

**Example:**
```dart
// Default
AppLoadingIndicator()

// With message
AppLoadingIndicator(
  message: 'Loading devices...',
)

// Custom color
AppLoadingIndicator(
  color: AppColors.primary,
)
```

### AppErrorView

Error state display.

**Example:**
```dart
AppErrorView(
  error: error,
  onRetry: () => _retry(),
)

// Custom message
AppErrorView(
  title: 'No Connection',
  message: 'Please check your internet connection',
  icon: CupertinoIcons.wifi_slash,
  onRetry: () => _retry(),
)
```

### AppEmptyState

Empty state display.

**Example:**
```dart
AppEmptyState(
  icon: CupertinoIcons.tray,
  title: 'No Devices',
  message: 'Add your first device to get started',
  actionLabel: 'Add Device',
  onAction: () => _addDevice(),
)
```

### AppBadge

Small badge/label.

**Example:**
```dart
AppBadge(
  label: 'New',
  color: AppColors.success,
)

AppBadge(
  label: '5',
  color: AppColors.error,
)
```

### AppSnackbar

Temporary notification.

**Example:**
```dart
AppSnackbar.show(
  context: context,
  message: 'Device added successfully',
  type: SnackbarType.success,
)

AppSnackbar.show(
  context: context,
  message: 'Failed to connect',
  type: SnackbarType.error,
  action: SnackbarAction(
    label: 'Retry',
    onPressed: () => _retry(),
  ),
)
```

---

## 📊 Data Display

### AppAvatar

User/item avatar.

**Example:**
```dart
// With image
AppAvatar(
  imageUrl: user.photoUrl,
  size: 48,
)

// With initials
AppAvatar(
  initials: 'JD',
  backgroundColor: AppColors.primary,
  size: 48,
)

// With icon
AppAvatar(
  icon: CupertinoIcons.person,
  size: 32,
)
```

### AppProgressBar

Progress indicator.

**Example:**
```dart
AppProgressBar(
  value: 0.65,  // 65%
  backgroundColor: AppColors.gray5,
  foregroundColor: AppColors.success,
)
```

### AppChip

Small labeled chip.

**Example:**
```dart
AppChip(
  label: 'Active',
  color: AppColors.success,
)

AppChip(
  label: 'Premium',
  icon: CupertinoIcons.star_fill,
  color: AppColors.warning,
  onTap: () => _showPremium(),
)
```

---

**Sonraki:** [Best Practices →](BEST_PRACTICES.md)
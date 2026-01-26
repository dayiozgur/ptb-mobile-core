# 🎨 Design System Dokümantasyonu

## İçindekiler

1. [Apple Human Interface Guidelines](#apple-human-interface-guidelines)
2. [Renk Sistemi](#renk-sistemi)
3. [Typography](#typography)
4. [Spacing & Layout](#spacing--layout)
5. [Iconography](#iconography)
6. [Shadows & Elevation](#shadows--elevation)
7. [Animation & Motion](#animation--motion)
8. [Accessibility](#accessibility)
9. [Dark Mode](#dark-mode)

## 🍎 Apple Human Interface Guidelines

### Temel Prensipler

#### 1. Clarity (Netlik)
- Metinler her boyutta okunabilir
- İkonlar kesin ve anlaşılır
- Süslemeler amaçlı ve uygun
- İşlevsellik odaklı tasarım

#### 2. Deference (Saygı)
- İçerik kontrolü kullanıcıda
- UI arka planda kalır
- Dikkat dağıtıcı elementler yok
- Beyaz alan kullanımı

#### 3. Depth (Derinlik)
- Katmanlar ile hiyerarşi
- Gerçekçi hareket
- Context-aware geçişler
- Spatial awareness

### Platform Guidelines
```dart
// iOS Native Behavior
- Pull-to-refresh
- Swipe actions
- Navigation bar
- Tab bar
- Modal presentations
- Context menus
```

## 🎨 Renk Sistemi

### Temel Palet
```dart
class AppColors {
  // MARK: - Brand Colors
  static const Color primary = Color(0xFF007AFF);      // iOS Blue
  static const Color primaryLight = Color(0xFF5AC8FA);
  static const Color primaryDark = Color(0xFF0051D5);
  
  static const Color secondary = Color(0xFF5856D6);    // iOS Purple
  static const Color accent = Color(0xFFFF9500);       // iOS Orange
  
  // MARK: - Semantic Colors
  static const Color success = Color(0xFF34C759);      // iOS Green
  static const Color warning = Color(0xFFFF9500);      // iOS Orange
  static const Color error = Color(0xFFFF3B30);        // iOS Red
  static const Color info = Color(0xFF007AFF);         // iOS Blue
  
  // MARK: - Neutral Colors (Light Mode)
  static const Color backgroundLight = Color(0xFFF2F2F7);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  
  static const Color textPrimaryLight = Color(0xFF000000);
  static const Color textSecondaryLight = Color(0xFF8E8E93);
  static const Color textTertiaryLight = Color(0xFFC7C7CC);
  
  // MARK: - Neutral Colors (Dark Mode)
  static const Color backgroundDark = Color(0xFF000000);
  static const Color surfaceDark = Color(0xFF1C1C1E);
  static const Color cardDark = Color(0xFF2C2C2E);
  
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF8E8E93);
  static const Color textTertiaryDark = Color(0xFF48484A);
  
  // MARK: - System Colors
  static const Color separator = Color(0xFFC6C6C8);
  static const Color separatorDark = Color(0xFF38383A);
  static const Color overlay = Color(0x33000000);
  
  // MARK: - iOS System Grays
  static const Color gray = Color(0xFF8E8E93);
  static const Color gray2 = Color(0xFFAEAEB2);
  static const Color gray3 = Color(0xFFC7C7CC);
  static const Color gray4 = Color(0xFFD1D1D6);
  static const Color gray5 = Color(0xFFE5E5EA);
  static const Color gray6 = Color(0xFFF2F2F7);
}
```

### Renk Kullanım Kuralları

#### Primary Colors
```dart
// ✅ DOĞRU - Aksiyon butonları, linkler, aktif durumlar
AppButton(
  variant: AppButtonVariant.primary,
  label: 'Continue',
)

// ❌ YANLIŞ - Başlıklar, body text
Text('Heading', style: TextStyle(color: AppColors.primary))
```

#### Semantic Colors
```dart
// ✅ DOĞRU - Anlamlı kullanım
Container(
  decoration: BoxDecoration(
    color: isSuccess ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
  ),
  child: Text(
    message,
    style: TextStyle(
      color: isSuccess ? AppColors.success : AppColors.error,
    ),
  ),
)

// ❌ YANLIŞ - Sadece estetik
Container(color: AppColors.success)  // Neden yeşil? Başarı var mı?
```

### Adaptive Colors (Light/Dark Mode)
```dart
extension BuildContextTheme on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  
  Color get backgroundColor => isDarkMode 
    ? AppColors.backgroundDark 
    : AppColors.backgroundLight;
    
  Color get textPrimary => isDarkMode 
    ? AppColors.textPrimaryDark 
    : AppColors.textPrimaryLight;
}

// Kullanım
Container(
  color: context.backgroundColor,
  child: Text(
    'Hello',
    style: TextStyle(color: context.textPrimary),
  ),
)
```

## ✍️ Typography

### SF Pro Font Family
```dart
class AppTypography {
  // MARK: - Font Families
  static const String fontFamily = 'SF Pro Display';
  static const String fontFamilyRounded = 'SF Pro Rounded';
  static const String fontFamilyMono = 'SF Mono';
  
  // MARK: - Large Titles (iOS 11+)
  static const TextStyle largeTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.37,
    height: 1.2,
  );
  
  // MARK: - Titles
  static const TextStyle title1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.36,
    height: 1.3,
  );
  
  static const TextStyle title2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.35,
    height: 1.3,
  );
  
  static const TextStyle title3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.38,
    height: 1.4,
  );
  
  // MARK: - Headlines
  static const TextStyle headline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.41,
    height: 1.4,
  );
  
  // MARK: - Body
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.41,
    height: 1.5,
  );
  
  static const TextStyle bodyEmphasized = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.41,
    height: 1.5,
  );
  
  // MARK: - Callout
  static const TextStyle callout = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.32,
    height: 1.4,
  );
  
  // MARK: - Subhead
  static const TextStyle subhead = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.24,
    height: 1.4,
  );
  
  // MARK: - Footnote
  static const TextStyle footnote = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.08,
    height: 1.3,
  );
  
  // MARK: - Caption
  static const TextStyle caption1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.3,
  );
  
  static const TextStyle caption2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.06,
    height: 1.2,
  );
}
```

### Typography Scale
```
┌──────────────┬──────────┬──────────┬─────────────────────┐
│ Style        │ Size(pt) │ Weight   │ Use Case            │
├──────────────┼──────────┼──────────┼─────────────────────┤
│ Large Title  │ 34       │ Bold     │ Navigation bar      │
│ Title 1      │ 28       │ Bold     │ Screen titles       │
│ Title 2      │ 22       │ Bold     │ Section headers     │
│ Title 3      │ 20       │ Semibold │ Card titles         │
│ Headline     │ 17       │ Semibold │ Emphasized text     │
│ Body         │ 17       │ Regular  │ Main content        │
│ Callout      │ 16       │ Regular  │ Secondary content   │
│ Subhead      │ 15       │ Regular  │ Labels              │
│ Footnote     │ 13       │ Regular  │ Captions, metadata  │
│ Caption 1    │ 12       │ Regular  │ Small labels        │
│ Caption 2    │ 11       │ Regular  │ Tiny text           │
└──────────────┴──────────┴──────────┴─────────────────────┘
```

### Typography Usage Guidelines
```dart
// ✅ DOĞRU - Hiyerarşik kullanım
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text('Energy Consumption', style: AppTypography.title2),      // Başlık
    SizedBox(height: 8),
    Text('Last 7 days', style: AppTypography.subhead),            // Alt başlık
    SizedBox(height: 16),
    Text('Monitor your energy usage...', style: AppTypography.body),  // İçerik
    SizedBox(height: 4),
    Text('Updated 5 min ago', style: AppTypography.footnote),     // Meta bilgi
  ],
)

// ❌ YANLIŞ - Karışık hiyerarşi
Column(
  children: [
    Text('Title', style: AppTypography.caption1),    // Çok küçük başlık
    Text('Body', style: AppTypography.title1),       // Çok büyük body
  ],
)
```

## 📏 Spacing & Layout

### Spacing System
```dart
class AppSpacing {
  // MARK: - Base Spacing (4px grid)
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;
  
  // MARK: - Screen Padding
  static const double screenHorizontal = 16.0;
  static const double screenVertical = 16.0;
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: screenHorizontal,
    vertical: screenVertical,
  );
  
  // MARK: - Component Spacing
  static const double cardPadding = 16.0;
  static const double listItemPadding = 16.0;
  static const double sectionSpacing = 32.0;
  static const double elementSpacing = 8.0;
  
  // MARK: - Safe Area
  static const EdgeInsets safeAreaPadding = EdgeInsets.only(
    left: 16.0,
    right: 16.0,
    top: 8.0,
    bottom: 8.0,
  );
}
```

### Border Radius
```dart
class AppRadius {
  // MARK: - Border Radius
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double pill = 999.0;
  
  // MARK: - Component Specific
  static const double card = 12.0;
  static const double sheet = 16.0;
  static const double button = 12.0;
  static const double input = 10.0;
  static const double badge = 12.0;
  static const double avatar = 999.0;
  
  // MARK: - BorderRadius Objects
  static final BorderRadius cardRadius = BorderRadius.circular(card);
  static final BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
  static final BorderRadius buttonRadius = BorderRadius.circular(button);
}
```

### Layout Grid (8px base)
```
┌─────────────────────────────────────────┐
│  Spacing    Value    Usage              │
├─────────────────────────────────────────┤
│  xxs        2px      Icon padding       │
│  xs         4px      Tight spacing      │
│  sm         8px      Element spacing    │
│  md         16px     Section spacing    │
│  lg         24px     Component spacing  │
│  xl         32px     Large gaps         │
│  xxl        48px     Screen sections    │
│  xxxl       64px     Major divisions    │
└─────────────────────────────────────────┘
```

## 🎯 Iconography

### Icon Sizes
```dart
class AppIconSize {
  static const double xs = 12.0;
  static const double sm = 16.0;
  static const double md = 24.0;
  static const double lg = 32.0;
  static const double xl = 48.0;
  static const double xxl = 64.0;
}
```

### SF Symbols
```dart
// iOS native icons
Icon(CupertinoIcons.home)
Icon(CupertinoIcons.person)
Icon(CupertinoIcons.settings)
Icon(CupertinoIcons.heart_fill)
Icon(CupertinoIcons.checkmark_circle_fill)

// Custom icons with SF style
class AppIcons {
  static const IconData dashboard = IconData(0xe900, fontFamily: 'AppIcons');
  static const IconData devices = IconData(0xe901, fontFamily: 'AppIcons');
  static const IconData analytics = IconData(0xe902, fontFamily: 'AppIcons');
}
```

### Icon Usage
```dart
// ✅ DOĞRU - Semantik kullanım
AppButton(
  icon: CupertinoIcons.add,
  label: 'Add Device',
)

ListTile(
  leading: Icon(CupertinoIcons.device_phone_portrait),
  title: Text('iPhone 13'),
)

// ❌ YANLIŞ - Görsel gürültü
Text('Hello', 
  style: TextStyle(
    // Icon in text - avoid
  ),
)
```

## 🌓 Shadows & Elevation

### Shadow System
```dart
class AppShadows {
  // MARK: - iOS-style Subtle Shadows
  static const List<BoxShadow> none = [];
  
  static const List<BoxShadow> xs = [
    BoxShadow(
      color: Color(0x0A000000),
      offset: Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];
  
  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x0F000000),
      offset: Offset(0, 1),
      blurRadius: 3,
      spreadRadius: 0,
    ),
  ];
  
  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x14000000),
      offset: Offset(0, 2),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];
  
  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x1F000000),
      offset: Offset(0, 4),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];
  
  static const List<BoxShadow> xl = [
    BoxShadow(
      color: Color(0x29000000),
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: 0,
    ),
  ];
  
  // MARK: - Component Specific
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0A000000),
      offset: Offset(0, 1),
      blurRadius: 3,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x0D000000),
      offset: Offset(0, 2),
      blurRadius: 6,
      spreadRadius: 0,
    ),
  ];
  
  static const List<BoxShadow> button = [
    BoxShadow(
      color: Color(0x14000000),
      offset: Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];
  
  static const List<BoxShadow> sheet = [
    BoxShadow(
      color: Color(0x29000000),
      offset: Offset(0, -2),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];
}
```

### Elevation Guidelines
```
Level 0 (No shadow)     - Background
Level 1 (xs/sm)         - Cards, Tiles
Level 2 (md)            - Buttons, Inputs
Level 3 (lg)            - Sheets, Dialogs
Level 4 (xl)            - Modals, Menus
```

## 🎬 Animation & Motion

### Animation Durations
```dart
class AppDuration {
  static const Duration instant = Duration(milliseconds: 0);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
  static const Duration slower = Duration(milliseconds: 500);
}
```

### Animation Curves
```dart
class AppCurves {
  // iOS native curves
  static const Curve easeIn = Curves.easeIn;
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeInOut = Curves.easeInOut;
  
  // iOS spring
  static const Curve spring = Curves.elasticOut;
  
  // Custom curves
  static const Curve smooth = Cubic(0.4, 0.0, 0.2, 1.0);
  static const Curve snappy = Cubic(0.25, 0.1, 0.25, 1.0);
}
```

### Motion Guidelines
```dart
// ✅ DOĞRU - Smooth transitions
AnimatedContainer(
  duration: AppDuration.normal,
  curve: AppCurves.easeInOut,
  color: isActive ? AppColors.primary : AppColors.gray,
)

// ✅ DOĞRU - Page transitions
PageRouteBuilder(
  transitionDuration: AppDuration.normal,
  pageBuilder: (context, animation, secondaryAnimation) => NextPage(),
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: AppCurves.easeOut,
      )),
      child: child,
    );
  },
)

// ❌ YANLIŞ - Çok yavaş animasyon
AnimatedContainer(
  duration: Duration(seconds: 2),  // Too slow!
)
```

## ♿ Accessibility

### Text Scaling
```dart
// Dynamic type support
Text(
  'Hello',
  style: AppTypography.body,
  textScaleFactor: MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.3),
)
```

### Touch Targets
```dart
class AppTouchTarget {
  static const double minimum = 44.0;  // iOS minimum
  static const double comfortable = 48.0;
  static const double large = 56.0;
}

// Button implementation
Container(
  constraints: BoxConstraints(
    minHeight: AppTouchTarget.minimum,
    minWidth: AppTouchTarget.minimum,
  ),
  child: TextButton(...),
)
```

### Semantic Labels
```dart
// ✅ DOĞRU - Screen reader support
Semantics(
  label: 'Add new device',
  button: true,
  child: IconButton(
    icon: Icon(CupertinoIcons.add),
    onPressed: _addDevice,
  ),
)

// Image alt text
Semantics(
  label: 'Device status: Online',
  child: Image.asset('assets/device.png'),
)
```

### Color Contrast
```
WCAG 2.1 Guidelines:
- Normal text: 4.5:1 minimum
- Large text: 3:1 minimum
- UI components: 3:1 minimum

✅ AppColors.primary on white: 4.52:1
✅ AppColors.textPrimaryLight on white: 21:1
⚠️ AppColors.gray3 on white: 2.8:1 (Fail)
```

## 🌙 Dark Mode

### Adaptive Colors
```dart
class AdaptiveColors {
  static Color background(BuildContext context) {
    return context.isDarkMode 
      ? AppColors.backgroundDark 
      : AppColors.backgroundLight;
  }
  
  static Color surface(BuildContext context) {
    return context.isDarkMode 
      ? AppColors.surfaceDark 
      : AppColors.surfaceLight;
  }
  
  static Color textPrimary(BuildContext context) {
    return context.isDarkMode 
      ? AppColors.textPrimaryDark 
      : AppColors.textPrimaryLight;
  }
}
```

### Dark Mode Best Practices
```dart
// ✅ DOĞRU - Adaptive implementation
Container(
  decoration: BoxDecoration(
    color: context.isDarkMode 
      ? AppColors.cardDark 
      : AppColors.cardLight,
    boxShadow: context.isDarkMode 
      ? [] 
      : AppShadows.card,  // No shadow in dark mode
  ),
)

// ✅ DOĞRU - Semantic colors work in both modes
Container(
  color: AppColors.success.withOpacity(0.1),
  child: Text(
    'Success!',
    style: TextStyle(color: AppColors.success),
  ),
)

// ❌ YANLIŞ - Hardcoded colors
Container(
  color: Colors.white,  // Doesn't adapt!
  child: Text(
    'Text',
    style: TextStyle(color: Colors.black),  // Doesn't adapt!
  ),
)
```

### Testing Dark Mode
```dart
// Force dark mode for testing
runApp(
  MaterialApp(
    themeMode: ThemeMode.dark,  // Force dark
    darkTheme: AppTheme.dark,
    home: MyApp(),
  ),
);

// Toggle at runtime
class DarkModeToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    
    return CupertinoSwitch(
      value: isDark,
      onChanged: (value) {
        ref.read(themeProvider.notifier).state = 
          value ? ThemeMode.dark : ThemeMode.light;
      },
    );
  }
}
```

---

**Sonraki:** [Development Guide →](DEVELOPMENT_GUIDE.md)
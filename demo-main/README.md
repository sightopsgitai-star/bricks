# Industrial Machine Monitoring Dashboard

A comprehensive Flutter application for monitoring industrial production machines across multiple companies. Features real-time dashboard metrics, production reports with PDF export, and alert management with local notifications.

## 📱 Features

### Authentication
- Simple hardcoded login system
- **Username:** `admin`
- **Password:** `1234`

### Navigation
- Persistent BottomNavigationBar with 3 screens
- IndexedStack for state preservation across tabs
- Global company selector in AppBar

### Dashboard (Home Screen)
- Machine status overview (Running/Stopped/Maintenance)
- Real-time production metrics
- Cycle counts and cure cycle times
- Start/Stop tracking
- Concurrent calls monitoring
- Downtime tracking
- Average production with period selector (Today/Weekly/Monthly)
- Machine details modal with full statistics

### Reports Screen
- Date range selection with quick presets (Today, 7 Days, 30 Days)
- Production summary cards
- Daily breakdown table
- **PDF report generation** with formatted layout
- Download/print functionality via printing package

### Alerts Screen
- Real-time alert monitoring
- Severity filtering (Critical/High/Medium/Low)
- Unread filter toggle
- Mark as read/resolved functionality
- Local notifications via flutter_local_notifications
- Alert detail modal with full information

## 🏗 Architecture

```
lib/
├── main.dart                 # App entry point with Provider setup
├── models/
│   └── models.dart          # Data models (Company, Machine, Alert, etc.)
├── providers/
│   └── providers.dart       # State management (Auth, Company, Alert)
├── screens/
│   ├── login_screen.dart    # Authentication screen
│   ├── main_screen.dart     # Navigation container
│   ├── home_screen.dart     # Dashboard with metrics
│   ├── reports_screen.dart  # Report generation & PDF export
│   └── alerts_screen.dart   # Alert management
├── services/
│   ├── services.dart        # Data service with mock data
│   └── notification_service.dart  # Local notifications
└── widgets/
    └── widgets.dart         # Reusable UI components
```

## 📊 Sample Data

### Companies

| Company | Industry | Location | Machines |
|---------|----------|----------|----------|
| Apex Manufacturing | Automotive Parts | Detroit, MI | 8 |
| TechForge Industries | Electronics Manufacturing | San Jose, CA | 6 |
| SteelCore Solutions | Metal Fabrication | Pittsburgh, PA | 10 |

### Sample Machines (Apex Manufacturing)

| ID | Name | Type | Status | Cycles | Efficiency |
|----|------|------|--------|--------|------------|
| APX-CNC-001 | CNC Router Alpha | CNC Router | Running | 12,847 | 94.2% |
| APX-CNC-002 | CNC Router Beta | CNC Router | Running | 11,532 | 91.5% |
| APX-PRS-001 | Hydraulic Press A1 | Hydraulic Press | Stopped | 8,921 | 0% |
| APX-PRS-002 | Hydraulic Press A2 | Hydraulic Press | Running | 9,234 | 88.7% |
| APX-INJ-001 | Injection Molder 1 | Injection Molding | Running | 24,567 | 96.8% |
| APX-INJ-002 | Injection Molder 2 | Injection Molding | Maintenance | 22,341 | 0% |
| APX-ASM-001 | Assembly Line Station 1 | Assembly | Running | 45,678 | 97.3% |
| APX-ASM-002 | Assembly Line Station 2 | Assembly | Running | 43,921 | 95.1% |

### Production Statistics

| Company | Daily | Weekly | Monthly | Efficiency |
|---------|-------|--------|---------|------------|
| Apex Manufacturing | 2,847 units | 18,234 units | 72,456 units | ~93% |
| TechForge Industries | 15,234 units | 98,765 units | 412,345 units | ~97% |
| SteelCore Solutions | 1,876 units | 12,456 units | 51,234 units | ~91% |

### Alert Types
- 🔴 Machine Stopped
- ⏱️ High Downtime (>60 minutes)
- 🌡️ Temperature Warning
- 🔧 Maintenance Due
- 📉 Production Target Missed
- ⚠️ Abnormal Condition
- 📊 Low Efficiency

## 🔄 Data Flow

```
┌──────────────────────────────────────────────────────────────┐
│                        main.dart                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              MultiProvider (State Management)            │ │
│  │  ┌───────────┐  ┌───────────────┐  ┌─────────────────┐  │ │
│  │  │AuthProvider│  │CompanyProvider│  │ AlertProvider   │  │ │
│  │  └───────────┘  └───────────────┘  └─────────────────┘  │ │
│  └─────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                    LoginScreen                                │
│         (Validates credentials via AuthProvider)              │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                     MainScreen                                │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ AppBar: Company Dropdown ───────► CompanyProvider        │ │
│  └─────────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                   IndexedStack                           │ │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────────────┐   │ │
│  │  │ HomeScreen │ │ReportsScreen│ │   AlertsScreen    │   │ │
│  │  │(Dashboard) │ │ (PDF Gen)  │ │  (Notifications)  │   │ │
│  │  └────────────┘ └────────────┘ └────────────────────┘   │ │
│  └─────────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              BottomNavigationBar                         │ │
│  └─────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                      DataService                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Mock data for companies, machines, alerts, stats       │  │
│  │  Returns data filtered by selected company              │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

## 📦 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2          # State management
  pdf: ^3.11.0              # PDF generation
  printing: ^5.13.1         # PDF preview/print
  flutter_local_notifications: ^17.2.4  # Local notifications
  intl: ^0.19.0             # Date/time formatting
  path_provider: ^2.1.4     # File system access
  cupertino_icons: ^1.0.8   # iOS icons
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.0+)
- Dart SDK (3.0+)
- Android Studio / VS Code with Flutter extensions

### Installation

1. Clone or copy the project files

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Running on Different Platforms

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d chrome

# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux
```

## 📱 Platform-Specific Configuration

### Android
No additional setup required. Notifications will work out of the box.

### iOS
Add the following to `ios/Runner/Info.plist` for notifications:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

### Windows/macOS/Linux
Local notifications require platform-specific configuration. Refer to [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) documentation.

## 🎨 Theme

The app uses Material Design 3 with a deep blue (#1565C0) color scheme for an industrial feel:
- Primary Color: Industrial Blue
- Status Colors:
  - 🟢 Green: Running machines
  - 🔴 Red: Stopped machines
  - 🟠 Orange: Maintenance

## 🔮 Future Enhancements

- [ ] Real API integration
- [ ] User management with roles
- [ ] Push notifications (Firebase)
- [ ] Offline support with local database
- [ ] Machine detail charts/graphs
- [ ] Export to CSV/Excel
- [ ] Multi-language support
- [ ] Dark mode

## 📝 License

This project is for demonstration purposes.

## 🤝 Contributing

This is a demo project showcasing Flutter capabilities for industrial monitoring applications.

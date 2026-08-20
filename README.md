# SpendBook

SpendBook is a minimalist, privacy-first expense tracking app built with Flutter. It helps you effortlessly record your daily spending, visualize your financial habits through interactive charts, and stay on top of your budget — all without requiring an internet connection or cloud account. Your data stays on your device.

Designed with Material You (Material 3) and dynamic theming, SpendBook adapts to your system's color palette for a seamless, native feel on every Android device.

---

## Features

### 💸 Quick Expense Entry
Record transactions in seconds. Simply pick a category (or create a new one on the fly) and enter the amount. If you log multiple expenses under the same category on the same day, SpendBook automatically sums them together — no duplicates, no clutter.

### 📊 Interactive Analytics & Visualizations
Once you've tracked expenses for 7+ days, unlock a powerful analytics dashboard:
- **Line & Bar Charts** — View expense trends grouped by day, week, or month.
- **Pie Chart** — See how your spending is distributed across categories at a glance.
- **Category Breakdown** — A detailed legend showing each category's total and percentage share.
- **Date Filtering** — Filter by custom date ranges, or use quick shortcuts (Today, This Week, This Month).

### 📥 Import & Export
- **Export to Excel** — Download all your expense data as an `.xlsx` file to your Downloads folder.
- **Import from Excel** — Bulk-import transactions from a properly formatted spreadsheet. Existing records for overlapping dates are intelligently replaced.

### 🎨 Material You Theming
SpendBook uses `dynamic_color` to adopt your device's Material You color palette. On devices without dynamic color support, it falls back to a clean blue theme. Supports both light and dark modes automatically.

### 🔄 In-App Updates
SpendBook includes a built-in self-update system:
- Automatically checks for new versions on every app launch by querying a remote JSON endpoint.
- Displays a styled update dialog with **Later** and **Update Now** options.
- Downloads the update APK with a real-time progress indicator showing size and download speed.
- Triggers the Android system installer to apply the update seamlessly.
- Supports **force update** mode — when enabled, the "Later" option is disabled.
- Old APK files are automatically cleaned up after a successful download.

### 🔒 Privacy First
- All data is stored locally in an SQLite database on your device.
- No accounts, no cloud sync, no telemetry.
- The app only uses the internet to check for updates.

---

## Technologies

| Layer | Technology |
|-------|------------|
| **Framework** | [Flutter](https://flutter.dev) (Dart) |
| **UI System** | Material 3 / Material You |
| **Dynamic Theming** | [dynamic_color](https://pub.dev/packages/dynamic_color) |
| **Local Database** | [sqflite](https://pub.dev/packages/sqflite) (SQLite) |
| **Charts** | [fl_chart](https://pub.dev/packages/fl_chart) |
| **Excel I/O** | [excel](https://pub.dev/packages/excel) |
| **File Picking** | [file_picker](https://pub.dev/packages/file_picker) |
| **Networking** | [http](https://pub.dev/packages/http) |
| **Version Detection** | [package_info_plus](https://pub.dev/packages/package_info_plus) |
| **Permissions** | [permission_handler](https://pub.dev/packages/permission_handler) |
| **Date Formatting** | [intl](https://pub.dev/packages/intl) |
| **File System** | [path_provider](https://pub.dev/packages/path_provider), [path](https://pub.dev/packages/path) |
| **Platform Channel** | Kotlin (Android) — FileProvider + Package Installer Intent |

---

## Building

```bash
# Get dependencies
flutter pub get

# Run in debug mode
flutter run

# Build release APK
flutter build apk --release
```

The release APK will be generated at `build/app/outputs/flutter-apk/app-release.apk`.

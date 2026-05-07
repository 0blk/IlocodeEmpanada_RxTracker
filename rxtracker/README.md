# RxTracker — Prescription Reader & Medicine Tracker

A full-stack medicine management app with prescription OCR, daily dose tracking, and push reminders.

```
rxtracker/
├── backend/          Python FastAPI backend
│   ├── main.py       API routes (prescriptions, medicines, doses)
│   ├── database.py   SQLite schema + connection helper
│   └── requirements.txt
└── flutter_app/      Flutter frontend
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── models/       medicine.dart, dose.dart
        ├── services/     api_service.dart, medicine_provider.dart, notification_service.dart
        ├── screens/      home, scan, add_medicine, history, stats
        └── widgets/      dose_card.dart, adherence_banner.dart
```

---

## Backend Setup

### 1. Install dependencies
```bash
cd backend
pip install -r requirements.txt
```

### 2. Set environment variables (optional)
```bash
export ANTHROPIC_API_KEY=sk-ant-...   # Required for real prescription OCR
export DB_PATH=rxtracker.db           # Default: rxtracker.db in current directory
```

> Without `ANTHROPIC_API_KEY`, the `/api/prescriptions/scan` endpoint returns mock data — perfect for testing.

### 3. Run
```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

The API will be available at `http://localhost:8000`.  
Interactive docs: `http://localhost:8000/docs`

---

## Flutter Setup

### 1. Prerequisites
- Flutter SDK ≥ 3.3.0 ([install guide](https://docs.flutter.dev/get-started/install))
- Android Studio / Xcode for device/emulator

### 2. Configure backend URL
Edit `flutter_app/lib/services/api_service.dart`:
```dart
// For Android emulator talking to localhost backend:
static const String baseUrl = 'http://10.0.2.2:8000';

// For iOS simulator:
static const String baseUrl = 'http://localhost:8000';

// For physical device (use your machine's local IP):
static const String baseUrl = 'http://192.168.x.x:8000';
```

### 3. Install packages & run
```bash
cd flutter_app
flutter pub get
flutter run
```

### 4. Android permissions
The following are already declared in `android/app/src/main/AndroidManifest.xml` by the packages, but verify:
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

---

## Features

| Feature | Details |
|---|---|
| **Prescription Scan** | Upload photo → Claude Vision extracts medicine names, dosages, frequencies, duration |
| **Manual Entry** | Add medicines with name, dosage, frequency, schedule times, stock count |
| **Today View** | All doses grouped by status: Overdue / Due Now / Upcoming / Taken |
| **One-tap logging** | Mark doses taken/untaken with optimistic UI update |
| **Push Reminders** | Daily local notifications scheduled per medicine time slot |
| **Dose History** | Scrollable log grouped by date, filterable by 7/14/30 days |
| **Adherence Stats** | Per-medicine and overall adherence percentage with progress bars |
| **Stock Tracking** | Optional pill count with low-stock warnings (≤5 remaining) |
| **Dark/Light mode** | Follows system theme via Material You |

---

## API Reference

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/prescriptions/scan` | Upload image, returns extracted medicines |
| GET | `/api/medicines` | List all medicines |
| POST | `/api/medicines` | Create medicine |
| PATCH | `/api/medicines/{id}` | Update medicine |
| DELETE | `/api/medicines/{id}` | Delete medicine + logs |
| GET | `/api/doses/today` | Today's scheduled doses with log status |
| POST | `/api/doses/log` | Mark dose taken/not taken |
| GET | `/api/doses/history` | Historical dose logs |
| GET | `/api/doses/stats` | Adherence stats per medicine |
| GET | `/health` | Health check |

---

## Architecture Notes

- **Backend**: FastAPI + SQLite (no ORM). Simple, zero-dependency storage.
- **State**: Flutter `Provider` pattern. `MedicineProvider` holds all app state and syncs with backend.
- **Notifications**: `flutter_local_notifications` schedules daily repeating alarms per time slot. Notifications auto-reschedule on app launch.
- **OCR**: Uses Anthropic Claude `claude-sonnet-4-20250514` with vision for prescription reading. Structured JSON output is parsed into `Medicine` objects.
- **Offline tolerance**: UI shows cached state while loading; errors surface as snackbars or error banners with retry.

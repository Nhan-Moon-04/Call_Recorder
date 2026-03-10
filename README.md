# 📞 Call Recorder - Ghi Âm Cuộc Gọi

Ứng dụng Android ghi âm cuộc gọi từ SIM, Zalo, WhatsApp, Telegram, Viber, Messenger và các ứng dụng khác.

## ✨ Tính năng

### Ghi âm cuộc gọi

- 🎙️ **Ghi âm** cuộc gọi thoại từ mọi nguồn
- 📹 **Ghi hình** video call
- 🫧 **Bong bóng nổi** hiện lên khi phát hiện cuộc gọi, cho phép chọn ghi âm/ghi hình
- ⚡ **Tự động ghi âm** - có thể bật tự động ghi khi phát hiện cuộc gọi

### Nguồn hỗ trợ

- 📱 Cuộc gọi SIM (điện thoại thường)
- 💬 Zalo
- 📲 WhatsApp
- ✈️ Telegram
- 📞 Viber
- 💭 Messenger

### Giao diện

- 🌐 **Đa ngôn ngữ**: Tiếng Việt & English
- 🌗 **Chế độ sáng/tối**: Light & Dark theme
- 📱 Material Design 3

### Tài khoản & Đám mây

- 🔐 **Đăng nhập/Đăng ký** với Firebase Auth
- ☁️ **Lưu trữ đám mây** - tải bản ghi lên Firebase Storage
- 📊 **Quản lý bản ghi** - tìm kiếm, lọc, phát lại

## 🏗️ Cấu trúc dự án

```
lib/
├── main.dart                    # Entry point
├── config/
│   ├── app_constants.dart       # App constants
│   └── firebase_config.dart     # Firebase config
├── l10n/
│   └── app_localizations.dart   # i18n (EN/VI)
├── models/
│   ├── recording_model.dart     # Recording data model
│   └── user_model.dart          # User data model
├── providers/
│   ├── auth_provider.dart       # Authentication state
│   ├── locale_provider.dart     # Language state
│   ├── recording_provider.dart  # Recording state
│   └── theme_provider.dart      # Theme state
├── screens/
│   ├── auth/
│   │   └── login_screen.dart    # Login/Register screen
│   ├── home_screen.dart         # Home screen
│   ├── main_screen.dart         # Navigation container
│   ├── recordings_screen.dart   # Recordings list
│   └── settings_screen.dart     # Settings screen
├── services/
│   ├── auth_service.dart        # Firebase Auth service
│   ├── firestore_service.dart   # Firestore service
│   ├── native_call_service.dart # Native Android bridge
│   └── recording_service.dart   # Audio recording service
└── widgets/
    └── recording_indicator.dart # Recording animation

android/app/src/main/kotlin/.../
├── MainActivity.kt              # Flutter - Native bridge
├── BubbleService.kt             # Floating bubble overlay
├── CallDetectionService.kt      # SIM call detection
├── CallDetectorAccessibilityService.kt  # App call detection
├── ScreenRecordService.kt       # Video recording service
├── BootReceiver.kt              # Auto-start on boot
└── PhoneStateReceiver.kt        # Phone state receiver
```

## 🚀 Cài đặt & Chạy

### Yêu cầu

- Flutter SDK 3.10+
- Android Studio / VS Code
- Firebase project

### 1. Cấu hình Firebase

```bash
# Cài đặt FlutterFire CLI
dart pub global activate flutterfire_cli

# Cấu hình Firebase cho project
flutterfire configure
```

Hoặc thêm file `google-services.json` vào `android/app/`.

### 2. Cài đặt dependencies

```bash
flutter pub get
```

### 3. Chạy ứng dụng

```bash
flutter run
```

### 4. Build APK

```bash
flutter build apk --release
```

## 🔑 Quyền cần thiết

| Quyền                 | Mục đích                                   |
| --------------------- | ------------------------------------------ |
| RECORD_AUDIO          | Ghi âm cuộc gọi                            |
| READ_PHONE_STATE      | Phát hiện cuộc gọi SIM                     |
| SYSTEM_ALERT_WINDOW   | Hiển thị bong bóng nổi                     |
| FOREGROUND_SERVICE    | Chạy dịch vụ nền                           |
| POST_NOTIFICATIONS    | Thông báo khi đang ghi                     |
| Accessibility Service | Phát hiện cuộc gọi từ Zalo, WhatsApp, etc. |

## 📋 Firebase Setup

### Firestore Rules

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /recordings/{recordingId} {
      allow read, write: if request.auth != null && resource.data.userId == request.auth.uid;
      allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
    }
  }
}
```

### Storage Rules

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /recordings/{userId}/{fileName} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## ⚠️ Lưu ý quan trọng

1. **Android 10+**: Google hạn chế ghi âm cuộc gọi. App ghi âm qua microphone (loa ngoài).
2. **Accessibility Service**: Cần bật trong Settings > Accessibility để phát hiện cuộc gọi từ Zalo, WhatsApp.
3. **Overlay Permission**: Cần cấp quyền hiển thị trên ứng dụng khác để hiện bong bóng.
4. **Battery Optimization**: Nên tắt tối ưu pin cho app để dịch vụ chạy ổn định.

## 📄 License

MIT License

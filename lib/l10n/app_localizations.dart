import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // App
      'app_name': 'Call Recorder',
      'app_subtitle': 'Record calls from any app',

      // Auth
      'login': 'Login',
      'register': 'Register',
      'email': 'Email',
      'password': 'Password',
      'confirm_password': 'Confirm Password',
      'forgot_password': 'Forgot Password?',
      'no_account': "Don't have an account? ",
      'have_account': 'Already have an account? ',
      'reset_password': 'Reset Password',
      'reset_email_sent': 'Password reset email sent!',
      'login_success': 'Login successful!',
      'register_success': 'Registration successful!',
      'logout': 'Logout',
      'logout_confirm': 'Are you sure you want to logout?',

      // Home
      'home': 'Home',
      'recordings': 'Recordings',
      'settings': 'Settings',
      'no_recordings': 'No recordings yet',
      'start_recording': 'Start Recording',
      'stop_recording': 'Stop Recording',
      'recording_in_progress': 'Recording in progress...',

      // Recording
      'record_audio': 'Record Audio',
      'record_video': 'Record Video',
      'recording_saved': 'Recording saved!',
      'recording_deleted': 'Recording deleted!',
      'delete_recording': 'Delete Recording',
      'delete_confirm': 'Are you sure you want to delete this recording?',
      'play': 'Play',
      'pause': 'Pause',
      'stop': 'Stop',
      'duration': 'Duration',
      'date': 'Date',
      'source': 'Source',
      'type': 'Type',
      'audio': 'Audio',
      'video': 'Video',
      'size': 'Size',
      'upload_to_cloud': 'Upload to Cloud',
      'uploading': 'Uploading...',
      'uploaded': 'Uploaded to cloud!',

      // Bubble
      'bubble_title': 'Call Detected',
      'bubble_record_audio': 'Record Audio',
      'bubble_record_video': 'Record Video',
      'bubble_dismiss': 'Dismiss',
      'bubble_auto_recording': 'Auto Recording Active',

      // Settings
      'auto_record': 'Auto Record',
      'auto_record_desc': 'Automatically record when a call is detected',
      'auto_record_audio_only': 'Audio Only',
      'auto_record_audio_video': 'Audio & Video',
      'recording_quality': 'Recording Quality',
      'quality_low': 'Low',
      'quality_medium': 'Medium',
      'quality_high': 'High',
      'language': 'Language',
      'theme': 'Theme',
      'theme_light': 'Light',
      'theme_dark': 'Dark',
      'theme_system': 'System',
      'about': 'About',
      'version': 'Version',
      'permissions': 'Permissions',
      'grant_permissions': 'Grant Permissions',
      'permission_microphone': 'Microphone',
      'permission_phone': 'Phone',
      'permission_storage': 'Storage',
      'permission_overlay': 'Overlay',
      'permission_notification': 'Notification',
      'permission_granted': 'Granted',
      'permission_denied': 'Denied',
      'call_sources': 'Call Sources',
      'select_sources': 'Select which apps to monitor',
      'select_all': 'Select All',
      'select_sim_only': 'SIM Only',
      'monitoring_active': 'Background monitoring active',
      'monitoring_inactive': 'Monitoring inactive',
      'overlay_permission': 'Overlay Permission',
      'overlay_permission_desc':
          'Required to show recording bubble during calls',
      'accessibility_service': 'Accessibility Service',
      'accessibility_service_desc': 'Required to detect calls from apps',
      'notification_listener': 'Notification Listener',
      'notification_listener_desc':
          'Detect calls from Zalo, WhatsApp, etc. via notifications (does not affect banking apps)',

      // General
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'delete': 'Delete',
      'save': 'Save',
      'error': 'Error',
      'success': 'Success',
      'loading': 'Loading...',
      'retry': 'Retry',
      'ok': 'OK',
      'yes': 'Yes',
      'no': 'No',
      'search': 'Search',
      'filter': 'Filter',
      'all': 'All',
      'today': 'Today',
      'this_week': 'This Week',
      'this_month': 'This Month',
    },
    'vi': {
      // App
      'app_name': 'Ghi Âm Cuộc Gọi',
      'app_subtitle': 'Ghi âm cuộc gọi từ mọi ứng dụng',

      // Auth
      'login': 'Đăng Nhập',
      'register': 'Đăng Ký',
      'email': 'Email',
      'password': 'Mật khẩu',
      'confirm_password': 'Xác nhận mật khẩu',
      'forgot_password': 'Quên mật khẩu?',
      'no_account': 'Chưa có tài khoản? ',
      'have_account': 'Đã có tài khoản? ',
      'reset_password': 'Đặt lại mật khẩu',
      'reset_email_sent': 'Email đặt lại mật khẩu đã được gửi!',
      'login_success': 'Đăng nhập thành công!',
      'register_success': 'Đăng ký thành công!',
      'logout': 'Đăng Xuất',
      'logout_confirm': 'Bạn có chắc chắn muốn đăng xuất?',

      // Home
      'home': 'Trang Chủ',
      'recordings': 'Bản Ghi',
      'settings': 'Cài Đặt',
      'no_recordings': 'Chưa có bản ghi nào',
      'start_recording': 'Bắt đầu ghi',
      'stop_recording': 'Dừng ghi',
      'recording_in_progress': 'Đang ghi âm...',

      // Recording
      'record_audio': 'Ghi Âm',
      'record_video': 'Ghi Hình',
      'recording_saved': 'Đã lưu bản ghi!',
      'recording_deleted': 'Đã xóa bản ghi!',
      'delete_recording': 'Xóa bản ghi',
      'delete_confirm': 'Bạn có chắc chắn muốn xóa bản ghi này?',
      'play': 'Phát',
      'pause': 'Tạm dừng',
      'stop': 'Dừng',
      'duration': 'Thời lượng',
      'date': 'Ngày',
      'source': 'Nguồn',
      'type': 'Loại',
      'audio': 'Âm thanh',
      'video': 'Video',
      'size': 'Kích thước',
      'upload_to_cloud': 'Tải lên Cloud',
      'uploading': 'Đang tải lên...',
      'uploaded': 'Đã tải lên cloud!',

      // Bubble
      'bubble_title': 'Phát hiện cuộc gọi',
      'bubble_record_audio': 'Ghi Âm',
      'bubble_record_video': 'Ghi Hình',
      'bubble_dismiss': 'Bỏ qua',
      'bubble_auto_recording': 'Đang tự động ghi âm',

      // Settings
      'auto_record': 'Tự động ghi',
      'auto_record_desc': 'Tự động ghi khi phát hiện cuộc gọi',
      'auto_record_audio_only': 'Chỉ âm thanh',
      'auto_record_audio_video': 'Âm thanh & Video',
      'recording_quality': 'Chất lượng ghi',
      'quality_low': 'Thấp',
      'quality_medium': 'Trung bình',
      'quality_high': 'Cao',
      'language': 'Ngôn ngữ',
      'theme': 'Giao diện',
      'theme_light': 'Sáng',
      'theme_dark': 'Tối',
      'theme_system': 'Hệ thống',
      'about': 'Giới thiệu',
      'version': 'Phiên bản',
      'permissions': 'Quyền truy cập',
      'grant_permissions': 'Cấp quyền',
      'permission_microphone': 'Microphone',
      'permission_phone': 'Điện thoại',
      'permission_storage': 'Bộ nhớ',
      'permission_overlay': 'Hiển thị trên ứng dụng khác',
      'permission_notification': 'Thông báo',
      'permission_granted': 'Đã cấp',
      'permission_denied': 'Từ chối',
      'call_sources': 'Nguồn cuộc gọi',
      'select_sources': 'Chọn ứng dụng cần theo dõi',
      'select_all': 'Chọn tất cả',
      'select_sim_only': 'Chỉ SIM',
      'monitoring_active': 'Đang theo dõi cuộc gọi',
      'monitoring_inactive': 'Chưa theo dõi',
      'overlay_permission': 'Quyền hiển thị trên ứng dụng khác',
      'overlay_permission_desc':
          'Cần thiết để hiện bong bóng ghi âm trong cuộc gọi',
      'accessibility_service': 'Dịch vụ trợ năng',
      'accessibility_service_desc':
          'Cần thiết để phát hiện cuộc gọi từ ứng dụng',
      'notification_listener': 'Quyền đọc thông báo',
      'notification_listener_desc':
          'Phát hiện cuộc gọi từ Zalo, WhatsApp... qua thông báo (không ảnh hưởng app ngân hàng)',

      // General
      'cancel': 'Hủy',
      'confirm': 'Xác nhận',
      'delete': 'Xóa',
      'save': 'Lưu',
      'error': 'Lỗi',
      'success': 'Thành công',
      'loading': 'Đang tải...',
      'retry': 'Thử lại',
      'ok': 'OK',
      'yes': 'Có',
      'no': 'Không',
      'search': 'Tìm kiếm',
      'filter': 'Lọc',
      'all': 'Tất cả',
      'today': 'Hôm nay',
      'this_week': 'Tuần này',
      'this_month': 'Tháng này',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'vi'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// Extension for easy access
extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String tr(String key) => AppLocalizations.of(this).translate(key);
}

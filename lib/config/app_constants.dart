class AppConstants {
  static const String appName = 'Call Recorder';
  static const String appVersion = '1.0.0';

  // Recording formats
  static const String audioExtension = '.m4a';
  static const String videoExtension = '.mp4';

  // Shared preferences keys
  static const String prefThemeMode = 'theme_mode';
  static const String prefLocale = 'locale';
  static const String prefAutoRecord = 'auto_record';
  static const String prefAutoRecordAudio = 'auto_record_audio';
  static const String prefAutoRecordVideo = 'auto_record_video';
  static const String prefRecordingQuality = 'recording_quality';

  // Call sources
  static const String sourceSim = 'SIM';
  static const String sourceZalo = 'Zalo';
  static const String sourceWhatsApp = 'WhatsApp';
  static const String sourceViber = 'Viber';
  static const String sourceTelegram = 'Telegram';
  static const String sourceMessenger = 'Messenger';
  static const String sourceOther = 'Other';

  static const List<String> callSources = [
    sourceSim,
    sourceZalo,
    sourceWhatsApp,
    sourceViber,
    sourceTelegram,
    sourceMessenger,
    sourceOther,
  ];
}

import 'package:flutter/services.dart';

/// Service to communicate with native Android code for:
/// - Call detection (phone state listener)
/// - Floating bubble overlay
/// - Screen recording (video calls)
/// - Accessibility service for detecting 3rd party app calls
class NativeCallService {
  static const MethodChannel _channel = MethodChannel(
    'com.zalocall.zalo_call_recorder/call_service',
  );

  static const EventChannel _callEventChannel = EventChannel(
    'com.zalocall.zalo_call_recorder/call_events',
  );

  /// Start listening for phone calls
  static Future<void> startCallDetection() async {
    try {
      await _channel.invokeMethod('startCallDetection');
    } on PlatformException catch (e) {
      throw Exception('Failed to start call detection: ${e.message}');
    }
  }

  /// Stop listening for phone calls
  static Future<void> stopCallDetection() async {
    try {
      await _channel.invokeMethod('stopCallDetection');
    } on PlatformException catch (e) {
      throw Exception('Failed to stop call detection: ${e.message}');
    }
  }

  /// Show floating bubble overlay
  static Future<void> showBubble({
    required String source,
    bool autoRecord = false,
  }) async {
    try {
      await _channel.invokeMethod('showBubble', {
        'source': source,
        'autoRecord': autoRecord,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to show bubble: ${e.message}');
    }
  }

  /// Hide floating bubble
  static Future<void> hideBubble() async {
    try {
      await _channel.invokeMethod('hideBubble');
    } on PlatformException catch (e) {
      throw Exception('Failed to hide bubble: ${e.message}');
    }
  }

  /// Check if overlay permission is granted
  static Future<bool> hasOverlayPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasOverlayPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Request overlay permission
  static Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } on PlatformException catch (e) {
      throw Exception('Failed to request overlay permission: ${e.message}');
    }
  }

  /// Start screen recording (for video calls)
  static Future<void> startScreenRecording() async {
    try {
      await _channel.invokeMethod('startScreenRecording');
    } on PlatformException catch (e) {
      throw Exception('Failed to start screen recording: ${e.message}');
    }
  }

  /// Stop screen recording
  static Future<String?> stopScreenRecording() async {
    try {
      final result = await _channel.invokeMethod<String>('stopScreenRecording');
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to stop screen recording: ${e.message}');
    }
  }

  /// Check if accessibility service is enabled
  static Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'isAccessibilityServiceEnabled',
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Open accessibility settings
  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      throw Exception('Failed to open accessibility settings: ${e.message}');
    }
  }

  /// Listen for call events from native
  static Stream<Map<String, dynamic>> get callEvents {
    return _callEventChannel.receiveBroadcastStream().map(
      (event) => Map<String, dynamic>.from(event as Map),
    );
  }
}

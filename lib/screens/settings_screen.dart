import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/auth_provider.dart' as app;
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/recording_provider.dart';
import '../services/native_call_service.dart';
import '../l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  Map<Permission, PermissionStatus> _permissionStatuses = {};
  bool _overlayGranted = false;
  bool _accessibilityGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check all permissions when user returns from system settings
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  /// Get the correct storage permission based on Android version
  Permission get _storagePermission {
    if (Platform.isAndroid) {
      // Android 13+ (API 33+) uses manageExternalStorage or media permissions
      return Permission.manageExternalStorage;
    }
    return Permission.storage;
  }

  Future<void> _checkPermissions() async {
    // Check standard permissions (status only, don't auto-request)
    final statuses = <Permission, PermissionStatus>{};
    statuses[Permission.microphone] = await Permission.microphone.status;
    statuses[Permission.phone] = await Permission.phone.status;
    statuses[_storagePermission] = await _storagePermission.status;
    statuses[Permission.notification] = await Permission.notification.status;

    // Check overlay permission
    final overlayStatus = await Permission.systemAlertWindow.status;

    // Check accessibility service status via native channel
    bool accessibilityEnabled = false;
    try {
      accessibilityEnabled =
          await NativeCallService.isAccessibilityServiceEnabled();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _permissionStatuses = statuses;
        _overlayGranted = overlayStatus.isGranted;
        _accessibilityGranted = accessibilityEnabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final recordingProvider = context.watch<RecordingProvider>();
    final authProvider = context.watch<app.AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Info Card
          _buildUserCard(theme, authProvider),
          const SizedBox(height: 16),

          // Recording Settings
          _buildSectionTitle(theme, context.tr('auto_record')),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(context.tr('auto_record')),
                  subtitle: Text(context.tr('auto_record_desc')),
                  value: recordingProvider.autoRecord,
                  onChanged: (value) => recordingProvider.setAutoRecord(value),
                  secondary: const Icon(Icons.auto_awesome),
                ),
                if (recordingProvider.autoRecord) ...[
                  const Divider(height: 1),
                  RadioGroup<bool>(
                    groupValue: recordingProvider.autoRecordVideo,
                    onChanged: (value) =>
                        recordingProvider.setAutoRecordVideo(value ?? false),
                    child: Column(
                      children: [
                        RadioListTile<bool>(
                          title: Text(context.tr('auto_record_audio_only')),
                          secondary: const Icon(Icons.mic),
                          value: false,
                        ),
                        RadioListTile<bool>(
                          title: Text(context.tr('auto_record_audio_video')),
                          secondary: const Icon(Icons.videocam),
                          value: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Recording Quality
          _buildSectionTitle(theme, context.tr('recording_quality')),
          Card(
            child: RadioGroup<String>(
              groupValue: recordingProvider.recordingQuality,
              onChanged: (value) =>
                  recordingProvider.setRecordingQuality(value ?? 'medium'),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: Text(context.tr('quality_low')),
                    subtitle: const Text('16kHz, 64kbps'),
                    value: 'low',
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    title: Text(context.tr('quality_medium')),
                    subtitle: const Text('44.1kHz, 128kbps'),
                    value: 'medium',
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    title: Text(context.tr('quality_high')),
                    subtitle: const Text('48kHz, 192kbps'),
                    value: 'high',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Theme
          _buildSectionTitle(theme, context.tr('theme')),
          Card(
            child: RadioGroup<ThemeMode>(
              groupValue: themeProvider.themeMode,
              onChanged: (value) =>
                  themeProvider.setThemeMode(value ?? ThemeMode.system),
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: Text(context.tr('theme_system')),
                    secondary: const Icon(Icons.brightness_auto),
                    value: ThemeMode.system,
                  ),
                  const Divider(height: 1),
                  RadioListTile<ThemeMode>(
                    title: Text(context.tr('theme_light')),
                    secondary: const Icon(Icons.light_mode),
                    value: ThemeMode.light,
                  ),
                  const Divider(height: 1),
                  RadioListTile<ThemeMode>(
                    title: Text(context.tr('theme_dark')),
                    secondary: const Icon(Icons.dark_mode),
                    value: ThemeMode.dark,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Language
          _buildSectionTitle(theme, context.tr('language')),
          Card(
            child: RadioGroup<String>(
              groupValue: localeProvider.locale.languageCode,
              onChanged: (value) =>
                  localeProvider.setLocale(Locale(value ?? 'vi')),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('Tiếng Việt'),
                    secondary: const Text(
                      '🇻🇳',
                      style: TextStyle(fontSize: 24),
                    ),
                    value: 'vi',
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    title: const Text('English'),
                    secondary: const Text(
                      '🇺🇸',
                      style: TextStyle(fontSize: 24),
                    ),
                    value: 'en',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Permissions
          _buildSectionTitle(theme, context.tr('permissions')),
          Card(
            child: Column(
              children: [
                _buildPermissionTile(
                  icon: Icons.mic,
                  title: context.tr('permission_microphone'),
                  permission: Permission.microphone,
                ),
                const Divider(height: 1),
                _buildPermissionTile(
                  icon: Icons.phone,
                  title: context.tr('permission_phone'),
                  permission: Permission.phone,
                ),
                const Divider(height: 1),
                _buildPermissionTile(
                  icon: Icons.folder,
                  title: context.tr('permission_storage'),
                  permission: _storagePermission,
                ),
                const Divider(height: 1),
                _buildPermissionTile(
                  icon: Icons.notifications,
                  title: context.tr('permission_notification'),
                  permission: Permission.notification,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.layers),
                  title: Text(context.tr('overlay_permission')),
                  subtitle: Text(context.tr('overlay_permission_desc')),
                  trailing: _overlayGranted
                      ? Chip(
                          label: Text(
                            context.tr('permission_granted'),
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: Colors.green.withValues(alpha: 0.1),
                          side: BorderSide.none,
                        )
                      : TextButton(
                          onPressed: () async {
                            await NativeCallService.requestOverlayPermission();
                            // Re-check after returning from settings
                            Future.delayed(
                              const Duration(milliseconds: 500),
                              () {
                                _checkPermissions();
                              },
                            );
                          },
                          child: Text(context.tr('grant_permissions')),
                        ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_active),
                  title: Text(context.tr('notification_listener')),
                  subtitle: Text(context.tr('notification_listener_desc')),
                  trailing: _accessibilityGranted
                      ? Chip(
                          label: Text(
                            context.tr('permission_granted'),
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: Colors.green.withValues(alpha: 0.1),
                          side: BorderSide.none,
                        )
                      : TextButton(
                          onPressed: () async {
                            await NativeCallService.openAccessibilitySettings();
                          },
                          child: Text(context.tr('grant_permissions')),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // About
          _buildSectionTitle(theme, context.tr('about')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(context.tr('version')),
                  trailing: const Text('1.0.0'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Logout Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(authProvider),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: Text(
                context.tr('logout'),
                style: const TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildUserCard(ThemeData theme, app.AuthProvider authProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.person,
                size: 32,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authProvider.user?.email ?? '',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'UID: ${authProvider.user?.uid.substring(0, 8) ?? ''}...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required Permission permission,
  }) {
    final status = _permissionStatuses[permission];
    final isGranted = status?.isGranted ?? false;

    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: isGranted
          ? Chip(
              label: Text(
                context.tr('permission_granted'),
                style: const TextStyle(color: Colors.green, fontSize: 12),
              ),
              backgroundColor: Colors.green.withValues(alpha: 0.1),
              side: BorderSide.none,
            )
          : TextButton(
              onPressed: () async {
                final result = await permission.request();
                if (result.isPermanentlyDenied) {
                  // Open app settings if permanently denied
                  await openAppSettings();
                }
                // Re-check after a small delay (user returns from settings)
                Future.delayed(const Duration(milliseconds: 500), () {
                  _checkPermissions();
                });
              },
              child: Text(context.tr('grant_permissions')),
            ),
    );
  }

  void _showLogoutDialog(app.AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('logout')),
        content: Text(context.tr('logout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              authProvider.logout();
            },
            child: Text(context.tr('logout')),
          ),
        ],
      ),
    );
  }
}

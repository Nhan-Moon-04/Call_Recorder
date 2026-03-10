import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app;
import '../providers/recording_provider.dart';
import '../models/recording_model.dart';
import '../config/app_constants.dart';
import '../l10n/app_localizations.dart';
import '../widgets/recording_indicator.dart';
import '../services/native_call_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Set<String> _selectedSources = {AppConstants.sourceSim};
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  Future<void> _startMonitoring() async {
    try {
      await NativeCallService.startCallDetection();
      if (mounted) setState(() => _isMonitoring = true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<app.AuthProvider>();
    final recordingProvider = context.watch<RecordingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('app_name')),
        actions: [
          // Recording indicator
          if (recordingProvider.isRecording)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: RecordingIndicator(),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            _buildStatusCard(theme, recordingProvider),
            const SizedBox(height: 24),

            // Source Selection
            Text(
              context.tr('source'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildSourceSelector(theme),
            const SizedBox(height: 24),

            // Recording Controls
            Text(
              context.tr('record_audio'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildRecordingControls(theme, recordingProvider, authProvider),
            const SizedBox(height: 24),

            // Auto Record Toggle
            _buildAutoRecordCard(theme, recordingProvider),
            const SizedBox(height: 24),

            // Recent Recordings
            Text(
              context.tr('recordings'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildRecentRecordings(theme, recordingProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme, RecordingProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: provider.isRecording
                    ? Colors.red.withValues(alpha: 0.1)
                    : theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                provider.isRecording ? Icons.fiber_manual_record : Icons.mic,
                size: 32,
                color: provider.isRecording
                    ? Colors.red
                    : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.isRecording
                        ? context.tr('recording_in_progress')
                        : context.tr('app_subtitle'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: provider.isRecording ? Colors.red : null,
                    ),
                  ),
                  if (provider.isRecording) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatDuration(provider.currentDuration),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontFeatures: [const FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${context.tr('source')}: ${_selectedSources.join(", ")}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _isMonitoring ? Icons.shield : Icons.shield_outlined,
                        size: 14,
                        color: _isMonitoring ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isMonitoring
                            ? context.tr('monitoring_active')
                            : context.tr('monitoring_inactive'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _isMonitoring ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AppConstants.callSources.map((source) {
            final isSelected = _selectedSources.contains(source);
            return FilterChip(
              label: Text(source),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedSources.add(source);
                  } else {
                    // Don't allow deselecting all sources
                    if (_selectedSources.length > 1) {
                      _selectedSources.remove(source);
                    }
                  }
                });
              },
              avatar: Icon(_getSourceIcon(source), size: 18),
              showCheckmark: true,
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedSources = AppConstants.callSources.toSet();
                });
              },
              icon: const Icon(Icons.select_all, size: 16),
              label: Text(context.tr('select_all')),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedSources = {AppConstants.sourceSim};
                });
              },
              icon: const Icon(Icons.deselect, size: 16),
              label: Text(context.tr('select_sim_only')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecordingControls(
    ThemeData theme,
    RecordingProvider provider,
    app.AuthProvider authProvider,
  ) {
    return Row(
      children: [
        // Record Audio Button
        Expanded(
          child: _buildRecordButton(
            theme: theme,
            icon: Icons.mic_rounded,
            label: context.tr('record_audio'),
            isRecording:
                provider.isRecording &&
                provider.recordingType == RecordingType.audio,
            onPressed: () =>
                _toggleRecording(provider, authProvider, RecordingType.audio),
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        // Record Video Button
        Expanded(
          child: _buildRecordButton(
            theme: theme,
            icon: Icons.videocam_rounded,
            label: context.tr('record_video'),
            isRecording:
                provider.isRecording &&
                provider.recordingType == RecordingType.video,
            onPressed: () =>
                _toggleRecording(provider, authProvider, RecordingType.video),
            color: Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordButton({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required bool isRecording,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Card(
      color: isRecording ? color.withValues(alpha: 0.1) : null,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                isRecording ? Icons.stop_circle_rounded : icon,
                size: 48,
                color: isRecording ? Colors.red : color,
              ),
              const SizedBox(height: 8),
              Text(
                isRecording ? context.tr('stop_recording') : label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isRecording ? Colors.red : null,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutoRecordCard(ThemeData theme, RecordingProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              title: Text(context.tr('auto_record')),
              subtitle: Text(context.tr('auto_record_desc')),
              value: provider.autoRecord,
              onChanged: (value) => provider.setAutoRecord(value),
              secondary: Icon(
                Icons.auto_awesome,
                color: provider.autoRecord ? theme.colorScheme.primary : null,
              ),
            ),
            if (provider.autoRecord) ...[
              const Divider(),
              RadioGroup<bool>(
                groupValue: provider.autoRecordVideo,
                onChanged: (value) =>
                    provider.setAutoRecordVideo(value ?? false),
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      title: Text(context.tr('auto_record_audio_only')),
                      value: false,
                    ),
                    RadioListTile<bool>(
                      title: Text(context.tr('auto_record_audio_video')),
                      value: true,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentRecordings(ThemeData theme, RecordingProvider provider) {
    final recentRecordings = provider.recordings.take(5).toList();

    if (recentRecordings.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.folder_open,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('no_recordings'),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: recentRecordings.map((recording) {
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: recording.type == RecordingType.audio
                  ? Colors.blue.withValues(alpha: 0.1)
                  : Colors.purple.withValues(alpha: 0.1),
              child: Icon(
                recording.type == RecordingType.audio
                    ? Icons.mic
                    : Icons.videocam,
                color: recording.type == RecordingType.audio
                    ? Colors.blue
                    : Colors.purple,
              ),
            ),
            title: Text(recording.source),
            subtitle: Text(
              '${recording.formattedDuration} • ${recording.formattedSize}',
            ),
            trailing: Text(
              _formatDate(recording.createdAt),
              style: theme.textTheme.bodySmall,
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _toggleRecording(
    RecordingProvider provider,
    app.AuthProvider authProvider,
    RecordingType type,
  ) async {
    if (provider.isRecording) {
      final recording = await provider.stopRecording(
        userId: authProvider.user!.uid,
      );
      if (recording != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('recording_saved'))));
      }
    } else {
      await provider.startRecording(
        userId: authProvider.user!.uid,
        type: type,
        source: _selectedSources.join(', '),
      );
    }
  }

  IconData _getSourceIcon(String source) {
    switch (source) {
      case AppConstants.sourceSim:
        return Icons.phone;
      case AppConstants.sourceZalo:
        return Icons.chat_bubble;
      case AppConstants.sourceWhatsApp:
        return Icons.message;
      case AppConstants.sourceViber:
        return Icons.phone_in_talk;
      case AppConstants.sourceTelegram:
        return Icons.telegram;
      case AppConstants.sourceMessenger:
        return Icons.facebook;
      default:
        return Icons.apps;
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

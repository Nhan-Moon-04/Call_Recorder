import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/recording_provider.dart';
import '../models/recording_model.dart';
import '../l10n/app_localizations.dart';

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingId;
  String _filter = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // Playback state
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isPlaying = false;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _completeSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _setupAudioListeners();
  }

  void _setupAudioListeners() {
    _positionSub = _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _currentPosition = pos);
    });
    _durationSub = _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _totalDuration = dur);
    });
    _completeSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playingId = null;
          _isPlaying = false;
          _currentPosition = Duration.zero;
        });
      }
    });
    _stateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    _stateSub?.cancel();
    _audioPlayer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recordingProvider = context.watch<RecordingProvider>();

    final filteredRecordings = _getFilteredRecordings(
      recordingProvider.recordings,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('recordings')),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _filter = value);
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'all', child: Text(context.tr('all'))),
              PopupMenuItem(value: 'audio', child: Text(context.tr('audio'))),
              PopupMenuItem(value: 'video', child: Text(context.tr('video'))),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'today', child: Text(context.tr('today'))),
              PopupMenuItem(
                value: 'week',
                child: Text(context.tr('this_week')),
              ),
              PopupMenuItem(
                value: 'month',
                child: Text(context.tr('this_month')),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: context.tr('search'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),

          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${filteredRecordings.length} ${context.tr('recordings').toLowerCase()}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Recordings List
          Expanded(
            child: filteredRecordings.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredRecordings.length,
                    itemBuilder: (context, index) {
                      return _buildRecordingCard(
                        theme,
                        filteredRecordings[index],
                        recordingProvider,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 80,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('no_recordings'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingCard(
    ThemeData theme,
    RecordingModel recording,
    RecordingProvider provider,
  ) {
    final isPlaying = _playingId == recording.id;
    final isThisActive = _playingId == recording.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: recording.type == RecordingType.audio
            ? () => _togglePlayback(recording)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  // Type Icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isPlaying
                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                          : recording.type == RecordingType.audio
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isPlaying
                          ? Icons.graphic_eq_rounded
                          : recording.type == RecordingType.audio
                          ? Icons.mic
                          : Icons.videocam,
                      color: isPlaying
                          ? theme.colorScheme.primary
                          : recording.type == RecordingType.audio
                          ? Colors.blue
                          : Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _getDisplaySource(recording.source),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (recording.isUploaded)
                              Icon(
                                Icons.cloud_done,
                                size: 16,
                                color: Colors.green[600],
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${recording.formattedDuration} • ${recording.formattedSize}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          _formatDateTime(recording.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Play/Pause
                      if (recording.type == RecordingType.audio)
                        IconButton(
                          icon: Icon(
                            isPlaying && _isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            color: theme.colorScheme.primary,
                            size: 36,
                          ),
                          onPressed: () => _togglePlayback(recording),
                        ),
                      // More actions
                      PopupMenuButton<String>(
                        itemBuilder: (context) => [
                          if (!recording.isUploaded)
                            PopupMenuItem(
                              value: 'upload',
                              child: ListTile(
                                leading: const Icon(Icons.cloud_upload),
                                title: Text(context.tr('upload_to_cloud')),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: const Icon(
                                Icons.delete,
                                color: Colors.red,
                              ),
                              title: Text(
                                context.tr('delete'),
                                style: const TextStyle(color: Colors.red),
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'upload') {
                            provider.uploadRecording(recording);
                          } else if (value == 'delete') {
                            _showDeleteDialog(recording, provider);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),

              // Seekbar - shown when this recording is active
              if (isThisActive) ...[
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: theme.colorScheme.primary,
                    inactiveTrackColor: theme.colorScheme.primary.withValues(
                      alpha: 0.2,
                    ),
                    thumbColor: theme.colorScheme.primary,
                  ),
                  child: Slider(
                    value: _totalDuration.inMilliseconds > 0
                        ? _currentPosition.inMilliseconds.toDouble().clamp(
                            0,
                            _totalDuration.inMilliseconds.toDouble(),
                          )
                        : 0,
                    max: _totalDuration.inMilliseconds > 0
                        ? _totalDuration.inMilliseconds.toDouble()
                        : 1,
                    onChanged: (value) {
                      _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_currentPosition),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontFeatures: [const FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        _formatDuration(_totalDuration),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontFeatures: [const FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Fix display for old files named "{source}_..." (broken $ interpolation)
  String _getDisplaySource(String source) {
    if (source == '{source}' || source.isEmpty) return 'SIM';
    return source;
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final hours = d.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  List<RecordingModel> _getFilteredRecordings(List<RecordingModel> recordings) {
    var filtered = recordings;

    // Type filter
    if (_filter == 'audio') {
      filtered = filtered.where((r) => r.type == RecordingType.audio).toList();
    } else if (_filter == 'video') {
      filtered = filtered.where((r) => r.type == RecordingType.video).toList();
    } else if (_filter == 'today') {
      final now = DateTime.now();
      filtered = filtered
          .where(
            (r) =>
                r.createdAt.year == now.year &&
                r.createdAt.month == now.month &&
                r.createdAt.day == now.day,
          )
          .toList();
    } else if (_filter == 'week') {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      filtered = filtered.where((r) => r.createdAt.isAfter(weekAgo)).toList();
    } else if (_filter == 'month') {
      final monthAgo = DateTime.now().subtract(const Duration(days: 30));
      filtered = filtered.where((r) => r.createdAt.isAfter(monthAgo)).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (r) =>
                r.source.toLowerCase().contains(query) ||
                r.fileName.toLowerCase().contains(query) ||
                (r.callerName?.toLowerCase().contains(query) ?? false) ||
                (r.callerNumber?.toLowerCase().contains(query) ?? false),
          )
          .toList();
    }

    return filtered;
  }

  Future<void> _togglePlayback(RecordingModel recording) async {
    if (_playingId == recording.id) {
      // Same recording: toggle pause/resume
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.resume();
      }
    } else {
      // Different recording: stop current, play new
      await _audioPlayer.stop();
      setState(() {
        _playingId = recording.id;
        _currentPosition = Duration.zero;
        _totalDuration = Duration.zero;
      });

      try {
        // Check if file exists and is valid before playing
        final file = File(recording.filePath);
        if (!await file.exists()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File not found'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _playingId = null);
          return;
        }
        final fileSize = await file.length();
        if (fileSize < 4096) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File is corrupt or empty'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          setState(() => _playingId = null);
          return;
        }

        await _audioPlayer.play(DeviceFileSource(recording.filePath));
      } catch (e) {
        debugPrint('Playback error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot play: ${e.toString().split('\n').first}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _playingId = null);
      }
    }
  }

  void _showDeleteDialog(RecordingModel recording, RecordingProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('delete_recording')),
        content: Text(context.tr('delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              provider.deleteRecording(recording);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.tr('recording_deleted'))),
              );
            },
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../config/app_constants.dart';
import '../models/recording_model.dart';

class RecordingService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _currentFilePath;
  DateTime? _startTime;

  /// Get the recording directory organized by date:
  /// /storage/emulated/0/Documents/CallRecorder/YYYY-MM/YYYY-MM-DD/
  Future<String> get _recordingDirectory async {
    final now = DateTime.now();
    final monthFolder = DateFormat('yyyy-MM').format(now);
    final dayFolder = DateFormat('yyyy-MM-dd').format(now);

    final baseDir = Directory('/storage/emulated/0/Documents/CallRecorder');
    final recordingDir = Directory(p.join(baseDir.path, monthFolder, dayFolder));
    if (!await recordingDir.exists()) {
      await recordingDir.create(recursive: true);
    }
    return recordingDir.path;
  }

  Future<void> startRecording({
    required RecordingType type,
    String quality = 'medium',
  }) async {
    if (await _audioRecorder.isRecording()) return;

    final dir = await _recordingDirectory;
    final uuid = const Uuid().v4();
    final extension = type == RecordingType.audio
        ? AppConstants.audioExtension
        : AppConstants.audioExtension; // Audio part is always m4a
    final fileName = 'recording_$uuid$extension';
    _currentFilePath = p.join(dir, fileName);
    _startTime = DateTime.now();

    // Configure recording quality
    final config = _getRecordConfig(quality);

    await _audioRecorder.start(config, path: _currentFilePath!);
  }

  RecordConfig _getRecordConfig(String quality) {
    switch (quality) {
      case 'low':
        return const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          bitRate: 64000,
        );
      case 'high':
        return const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 48000,
          bitRate: 192000,
        );
      default: // medium
        return const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
        );
    }
  }

  Future<RecordingModel?> stopRecording({
    required String userId,
    required String source,
    required RecordingType type,
    required Duration duration,
  }) async {
    if (!await _audioRecorder.isRecording()) return null;

    final path = await _audioRecorder.stop();
    if (path == null || _currentFilePath == null) return null;

    final file = File(_currentFilePath!);
    if (!await file.exists()) return null;

    final fileSize = await file.length();
    final fileName = p.basename(_currentFilePath!);

    final recording = RecordingModel(
      id: const Uuid().v4(),
      userId: userId,
      fileName: fileName,
      filePath: _currentFilePath!,
      type: type,
      source: source,
      duration: duration,
      fileSize: fileSize,
      createdAt: _startTime ?? DateTime.now(),
    );

    _currentFilePath = null;
    _startTime = null;

    return recording;
  }

  Future<void> deleteRecording(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<bool> isRecording() async {
    return await _audioRecorder.isRecording();
  }

  void dispose() {
    _audioRecorder.dispose();
  }
}

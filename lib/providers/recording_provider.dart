import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import '../config/app_constants.dart';
import '../models/recording_model.dart';
import '../services/recording_service.dart';
import '../services/firestore_service.dart';

class RecordingProvider with ChangeNotifier {
  final RecordingService _recordingService = RecordingService();
  final FirestoreService _firestoreService = FirestoreService();

  bool _isRecording = false;
  bool _autoRecord = false;
  bool _autoRecordVideo = false;
  RecordingType _recordingType = RecordingType.audio;
  String _currentSource = AppConstants.sourceSim;
  List<RecordingModel> _recordings = [];
  Duration _currentDuration = Duration.zero;
  String _recordingQuality = 'medium';

  bool get isRecording => _isRecording;
  bool get autoRecord => _autoRecord;
  bool get autoRecordVideo => _autoRecordVideo;
  RecordingType get recordingType => _recordingType;
  String get currentSource => _currentSource;
  List<RecordingModel> get recordings => _recordings;
  Duration get currentDuration => _currentDuration;
  String get recordingQuality => _recordingQuality;

  RecordingProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoRecord = prefs.getBool(AppConstants.prefAutoRecord) ?? false;
    _autoRecordVideo = prefs.getBool(AppConstants.prefAutoRecordVideo) ?? false;
    _recordingQuality =
        prefs.getString(AppConstants.prefRecordingQuality) ?? 'medium';
    notifyListeners();
  }

  Future<void> setAutoRecord(bool value) async {
    _autoRecord = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefAutoRecord, value);
    notifyListeners();
  }

  Future<void> setAutoRecordVideo(bool value) async {
    _autoRecordVideo = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefAutoRecordVideo, value);
    notifyListeners();
  }

  Future<void> setRecordingQuality(String quality) async {
    _recordingQuality = quality;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefRecordingQuality, quality);
    notifyListeners();
  }

  void setSource(String source) {
    _currentSource = source;
    notifyListeners();
  }

  void setRecordingType(RecordingType type) {
    _recordingType = type;
    notifyListeners();
  }

  Future<void> startRecording({
    required String userId,
    RecordingType? type,
    String? source,
  }) async {
    if (_isRecording) return;

    _recordingType = type ?? _recordingType;
    _currentSource = source ?? _currentSource;
    _isRecording = true;
    _currentDuration = Duration.zero;
    notifyListeners();

    await _recordingService.startRecording(
      type: _recordingType,
      quality: _recordingQuality,
    );

    // Start duration timer
    _startDurationTimer();
  }

  void _startDurationTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (_isRecording) {
        _currentDuration += const Duration(seconds: 1);
        notifyListeners();
        return true;
      }
      return false;
    });
  }

  Future<RecordingModel?> stopRecording({required String userId}) async {
    if (!_isRecording) return null;

    _isRecording = false;
    notifyListeners();

    final recording = await _recordingService.stopRecording(
      userId: userId,
      source: _currentSource,
      type: _recordingType,
      duration: _currentDuration,
    );

    if (recording != null) {
      _recordings.insert(0, recording);
      await _firestoreService.saveRecording(recording);
      notifyListeners();
    }

    _currentDuration = Duration.zero;
    return recording;
  }

  Future<void> loadRecordings(String userId) async {
    // Load from local storage (native recordings)
    final localRecordings = await _scanLocalRecordings(userId);

    // Load from Firestore
    List<RecordingModel> firestoreRecordings = [];
    try {
      firestoreRecordings = await _firestoreService.getRecordings(userId);
    } catch (e) {
      debugPrint('Failed to load from Firestore: $e');
    }

    // Merge: local files take priority, avoid duplicates by filePath
    final existingPaths = firestoreRecordings.map((r) => r.filePath).toSet();
    final merged = <RecordingModel>[...firestoreRecordings];
    for (final local in localRecordings) {
      if (!existingPaths.contains(local.filePath)) {
        merged.add(local);
      }
    }

    // Sort by date descending (newest first)
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _recordings = merged;
    notifyListeners();
  }

  /// Scan local directories for audio files (our app + MIUI built-in recorder)
  Future<List<RecordingModel>> _scanLocalRecordings(String userId) async {
    final List<RecordingModel> results = [];

    // Directories to scan: our app + MIUI built-in call recording locations
    final scanDirs = [
      '/storage/emulated/0/Documents/CallRecorder',
      '/storage/emulated/0/MIUI/sound_recorder/call_rec',
      '/storage/emulated/0/Music/Recordings/Call Recordings',
      '/storage/emulated/0/Recordings',
      '/storage/emulated/0/sound_recorder/call_rec',
    ];

    for (final dirPath in scanDirs) {
      try {
        final baseDir = Directory(dirPath);
        if (!await baseDir.exists()) continue;

        await for (final entity in baseDir.list(recursive: true)) {
          final path = entity.path.toLowerCase();
          if (entity is File &&
              (path.endsWith('.m4a') ||
                  path.endsWith('.wav') ||
                  path.endsWith('.mp3') ||
                  path.endsWith('.amr') ||
                  path.endsWith('.aac') ||
                  path.endsWith('.3gp'))) {
            final stat = await entity.stat();
            final fileName = p.basename(entity.path);

            // Skip corrupt/empty files (must be at least 4KB)
            if (stat.size < 4096) {
              debugPrint(
                'Skipping corrupt file (${stat.size} bytes): ${entity.path}',
              );
              continue;
            }

            // Parse source from filename: "SIM_193025.wav" -> "SIM"
            final parts = fileName.split('_');
            String source = parts.isNotEmpty ? parts.first : 'Unknown';
            // Fix old files with broken interpolation: "{source}" -> "SIM"
            if (source == '{source}' || source.isEmpty) source = 'SIM';

            // Estimate duration based on file format
            final Duration estimatedDuration;
            if (path.endsWith('.wav')) {
              // WAV: 44100Hz mono 16-bit = 88200 bytes/sec
              estimatedDuration = Duration(
                seconds: ((stat.size - 44) / 88200).round().clamp(1, 999999),
              );
            } else if (path.endsWith('.amr')) {
              // AMR: ~1.6KB/s
              estimatedDuration = Duration(
                seconds: (stat.size / 1600).round().clamp(1, 999999),
              );
            } else {
              // AAC/M4A/MP3/3GP: ~16KB/s for 128kbps
              estimatedDuration = Duration(
                seconds: (stat.size / 16000).round().clamp(1, 999999),
              );
            }

            results.add(
              RecordingModel(
                id: fileName, // Use filename as ID for local files
                userId: userId,
                fileName: fileName,
                filePath: entity.path,
                type: RecordingType.audio,
                source: source,
                duration: estimatedDuration,
                fileSize: stat.size,
                createdAt: stat.modified,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Failed to scan $dirPath: $e');
      }
    } // end for scanDirs
    return results;
  }

  Future<void> deleteRecording(RecordingModel recording) async {
    await _recordingService.deleteRecording(recording.filePath);
    try {
      await _firestoreService.deleteRecording(recording.id);
    } catch (_) {} // May not exist in Firestore for local-only recordings
    _recordings.removeWhere((r) => r.id == recording.id);
    notifyListeners();
  }

  Future<void> uploadRecording(RecordingModel recording) async {
    final url = await _firestoreService.uploadRecording(recording);
    if (url != null) {
      final updated = recording.copyWith(cloudUrl: url, isUploaded: true);
      await _firestoreService.updateRecording(updated);
      final index = _recordings.indexWhere((r) => r.id == recording.id);
      if (index != -1) {
        _recordings[index] = updated;
        notifyListeners();
      }
    }
  }
}

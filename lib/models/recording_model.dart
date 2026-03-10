import 'package:cloud_firestore/cloud_firestore.dart';

enum RecordingType { audio, video }

class RecordingModel {
  final String id;
  final String userId;
  final String fileName;
  final String filePath;
  final RecordingType type;
  final String source; // SIM, Zalo, WhatsApp, etc.
  final Duration duration;
  final int fileSize; // bytes
  final DateTime createdAt;
  final String? cloudUrl;
  final bool isUploaded;
  final String? callerNumber;
  final String? callerName;

  RecordingModel({
    required this.id,
    required this.userId,
    required this.fileName,
    required this.filePath,
    required this.type,
    required this.source,
    required this.duration,
    required this.fileSize,
    required this.createdAt,
    this.cloudUrl,
    this.isUploaded = false,
    this.callerNumber,
    this.callerName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'fileName': fileName,
      'filePath': filePath,
      'type': type == RecordingType.audio ? 'audio' : 'video',
      'source': source,
      'duration': duration.inSeconds,
      'fileSize': fileSize,
      'createdAt': Timestamp.fromDate(createdAt),
      'cloudUrl': cloudUrl,
      'isUploaded': isUploaded,
      'callerNumber': callerNumber,
      'callerName': callerName,
    };
  }

  factory RecordingModel.fromMap(Map<String, dynamic> map) {
    return RecordingModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      fileName: map['fileName'] ?? '',
      filePath: map['filePath'] ?? '',
      type: map['type'] == 'video' ? RecordingType.video : RecordingType.audio,
      source: map['source'] ?? 'Unknown',
      duration: Duration(seconds: map['duration'] ?? 0),
      fileSize: map['fileSize'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      cloudUrl: map['cloudUrl'],
      isUploaded: map['isUploaded'] ?? false,
      callerNumber: map['callerNumber'],
      callerName: map['callerName'],
    );
  }

  RecordingModel copyWith({String? cloudUrl, bool? isUploaded}) {
    return RecordingModel(
      id: id,
      userId: userId,
      fileName: fileName,
      filePath: filePath,
      type: type,
      source: source,
      duration: duration,
      fileSize: fileSize,
      createdAt: createdAt,
      cloudUrl: cloudUrl ?? this.cloudUrl,
      isUploaded: isUploaded ?? this.isUploaded,
      callerNumber: callerNumber,
      callerName: callerName,
    );
  }

  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

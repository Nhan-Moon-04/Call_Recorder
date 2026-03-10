import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../config/firebase_config.dart';
import '../models/recording_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Save recording metadata
  Future<void> saveRecording(RecordingModel recording) async {
    await _firestore
        .collection(FirebaseConfig.recordingsCollection)
        .doc(recording.id)
        .set(recording.toMap());
  }

  // Get all recordings for a user
  Future<List<RecordingModel>> getRecordings(String userId) async {
    final snapshot = await _firestore
        .collection(FirebaseConfig.recordingsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => RecordingModel.fromMap(doc.data()))
        .toList();
  }

  // Stream recordings for real-time updates
  Stream<List<RecordingModel>> streamRecordings(String userId) {
    return _firestore
        .collection(FirebaseConfig.recordingsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RecordingModel.fromMap(doc.data()))
              .toList(),
        );
  }

  // Delete recording
  Future<void> deleteRecording(String recordingId) async {
    final doc = await _firestore
        .collection(FirebaseConfig.recordingsCollection)
        .doc(recordingId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      // Delete from storage if uploaded
      if (data['isUploaded'] == true && data['cloudUrl'] != null) {
        try {
          await _storage.refFromURL(data['cloudUrl']).delete();
        } catch (_) {}
      }
    }

    await _firestore
        .collection(FirebaseConfig.recordingsCollection)
        .doc(recordingId)
        .delete();
  }

  // Update recording
  Future<void> updateRecording(RecordingModel recording) async {
    await _firestore
        .collection(FirebaseConfig.recordingsCollection)
        .doc(recording.id)
        .update(recording.toMap());
  }

  // Upload recording file to Firebase Storage
  Future<String?> uploadRecording(RecordingModel recording) async {
    try {
      final file = File(recording.filePath);
      if (!await file.exists()) return null;

      final ref = _storage.ref().child(
        '${FirebaseConfig.recordingsStoragePath}/${recording.userId}/${recording.fileName}',
      );

      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      return null;
    }
  }
}

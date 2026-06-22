import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/experiment.dart';
import '../models/session_record.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Experiments catalog
  // ---------------------------------------------------------------------------

  Stream<List<Experiment>> experimentsStream() {
    return _db.collection('experiments').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Experiment.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  // ---------------------------------------------------------------------------
  // Station locks
  // ---------------------------------------------------------------------------

  Stream<List<Station>> stationsStream(String experimentId) {
    return _db
        .collection('experiments')
        .doc(experimentId)
        .collection('stations')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Station.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> lockStation({
    required String experimentId,
    required String stationId,
    required String userId,
    required String displayName,
  }) async {
    await _db
        .collection('experiments')
        .doc(experimentId)
        .collection('stations')
        .doc(stationId)
        .set({
      'lockedBy': userId,
      'lockedByName': displayName,
      'lockedSince': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> unlockStation(String experimentId, String stationId) async {
    await _db
        .collection('experiments')
        .doc(experimentId)
        .collection('stations')
        .doc(stationId)
        .set({'lockedBy': null, 'lockedByName': null, 'lockedSince': null});
  }

  // ---------------------------------------------------------------------------
  // Session history
  // ---------------------------------------------------------------------------

  Future<String> saveSession(SessionRecord record) async {
    final ref = await _db.collection('sessions').add(record.toMap());
    return ref.id;
  }

  Future<void> endSession(String sessionId, double peakCurrentMa) async {
    await _db.collection('sessions').doc(sessionId).update({
      'endedAt': DateTime.now().millisecondsSinceEpoch,
      'peakCurrentMa': peakCurrentMa,
    });
  }

  Stream<List<SessionRecord>> userSessionsStream(String userId) {
    return _db
        .collection('sessions')
        .where('userId', isEqualTo: userId)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SessionRecord.fromMap(doc.id, doc.data()))
            .toList());
  }
}

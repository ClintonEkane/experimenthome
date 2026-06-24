class SessionRecord {
  final String id;
  final String userId;
  final String experimentId;
  final String stationId;
  final int resistorOhms;
  final double peakCurrentMa;
  final DateTime startedAt;
  final DateTime? endedAt;

  const SessionRecord({
    required this.id,
    required this.userId,
    required this.experimentId,
    required this.stationId,
    required this.resistorOhms,
    required this.peakCurrentMa,
    required this.startedAt,
    this.endedAt,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'experimentId': experimentId,
        'stationId': stationId,
        'resistorOhms': resistorOhms,
        'peakCurrentMa': peakCurrentMa,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'endedAt': endedAt?.millisecondsSinceEpoch,
      };

  factory SessionRecord.fromMap(String id, Map<String, dynamic> map) {
    return SessionRecord(
      id: id,
      userId: map['userId'] as String,
      experimentId: map['experimentId'] as String,
      stationId: map['stationId'] as String,
      resistorOhms: map['resistorOhms'] as int,
      peakCurrentMa: (map['peakCurrentMa'] as num).toDouble(),
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['startedAt'] as int),
      endedAt: map['endedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endedAt'] as int)
          : null,
    );
  }
}

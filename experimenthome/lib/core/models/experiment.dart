class Station {
  final String id;
  final String? lockedBy;
  final String? lockedByName;
  final DateTime? lockedSince;

  const Station({
    required this.id,
    this.lockedBy,
    this.lockedByName,
    this.lockedSince,
  });

  bool get isStale =>
      lockedSince != null &&
      DateTime.now().difference(lockedSince!).inMinutes > 10;

  bool get isAvailable => lockedBy == null || isStale;
  bool isAvailableFor(String userId) =>
      lockedBy == null || lockedBy == userId || isStale;

  factory Station.fromMap(String id, Map<String, dynamic> map) {
    return Station(
      id: id,
      lockedBy: map['lockedBy'] as String?,
      lockedByName: map['lockedByName'] as String?,
      lockedSince: map['lockedSince'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lockedSince'] as int)
          : null,
    );
  }
}

class Experiment {
  final String id;
  final String name;
  final String description;
  final List<Station> stations;

  const Experiment({
    required this.id,
    required this.name,
    required this.description,
    required this.stations,
  });

  int get totalStations => stations.length;
  int get availableStations => stations.where((s) => s.isAvailable).length;

  factory Experiment.fromMap(String id, Map<String, dynamic> map) {
    return Experiment(
      id: id,
      name: (map['name'] as String?) ?? 'Unnamed Experiment',
      description: (map['description'] as String?) ?? '',
      stations: const [],
    );
  }
}

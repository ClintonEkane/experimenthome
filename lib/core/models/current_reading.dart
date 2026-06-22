class CurrentReading {
  final double currentMa;
  final DateTime timestamp;

  const CurrentReading({required this.currentMa, required this.timestamp});

  factory CurrentReading.fromJson(Map<String, dynamic> json) {
    return CurrentReading(
      currentMa: (json['current_mA'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
          (json['timestamp'] as num).toInt() * 1000),
    );
  }
}

class MqttTopics {
  MqttTopics._();

  static String control(String experimentId, String stationId) =>
      'experiments/$experimentId/stations/$stationId/control';

  static String current(String experimentId, String stationId) =>
      'experiments/$experimentId/stations/$stationId/current';

  static String status(String experimentId, String stationId) =>
      'experiments/$experimentId/stations/$stationId/status';

  static String session(String experimentId, String stationId) =>
      'experiments/$experimentId/stations/$stationId/session';
}

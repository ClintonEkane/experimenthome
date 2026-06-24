import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_client_factory.dart';
import '../constants/mqtt_topics.dart';
import '../models/current_reading.dart';

enum DeviceStatus { online, stale, offline }

class MqttService {
  MqttClient? _client;

  final _currentController = StreamController<CurrentReading>.broadcast();
  final _statusController = StreamController<DeviceStatus>.broadcast();

  Stream<CurrentReading> get currentStream => _currentController.stream;
  Stream<DeviceStatus> get statusStream => _statusController.stream;

  DeviceStatus _deviceStatus = DeviceStatus.offline;
  DeviceStatus get deviceStatus => _deviceStatus;

  DateTime? _lastHeartbeat;
  Timer? _heartbeatWatcher;

  String? _experimentId;
  String? _stationId;

  // ---------------------------------------------------------------------------
  // Connect
  // ---------------------------------------------------------------------------

  Future<void> connect({
    required String broker,
    required int port,
    required String username,
    required String password,
    required String clientId,
    required String experimentId,
    required String stationId,
  }) async {
    _experimentId = experimentId;
    _stationId = stationId;

    _client = createMqttClient(broker, clientId, port);
    _client!.keepAlivePeriod = 20;
    _client!.onDisconnected = _onDisconnected;

    // LWT — broker publishes this if we disconnect ungracefully
    _client!.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(username, password)
        .withWillTopic(MqttTopics.session(experimentId, stationId))
        .withWillMessage(jsonEncode({'online': false, 'reason': 'lwt'}))
        .withWillQos(MqttQos.atLeastOnce)
        .startClean();

    try {
      await _client!.connect(username, password);
    } catch (_) {
      _client!.disconnect();
      return;
    }

    if (_client!.connectionStatus!.state != MqttConnectionState.connected) {
      return;
    }

    _subscribe();
    _startHeartbeatWatcher();
  }

  // ---------------------------------------------------------------------------
  // Subscribe to incoming topics
  // ---------------------------------------------------------------------------

  void _subscribe() {
    final currentTopic = MqttTopics.current(_experimentId!, _stationId!);
    final statusTopic = MqttTopics.status(_experimentId!, _stationId!);

    _client!.subscribe(currentTopic, MqttQos.atMostOnce);
    _client!.subscribe(statusTopic, MqttQos.atMostOnce);

    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (final msg in messages) {
        final payload = MqttPublishPayload.bytesToStringAsString(
          (msg.payload as MqttPublishMessage).payload.message,
        );
        final data = jsonDecode(payload) as Map<String, dynamic>;

        if (msg.topic == currentTopic) {
          _currentController.add(CurrentReading.fromJson(data));
        } else if (msg.topic == statusTopic) {
          _lastHeartbeat = DateTime.now();
          _setStatus(DeviceStatus.online);
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Publish commands
  // ---------------------------------------------------------------------------

  void sendCommand(Map<String, dynamic> payload) {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }
    final topic = MqttTopics.control(_experimentId!, _stationId!);
    final builder = MqttClientPayloadBuilder()..addString(jsonEncode(payload));
    _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void startExperiment() => sendCommand({'action': 'start'});
  void stopExperiment() => sendCommand({'action': 'stop'});
  void selectResistor(int ohms) =>
      sendCommand({'action': 'select_resistor', 'value': ohms});

  // ---------------------------------------------------------------------------
  // Heartbeat watcher — Online / Stale / Offline
  // ---------------------------------------------------------------------------

  void _startHeartbeatWatcher() {
    _heartbeatWatcher?.cancel();
    _heartbeatWatcher = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_lastHeartbeat == null) return;
      final elapsed = DateTime.now().difference(_lastHeartbeat!).inSeconds;
      if (elapsed <= 10) {
        _setStatus(DeviceStatus.online);
      } else if (elapsed <= 30) {
        _setStatus(DeviceStatus.stale);
      } else {
        _setStatus(DeviceStatus.offline);
      }
    });
  }

  void _setStatus(DeviceStatus s) {
    if (s != _deviceStatus) {
      _deviceStatus = s;
      _statusController.add(s);
    }
  }

  void _onDisconnected() {
    _setStatus(DeviceStatus.offline);
  }

  // ---------------------------------------------------------------------------
  // Disconnect
  // ---------------------------------------------------------------------------

  void disconnect() {
    _heartbeatWatcher?.cancel();
    _client?.disconnect();
  }

  void dispose() {
    disconnect();
    _currentController.close();
    _statusController.close();
  }
}

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

MqttClient createMqttClient(String broker, String clientId, int port) {
  final client = MqttBrowserClient('wss://$broker/mqtt', clientId);
  client.port = 8884;
  return client;
}

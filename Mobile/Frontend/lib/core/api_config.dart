/// Spring Boot `http://localhost:8080` → Android emülatörde `10.0.2.2` (host makine loopback).
/// Fiziksel cihazda bilgisayarın LAN IP’sini kullanın (ör. `192.168.1.x`).
class ApiConfig {
  ApiConfig._();

  static const String emulatorHost = '10.0.2.2';
  static const int port = 8080;
  static const String apiPrefix = '/api/v1';

  /// Emülatör + yerel backend için varsayılan taban URL.
  static const String baseUrl = 'http://$emulatorHost:$port$apiPrefix';
}

/// MQTT broker adresi. Broker aynı PC’de çalışıyorsa emülatörden `10.0.2.2`.
/// Ağdaki Raspberry / HiveMQ için cihazın erişebildiği IP’yi girin.
class MqttConfig {
  MqttConfig._();

  static const String brokerHost = '10.0.2.2';
  static const int port = 1883;
  static const String clientId = 'AgroTwin_App_01';
  static const String topicSensor = 'agrotwin/sensorler';
  static const String topicCommand = 'agrotwin/komutlar';
}

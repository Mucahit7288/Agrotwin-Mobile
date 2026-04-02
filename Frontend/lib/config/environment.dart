/// Environment configuration - separates backend/frontend concerns
/// Backend tarafında değişirse, buradan güncellemen yeterli.
class Environment {
  // MQTT Configuration (Broker Details)
  static const String mqttBroker = 'broker.hivemq.com';
  static const String mqttTopicSensor = 'agrotwin/sensorler';
  static const String mqttTopicCommand = 'agrotwin/komutlar';
  static const String mqttWebSocketPath = '/mqtt';
  static const List<int> mqttWebWssPorts = [8884, 443];
  static const Duration mqttConnectTimeout = Duration(seconds: 20);
  static const bool mqttSecure = true;
  static const bool mqttUseWebSocket = true;

  // Backend API Configuration (Backend tarafran yazacak)
  // TODO: Backend developer buraya API endpoints ekleyecek
  // static const String backendApiUrl = 'http://localhost:8080';
  // static const String backendApiVersion = 'v1';

  // App Configuration
  static const String appName = 'AgroTwin';
  static const String appVersion = '1.0.0';

  /// DEV ONLY: Hızlı test için override'lar
  /// Üretimde bu section'ı comment out et veya remove et.
  static bool enableDebugLogging = false;
}

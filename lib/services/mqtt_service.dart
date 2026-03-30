import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../core/app_state.dart';

class MqttService {
  static const String _broker    = '192.168.1.100';
  static const int    _port      = 1883;
  static const String _clientId  = 'AgroTwin_App_01';
  static const String _topicSensor  = 'agrotwin/sensorler';
  static const String _topicCommand = 'agrotwin/komutlar';
  static const Duration _connectTimeout = Duration(seconds: 10);

  MqttServerClient? _client;
  final AppState state;

  MqttService(this.state);

  Future<void> connect() async {
    if (state.mqttConnecting || state.mqttConnected) return;
    state.setMqttStatus(false, connecting: true);

    try { _client?.disconnect(); } catch (_) {}

    _client = MqttServerClient(_broker, _clientId)
      ..port = _port
      ..keepAlivePeriod = 30
      ..autoReconnect = true
      ..onDisconnected = _onDisconnected
      ..onConnected   = _onConnected
      ..logging(on: false);

    _client!.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(_clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    try {
      await _client!.connect().timeout(_connectTimeout);
    } on TimeoutException {
      debugPrint(
        '[MQTT] Zaman aşımı: $_broker:$_port yanıt vermedi. '
        'Emülatör kullanıyorsanız IP\'yi kontrol edin (ör. 10.0.2.2).',
      );
      _safeDisconnect();
      state.setMqttStatus(false);
      return;
    } catch (e) {
      debugPrint('[MQTT] Bağlantı hatası: $e');
      _safeDisconnect();
      state.setMqttStatus(false);
      return;
    }

    if (_client!.connectionStatus?.state != MqttConnectionState.connected) {
      debugPrint('[MQTT] Bağlantı kurulamadı: ${_client!.connectionStatus?.state}');
      _safeDisconnect();
      state.setMqttStatus(false);
      return;
    }

    _client!.subscribe(_topicSensor, MqttQos.atMostOnce);
    _client!.updates!.listen(_onMessage);
    state.setMqttStatus(true);
  }

  void _onConnected()    { debugPrint('[MQTT] Bağlı: $_broker'); state.setMqttStatus(true); }
  void _onDisconnected() { debugPrint('[MQTT] Bağlantı kesildi'); state.setMqttStatus(false); }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final msg in messages) {
      final raw     = msg.payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(raw.payload.message);
      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        state.updateSensor(SensorData.fromJson(json));
      } catch (e) {
        debugPrint('[MQTT] JSON parse hatası: $e');
      }
    }
  }

  /// [cihaz]: pompa | fan | isitici   [durum]: ON | OFF
  void publish(String cihaz, String durum) {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      debugPrint('[MQTT] Bağlı değil, komut gönderilemedi.');
      return;
    }
    final payload = jsonEncode({'cihaz': cihaz, 'durum': durum});
    final builder = MqttClientPayloadBuilder()..addString(payload);
    _client!.publishMessage(_topicCommand, MqttQos.atLeastOnce, builder.payload!);
    debugPrint('[MQTT] → $_topicCommand : $payload');
  }

  void _safeDisconnect() { try { _client?.disconnect(); } catch (_) {} }
  void disconnect()      => _safeDisconnect();
}

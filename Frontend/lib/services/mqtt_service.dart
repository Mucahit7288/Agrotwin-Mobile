import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../core/api_config.dart';
import '../core/app_state.dart';

class MqttService {
  static const Duration _connectTimeout = Duration(seconds: 10);

  MqttServerClient? _client;
  final AppState state;

  MqttService(this.state);

  Future<void> connect() async {
    if (state.mqttConnecting || state.mqttConnected) return;
    state.setMqttStatus(false, connecting: true);

    try { _client?.disconnect(); } catch (_) {}

    _client = MqttServerClient(MqttConfig.brokerHost, MqttConfig.clientId)
      ..port = MqttConfig.port
      ..keepAlivePeriod = 30
      ..autoReconnect = true
      ..onDisconnected = _onDisconnected
      ..onConnected   = _onConnected
      ..logging(on: false);

    _client!.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(MqttConfig.clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    try {
      await _client!.connect().timeout(_connectTimeout);
    } on TimeoutException {
      debugPrint(
        '[MQTT] Zaman aşımı: ${MqttConfig.brokerHost}:${MqttConfig.port} '
        'yanıt vermedi. Broker kapalıysa normal; '
        'ayarı lib/core/api_config.dart içinde değiştirin.',
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

    _client!.subscribe(MqttConfig.topicSensor, MqttQos.atMostOnce);
    _client!.updates!.listen(_onMessage);
    state.setMqttStatus(true);
  }

  void _onConnected() {
    debugPrint('[MQTT] Bağlı: ${MqttConfig.brokerHost}');
    state.setMqttStatus(true);
  }
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
    _client!.publishMessage(
      MqttConfig.topicCommand,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
    debugPrint('[MQTT] → ${MqttConfig.topicCommand} : $payload');
  }

  void _safeDisconnect() { try { _client?.disconnect(); } catch (_) {} }
  void disconnect()      => _safeDisconnect();
}

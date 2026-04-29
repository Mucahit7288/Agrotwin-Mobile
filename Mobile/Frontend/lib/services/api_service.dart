import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../core/api_config.dart';
import '../models/sensor_log.dart';
import '../models/price_forecast.dart';
import '../models/energy_schedule.dart';

class ApiService {
  static const Duration _timeout = Duration(seconds: 10);

  final String _baseUrl;
  final http.Client _client;

  ApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  // ─────────────────────────────────────────
  // SENSOR LOGS
  // ─────────────────────────────────────────

  /// /sensors/latest → Tek bir SensorLog döner; yoksa listeden son kayıt.
  Future<SensorLog> getLatestSensorLog() async {
    final uri = Uri.parse('$_baseUrl/sensors/latest');
    try {
      final response = await _client.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return SensorLog.fromJson(json);
      }
      if (response.statusCode == 404) {
        final all = await getAllSensorLogs();
        if (all.isEmpty) {
          throw Exception('getLatestSensorLog: liste boş (404 + /sensors).');
        }
        return all.last;
      }
      throw Exception(
        'getLatestSensorLog başarısız: '
        'HTTP ${response.statusCode} — ${response.body}',
      );
    } on SocketException {
      throw Exception(
        'Sunucuya bağlanılamadı. Emülatörde 10.0.2.2:8080 '
        'adresine erişilemiyor. Backend çalışıyor mu?',
      );
    } on TimeoutException {
      throw Exception(
        'İstek zaman aşımına uğradı (>${_timeout.inSeconds}s). '
        'Sunucu yanıt vermiyor.',
      );
    } catch (e) {
      throw Exception('getLatestSensorLog — beklenmedik hata: $e');
    }
  }

  /// /sensors → SensorLog listesi döner.
  Future<List<SensorLog>> getAllSensorLogs() async {
    final uri = Uri.parse('$_baseUrl/sensors');
    try {
      final response = await _client.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList
            .map((item) => SensorLog.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(
          'getAllSensorLogs başarısız: '
          'HTTP ${response.statusCode} — ${response.body}',
        );
      }
    } on SocketException {
      throw Exception(
        'Sunucuya bağlanılamadı. Backend çalışıyor ve '
        '10.0.2.2:8080 erişilebilir mi?',
      );
    } on TimeoutException {
      throw Exception('İstek zaman aşımına uğradı (>${_timeout.inSeconds}s).');
    } catch (e) {
      throw Exception('getAllSensorLogs — beklenmedik hata: $e');
    }
  }

  // ─────────────────────────────────────────
  // PRICE FORECASTS
  // ─────────────────────────────────────────

  /// /price-forecasts → PriceForecast listesi döner.
  Future<List<PriceForecast>> getPriceForecasts() async {
    final uri = Uri.parse('$_baseUrl/price-forecasts');
    try {
      final response = await _client.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList
            .map((item) => PriceForecast.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(
          'getPriceForecasts başarısız: '
          'HTTP ${response.statusCode} — ${response.body}',
        );
      }
    } on SocketException {
      throw Exception('Sunucuya bağlanılamadı (getPriceForecasts).');
    } on TimeoutException {
      throw Exception('İstek zaman aşımına uğradı (getPriceForecasts).');
    } catch (e) {
      throw Exception('getPriceForecasts — beklenmedik hata: $e');
    }
  }

  // ─────────────────────────────────────────
  // ENERGY SCHEDULES
  // ─────────────────────────────────────────

  /// /energy-schedules → EnergySchedule listesi döner.
  Future<List<EnergySchedule>> getEnergySchedules() async {
    final uri = Uri.parse('$_baseUrl/energy-schedules');
    try {
      final response = await _client.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList
            .map(
              (item) => EnergySchedule.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
      if (response.statusCode == 404) {
        debugPrint(
          '[API] energy-schedules henüz yok (404) — boş liste döndürülüyor.',
        );
        return [];
      }
      throw Exception(
        'getEnergySchedules başarısız: '
        'HTTP ${response.statusCode} — ${response.body}',
      );
    } on SocketException {
      throw Exception('Sunucuya bağlanılamadı (getEnergySchedules).');
    } on TimeoutException {
      throw Exception('İstek zaman aşımına uğradı (getEnergySchedules).');
    } catch (e) {
      throw Exception('getEnergySchedules — beklenmedik hata: $e');
    }
  }
}

// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SensorData {
  final double tOrtam;
  final double hOrtam;
  final double tSu;
  final double suMesafe;
  final int isikAnalog;

  const SensorData({
    this.tOrtam = 23.5,
    this.hOrtam = 62.0,
    this.tSu = 21.8,
    this.suMesafe = 14.0,
    this.isikAnalog = 2048,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) => SensorData(
    tOrtam: double.tryParse(json['T_ortam']?.toString() ?? '') ?? 23.5,
    hOrtam: double.tryParse(json['H_ortam']?.toString() ?? '') ?? 62.0,
    tSu: double.tryParse(json['T_su']?.toString() ?? '') ?? 21.8,
    suMesafe: double.tryParse(json['Su_Mesafe_cm']?.toString() ?? '') ?? 14.0,
    isikAnalog: int.tryParse(json['Isik_Analog']?.toString() ?? '') ?? 2048,
  );

  double get suSeviyePct => ((25.0 - suMesafe) / 25.0).clamp(0.0, 1.0);
  double get isikPct => (isikAnalog / 4095.0).clamp(0.0, 1.0);
}

enum SensorAnalyticsKind { ph, ortamSicaklik, ortamNem, suSicaklik, suSeviye }

class AppState extends ChangeNotifier {
  AppState(this._prefs) {
    _loadAuth();
  }

  final SharedPreferences _prefs;

  // Sensör
  SensorData sensorData = const SensorData();

  // MQTT
  bool mqttConnected = false;
  bool mqttConnecting = false;

  // Aktüatörler
  bool pompaOn = false;
  bool fanOn = false;
  bool isiticiOn = false;
  bool ledOn = true;
  double ledPwm = 0.75;

  // Kontrol
  int kontrolModu = 0;
  String seciliRecete = 'Kıvırcık Marul - Büyüme Fazı';

  // Simülatör
  double simPh = 6.2;
  double simEc = 1.8;
  double simIsikSaat = 16.0;
  double simSicaklik = 22.0;

  // Analitik yönlendirme
  SensorAnalyticsKind? analyticJumpTarget;
  bool analyticScrollToChart = false;
  int analyticJumpGeneration = 0;

  // Kimlik doğrulama
  bool _loggedIn = false;
  String _userEmail = '';
  String _userName = '';
  String _userPhone = '';

  bool get isLoggedIn => _loggedIn;
  String get userEmail => _userEmail;
  String get userName => _userName;
  String get userPhone => _userPhone;

  void _loadAuth() {
    _loggedIn = _prefs.getBool('auth_logged_in') ?? false;
    _userEmail = _prefs.getString('auth_email') ?? '';
    _userName = _prefs.getString('auth_name') ?? '';
    _userPhone = _prefs.getString('auth_phone') ?? '';
  }

  Future<void> _persistAuth() async {
    await _prefs.setBool('auth_logged_in', _loggedIn);
    await _prefs.setString('auth_email', _userEmail);
    await _prefs.setString('auth_name', _userName);
    await _prefs.setString('auth_phone', _userPhone);
  }

  Future<String?> login(String email, String password) async {
    final emailNorm = email.trim().toLowerCase();
    if (emailNorm.isEmpty || password.isEmpty)
      return 'E-posta ve şifre gerekli.';
    final usersJson = _prefs.getStringList('auth_users') ?? [];
    for (final row in usersJson) {
      final m = jsonDecode(row) as Map<String, dynamic>;
      if (m['email']?.toString().toLowerCase() == emailNorm &&
          m['password'] == password) {
        _loggedIn = true;
        _userEmail = m['email'] as String;
        _userName = (m['name'] as String?)?.trim() ?? '';
        _userPhone = (m['phone'] as String?)?.trim() ?? '';
        await _persistAuth();
        notifyListeners();
        return null;
      }
    }
    return 'E-posta veya şifre hatalı.';
  }

  void developerLogin() {
    _loggedIn = true;
    _userEmail = 'dev@agrotwin.local';
    _userName = 'Geliştirici';
    _userPhone = '';
    notifyListeners();
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    final emailNorm = email.trim().toLowerCase();
    if (name.trim().isEmpty) return 'Ad soyad gerekli.';
    if (emailNorm.isEmpty || !emailNorm.contains('@'))
      return 'Geçerli bir e-posta girin.';
    if (password.length < 4) return 'Şifre en az 4 karakter olmalı.';
    final usersJson = _prefs.getStringList('auth_users') ?? [];
    for (final row in usersJson) {
      final m = jsonDecode(row) as Map<String, dynamic>;
      if (m['email']?.toString().toLowerCase() == emailNorm)
        return 'Bu e-posta zaten kayıtlı.';
    }
    usersJson.add(
      jsonEncode({
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'phone': phone.trim(),
      }),
    );
    await _prefs.setStringList('auth_users', usersJson);
    return null;
  }

  Future<void> logout() async {
    _loggedIn = false;
    await _persistAuth();
    notifyListeners();
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
  }) async {
    _userName = name.trim();
    _userPhone = phone.trim();
    await _persistAuth();
    final usersJson = _prefs.getStringList('auth_users') ?? [];
    final emailNorm = _userEmail.toLowerCase();
    final next = <String>[];
    for (final row in usersJson) {
      final m = Map<String, dynamic>.from(jsonDecode(row) as Map);
      if (m['email']?.toString().toLowerCase() == emailNorm) {
        m['name'] = _userName;
        m['phone'] = _userPhone;
        next.add(jsonEncode(m));
      } else {
        next.add(row);
      }
    }
    await _prefs.setStringList('auth_users', next);
    notifyListeners();
  }

  void setAnalyticJump(SensorAnalyticsKind? k, {bool scrollToChart = false}) {
    analyticJumpTarget = k;
    analyticScrollToChart = scrollToChart;
    analyticJumpGeneration++;
    notifyListeners();
  }

  void clearAnalyticJump() {
    analyticJumpTarget = null;
    analyticScrollToChart = false;
    notifyListeners();
  }

  void updateSensor(SensorData data) {
    sensorData = data;
    notifyListeners();
  }

  void setMqttStatus(bool connected, {bool connecting = false}) {
    mqttConnected = connected;
    mqttConnecting = connecting;
    notifyListeners();
  }

  void togglePompa() {
    pompaOn = !pompaOn;
    notifyListeners();
  }

  void toggleFan() {
    fanOn = !fanOn;
    notifyListeners();
  }

  void toggleIsitici() {
    isiticiOn = !isiticiOn;
    notifyListeners();
  }

  void toggleLed() {
    ledOn = !ledOn;
    notifyListeners();
  }

  void setLedPwm(double v) {
    ledPwm = v;
    notifyListeners();
  }

  void setKontrolModu(int m) {
    kontrolModu = m;
    notifyListeners();
  }

  void setRecete(String r) {
    seciliRecete = r;
    notifyListeners();
  }

  // ── Simülatör ─────────────────────────────────────────────────────────────────
  void setSimPh(double v) {
    simPh = v;
    notifyListeners();
  }

  void setSimEc(double v) {
    simEc = v;
    notifyListeners();
  }

  void setSimIsikSaat(double v) {
    simIsikSaat = v;
    notifyListeners();
  }

  void setSimSicaklik(double v) {
    simSicaklik = v;
    notifyListeners();
  }

  int get tahminiHasatGun {
    final score = (simPh - 5.5) / 1.5 + (simEc - 1.0) / 1.5;
    return (6 - score.clamp(0, 2)).round();
  }

  double get tahminiMaliyet =>
      80 + simIsikSaat * 2.5 + (simSicaklik > 24 ? 30 : 0);
}

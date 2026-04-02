/// Spring Boot + Jackson genelde **camelCase** JSON üretir; MQTT yükleri eski
/// `T_ortam` anahtarlarını kullanabilir — [fromJson] ikisini de kabul eder.
class SensorLog {
  final int? id;
  final String? timestamp;
  final double? tOrtam;
  final double? hOrtam;
  final double? tSu;
  final double? suMesafeCm;
  final double? isikAnalog;
  final double? elektrikFiyati;
  final bool? pompaKarar;
  final bool? fanKarar;
  final bool? isiticiKarar;
  final bool? tahliyeKarar;

  const SensorLog({
    this.id,
    this.timestamp,
    this.tOrtam,
    this.hOrtam,
    this.tSu,
    this.suMesafeCm,
    this.isikAnalog,
    this.elektrikFiyati,
    this.pompaKarar,
    this.fanKarar,
    this.isiticiKarar,
    this.tahliyeKarar,
  });

  static int? _id(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _dbl(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// ON/OFF, 0/1, bool — backend bazen string karar döner.
  static bool? _bool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().trim().toUpperCase();
    if (s == 'ON' || s == 'TRUE' || s == '1') return true;
    if (s == 'OFF' || s == 'FALSE' || s == '0') return false;
    return null;
  }

  factory SensorLog.fromJson(Map<String, dynamic> json) {
    return SensorLog(
      id: _id(json['id']),
      timestamp: json['timestamp']?.toString(),
      tOrtam: _dbl(json['tOrtam'] ?? json['t_ortam'] ?? json['T_ortam']),
      hOrtam: _dbl(json['hOrtam'] ?? json['h_ortam'] ?? json['H_ortam']),
      tSu: _dbl(json['tSu'] ?? json['t_su'] ?? json['T_su']),
      suMesafeCm: _dbl(
        json['suMesafeCm'] ?? json['su_mesafe_cm'] ?? json['Su_Mesafe_cm'],
      ),
      isikAnalog: _dbl(
        json['isikAnalog'] ?? json['isik_analog'] ?? json['Isik_Analog'],
      ),
      elektrikFiyati: _dbl(json['elektrikFiyati'] ?? json['elektrik_fiyati']),
      pompaKarar: _bool(json['pompaKarar'] ?? json['pompa_karar']),
      fanKarar: _bool(json['fanKarar'] ?? json['fan_karar']),
      isiticiKarar: _bool(
        json['isiticiKarar'] ??
            json['isitiiciKarar'] /* backend yazım hatası */ ??
            json['isitici_karar'],
      ),
      tahliyeKarar: _bool(json['tahliyeKarar'] ?? json['tahliye_karar']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp,
      'tOrtam': tOrtam,
      'hOrtam': hOrtam,
      'tSu': tSu,
      'suMesafeCm': suMesafeCm,
      'isikAnalog': isikAnalog,
      'elektrikFiyati': elektrikFiyati,
      'pompaKarar': pompaKarar,
      'fanKarar': fanKarar,
      'isiticiKarar': isiticiKarar,
      'tahliyeKarar': tahliyeKarar,
    };
  }

  SensorLog copyWith({
    int? id,
    String? timestamp,
    double? tOrtam,
    double? hOrtam,
    double? tSu,
    double? suMesafeCm,
    double? isikAnalog,
    double? elektrikFiyati,
    bool? pompaKarar,
    bool? fanKarar,
    bool? isiticiKarar,
    bool? tahliyeKarar,
  }) {
    return SensorLog(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      tOrtam: tOrtam ?? this.tOrtam,
      hOrtam: hOrtam ?? this.hOrtam,
      tSu: tSu ?? this.tSu,
      suMesafeCm: suMesafeCm ?? this.suMesafeCm,
      isikAnalog: isikAnalog ?? this.isikAnalog,
      elektrikFiyati: elektrikFiyati ?? this.elektrikFiyati,
      pompaKarar: pompaKarar ?? this.pompaKarar,
      fanKarar: fanKarar ?? this.fanKarar,
      isiticiKarar: isiticiKarar ?? this.isiticiKarar,
      tahliyeKarar: tahliyeKarar ?? this.tahliyeKarar,
    );
  }

  @override
  String toString() =>
      'SensorLog(id: $id, timestamp: $timestamp, '
      'tOrtam: $tOrtam, hOrtam: $hOrtam, tSu: $tSu)';
}

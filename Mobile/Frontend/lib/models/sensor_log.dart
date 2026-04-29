/// Spring Boot + Jackson genelde **camelCase** JSON üretir; MQTT yükleri eski
/// `T_ortam` anahtarlarını kullanabilir — [fromJson] ikisini de kabul eder.
///
/// ── Güncelleme Özeti (Java Entity ile Uyum) ─────────────────────────────────
///   • isikAnalog  : double? → **int?**  (Java: @JsonProperty("Isik_Analog") Integer)
///   • pompaKarar  : bool?  (_bool() ON/OFF string parse eder)
///   • fanKarar    : bool?
///   • isiticiKarar: bool?
///   • tahliyeKarar: bool?  (Java: @JsonProperty("tahliye_karar") String)
class SensorLog {
  final int? id;
  final String? timestamp;

  /// @JsonProperty("T_ortam")
  final double? tOrtam;

  /// @JsonProperty("H_ortam")
  final double? hOrtam;

  /// @JsonProperty("T_su")
  final double? tSu;

  /// @JsonProperty("Su_Mesafe_cm")
  final double? suMesafeCm;

  /// @JsonProperty("Isik_Analog") — Java'da Integer → Flutter'da int?
  /// (Önceden double? idi — DÜZELTİLDİ)
  final int? isikAnalog;

  /// @JsonProperty("elektrik_fiyati")
  final double? elektrikFiyati;

  /// @JsonProperty("pompa_karar") — Java String (ON/OFF) → bool? via _bool()
  final bool? pompaKarar;

  /// @JsonProperty("fan_karar")
  final bool? fanKarar;

  /// @JsonProperty("isitici_karar")
  final bool? isiticiKarar;

  /// @JsonProperty("tahliye_karar")
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

  // ── Dönüştürücü yardımcılar ────────────────────────────────────────────────

  static int? _id(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  /// Integer alanlar için (Isik_Analog).
  static int? _int(dynamic v) {
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

  /// ON/OFF, 0/1, bool, "TRUE"/"FALSE" — backend String karar gönderebilir.
  static bool? _bool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().trim().toUpperCase();
    if (s == 'ON' || s == 'TRUE' || s == '1') return true;
    if (s == 'OFF' || s == 'FALSE' || s == '0') return false;
    return null;
  }

  // ── fromJson ───────────────────────────────────────────────────────────────
  /// Anahtar önceliği: camelCase → snake_case → Java @JsonProperty değeri.
  factory SensorLog.fromJson(Map<String, dynamic> json) {
    return SensorLog(
      id: _id(json['id']),
      timestamp: json['timestamp']?.toString(),

      tOrtam: _dbl(json['tOrtam'] ?? json['t_ortam'] ?? json['T_ortam']),
      hOrtam: _dbl(json['hOrtam'] ?? json['h_ortam'] ?? json['H_ortam']),
      tSu: _dbl(json['tSu'] ?? json['t_su'] ?? json['T_su']),

      suMesafeCm: _dbl(
        json['suMesafeCm'] ??
            json['su_mesafe_cm'] ??
            json['Su_Mesafe_cm'],
      ),

      // Java: Integer Isik_Analog → _int kullanıyoruz (önceki _dbl hatalıydı)
      isikAnalog: _int(
        json['isikAnalog'] ??
            json['isik_analog'] ??
            json['Isik_Analog'],
      ),

      elektrikFiyati: _dbl(
        json['elektrikFiyati'] ?? json['elektrik_fiyati'],
      ),

      // Java: String pompa_karar (ON/OFF) → bool
      pompaKarar: _bool(json['pompaKarar'] ?? json['pompa_karar']),
      fanKarar: _bool(json['fanKarar'] ?? json['fan_karar']),

      // backend'de "isitiiciKarar" yazım hatası da destekleniyor
      isiticiKarar: _bool(
        json['isiticiKarar'] ??
            json['isitiiciKarar'] /* backend yazım hatası */ ??
            json['isitici_karar'],
      ),

      tahliyeKarar: _bool(
        json['tahliyeKarar'] ?? json['tahliye_karar'],
      ),
    );
  }

  // ── toJson ─────────────────────────────────────────────────────────────────
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

  // ── copyWith ───────────────────────────────────────────────────────────────
  SensorLog copyWith({
    int? id,
    String? timestamp,
    double? tOrtam,
    double? hOrtam,
    double? tSu,
    double? suMesafeCm,
    int? isikAnalog, // ← int? (önceden double? idi)
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
      'tOrtam: $tOrtam, hOrtam: $hOrtam, tSu: $tSu, '
      'isikAnalog: $isikAnalog, elektrikFiyati: $elektrikFiyati, '
      'pompa: $pompaKarar, fan: $fanKarar, '
      'isitici: $isiticiKarar, tahliye: $tahliyeKarar)';
}
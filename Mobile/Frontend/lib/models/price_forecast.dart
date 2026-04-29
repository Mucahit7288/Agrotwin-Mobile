class PriceForecast {
  final int? id;
  final String? timestamp;
  /// API saat dilimini ISO string olarak döndürebilir (`forecastHour` alanı).
  final String? forecastHour;
  final double? gercekFiyat;
  final double? tahminFiyat;
  final bool? pahaliMi;
  final bool? ucuzMu;

  const PriceForecast({
    this.id,
    this.timestamp,
    this.forecastHour,
    this.gercekFiyat,
    this.tahminFiyat,
    this.pahaliMi,
    this.ucuzMu,
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

  static bool? _bool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is num) return v != 0;
    return null;
  }

  factory PriceForecast.fromJson(Map<String, dynamic> json) {
    final fh = json['forecastHour'] ?? json['forecast_hour'];
    String? hourStr;
    if (fh != null) hourStr = fh.toString();

    return PriceForecast(
      id: _id(json['id']),
      timestamp: json['timestamp']?.toString(),
      forecastHour: hourStr,
      gercekFiyat: _dbl(json['gercekFiyat'] ?? json['gercek_fiyat']),
      tahminFiyat: _dbl(json['tahminFiyat'] ?? json['tahmin_fiyat']),
      pahaliMi: _bool(json['pahaliMi'] ?? json['pahali_mi']),
      ucuzMu: _bool(json['ucuzMu'] ?? json['ucuz_mu']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp,
      'forecastHour': forecastHour,
      'gercekFiyat': gercekFiyat,
      'tahminFiyat': tahminFiyat,
      'pahaliMi': pahaliMi,
      'ucuzMu': ucuzMu,
    };
  }

  PriceForecast copyWith({
    int? id,
    String? timestamp,
    String? forecastHour,
    double? gercekFiyat,
    double? tahminFiyat,
    bool? pahaliMi,
    bool? ucuzMu,
  }) {
    return PriceForecast(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      forecastHour: forecastHour ?? this.forecastHour,
      gercekFiyat: gercekFiyat ?? this.gercekFiyat,
      tahminFiyat: tahminFiyat ?? this.tahminFiyat,
      pahaliMi: pahaliMi ?? this.pahaliMi,
      ucuzMu: ucuzMu ?? this.ucuzMu,
    );
  }

  @override
  String toString() => 'PriceForecast(id: $id, forecastHour: $forecastHour, '
      'gercekFiyat: $gercekFiyat, tahminFiyat: $tahminFiyat)';
}

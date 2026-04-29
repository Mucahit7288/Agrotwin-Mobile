class EnergySchedule {
  final int? id;
  final String? olusturulma;
  final String? cihaz;
  final String? planlananSaat;
  final double? beklenenFiyat;
  final bool? aktifMi;

  const EnergySchedule({
    this.id,
    this.olusturulma,
    this.cihaz,
    this.planlananSaat,
    this.beklenenFiyat,
    this.aktifMi,
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

  factory EnergySchedule.fromJson(Map<String, dynamic> json) {
    return EnergySchedule(
      id: _id(json['id']),
      olusturulma: json['olusturulma']?.toString(),
      cihaz: json['cihaz']?.toString(),
      planlananSaat:
          (json['planlananSaat'] ?? json['planlanan_saat'])?.toString(),
      beklenenFiyat: _dbl(json['beklenenFiyat'] ?? json['beklenen_fiyat']),
      aktifMi: _bool(json['aktifMi'] ?? json['aktif_mi']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'olusturulma': olusturulma,
      'cihaz': cihaz,
      'planlananSaat': planlananSaat,
      'beklenenFiyat': beklenenFiyat,
      'aktifMi': aktifMi,
    };
  }

  EnergySchedule copyWith({
    int? id,
    String? olusturulma,
    String? cihaz,
    String? planlananSaat,
    double? beklenenFiyat,
    bool? aktifMi,
  }) {
    return EnergySchedule(
      id: id ?? this.id,
      olusturulma: olusturulma ?? this.olusturulma,
      cihaz: cihaz ?? this.cihaz,
      planlananSaat: planlananSaat ?? this.planlananSaat,
      beklenenFiyat: beklenenFiyat ?? this.beklenenFiyat,
      aktifMi: aktifMi ?? this.aktifMi,
    );
  }

  @override
  String toString() => 'EnergySchedule(id: $id, cihaz: $cihaz, '
      'planlananSaat: $planlananSaat, aktifMi: $aktifMi)';
}

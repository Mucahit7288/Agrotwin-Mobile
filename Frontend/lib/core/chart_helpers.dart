import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'app_state.dart';

/// Seçilen metrik için anlık değer (pH donanımda yoksa null).
double? metricValue(SensorAnalyticsKind k, SensorData s) {
  switch (k) {
    case SensorAnalyticsKind.ph:
      return null;
    case SensorAnalyticsKind.ortamSicaklik:
      return s.tOrtam;
    case SensorAnalyticsKind.ortamNem:
      return s.hOrtam;
    case SensorAnalyticsKind.suSicaklik:
      return s.tSu;
    case SensorAnalyticsKind.suSeviye:
      final p = s.suSeviyePct;
      return p == null ? null : p * 100.0;
    case SensorAnalyticsKind.isik:
      return s.isikAnalog?.toDouble();
    case SensorAnalyticsKind.elektrikFiyati:
      return s.elektrikFiyati;
  }
}

/// Geçmiş seri yok; tek canlı ölçümü 24 noktada düz çizgi olarak gösterir (mock gürültü yok).
List<FlSpot> spotsForMetric(SensorAnalyticsKind k, SensorData s) {
  if (k == SensorAnalyticsKind.isik) {
    return s.isikAnalog != null ? [FlSpot(0, s.isikAnalog!.toDouble())] : [];
  }

  if (k == SensorAnalyticsKind.elektrikFiyati) {
    return s.elektrikFiyati != null ? [FlSpot(0, s.elektrikFiyati!)] : [];
  }
  final v = metricValue(k, s);
  if (v == null) return [];
  return List.generate(24, (i) => FlSpot(i.toDouble(), v));
}

/// Sensör metriği için durum açıklaması.
String sensorDurumMetni(SensorAnalyticsKind k, SensorData s) {
  if (metricValue(k, s) == null) {
    if (k == SensorAnalyticsKind.ph) {
      return 'pH için canlı veri akışı yok. Sensör bağlı değil veya MQTT yükünde pH alanı bulunmuyor.';
    }
    return 'Bu metrik için henüz veri yok. MQTT bağlantısını ve sensör yayınını kontrol edin.';
  }
  switch (k) {
    case SensorAnalyticsKind.isik:
      return s.isikAnalog != null
          ? 'Anlık analog değer: ${s.isikAnalog}. Hedef 500–3500 aralığında olmalı.'
          : 'Işık sensöründen henüz veri gelmiyor.';

    case SensorAnalyticsKind.elektrikFiyati:
      return s.elektrikFiyati != null
          ? 'Anlık fiyat: ${s.elektrikFiyati!.toStringAsFixed(2)} ₺. 6.5 ₺ üzeri pik saat.'
          : 'Elektrik fiyatı verisi henüz alınamadı.';
    case SensorAnalyticsKind.ph:
      return 'pH hedef bantta tutulduğunda kök emilimi ve besin dengesi ideal olur.';
    case SensorAnalyticsKind.ortamSicaklik:
      final t = s.tOrtam!;
      if (t < 22) {
        return 'Ortam sıcaklığı hedefin altında; fotosentez yavaşlayabilir.';
      }
      if (t > 26) {
        return 'Ortam sıcaklığı hedefin üstünde; havalandırmayı gözden geçirin.';
      }
      return 'Ortam sıcaklığı hedef aralıkta; bitki metabolizması için uygun.';
    case SensorAnalyticsKind.ortamNem:
      final h = s.hOrtam!;
      if (h < 55) return 'Ortam nemi düşük; yaprak uçları kuruyabilir.';
      if (h > 75) {
        return 'Ortam nemi yüksek; küf riskine karşı hava akışını artırın.';
      }
      return 'Ortam nemi hedef aralıkta.';
    case SensorAnalyticsKind.suSicaklik:
      final ts = s.tSu!;
      if (ts < 18) {
        return 'Su sıcaklığı düşük; kök bölgesi için ısıtma düşünülebilir.';
      }
      if (ts > 24) {
        return 'Su sıcaklığı yüksek; çözünmüş oksijen azalabilir.';
      }
      return 'Su sıcaklığı hedef aralıkta.';
    case SensorAnalyticsKind.suSeviye:
      final p = s.suSeviyePct!;
      if (p < 0.3) {
        return 'Su seviyesi kritik; rezervuarı zamanında doldurun.';
      }
      return 'Su seviyesi izlenebilir; pompa döngüleri için yeterli hacim var.';
  }
}

/// Özet istatistik (tek değerden min=max=ort).
(double min, double max, double avg) minMaxAvgFromSpots(List<FlSpot> spots) {
  if (spots.isEmpty) return (0, 0, 0);
  final ys = spots.map((e) => e.y).toList();
  final mn = ys.reduce(math.min);
  final mx = ys.reduce(math.max);
  final avg = ys.reduce((a, b) => a + b) / ys.length;
  return (mn, mx, avg);
}

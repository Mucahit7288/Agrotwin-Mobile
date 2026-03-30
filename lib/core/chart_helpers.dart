import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'app_state.dart';

/// Her metrik için 24 saatlik mock FlSpot listesi üretir.
List<FlSpot> mockSpotsForMetric(SensorAnalyticsKind k, SensorData s) {
  final rng = math.Random(k.index * 31 + 42);
  final base = switch (k) {
    SensorAnalyticsKind.ph            => 6.2,
    SensorAnalyticsKind.ortamSicaklik => s.tOrtam,
    SensorAnalyticsKind.ortamNem      => s.hOrtam,
    SensorAnalyticsKind.suSicaklik    => s.tSu,
    SensorAnalyticsKind.suSeviye      => s.suSeviyePct * 100,
  };
  final amp = switch (k) {
    SensorAnalyticsKind.ph            => 0.35,
    SensorAnalyticsKind.ortamSicaklik => 1.2,
    SensorAnalyticsKind.ortamNem      => 3.0,
    SensorAnalyticsKind.suSicaklik    => 1.0,
    SensorAnalyticsKind.suSeviye      => 5.0,
  };
  final lo = switch (k) {
    SensorAnalyticsKind.ph            => 5.0,
    SensorAnalyticsKind.ortamSicaklik => 15.0,
    SensorAnalyticsKind.ortamNem      => 40.0,
    SensorAnalyticsKind.suSicaklik    => 15.0,
    SensorAnalyticsKind.suSeviye      => 0.0,
  };
  final hi = switch (k) {
    SensorAnalyticsKind.ph            => 7.5,
    SensorAnalyticsKind.ortamSicaklik => 32.0,
    SensorAnalyticsKind.ortamNem      => 100.0,
    SensorAnalyticsKind.suSicaklik    => 30.0,
    SensorAnalyticsKind.suSeviye      => 100.0,
  };
  return List.generate(24, (i) {
    final y = base + (rng.nextDouble() - 0.5) * amp * 2;
    return FlSpot(i.toDouble(), y.clamp(lo, hi));
  });
}

/// Sensör metriği için durum açıklama metni döner.
String sensorDurumMetni(SensorAnalyticsKind k, SensorData s) {
  switch (k) {
    case SensorAnalyticsKind.ph:
      return 'pH hedef bantta tutulduğunda kök emilimi ve besin dengesi ideal olur.';
    case SensorAnalyticsKind.ortamSicaklik:
      if (s.tOrtam < 22) return 'Ortam sıcaklığı hedefin altında; fotosentez yavaşlayabilir.';
      if (s.tOrtam > 26) return 'Ortam sıcaklığı hedefin üstünde; havalandırmayı gözden geçirin.';
      return 'Ortam sıcaklığı hedef aralıkta; bitki metabolizması için uygun.';
    case SensorAnalyticsKind.ortamNem:
      if (s.hOrtam < 55) return 'Ortam nemi düşük; yaprak uçları kuruyabilir.';
      if (s.hOrtam > 75) return 'Ortam nemi yüksek; küf riskine karşı hava akışını artırın.';
      return 'Ortam nemi hedef aralıkta.';
    case SensorAnalyticsKind.suSicaklik:
      if (s.tSu < 18) return 'Su sıcaklığı düşük; kök bölgesi için ısıtma düşünülebilir.';
      if (s.tSu > 24) return 'Su sıcaklığı yüksek; çözünmüş oksijen azalabilir.';
      return 'Su sıcaklığı hedef aralıkta.';
    case SensorAnalyticsKind.suSeviye:
      if (s.suSeviyePct < 0.3) return 'Su seviyesi kritik; rezervuarı zamanında doldurun.';
      return 'Su seviyesi izlenebilir; pompa döngüleri için yeterli hacim var.';
  }
}

import 'app_state.dart';

String fmtTempC(double? v) =>
    v == null ? '—' : '${v.toStringAsFixed(1)}°C';

String fmtPct0(double? v) =>
    v == null ? '—' : '%${v.toStringAsFixed(0)}';

String fmtSuSeviyePct(SensorData s) {
  final p = s.suSeviyePct;
  if (p == null) return '—';
  return '%${(p * 100).toStringAsFixed(0)}';
}

String fmtSuMesafe(SensorData s) {
  if (s.suMesafe == null) return 'Mesafe bilinmiyor';
  return '${s.suMesafe!.toStringAsFixed(1)} cm mesafe';
}

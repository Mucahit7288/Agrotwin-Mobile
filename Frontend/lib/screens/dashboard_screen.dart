// ignore_for_file: duplicate_ignore, curly_braces_in_flow_control_structures, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../core/constants.dart';
import '../core/app_state.dart';
import '../core/chart_helpers.dart';
import '../core/sensor_ui.dart';
import 'user_settings_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  DASHBOARD PAGE
// ═════════════════════════════════════════════════════════════════════════════
class DashboardPage extends StatelessWidget {
  final AppState state;
  final void Function(SensorAnalyticsKind kind, {bool scrollToChart})
  onOpenAnalytics;

  const DashboardPage({
    super.key,
    required this.state,
    required this.onOpenAnalytics,
  });

  void _openSensorSheet(
    BuildContext context,
    SensorAnalyticsKind kind,
    SensorData s,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SensorDetailSheet(
        kind: kind,
        sensor: s,
        onMoreDetail: () {
          Navigator.pop(ctx);
          onOpenAnalytics(kind, scrollToChart: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = state.sensorData;
    final initials = state.userName.isNotEmpty
        ? state.userName
              .trim()
              .split(RegExp(r'\s+'))
              .map((e) => e.isNotEmpty ? e[0] : '')
              .take(2)
              .join()
              .toUpperCase()
        : 'AT';

    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          // AppBar
          SliverAppBar(
            expandedHeight: 0,
            pinned: true,
            backgroundColor: kBg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Row(
              children: [
                // Sembol logosu — şeffaf arka plan, büyütülmüş
                Image.asset(
                  kAssetLogoSymbol,
                  height: kLogoSymbolAppBar, // 56px (eski 42px)
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) =>
                      Icon(Icons.eco_rounded, color: kGreen, size: 44),
                ),
                const SizedBox(width: 10),
                // Yazı logosu — şeffaf arka plan, büyütülmüş
                Image.asset(
                  kAssetLogoWord,
                  height: kLogoWordAppBar, // 40px (eski 30px)
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) => const Text(
                    'AgroTwin',
                    style: TextStyle(
                      color: kTextPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 30, // büyütüldü
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const Spacer(),
                _MqttStatusChip(connected: state.mqttConnected),
                const SizedBox(width: 8),
                Material(
                  color: kGreen,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => UserSettingsPage(state: state),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(22),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.transparent,
                      child: Text(
                        initials.isEmpty ? 'AT' : initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // İçerik
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _HealthGauge(state: state),
                const SizedBox(height: 20),
                const Text(
                  'Sensör Verileri',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    _SensorCard(
                      icon: Icons.thermostat_rounded,
                      iconColor: kOrange,
                      label: 'Ortam Sıcaklığı',
                      value: fmtTempC(s.tOrtam),
                      sub: s.tOrtam == null
                          ? (state.mqttConnected
                                ? 'Sensör verisi yok'
                                : 'MQTT bağlı değil')
                          : 'Hedef: 22–26°C',
                      hasData: s.tOrtam != null,
                      ok: s.tOrtam != null &&
                          s.tOrtam! >= 22 &&
                          s.tOrtam! <= 26,
                      onTap: () => _openSensorSheet(
                        context,
                        SensorAnalyticsKind.ortamSicaklik,
                        s,
                      ),
                    ),
                    _SensorCard(
                      icon: Icons.water_drop_rounded,
                      iconColor: kBlue,
                      label: 'Ortam Nemi',
                      value: fmtPct0(s.hOrtam),
                      sub: s.hOrtam == null
                          ? (state.mqttConnected
                                ? 'Sensör verisi yok'
                                : 'MQTT bağlı değil')
                          : 'Hedef: 55–75%',
                      hasData: s.hOrtam != null,
                      ok: s.hOrtam != null &&
                          s.hOrtam! >= 55 &&
                          s.hOrtam! <= 75,
                      onTap: () => _openSensorSheet(
                        context,
                        SensorAnalyticsKind.ortamNem,
                        s,
                      ),
                    ),
                    _SensorCard(
                      icon: Icons.waves_rounded,
                      iconColor: kCyan,
                      label: 'Su Sıcaklığı',
                      value: fmtTempC(s.tSu),
                      sub: s.tSu == null
                          ? (state.mqttConnected
                                ? 'Sensör verisi yok'
                                : 'MQTT bağlı değil')
                          : 'Hedef: 18–24°C',
                      hasData: s.tSu != null,
                      ok: s.tSu != null && s.tSu! >= 18 && s.tSu! <= 24,
                      onTap: () => _openSensorSheet(
                        context,
                        SensorAnalyticsKind.suSicaklik,
                        s,
                      ),
                    ),
                    _SensorCard(
                      icon: Icons.opacity_rounded,
                      iconColor: kGreen,
                      label: 'Su Seviyesi',
                      value: fmtSuSeviyePct(s),
                      sub: fmtSuMesafe(s),
                      hasData: s.suMesafe != null && s.suSeviyePct != null,
                      ok: s.suSeviyePct != null && s.suSeviyePct! > 0.3,
                      onTap: () => _openSensorSheet(
                        context,
                        SensorAnalyticsKind.suSeviye,
                        s,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _AiDecisionCard(state: state),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MqttStatusChip extends StatelessWidget {
  final bool connected;
  const _MqttStatusChip({required this.connected});

  @override
  Widget build(BuildContext context) {
    final c = connected ? kGreen : kRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c),
          ),
          const SizedBox(width: 5),
          Text(
            connected ? 'MQTT Bağlı' : 'MQTT Yok',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthGauge extends StatelessWidget {
  final AppState state;
  const _HealthGauge({required this.state});

  static double _healthFraction(SensorData s) {
    var ok = 0;
    var n = 0;
    void c(double? v, bool Function(double) good) {
      if (v == null) return;
      n++;
      if (good(v)) ok++;
    }

    c(s.tOrtam, (v) => v >= 22 && v <= 26);
    c(s.hOrtam, (v) => v >= 55 && v <= 75);
    c(s.tSu, (v) => v >= 18 && v <= 24);
    final p = s.suSeviyePct;
    if (p != null) {
      n++;
      if (p > 0.3) ok++;
    }
    if (n == 0) return 0;
    return ok / n;
  }

  static String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final s = state.sensorData;
    final mqtt = state.mqttConnected;
    final has = s.hasAnyReading;
    final frac = has ? _healthFraction(s).clamp(0.0, 1.0) : 0.0;
    final ring = !mqtt
        ? kRed
        : (!has ? kOrange : kGreen);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: kCardDecoration,
      child: Row(
        children: [
          CircularPercentIndicator(
            radius: 70,
            lineWidth: 12,
            percent: frac,
            animation: true,
            animationDuration: 800,
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  !mqtt
                      ? '—'
                      : (!has ? '…' : '${(frac * 100).round()}%'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: ring,
                  ),
                ),
                Text(
                  !mqtt
                      ? 'BAĞLANTI YOK'
                      : (!has ? 'VERİ YOK' : 'ÖZET'),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: ring,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            progressColor: ring,
            backgroundColor: ring.withOpacity(0.12),
            circularStrokeCap: CircularStrokeCap.round,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sistem Sağlığı',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  !mqtt
                      ? 'MQTT bağlı değil — canlı sensör verisi alınamıyor.'
                      : (!has
                            ? 'MQTT bağlı; sensörden henüz ölçüm gelmedi.'
                            : 'Son ölçümlere göre hedef aralıkların özeti.'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: kTextSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.eco_rounded,
                  text: state.seciliRecete,
                ),
                const SizedBox(height: 4),
                _InfoRow(
                  icon: Icons.schedule_rounded,
                  text: state.lastSensorUpdateAt != null
                      ? 'Son güncelleme: ${_hm(state.lastSensorUpdateAt!)}'
                      : (mqtt
                            ? 'Canlı ölçüm zamanı henüz yok'
                            : 'MQTT bağlantısı gerekli'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 14, color: kGreen),
      const SizedBox(width: 5),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, color: kTextSecondary),
        ),
      ),
    ],
  );
}

class _SensorCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value, sub;
  final bool hasData;
  final bool ok;
  final VoidCallback? onTap;

  const _SensorCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.sub,
    required this.hasData,
    required this.ok,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      padding: const EdgeInsets.all(14),
      decoration: kCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const Spacer(),
              if (!hasData)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: kTextSecondary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.sensors_off_rounded,
                        size: 10,
                        color: kTextSecondary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Veri yok',
                        style: TextStyle(
                          fontSize: 9,
                          color: kTextSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: ok ? kGreen.withOpacity(0.1) : kRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        ok ? Icons.check_circle_rounded : Icons.warning_rounded,
                        size: 10,
                        color: ok ? kGreen : kRed,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        ok ? 'Normal' : 'Uyarı',
                        style: TextStyle(
                          fontSize: 9,
                          color: ok ? kGreen : kRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: kTextPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: kTextSecondary,
            ),
          ),
          Text(
            sub,
            style: const TextStyle(fontSize: 10, color: kTextSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    if (onTap == null) return inner;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(kRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadius),
        child: inner,
      ),
    );
  }
}

class _SensorDetailSheet extends StatelessWidget {
  final SensorAnalyticsKind kind;
  final SensorData sensor;
  final VoidCallback onMoreDetail;

  const _SensorDetailSheet({
    required this.kind,
    required this.sensor,
    required this.onMoreDetail,
  });

  @override
  Widget build(BuildContext context) {
    final spots = spotsForMetric(kind, sensor);
    final hasChart = spots.isNotEmpty;
    late final double mn, mx, avg;
    if (hasChart) {
      final t = minMaxAvgFromSpots(spots);
      mn = t.$1;
      mx = t.$2;
      avg = t.$3;
    } else {
      mn = 0;
      mx = 0;
      avg = 0;
    }
    final title = switch (kind) {
      SensorAnalyticsKind.ph => 'pH',
      SensorAnalyticsKind.ortamSicaklik => 'Ortam Sıcaklığı',
      SensorAnalyticsKind.ortamNem => 'Ortam Nemi',
      SensorAnalyticsKind.suSicaklik => 'Su Sıcaklığı',
      SensorAnalyticsKind.suSeviye => 'Su Seviyesi',
    };
    final unit = switch (kind) {
      SensorAnalyticsKind.ph => '',
      SensorAnalyticsKind.ortamSicaklik => '°C',
      SensorAnalyticsKind.ortamNem => '%',
      SensorAnalyticsKind.suSicaklik => '°C',
      SensorAnalyticsKind.suSeviye => '%',
    };
    final color = switch (kind) {
      SensorAnalyticsKind.ph => kGreen,
      SensorAnalyticsKind.ortamSicaklik => kOrange,
      SensorAnalyticsKind.ortamNem => kBlue,
      SensorAnalyticsKind.suSicaklik => kCyan,
      SensorAnalyticsKind.suSeviye => kGreenDark,
    };
    final (minY, maxY) = switch (kind) {
      SensorAnalyticsKind.ph => (5.0, 7.5),
      SensorAnalyticsKind.ortamSicaklik => (15.0, 32.0),
      SensorAnalyticsKind.ortamNem => (35.0, 95.0),
      SensorAnalyticsKind.suSicaklik => (15.0, 30.0),
      SensorAnalyticsKind.suSeviye => (0.0, 100.0),
    };
    return DraggableScrollableSheet(
      initialChildSize: 0.58,
      minChildSize: 0.42,
      maxChildSize: 0.92,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              sensorDurumMetni(kind, sensor),
              style: const TextStyle(
                fontSize: 13,
                color: kTextSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: hasChart
                  ? LineChart(
                      LineChartData(
                        minY: minY,
                        maxY: maxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (v) => FlLine(
                            color: Colors.grey.withOpacity(0.15),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              getTitlesWidget: (v, _) => Text(
                                v.toStringAsFixed(
                                  kind == SensorAnalyticsKind.ph ? 1 : 0,
                                ),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: kTextSecondary,
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 4,
                              getTitlesWidget: (v, _) => Text(
                                '${v.toInt()}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: kTextSecondary,
                                ),
                              ),
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: false,
                            color: color,
                            barWidth: 2.5,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: color.withOpacity(0.08),
                            ),
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (ts) => ts
                                .map(
                                  (e) => LineTooltipItem(
                                    kind == SensorAnalyticsKind.ph
                                        ? 'pH ${e.y.toStringAsFixed(2)}'
                                        : '${e.y.toStringAsFixed(1)}$unit',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.show_chart_rounded,
                            size: 40,
                            color: kTextSecondary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bu metrik için grafik çizilecek ölçüm yok',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: kTextSecondary.withOpacity(0.9),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            if (hasChart)
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'Min',
                      value: mn,
                      unit: unit,
                      kind: kind,
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      label: 'Ort.',
                      value: avg,
                      unit: unit,
                      kind: kind,
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      label: 'Maks',
                      value: mx,
                      unit: unit,
                      kind: kind,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onMoreDetail,
                icon: const Icon(Icons.analytics_rounded, color: kGreen),
                label: const Text(
                  'Daha detaylı bilgi (Analitik)',
                  style: TextStyle(color: kGreen, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: kGreen),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, unit;
  final double value;
  final SensorAnalyticsKind kind;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.kind,
  });

  @override
  Widget build(BuildContext context) {
    final s = kind == SensorAnalyticsKind.ph
        ? value.toStringAsFixed(2)
        : value.toStringAsFixed(1);
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: kTextSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          '$s$unit',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: kTextPrimary,
          ),
        ),
      ],
    );
  }
}

class _AiDecisionCard extends StatelessWidget {
  final AppState state;
  const _AiDecisionCard({required this.state});

  String _aiText(SensorData s) {
    if (!state.mqttConnected) {
      return 'MQTT bağlı değil; canlı sensör verisi alınamıyor. Broker ve ağ ayarlarını kontrol edin.';
    }
    if (!s.hasAnyReading) {
      return 'MQTT bağlı ancak henüz ölçüm alınmadı. Sensörün `agrotwin/sensorler` konusuna veri gönderdiğinden emin olun.';
    }
    if (s.tOrtam != null && s.tOrtam! < 20) {
      return 'Ortam sıcaklığı düşük (${s.tOrtam!.toStringAsFixed(1)}°C). Isıtıcıyı değerlendirin.';
    }
    if (s.suSeviyePct != null && s.suSeviyePct! < 0.3) {
      return 'Su seviyesi kritik (%${(s.suSeviyePct! * 100).toStringAsFixed(0)}). Rezervuarı doldurun.';
    }
    if (s.hOrtam != null && s.hOrtam! > 80) {
      return 'Ortam nemi yüksek (%${s.hOrtam!.toStringAsFixed(0)}). Havalandırmayı artırın.';
    }
    return 'Son ölçümlere göre acil uyarı yok; hedef aralıkları izlemeye devam edin.';
  }

  @override
  Widget build(BuildContext context) {
    final s = state.sensorData;
    final live = state.mqttConnected && s.hasAnyReading;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kGreenDark, kGreen, kGreenLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: [
          BoxShadow(
            color: kGreen.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'AI Kararı & Tavsiyesi',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  live ? 'CANLI' : 'BEKLEMEDE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _aiText(s),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            live
                ? 'İleri düzey AI skorları (büyüme, enerji, risk) backend tanımlandığında burada gösterilecek.'
                : 'Canlı sensör verisi olmadan sayısal özet üretilemez.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

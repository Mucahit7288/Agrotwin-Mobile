// ignore_for_file: curly_braces_in_flow_control_structures, unnecessary_cast, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/constants.dart';
import '../core/app_state.dart';
import '../core/chart_helpers.dart';

class AnalitikPage extends StatefulWidget {
  final AppState state;
  const AnalitikPage({super.key, required this.state});
  @override State<AnalitikPage> createState() => _AnalitikPageState();
}

class _AnalitikPageState extends State<AnalitikPage> {
  int _selectedRange  = 1;
  int _metricIndex    = 0;
  int _handledJumpGen = 0;
  final List<String> _ranges    = ['1S', '1G', '1H', '1A'];
  final GlobalKey _chartKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onJump);
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryHandleJump());
  }

  @override
  void dispose() { widget.state.removeListener(_onJump); super.dispose(); }

  void _onJump() => _tryHandleJump();

  void _tryHandleJump() {
    if (!mounted) return;
    final gen = widget.state.analyticJumpGeneration;
    final t   = widget.state.analyticJumpTarget;
    if (t == null || gen <= _handledJumpGen) return;
    _handledJumpGen = gen;
    final needScroll = widget.state.analyticScrollToChart;
    setState(() => _metricIndex = t.index);
    widget.state.clearAnalyticJump();
    if (!needScroll) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _chartKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic, alignment: 0.1);
    });
  }

  SensorAnalyticsKind get _metric => SensorAnalyticsKind.values[_metricIndex];

  String _metricTitle(SensorAnalyticsKind k) => switch (k) {
    SensorAnalyticsKind.ph            => 'pH Analizi',
    SensorAnalyticsKind.ortamSicaklik => 'Ortam Sıcaklığı',
    SensorAnalyticsKind.ortamNem      => 'Ortam Nemi',
    SensorAnalyticsKind.suSicaklik    => 'Su Sıcaklığı',
    SensorAnalyticsKind.suSeviye      => 'Su Seviyesi',
  };

  String _metricBand(SensorAnalyticsKind k) => switch (k) {
    SensorAnalyticsKind.ph            => 'Hedef Bant: 5.8–6.8',
    SensorAnalyticsKind.ortamSicaklik => 'Hedef: 22–26°C',
    SensorAnalyticsKind.ortamNem      => 'Hedef: 55–75%',
    SensorAnalyticsKind.suSicaklik    => 'Hedef: 18–24°C',
    SensorAnalyticsKind.suSeviye      => 'Kritik alt: %30',
  };

  Color _metricColor(SensorAnalyticsKind k) => switch (k) {
    SensorAnalyticsKind.ph            => kGreen,
    SensorAnalyticsKind.ortamSicaklik => kOrange,
    SensorAnalyticsKind.ortamNem      => kBlue,
    SensorAnalyticsKind.suSicaklik    => kCyan,
    SensorAnalyticsKind.suSeviye      => kGreenDark,
  };

  (double, double) _yRange(SensorAnalyticsKind k) => switch (k) {
    SensorAnalyticsKind.ph            => (5.0,  7.5),
    SensorAnalyticsKind.ortamSicaklik => (15.0, 32.0),
    SensorAnalyticsKind.ortamNem      => (35.0, 95.0),
    SensorAnalyticsKind.suSicaklik    => (15.0, 30.0),
    SensorAnalyticsKind.suSeviye      => (0.0, 100.0),
  };

  String _fmt(SensorAnalyticsKind k, double v) =>
      k == SensorAnalyticsKind.ph ? v.toStringAsFixed(2) : v.toStringAsFixed(1);

  String _suffix(SensorAnalyticsKind k) => switch (k) {
    SensorAnalyticsKind.ph            => '',
    SensorAnalyticsKind.ortamSicaklik => '°C',
    SensorAnalyticsKind.ortamNem      => '%',
    SensorAnalyticsKind.suSicaklik    => '°C',
    SensorAnalyticsKind.suSeviye      => '%',
  };

  RangeAnnotations _rangeAnnotation(SensorAnalyticsKind k) {
    final bands = {
      SensorAnalyticsKind.ph:            (5.8,  6.8,  kGreen),
      SensorAnalyticsKind.ortamSicaklik: (22.0, 26.0, kOrange),
      SensorAnalyticsKind.ortamNem:      (55.0, 75.0, kBlue),
      SensorAnalyticsKind.suSicaklik:    (18.0, 24.0, kCyan),
      SensorAnalyticsKind.suSeviye:      (30.0, 100.0, kGreen),
    };
    final b = bands[k]!;
    return RangeAnnotations(horizontalRangeAnnotations: [
      HorizontalRangeAnnotation(y1: b.$1, y2: b.$2, color: (b.$3 as Color).withOpacity(0.1)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final s      = widget.state.sensorData;
    final metric = _metric;
    final spots  = spotsForMetric(metric, s);
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
    final color  = _metricColor(metric);
    final (minY, maxY) = _yRange(metric);
    const chipLabels = ['pH', 'Ortam °C', 'Nem %', 'Su °C', 'Su %'];

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: const Text('Sensör Analitiği'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          // Metrik seçici
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: List.generate(SensorAnalyticsKind.values.length, (i) {
              final sel = _metricIndex == i;
              return Padding(padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(chipLabels[i]),
                  selected: sel,
                  onSelected: (_) => setState(() => _metricIndex = i),
                  selectedColor: color.withOpacity(0.22),
                  checkmarkColor: color,
                  labelStyle: TextStyle(color: sel ? color : kTextSecondary, fontWeight: FontWeight.w700, fontSize: 12),
                ));
            })),
          ),
          const SizedBox(height: 12),
          // Zaman aralığı seçici
          Row(children: List.generate(_ranges.length, (i) {
            final sel = _selectedRange == i;
            return GestureDetector(
              onTap: () => setState(() => _selectedRange = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? kGreen : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: sel ? [BoxShadow(color: kGreen.withOpacity(0.35), blurRadius: 8)] : [],
                ),
                child: Text(_ranges[i], style: TextStyle(
                  color: sel ? Colors.white : kTextSecondary,
                  fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            );
          })),
          const SizedBox(height: 16),
          // Grafik kartı
          Container(
            key: _chartKey,
            padding: const EdgeInsets.all(16),
            decoration: kCardDecoration,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(_metricTitle(metric),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(_metricBand(metric),
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 8),
              Text(sensorDurumMetni(metric, s),
                style: const TextStyle(fontSize: 12, color: kTextSecondary, height: 1.35)),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: hasChart
                    ? LineChart(LineChartData(
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
                                metric == SensorAnalyticsKind.ph
                                    ? v.toStringAsFixed(1)
                                    : v.toStringAsFixed(0),
                                style: const TextStyle(
                                  fontSize: 10,
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
                                  fontSize: 10,
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
                        rangeAnnotations: _rangeAnnotation(metric),
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
                                    metric == SensorAnalyticsKind.ph
                                        ? 'pH ${e.y.toStringAsFixed(2)}'
                                        : '${_fmt(metric, e.y)}${_suffix(metric)}',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ))
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            sensorDurumMetni(metric, s),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: kTextSecondary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          // Özet istatistikler
          Container(
            padding: const EdgeInsets.all(16),
            decoration: kCardDecoration,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Özet İstatistikler',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary)),
              const SizedBox(height: 14),
              if (hasChart)
                Row(children: [
                  _StatItem(icon: Icons.arrow_downward_rounded, iconColor: kBlue,  label: 'Minimum', value: '${_fmt(metric, mn)}${_suffix(metric)}'),
                  _StatItem(icon: Icons.arrow_upward_rounded,   iconColor: kRed,   label: 'Maksimum', value: '${_fmt(metric, mx)}${_suffix(metric)}'),
                  _StatItem(icon: Icons.horizontal_rule_rounded, iconColor: kGreen, label: 'Ortalama', value: '${_fmt(metric, avg)}${_suffix(metric)}'),
                ])
              else
                const Text(
                  'Bu metrik için henüz canlı değer yok; özet üretilemez.',
                  style: TextStyle(fontSize: 13, color: kTextSecondary, height: 1.35),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          // Uyarılar (sahte kayıtlar kaldırıldı — backend uyarı API’si eklendiğinde doldurulur)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: kCardDecoration,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Uyarılar',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary)),
              const SizedBox(height: 12),
              Text(
                widget.state.mqttConnected
                    ? (s.hasAnyReading
                        ? 'Geçmiş uyarılar sunucu veya MQTT bildirimleriyle bağlandığında burada listelenecek.'
                        : 'Sensör verisi gelene kadar uyarı üretilemez.')
                    : 'MQTT bağlı değil; canlı uyarı akışı yok.',
                style: const TextStyle(fontSize: 13, color: kTextSecondary, height: 1.35),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value;
  const _StatItem({required this.icon, required this.iconColor, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Container(padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: iconColor, size: 18)),
    const SizedBox(height: 6),
    Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTextPrimary)),
    Text(label, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
  ]));
}

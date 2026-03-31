// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/constants.dart';
import '../core/app_state.dart';
import '../services/mqtt_service.dart';

class KontrolPage extends StatelessWidget {
  final AppState state;
  final MqttService mqtt;
  const KontrolPage({super.key, required this.state, required this.mqtt});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: const Text('Kontrol Paneli'), centerTitle: false),
      body: AnimatedBuilder(
        animation: state,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          children: [
            // Mod Seçici
            Container(
              padding: const EdgeInsets.all(16),
              decoration: kCardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kontrol Modu',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _ModeBtn(
                        index: 0,
                        selected: state.kontrolModu,
                        label: '🤖 Otonom AI',
                        color: kGreen,
                        onTap: () => state.setKontrolModu(0),
                      ),
                      const SizedBox(width: 8),
                      _ModeBtn(
                        index: 1,
                        selected: state.kontrolModu,
                        label: '🎮 Manuel',
                        color: kBlue,
                        onTap: () => state.setKontrolModu(1),
                      ),
                      const SizedBox(width: 8),
                      _ModeBtn(
                        index: 2,
                        selected: state.kontrolModu,
                        label: '💰 Ekonomik',
                        color: kOrange,
                        onTap: () => state.setKontrolModu(2),
                      ),
                    ],
                  ),
                  if (state.kontrolModu == 0)
                    _ModeHint(
                      color: kGreen,
                      text:
                          '🤖 Otonom AI: Sensör verilerine göre pompa, fan, ısıtıcı ve LED otomatik yönetilir.',
                    ),
                  if (state.kontrolModu == 1)
                    _ModeHint(
                      color: kBlue,
                      text:
                          '🎮 Manuel: Tüm eyleyicileri bu ekrandan siz açıp kapatırsınız; AI müdahale etmez.',
                    ),
                  if (state.kontrolModu == 2)
                    _ModeHint(
                      color: kOrange,
                      text:
                          '💰 Ekonomik: EPİAŞ ucuz saatlerinde pompa/LED kullanımı önceliklendirilir; maliyet düşük tutulur.',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // EPİAŞ Grafiği
            Container(
              padding: const EdgeInsets.all(16),
              decoration: kCardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'EPİAŞ Enerji Borsası',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: kGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Bugün',
                          style: TextStyle(
                            color: kGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Saatlik fiyat ve pik bilgisi',
                    style: TextStyle(fontSize: 11, color: kTextSecondary),
                  ),
                  const SizedBox(height: 14),
                  const _EpiasChart(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _EpiasLegend(color: kRed, label: 'Pik Saatler'),
                      const SizedBox(width: 14),
                      _EpiasLegend(color: kGreen, label: 'Ucuz Saatler'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Eyleyici Kontrolü
            Container(
              padding: const EdgeInsets.all(16),
              decoration: kCardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Eyleyici Kontrolü',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // LED
                  _ActuatorTile(
                    icon: Icons.light_rounded,
                    iconColor: kAmber,
                    label: 'LED Işıklar',
                    sub: 'PWM: %${(state.ledPwm * 100).toStringAsFixed(0)}',
                    value: state.ledOn,
                    onChanged: (_) => state.toggleLed(),
                  ),
                  if (state.ledOn)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(48, 0, 0, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Parlaklık: %${(state.ledPwm * 100).toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: kTextSecondary,
                            ),
                          ),
                          SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: kAmber,
                              inactiveTrackColor: kAmber.withOpacity(0.2),
                              thumbColor: kAmber,
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: state.ledPwm,
                              min: 0,
                              max: 1,
                              onChanged: state.setLedPwm,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 1),
                  // Su Pompası — MQTT'ye komut gönderir
                  _ActuatorTile(
                    icon: Icons.water_rounded,
                    iconColor: kBlue,
                    label: 'Su Pompası',
                    sub: state.pompaOn ? 'Çalışıyor' : 'Durdu',
                    value: state.pompaOn,
                    onChanged: (_) {
                      state.togglePompa();
                      mqtt.publish('pompa', state.pompaOn ? 'ON' : 'OFF');
                    },
                  ),
                  const Divider(height: 1),
                  // Fan — MQTT'ye komut gönderir
                  _ActuatorTile(
                    icon: Icons.air_rounded,
                    iconColor: kCyan,
                    label: 'Fan / Hava Motoru',
                    sub: state.fanOn ? 'Çalışıyor' : 'Durdu',
                    value: state.fanOn,
                    onChanged: (_) {
                      state.toggleFan();
                      mqtt.publish('fan', state.fanOn ? 'ON' : 'OFF');
                    },
                  ),
                  const Divider(height: 1),
                  // Isıtıcı — MQTT'ye komut gönderir
                  _ActuatorTile(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: kRed,
                    label: 'Isıtıcı',
                    sub: state.isiticiOn ? 'Aktif' : 'Pasif',
                    value: state.isiticiOn,
                    onChanged: (_) {
                      state.toggleIsitici();
                      mqtt.publish('isitici', state.isiticiOn ? 'ON' : 'OFF');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Bitki Reçetesi Seçimi
            Container(
              padding: const EdgeInsets.all(16),
              decoration: kCardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bitki Reçetesi Seçimi',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Seçime göre AI hedef parametreleri otomatik güncellenir.',
                    style: TextStyle(fontSize: 11, color: kTextSecondary),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: state.seciliRecete,
                      isExpanded: true,
                      underline: const SizedBox(),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: kTextSecondary,
                      ),
                      style: const TextStyle(color: kTextPrimary, fontSize: 13),
                      items: const [
                        DropdownMenuItem(
                          value: 'Kıvırcık Marul - Büyüme Fazı',
                          child: Text('🥬 Kıvırcık Marul - Büyüme Fazı'),
                        ),
                        DropdownMenuItem(
                          value: 'Kıvırcık Marul - Hasat Fazı',
                          child: Text('🌿 Kıvırcık Marul - Hasat Fazı'),
                        ),
                        DropdownMenuItem(
                          value: 'Fesleğen - Fidan Fazı',
                          child: Text('🌱 Fesleğen - Fidan Fazı'),
                        ),
                        DropdownMenuItem(
                          value: 'Roka - Yoğun Büyüme Fazı',
                          child: Text('🥗 Roka - Yoğun Büyüme'),
                        ),
                        DropdownMenuItem(
                          value: 'Ispanak - Standart Protokol',
                          child: Text('🍃 Ispanak - Standart'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) state.setRecete(v);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kGreen.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: kGreen,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Seçili: ${state.seciliRecete}\nHedef pH 6.0–6.5 · EC 1.6–2.0 · Işık 16 Sa',
                            style: const TextStyle(fontSize: 11, color: kGreen),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeHint extends StatelessWidget {
  final Color color;
  final String text;
  const _ModeHint({required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, height: 1.35),
      ),
    ),
  );
}

class _ModeBtn extends StatelessWidget {
  final int index, selected;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ModeBtn({
    required this.index,
    required this.selected,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sel = selected == index;
    return Expanded(
      child: Material(
        color: sel ? color : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        elevation: sel ? 2 : 0,
        shadowColor: color.withOpacity(0.4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          splashColor: color.withOpacity(0.25),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: sel ? Colors.white : color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActuatorTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ActuatorTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sub,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 11,
                  color: value ? kGreen : kTextSecondary,
                  fontWeight: value ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        Transform.scale(
          scale: 0.85,
          child: Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: iconColor,
          ),
        ),
      ],
    ),
  );
}

class _EpiasChart extends StatelessWidget {
  const _EpiasChart();

  @override
  Widget build(BuildContext context) {
    final prices = [
      3.2,
      2.8,
      2.5,
      2.4,
      2.6,
      3.8,
      5.2,
      6.8,
      7.1,
      6.5,
      5.9,
      5.2,
      4.8,
      4.5,
      4.9,
      5.8,
      7.2,
      8.1,
      7.8,
      7.1,
      5.9,
      4.8,
      3.9,
      3.2,
    ];
    return SizedBox(
      height: 90,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 9,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                '${rod.toY.toStringAsFixed(1)} ₺',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 6,
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()}:00',
                  style: const TextStyle(fontSize: 9, color: kTextSecondary),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: List.generate(prices.length, (i) {
            final isPeak = prices[i] > 6.0;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: prices[i],
                  color: isPeak
                      ? kRed.withOpacity(0.8)
                      : kGreen.withOpacity(0.7),
                  width: 8,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _EpiasLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _EpiasLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
    ],
  );
}

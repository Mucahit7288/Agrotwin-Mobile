// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/app_state.dart';

enum TrendDir { up, down, neutral }

class SimulatorPage extends StatelessWidget {
  final AppState state;
  const SimulatorPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Dijital İkiz Simülatör'),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: kBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.science_rounded, color: kBlue, size: 14),
                SizedBox(width: 4),
                Text(
                  'What-If Modu',
                  style: TextStyle(
                    color: kBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: state,
        builder: (context, _) => Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sol: Mevcut Durum
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _SimHeader(
                                  label: 'Mevcut Durum',
                                  icon: Icons.sensors_rounded,
                                  color: kGreen,
                                ),
                                const SizedBox(height: 8),
                                _SimStatusCard(
                                  label: 'Sistem Sağlığı',
                                  value: '%96',
                                  icon: Icons.favorite_rounded,
                                  color: kGreen,
                                ),
                                _SimStatusCard(
                                  label: 'pH',
                                  value: '6.2',
                                  icon: Icons.science_rounded,
                                  color: kBlue,
                                ),
                                _SimStatusCard(
                                  label: 'EC',
                                  value: '1.8 mS',
                                  icon: Icons.electric_bolt_rounded,
                                  color: kOrange,
                                ),
                                _SimStatusCard(
                                  label: 'Işık Saati',
                                  value: '16 Sa',
                                  icon: Icons.wb_sunny_rounded,
                                  color: kAmber,
                                ),
                                _SimStatusCard(
                                  label: 'Su Sıcaklığı',
                                  value:
                                      '${state.sensorData.tSu.toStringAsFixed(1)}°C',
                                  icon: Icons.waves_rounded,
                                  color: kCyan,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Sağ: Simülasyon Slider'ları
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _SimHeader(
                                  label: 'Simülasyon',
                                  icon: Icons.tune_rounded,
                                  color: kBlue,
                                ),
                                const SizedBox(height: 8),
                                _SimSlider(
                                  label: 'pH Hedefi',
                                  value: state.simPh,
                                  min: 5.0,
                                  max: 7.5,
                                  displaySuffix: '',
                                  color: kBlue,
                                  onChanged: state.setSimPh,
                                ),
                                _SimSlider(
                                  label: 'EC Hedefi',
                                  value: state.simEc,
                                  min: 0.5,
                                  max: 3.5,
                                  displaySuffix: ' mS',
                                  color: kOrange,
                                  onChanged: state.setSimEc,
                                ),
                                _SimSlider(
                                  label: 'Işık Saati',
                                  value: state.simIsikSaat,
                                  min: 8,
                                  max: 20,
                                  displaySuffix: 'h',
                                  color: kAmber,
                                  onChanged: state.setSimIsikSaat,
                                ),
                                _SimSlider(
                                  label: 'Hedef Sıcaklık',
                                  value: state.simSicaklik,
                                  min: 18,
                                  max: 30,
                                  displaySuffix: '°C',
                                  color: kGreen,
                                  onChanged: state.setSimSicaklik,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tahmini Sonuçlar',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ResultCard(
                            icon: Icons.local_florist_rounded,
                            iconBg: kGreen.withOpacity(0.12),
                            iconColor: kGreen,
                            title: 'Tahmini Hasat',
                            value: '${state.tahminiHasatGun} Gün Sonra',
                            trend: state.tahminiHasatGun < 5
                                ? TrendDir.up
                                : TrendDir.down,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ResultCard(
                            icon: Icons.bolt_rounded,
                            iconBg: kOrange.withOpacity(0.12),
                            iconColor: kOrange,
                            title: 'Enerji Maliyeti',
                            value:
                                '${state.tahminiMaliyet.toStringAsFixed(0)} TL/Ay',
                            trend: state.tahminiMaliyet < 120
                                ? TrendDir.up
                                : TrendDir.down,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ResultCard(
                            icon: Icons.water_drop_rounded,
                            iconBg: kBlue.withOpacity(0.12),
                            iconColor: kBlue,
                            title: 'Su Tüketimi',
                            value:
                                '${(state.simEc * 2.5).toStringAsFixed(1)} L/Gün',
                            trend: TrendDir.neutral,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ResultCard(
                            icon: Icons.scale_rounded,
                            iconBg: kGreen.withOpacity(0.12),
                            iconColor: kGreen,
                            title: 'Tahmini Verim',
                            value: '${state.simPh > 6 ? 320 : 260} g/bitki',
                            trend: state.simPh > 6.0
                                ? TrendDir.up
                                : TrendDir.down,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          '✅ Simülasyon parametreleri uygulandı!',
                        ),
                        backgroundColor: kGreen,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Simülasyonu Uygula',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    elevation: 4,
                    shadowColor: kGreen.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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

class _SimHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SimHeader({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class _SimStatusCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _SimStatusCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: kTextSecondary),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: kTextPrimary,
          ),
        ),
      ],
    ),
  );
}

class _SimSlider extends StatelessWidget {
  final String label, displaySuffix;
  final double value, min, max;
  final Color color;
  final ValueChanged<double> onChanged;

  const _SimSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displaySuffix,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: kTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${value.toStringAsFixed(1)}$displaySuffix',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.15),
            thumbColor: color,
            overlayColor: color.withOpacity(0.1),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    ),
  );
}

class _ResultCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String title, value;
  final TrendDir trend;

  const _ResultCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) => Container(
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
                color: iconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const Spacer(),
            if (trend != TrendDir.neutral)
              Icon(
                trend == TrendDir.up
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: trend == TrendDir.up ? kGreen : kRed,
                size: 16,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: kTextPrimary,
          ),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 10, color: kTextSecondary),
        ),
      ],
    ),
  );
}

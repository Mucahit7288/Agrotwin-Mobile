import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants.dart';
import 'core/app_state.dart';
import 'services/mqtt_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/analitik_screen.dart';
import 'screens/ai_assistant_screen.dart';
import 'screens/simulator_screen.dart';
import 'screens/control_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const AgroTwinBootstrap());
}

class AgroTwinBootstrap extends StatefulWidget {
  const AgroTwinBootstrap({super.key});
  @override
  State<AgroTwinBootstrap> createState() => _AgroTwinBootstrapState();
}

class _AgroTwinBootstrapState extends State<AgroTwinBootstrap> {
  SharedPreferences? _prefs;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw TimeoutException('SharedPreferences timeout'),
      );
      if (!mounted) return;
      setState(() {
        _prefs = p;
        _loadError = null;
      });
    } catch (e, st) {
      debugPrint('[Bootstrap] $e\n$st');
      if (!mounted) return;
      try {
        final p = await SharedPreferences.getInstance();
        if (!mounted) return;
        setState(() {
          _prefs = p;
          _loadError = null;
        });
      } catch (e2) {
        if (!mounted) return;
        setState(() => _loadError = e2.toString());
      }
    }
  }

  ThemeData get _minTheme => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: kGreen,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: kBg,
  );

  @override
  Widget build(BuildContext context) {
    if (_prefs != null) return AgroTwinApp(prefs: _prefs!);

    if (_loadError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _minTheme,
        home: Scaffold(
          backgroundColor: kBg,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.storage_rounded,
                    size: 48,
                    color: kTextSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ayarlar yüklenemedi.\nEmülatörde "Wipe Data" deneyin.\n\n$_loadError',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: kTextSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _loadError = null;
                        _prefs = null;
                      });
                      _loadPrefs();
                    },
                    style: FilledButton.styleFrom(backgroundColor: kGreen),
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _minTheme,
      home: const Scaffold(
        backgroundColor: kBg,
        body: Center(child: CircularProgressIndicator(color: kGreen)),
      ),
    );
  }
}

class AgroTwinApp extends StatefulWidget {
  final SharedPreferences prefs;
  const AgroTwinApp({super.key, required this.prefs});
  @override
  State<AgroTwinApp> createState() => _AgroTwinAppState();
}

class _AgroTwinAppState extends State<AgroTwinApp> {
  late final AppState _appState;
  late final MqttService _mqtt;

  @override
  void initState() {
    super.initState();
    _appState = AppState(widget.prefs);
    _mqtt = MqttService(_appState);
  }

  @override
  void dispose() {
    _mqtt.disconnect();
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgroTwin',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: buildAppTheme(),
      home: _AppRouter(appState: _appState, mqtt: _mqtt),
    );
  }
}

// GİRİŞ SAYFASI
class _AppRouter extends StatelessWidget {
  final AppState appState;
  final MqttService mqtt;
  const _AppRouter({required this.appState, required this.mqtt});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (ctx, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 550),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final slide =
              Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: appState.isLoggedIn
            ? HomeShell(
                key: const ValueKey('shell'),
                appState: appState,
                mqtt: mqtt,
              )
            : LoginPage(key: const ValueKey('login'), state: appState),
      ),
    );
  }
}

// GİRİŞ SAYFASI
class LoginPage extends StatefulWidget {
  final AppState state;
  const LoginPage({super.key, required this.state});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  String? _err;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    final e = await widget.state.login(_email.text, _pass.text);
    if (mounted) {
      setState(() {
        _loading = false;
        _err = e;
      });
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kBg, kBg.withOpacity(0.98)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            children: [
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: kGreen.withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Image.asset(
                      kAssetLogoSymbol,
                      height: kLogoSymbolLogin,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.eco_rounded,
                        color: Color(0xFF88C9B3),
                        size: 120,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Image.asset(
                      kAssetLogoWord,
                      height: kLogoWordLogin,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, _, _) => const Text(
                        'AGROTWIN',
                        style: TextStyle(
                          color: kTextPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 48,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Hesabınıza giriş yapın',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: _dec('E-posta'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _pass,
                obscureText: true,
                decoration: _dec('Şifre'),
              ),
              if (_err != null) ...[
                const SizedBox(height: 12),
                Text(_err!, style: const TextStyle(color: kRed, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: kGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Giriş Yap',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => widget.state.developerLogin(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kGreen,
                          side: const BorderSide(color: kGreen, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Geliştirici',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => RegisterPage(state: widget.state),
                        ),
                      ),
                child: const Text(
                  'Hesabınız yok mu? Kayıt olun',
                  style: TextStyle(color: kGreen, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// KAYIT SAYFASI
class RegisterPage extends StatefulWidget {
  final AppState state;
  const RegisterPage({super.key, required this.state});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  String? _err;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    final e = await widget.state.register(
      name: _name.text,
      email: _email.text,
      password: _pass.text,
      phone: _phone.text,
    );
    if (e != null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _err = e;
        });
      }
      return;
    }
    await widget.state.login(_email.text, _pass.text);
    if (mounted) setState(() => _loading = false);
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: const Text('Kayıt Ol')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(controller: _name, decoration: _dec('Ad Soyad')),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: _dec('E-posta'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: _dec('Telefon'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            obscureText: true,
            decoration: _dec('Şifre (en az 4 karakter)'),
          ),
          if (_err != null) ...[
            const SizedBox(height: 12),
            Text(_err!, style: const TextStyle(color: kRed, fontSize: 13)),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: kGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Kayıt Ol',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ANA SHELL — 5 sekmeli PageView navigasyonu
class HomeShell extends StatefulWidget {
  final AppState appState;
  final MqttService mqtt;
  const HomeShell({super.key, required this.appState, required this.mqtt});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  late final PageController _pageController;
  static const Duration _pageAnim = Duration(milliseconds: 380);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.mqtt.connect());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goAnalitik(SensorAnalyticsKind kind, {bool scrollToChart = false}) {
    widget.appState.setAnalyticJump(kind, scrollToChart: scrollToChart);
    _onNavTap(1);
  }

  void _onNavTap(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: _pageAnim,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: PageView.builder(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        itemCount: 5,
        onPageChanged: (i) => setState(() => _selectedIndex = i),
        itemBuilder: (context, index) => switch (index) {
          0 => DashboardPage(
            state: widget.appState,
            onOpenAnalytics: _goAnalitik,
          ),
          1 => AnalitikPage(state: widget.appState),
          2 => SimulatorPage(state: widget.appState),
          3 => KontrolPage(state: widget.appState, mqtt: widget.mqtt),
          4 => AiAssistantPage(state: widget.appState),
          _ => const SizedBox.shrink(),
        },
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.dashboard_rounded, 'Dashboard'),
              _navItem(1, Icons.analytics_rounded, 'Analitik'),
              _navItem(2, Icons.device_hub_rounded, 'Simülatör'),
              _navItem(3, Icons.tune_rounded, 'Kontrol'),
              _navItem(4, Icons.smart_toy_rounded, 'AI'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final sel = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onNavTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? kGreen.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: sel ? kGreen : kTextSecondary,
              size: sel ? 26 : 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: sel ? kGreen : kTextSecondary,
                fontSize: 10,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

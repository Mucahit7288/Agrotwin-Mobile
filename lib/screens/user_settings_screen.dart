// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/app_state.dart';

class UserSettingsPage extends StatefulWidget {
  final AppState state;
  const UserSettingsPage({super.key, required this.state});
  @override
  State<UserSettingsPage> createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.state.userName);
    _phone = TextEditingController(text: widget.state.userPhone);
    _email = TextEditingController(text: widget.state.userEmail);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.state.updateProfile(name: _name.text, phone: _phone.text);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bilgiler güncellendi'),
          backgroundColor: kGreen,
        ),
      );
    }
  }

  InputDecoration _dec(String label, {bool enabled = true}) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: enabled ? Colors.white : Colors.grey.shade100,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          title: const Text('Kullanıcı Ayarları'),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Kaydet',
                      style: TextStyle(
                        color: kGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Kullanıcı bilgileri',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ad ve telefon bilgilerinizi güncelleyebilirsiniz.',
              style: TextStyle(fontSize: 12, color: kTextSecondary),
            ),
            const SizedBox(height: 18),
            TextField(controller: _name, decoration: _dec('Ad Soyad')),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              enabled: false,
              decoration: _dec('E-posta (değiştirilemez)', enabled: false),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: _dec('Telefon'),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await widget.state.logout();
                  // AnimatedSwitcher otomatik olarak LoginPage'e döner
                },
                icon: const Icon(Icons.logout_rounded, color: kRed),
                label: const Text(
                  'Çıkış Yap',
                  style: TextStyle(color: kRed, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: kRed),
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

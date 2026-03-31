// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/app_state.dart';

class _ChatBubble {
  final bool fromUser;
  final String text;
  const _ChatBubble({required this.fromUser, required this.text});
}

class AiAssistantPage extends StatefulWidget {
  final AppState state;
  const AiAssistantPage({super.key, required this.state});
  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_ChatBubble> _messages = [];

  @override
  void initState() {
    super.initState();
    _messages.add(
      const _ChatBubble(
        fromUser: false,
        text:
            'Merhaba, ben AgroTwin asistanıyım. Reçete önerisi, sensör yorumu veya '
            'günlük özet için yazabilirsiniz. Şu an yerel yanıt modundayım; dış API '
            'bağlandığında yanıtlar burada güncellenecek.',
      ),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _messages.add(_ChatBubble(fromUser: true, text: t));
      _input.clear();
      _messages.add(
        _ChatBubble(
          fromUser: false,
          text:
              'Anladım: "$t". Ortam sıcaklığı şu an yaklaşık '
              '${widget.state.sensorData.tOrtam.toStringAsFixed(1)}°C. '
              'Bu yanıt yerel; API bağlanınca detaylı öneri verilecek.',
        ),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            // Yazı logosu — şeffaf zemin, 44px (eski 34px)
            Image.asset(
              kAssetLogoWord,
              height: kLogoWordAiBar, // 44px
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => const Text(
                'AGROTWIN',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 30, // büyütüldü
                  color: kTextPrimary,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Asistan',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 28, // büyütüldü (eski 20)
                color: kTextPrimary,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Mesaj listesi
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                final bg = m.fromUser ? kGreen : Colors.white;
                final fg = m.fromUser ? Colors.white : kTextPrimary;
                return Align(
                  alignment: m.fromUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(14),
                        topRight: const Radius.circular(14),
                        bottomLeft: Radius.circular(m.fromUser ? 14 : 4),
                        bottomRight: Radius.circular(m.fromUser ? 4 : 14),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      m.text,
                      style: TextStyle(color: fg, fontSize: 14, height: 1.4),
                    ),
                  ),
                );
              },
            ),
          ),
          // Giriş alanı
          Material(
            color: Colors.white,
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Mesajınızı yazın…',
                          filled: true,
                          fillColor: kBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _send,
                      style: FilledButton.styleFrom(
                        backgroundColor: kGreen,
                        padding: const EdgeInsets.all(14),
                        shape: const CircleBorder(),
                      ),
                      child: const Icon(Icons.send_rounded, size: 22),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

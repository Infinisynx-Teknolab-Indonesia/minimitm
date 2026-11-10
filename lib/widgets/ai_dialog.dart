import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/i18n.dart';
import '../services/nav.dart';

/// Buka dialog "Tanya AI" dengan sebuah lampiran konteks (request/response/temuan).
Future<void> showAiDialog(BuildContext context, {required String title, required String attachment, String? starter}) {
  return showDialog(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 680),
        child: _AiChat(title: title, attachment: attachment, starter: starter),
      ),
    ),
  );
}

class _Msg {
  final String role; // user | assistant | error
  final String text;
  _Msg(this.role, this.text);
}

class _AiChat extends StatefulWidget {
  final String title;
  final String attachment;
  final String? starter;
  const _AiChat({required this.title, required this.attachment, this.starter});
  @override
  State<_AiChat> createState() => _AiChatState();
}

class _AiChatState extends State<_AiChat> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [];
  bool _sending = false;
  bool _attachOpen = false;
  bool _firstSent = false;

  @override
  void initState() {
    super.initState();
    if (widget.starter != null) _input.text = widget.starter!;
  }

  String get _system => tr(
      'Kamu asisten keamanan web. Jawab dalam Bahasa Indonesia secara ringkas dan jelas. Jelaskan maksud request/response, parameter/header penting, dan hal menarik dari sisi keamanan (auth, token, cookie, data sensitif). Jangan mengarang; kalau tidak yakin katakan tidak yakin.',
      'You are a web security assistant. Answer in English, concise and clear. Explain the request/response, important params/headers, and notable security aspects (auth, tokens, cookies, sensitive data). Do not make things up; if unsure, say so.');

  Future<void> _send() async {
    final q = _input.text.trim();
    if (q.isEmpty || _sending) return;
    setState(() {
      _msgs.add(_Msg('user', q));
      _input.clear();
      _sending = true;
    });
    _scrollDown();

    // bangun messages untuk API
    final api = <Map<String, String>>[{'role': 'system', 'content': _system}];
    bool injected = false;
    for (final m in _msgs) {
      if (m.role == 'error') continue;
      var content = m.text;
      if (m.role == 'user' && !injected && !_firstSent) {
        content = '=== ${tr('LAMPIRAN', 'ATTACHMENT')} ===\n${widget.attachment}\n\n=== ${tr('PERTANYAAN', 'QUESTION')} ===\n${m.text}';
        injected = true;
      }
      api.add({'role': m.role == 'assistant' ? 'assistant' : 'user', 'content': content});
    }
    _firstSent = true;

    final r = await Api.instance.aiAsk(api);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (r['ok'] == true) {
        _msgs.add(_Msg('assistant', (r['answer'] as String?)?.trim().isNotEmpty == true ? r['answer'] as String : '(${tr('kosong', 'empty')})'));
      } else {
        _msgs.add(_Msg('error', '${tr('Gagal', 'Failed')}: ${r['error']}\n\n${tr('Atur koneksi AI di Pengaturan → AI.', 'Configure the AI connection in Settings → AI.')}'));
      }
    });
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: YmColors.primarySoft, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.auto_awesome_rounded, color: YmColors.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('${tr('Tanya AI', 'Ask AI')} — ${widget.title}', style: YmTextStyles.headlineSm, maxLines: 1, overflow: TextOverflow.ellipsis)),
            TextButton.icon(onPressed: () => Nav.go('settings'), icon: const Icon(Icons.settings_outlined, size: 16), label: Text(tr('Setting AI', 'AI settings'))),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          ]),
        ),
        const Divider(height: 1),
        // lampiran (bisa dibuka/tutup)
        InkWell(
          onTap: () => setState(() => _attachOpen = !_attachOpen),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Icon(Icons.attach_file_rounded, size: 15, color: YmColors.outline),
              const SizedBox(width: 6),
              Text(tr('LAMPIRAN', 'ATTACHMENT'), style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
              const SizedBox(width: 6),
              Text('(${widget.attachment.length} ${tr('karakter', 'chars')})', style: YmTextStyles.labelSm),
              const Spacer(),
              Icon(_attachOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: YmColors.outline),
            ]),
          ),
        ),
        if (_attachOpen)
          Container(
            constraints: const BoxConstraints(maxHeight: 140),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
            child: SingleChildScrollView(child: SelectableText(widget.attachment, style: YmTextStyles.mono.copyWith(fontSize: 11))),
          ),
        const Divider(height: 1),
        // percakapan
        Expanded(
          child: _msgs.isEmpty
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(tr('Tulis pertanyaanmu tentang request/response ini, lalu kirim.', 'Type your question about this request/response, then send.'),
                      textAlign: TextAlign.center, style: YmTextStyles.bodySm),
                ))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: _msgs.length,
                  itemBuilder: (context, i) => _bubble(_msgs[i]),
                ),
        ),
        if (_sending)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: YmColors.primary)),
              const SizedBox(width: 10),
              Text(tr('AI sedang berpikir…', 'AI is thinking…'), style: YmTextStyles.bodySm),
            ]),
          ),
        const Divider(height: 1),
        // input
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                controller: _input,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(hintText: tr('Tanya sesuatu…', 'Ask something…')),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _sending ? null : _send,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(14)),
              child: const Icon(Icons.send_rounded, size: 18),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _bubble(_Msg m) {
    final isUser = m.role == 'user';
    final isErr = m.role == 'error';
    final bg = isUser ? YmColors.primary : (isErr ? YmColors.dangerSoft : YmColors.surfaceAlt);
    final fg = isUser ? YmColors.onPrimary : (isErr ? YmColors.onDangerSoft : YmColors.textDark);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: SelectableText(m.text, style: TextStyle(fontFamily: kFont, fontSize: 13, height: 1.5, color: fg)),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';

/// Menu "Email Login" — dua mode:
///  (A) Login Email (IMAP): masukkan email + password, provider & port dideteksi
///      otomatis, lalu kotak masuk dibaca untuk ambil OTP/link login.
///  (B) Penangkap (SMTP): server email mini bawaan; aplikasi uji-mu mengirim email
///      ke sini lalu OTP/link-nya ditangkap.
/// Hanya untuk akun/aplikasi/domain milikmu sendiri.
class EmailLoginPage extends StatefulWidget {
  const EmailLoginPage({super.key});
  @override
  State<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends State<EmailLoginPage> {
  int _mode = 0; // 0 = IMAP login, 1 = SMTP catcher

  // detail yang sedang dibuka (dipakai kedua mode)
  Map<String, dynamic>? _open;
  bool _openImap = false;

  // ---------- IMAP ----------
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _imapHost = TextEditingController();
  final _imapPort = TextEditingController(text: '993');
  bool _showPass = false;
  bool _unseen = false;
  int _proto = 0;            // 0 = IMAP, 1 = POP3
  bool _ssl = true;          // true = TLS implisit (993/995), false = plaintext/STARTTLS
  bool _starttls = false;    // kalau non-SSL, naikkan ke TLS (STARTTLS / STLS)
  Map<String, dynamic> _imapInfo = {};   // hasil detect terakhir (host imap & pop3)
  bool _imapBusy = false;
  bool _autoCopyImap = true;
  String _imapNote = '';
  bool _needAppPw = false;
  List<Map<String, dynamic>> _imapMails = [];
  Timer? _detectDebounce;

  // ---------- SMTP catcher ----------
  final _port = TextEditingController(text: '1025');
  final _filter = TextEditingController();
  Map<String, dynamic> _status = {'running': false, 'port': 1025, 'count': 0, 'ips': []};
  List<Map<String, dynamic>> _mails = [];
  bool _busy = false;
  bool _autoCopyOtp = true;
  int _lastTopId = 0;
  Timer? _poll;

  bool get _running => _status['running'] == true;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_mode == 1 && _running) _refreshList();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _detectDebounce?.cancel();
    _email.dispose(); _pass.dispose(); _imapHost.dispose(); _imapPort.dispose();
    _port.dispose(); _filter.dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _copy(String v) {
    Clipboard.setData(ClipboardData(text: v));
    _snack(tr('Disalin.', 'Copied.'));
  }

  String _time(dynamic ts) {
    final n = (ts as num?)?.toInt() ?? 0;
    if (n == 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(n);
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  // ===================== IMAP =====================
  void _onEmailChanged() {
    _detectDebounce?.cancel();
    _detectDebounce = Timer(const Duration(milliseconds: 400), _detect);
  }

  Future<void> _detect() async {
    final e = _email.text.trim();
    if (!e.contains('@')) return;
    try {
      final d = await Api.instance.imapDetect(e);
      if (!mounted || d['ok'] != true) return;
      setState(() {
        _imapInfo = d;
        _applyHostPort();
        _imapNote = (d['note'] ?? '').toString();
        _needAppPw = d['need_app_password'] == true;
      });
    } catch (_) {}
  }

  int _defaultPort() => _proto == 0 ? (_ssl ? 993 : 143) : (_ssl ? 995 : 110);

  /// Isi host & port sesuai protokol + mode yang dipilih (dari hasil detect).
  void _applyHostPort() {
    final d = _imapInfo;
    if (d['ok'] == true) {
      final host = _proto == 0
          ? (d['imap_host'] ?? d['host'] ?? '')
          : (d['pop3_host'] ?? d['host'] ?? '');
      _imapHost.text = host.toString();
    }
    _imapPort.text = '${_defaultPort()}';
  }

  /// Dipakai chip port: set protokol/mode/port sekaligus.
  void _pickPort(int proto, bool ssl, bool starttls, int port) {
    setState(() {
      _proto = proto; _ssl = ssl; _starttls = starttls;
      if (_imapInfo['ok'] == true) {
        final host = proto == 0
            ? (_imapInfo['imap_host'] ?? _imapInfo['host'] ?? '')
            : (_imapInfo['pop3_host'] ?? _imapInfo['host'] ?? '');
        _imapHost.text = host.toString();
      }
      _imapPort.text = '$port';
    });
  }

  Future<void> _imapFetch() async {
    final e = _email.text.trim();
    if (!e.contains('@') || _pass.text.isEmpty) {
      _snack(tr('Isi email dan password dulu.', 'Enter email and password first.'));
      return;
    }
    setState(() { _imapBusy = true; });
    try {
      final r = await Api.instance.imapFetch(
        email: e,
        password: _pass.text,
        host: _imapHost.text.trim().isEmpty ? null : _imapHost.text.trim(),
        port: int.tryParse(_imapPort.text.trim()),
        limit: 20,
        unseenOnly: _unseen && _proto == 0,
        proto: _proto == 0 ? 'imap' : 'pop3',
        ssl: _ssl,
        starttls: _starttls,
      );
      if (!mounted) return;
      if (r['ok'] == true) {
        final items = ((r['items'] as List?) ?? []).cast<Map<String, dynamic>>();
        // auto-salin OTP email teratas
        if (_autoCopyImap && items.isNotEmpty) {
          final otp = (items.first['otp'] ?? '').toString();
          if (otp.isNotEmpty) {
            Clipboard.setData(ClipboardData(text: otp));
            _snack(tr('OTP $otp disalin.', 'OTP $otp copied.'));
          }
        }
        setState(() => _imapMails = items);
        if (items.isEmpty) _snack(tr('Kotak masuk kosong (atau tak ada yang belum dibaca).', 'Inbox empty (or nothing unread).'));
      } else {
        _snack('${r['error'] ?? tr('Gagal', 'Failed')}');
      }
    } catch (e2) {
      _snack('$e2');
    }
    if (mounted) setState(() => _imapBusy = false);
  }

  // ===================== SMTP catcher =====================
  Future<void> _refreshStatus() async {
    try {
      final s = await Api.instance.mailStatus();
      if (!mounted) return;
      setState(() { _status = s; if (s['port'] != null) _port.text = '${s['port']}'; });
      if (_running) _refreshList();
    } catch (_) {}
  }

  Future<void> _refreshList() async {
    try {
      final items = await Api.instance.mailList(to: _filter.text.trim());
      if (!mounted) return;
      if (items.isNotEmpty) {
        final topId = (items.first['id'] as num?)?.toInt() ?? 0;
        if (topId > _lastTopId) {
          final otp = (items.first['otp'] ?? '').toString();
          if (_lastTopId != 0 && _autoCopyOtp && otp.isNotEmpty) {
            Clipboard.setData(ClipboardData(text: otp));
            _snack(tr('Email baru — OTP $otp disalin.', 'New email — OTP $otp copied.'));
          }
          _lastTopId = topId;
        }
      }
      setState(() => _mails = items);
    } catch (_) {}
  }

  Future<void> _start() async {
    final port = int.tryParse(_port.text.trim()) ?? 1025;
    setState(() => _busy = true);
    try {
      final r = await Api.instance.mailStart(port: port);
      if (!mounted) return;
      if (r['ok'] == true) { setState(() => _status = r); _refreshList(); }
      else { _snack('${tr('Gagal menyalakan', 'Could not start')}: ${r['error'] ?? ''}'); }
    } catch (e) { _snack('$e'); }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    try { final r = await Api.instance.mailStop(); if (mounted) setState(() => _status = r); } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _openCatcherMail(int id) async {
    try {
      final r = await Api.instance.mailGet(id);
      if (!mounted) return;
      if (r['ok'] == true) setState(() { _open = (r['mail'] as Map).cast<String, dynamic>(); _openImap = false; });
    } catch (_) {}
  }

  Future<void> _clear() async {
    await Api.instance.mailClear();
    if (mounted) setState(() { _mails = []; _open = null; });
  }

  Future<void> _openFirewall() async {
    final port = int.tryParse(_port.text.trim()) ?? 1025;
    final r = await Api.instance.firewallOpen(port);
    _snack(r['ok'] == true
        ? tr('Port $port dibuka di firewall.', 'Port $port opened in firewall.')
        : tr('Perlu dijalankan sebagai Administrator. Perintah disalin.', 'Needs Administrator. Command copied.'));
    if (r['ok'] != true && (r['command'] ?? '').toString().isNotEmpty) {
      Clipboard.setData(ClipboardData(text: r['command'].toString()));
    }
  }

  // ===================== BUILD =====================
  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            crumbs: [tr('Alat', 'Tools'), 'Email Login'],
            title: tr('Email Login', 'Email Login'),
            subtitle: tr(
                'Masuk ke akun email (IMAP) untuk baca OTP, atau tangkap email dari aplikasi uji-mu (SMTP). Hanya untuk akun/aplikasi milikmu.',
                'Sign in to an email account (IMAP) to read OTPs, or catch email from your test app (SMTP). Only for your own accounts/apps.'),
          ),
          const SizedBox(height: 14),
          _modeSwitch(),
          const SizedBox(height: 16),
          if (_mode == 0) _imapControls() else _catcherControls(),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 2, child: _inboxCard()),
            const SizedBox(width: 16),
            Expanded(flex: 3, child: _detailCard()),
          ]),
          const SizedBox(height: 16),
          if (_mode == 1) _vpsNote(),
        ],
      ),
    );
  }

  Widget _modeSwitch() {
    Widget seg(int i, IconData ic, String label) {
      final on = _mode == i;
      return InkWell(
        onTap: () => setState(() { _mode = i; _open = null; }),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: on ? YmColors.primary : YmColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ic, size: 17, color: on ? Colors.white : YmColors.textMuted),
            const SizedBox(width: 8),
            Text(label, style: YmTextStyles.labelMd.copyWith(color: on ? Colors.white : YmColors.textMuted, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
    }
    return Row(children: [
      seg(0, Icons.login_rounded, tr('Login Email (IMAP)', 'Email login (IMAP)')),
      const SizedBox(width: 8),
      seg(1, Icons.inbox_rounded, tr('Penangkap (SMTP)', 'Catcher (SMTP)')),
    ]);
  }

  // tombol pilih protokol (IMAP/POP3)
  Widget _protoBtn(int p, String label, IconData ic) {
    final on = _proto == p;
    return InkWell(
      onTap: () => setState(() {
        _proto = p;
        _ssl = true; _starttls = false;   // default balik ke SSL saat ganti protokol
        _applyHostPort();
      }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? YmColors.primary : YmColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ic, size: 15, color: on ? Colors.white : YmColors.textMuted),
          const SizedBox(width: 6),
          Text(label, style: YmTextStyles.labelMd.copyWith(color: on ? Colors.white : YmColors.textMuted, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  // chip port cepat sesuai protokol terpilih; port tetap bisa diisi manual
  List<Widget> _portChips() {
    // (label, port, ssl, starttls)
    final opts = _proto == 0
        ? <(String, int, bool, bool)>[
            ('993 · SSL', 993, true, false),
            ('143 · STARTTLS', 143, false, true),
            ('143 · plain', 143, false, false),
          ]
        : <(String, int, bool, bool)>[
            ('995 · SSL', 995, true, false),
            ('110 · STLS', 110, false, true),
            ('110 · plain', 110, false, false),
          ];
    final curPort = int.tryParse(_imapPort.text.trim()) ?? _defaultPort();
    return [
      for (final o in opts)
        Builder(builder: (_) {
          final sel = curPort == o.$2 && _ssl == o.$3 && _starttls == o.$4;
          return InkWell(
            onTap: () => _pickPort(_proto, o.$3, o.$4, o.$2),
            borderRadius: BorderRadius.circular(999),
            child: SoftChip(
              o.$1,
              icon: o.$3 ? Icons.lock_rounded : (o.$4 ? Icons.lock_open_rounded : Icons.wifi_rounded),
              fg: sel ? YmColors.onPrimaryFixed : YmColors.textMuted,
              bg: sel ? YmColors.primaryFixed : YmColors.surfaceContainerHigh,
              pill: true, bold: sel,
            ),
          );
        }),
    ];
  }

  // ---------- kontrol IMAP ----------
  Widget _imapControls() {
    return HoverCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Masuk ke akun email', 'Sign in to the email account'), style: YmTextStyles.headlineSm),
        const SizedBox(height: 4),
        Text(tr('Masukkan email & password — provider dan port terdeteksi otomatis.',
            'Enter email & password — the provider and port are detected automatically.'),
            style: YmTextStyles.bodySm.copyWith(color: YmColors.outline)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _email,
              onChanged: (_) => _onEmailChanged(),
              style: YmTextStyles.mono,
              decoration: InputDecoration(labelText: tr('Alamat email', 'Email address'), hintText: 'kamu@gmail.com', prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _pass,
              obscureText: !_showPass,
              style: YmTextStyles.mono,
              onSubmitted: (_) => _imapFetch(),
              decoration: InputDecoration(
                labelText: tr('Password / App Password', 'Password / App Password'),
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(_showPass ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                  onPressed: () => setState(() => _showPass = !_showPass),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        // Protokol: IMAP / POP3
        Row(children: [
          _protoBtn(0, 'IMAP', Icons.all_inbox_rounded),
          const SizedBox(width: 8),
          _protoBtn(1, 'POP3', Icons.download_for_offline_outlined),
          const SizedBox(width: 16),
          Text(tr('Port umum:', 'Common ports:'), style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
        ]),
        const SizedBox(height: 8),
        // Chip port cepat sesuai protokol (termasuk STARTTLS di port non-SSL)
        Wrap(spacing: 8, runSpacing: 8, children: _portChips()),
        const SizedBox(height: 10),
        Row(children: [
          SizedBox(width: 260, child: TextField(controller: _imapHost, style: YmTextStyles.mono, decoration: InputDecoration(labelText: _proto == 0 ? tr('Server IMAP (otomatis)', 'IMAP server (auto)') : tr('Server POP3 (otomatis)', 'POP3 server (auto)')))),
          const SizedBox(width: 10),
          SizedBox(width: 110, child: TextField(controller: _imapPort, keyboardType: TextInputType.number, style: YmTextStyles.mono, decoration: const InputDecoration(labelText: 'Port'))),
          const SizedBox(width: 16),
          if (_proto == 0)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Checkbox(value: _unseen, onChanged: (v) => setState(() => _unseen = v ?? false)),
              Text(tr('Belum dibaca saja', 'Unread only'), style: YmTextStyles.labelMd),
            ]),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          ElevatedButton.icon(
            onPressed: _imapBusy ? null : _imapFetch,
            icon: _imapBusy
                ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download_rounded, size: 18),
            label: Text(tr('Masuk & ambil email', 'Sign in & fetch')),
          ),
          const SizedBox(width: 10),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Switch(value: _autoCopyImap, onChanged: (v) => setState(() => _autoCopyImap = v)),
            Text(tr('Auto-salin OTP', 'Auto-copy OTP'), style: YmTextStyles.labelMd.copyWith(color: YmColors.textMuted)),
          ]),
        ]),
        if (_imapNote.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: (_needAppPw ? YmColors.warningSoft : YmColors.surfaceAlt).withOpacity(0.6), borderRadius: BorderRadius.circular(9)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(_needAppPw ? Icons.key_rounded : Icons.info_outline_rounded, size: 17, color: _needAppPw ? YmColors.onWarningSoft : YmColors.outline),
              const SizedBox(width: 9),
              Expanded(child: Text(_imapNote, style: YmTextStyles.labelSm.copyWith(color: _needAppPw ? YmColors.onWarningSoft : YmColors.outline))),
            ]),
          ),
        ],
        const SizedBox(height: 8),
        Text(tr('Password tidak disimpan — hanya dipakai sesaat untuk login, lalu koneksi ditutup.',
            'Your password is not stored — it is used only momentarily to sign in, then the connection is closed.'),
            style: YmTextStyles.labelSm.copyWith(color: YmColors.outline, fontStyle: FontStyle.italic)),
      ]),
    );
  }

  // chip port cepat untuk penangkap SMTP; port tetap bisa diisi manual
  List<Widget> _smtpPortChips() {
    const opts = <(String, int)>[
      ('25', 25), ('465 · SMTPS', 465), ('587 · STARTTLS', 587), ('2525', 2525), ('1025 · dev', 1025),
    ];
    final cur = int.tryParse(_port.text.trim());
    return [
      for (final o in opts)
        InkWell(
          onTap: _running ? null : () => setState(() => _port.text = '${o.$2}'),
          borderRadius: BorderRadius.circular(999),
          child: SoftChip(
            o.$1,
            fg: cur == o.$2 ? YmColors.onPrimaryFixed : YmColors.textMuted,
            bg: cur == o.$2 ? YmColors.primaryFixed : YmColors.surfaceContainerHigh,
            pill: true, bold: cur == o.$2,
          ),
        ),
    ];
  }

  // ---------- kontrol SMTP catcher ----------
  Widget _catcherControls() {
    final ips = ((_status['ips'] as List?) ?? []).map((e) => e.toString()).toList();
    final port = _status['port'] ?? _port.text;
    return HoverCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(tr('Penangkap email (SMTP mini)', 'Mail catcher (mini SMTP)'), style: YmTextStyles.headlineSm)),
          SoftChip(
            _running ? tr('AKTIF :$port', 'LIVE :$port') : tr('MATI', 'OFF'),
            icon: _running ? Icons.circle : Icons.circle_outlined,
            fg: _running ? YmColors.onSuccessSoft : YmColors.textMuted,
            bg: _running ? YmColors.successContainer.withOpacity(0.5) : YmColors.surfaceContainerHigh,
            pill: true, bold: true,
          ),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          SizedBox(width: 140, child: TextField(controller: _port, enabled: !_running, keyboardType: TextInputType.number, style: YmTextStyles.mono, decoration: InputDecoration(labelText: tr('Port SMTP', 'SMTP port'), hintText: '1025'))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _filter, onChanged: (_) => _refreshList(), style: YmTextStyles.mono, decoration: InputDecoration(labelText: tr('Pantau email (opsional)', 'Watch address (optional)'), hintText: tr('kosong = semua', 'empty = all'), prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18)))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text(tr('Port umum:', 'Common ports:'), style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
          const SizedBox(width: 10),
          Expanded(child: Wrap(spacing: 8, runSpacing: 8, children: _smtpPortChips())),
        ]),
        const SizedBox(height: 4),
        Text(tr('Catatan: penangkap ini menerima plaintext — chip hanya mengatur nomor port dengar. Untuk 465/587 arahkan SMTP app-mu ke sini TANPA TLS.',
            'Note: this catcher receives plaintext — chips only set the listen port. For 465/587 point your app\'s SMTP here WITHOUT TLS.'),
            style: YmTextStyles.labelSm.copyWith(color: YmColors.outline, fontStyle: FontStyle.italic)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (!_running)
            ElevatedButton.icon(onPressed: _busy ? null : _start, icon: const Icon(Icons.play_arrow_rounded, size: 18), label: Text(tr('Nyalakan', 'Start')))
          else
            ElevatedButton.icon(onPressed: _busy ? null : _stop, style: ElevatedButton.styleFrom(backgroundColor: YmColors.danger), icon: const Icon(Icons.stop_rounded, size: 18), label: Text(tr('Matikan', 'Stop'))),
          OutlinedButton.icon(onPressed: _openFirewall, icon: const Icon(Icons.shield_outlined, size: 18), label: Text(tr('Buka port di firewall', 'Open port in firewall'))),
          OutlinedButton.icon(onPressed: _refreshStatus, icon: const Icon(Icons.refresh_rounded, size: 18), label: Text(tr('Cek', 'Check'))),
        ]),
        const SizedBox(height: 6),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Switch(value: _autoCopyOtp, onChanged: (v) => setState(() => _autoCopyOtp = v)),
          Text(tr('Auto-salin OTP saat email baru masuk', 'Auto-copy OTP on new email'), style: YmTextStyles.labelMd.copyWith(color: YmColors.textMuted)),
        ]),
        if (_running) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: YmColors.successContainer.withOpacity(0.25), borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Arahkan SMTP aplikasimu ke sini (tanpa TLS/sandi):', 'Point your app\'s SMTP here (no TLS/password):'), style: YmTextStyles.labelMd.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                InkWell(onTap: () => _copy('127.0.0.1:$port'), child: SoftChip('127.0.0.1:$port', icon: Icons.copy_rounded, fg: YmColors.onSuccessSoft, bg: YmColors.successContainer.withOpacity(0.5), pill: true, bold: true)),
                for (final ip in ips)
                  InkWell(onTap: () => _copy('$ip:$port'), child: SoftChip('$ip:$port', icon: Icons.copy_rounded, fg: YmColors.onSuccessSoft, bg: YmColors.successContainer.withOpacity(0.5), pill: true, bold: true)),
              ]),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _vpsNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: YmColors.warningSoft.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, size: 18, color: YmColors.onWarningSoft),
        const SizedBox(width: 10),
        Expanded(child: Text(
          tr('Untuk menerima email ASLI dari luar (di VPS), server perlu port 25 terbuka + MX record domain mengarah ke IP-nya. Hanya untuk aplikasi/domain milikmu.',
              'To receive REAL external email (on a VPS), it needs port 25 open + an MX record pointing to its IP. Only for your own apps/domains.'),
          style: YmTextStyles.labelSm.copyWith(color: YmColors.onWarningSoft))),
      ]),
    );
  }

  // ---------- inbox (dipakai kedua mode) ----------
  Widget _inboxCard() {
    final list = _mode == 0 ? _imapMails : _mails;
    return HoverCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.inbox_rounded, color: YmColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(tr('Masuk', 'Inbox'), style: YmTextStyles.headlineSm),
          const Spacer(),
          Text('${list.length}', style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
          if (_mode == 1)
            IconButton(tooltip: tr('Bersihkan', 'Clear'), icon: Icon(Icons.delete_outline_rounded, size: 18, color: YmColors.outline), onPressed: _mails.isEmpty ? null : _clear),
        ]),
        const SizedBox(height: 8),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text(
              _mode == 0 ? tr('Masuk ke email untuk melihat kotak masuk.', 'Sign in to see the inbox.')
                         : (_running ? tr('Menunggu email masuk…', 'Waiting for incoming email…') : tr('Nyalakan dulu di atas.', 'Start it above first.')),
              style: YmTextStyles.bodySm.copyWith(color: YmColors.outline))),
          )
        else
          ...List.generate(list.length, (i) {
            final m = list[i];
            final otp = (m['otp'] ?? '').toString();
            final sel = _open != null && _open!['id'] == m['id'] && _openImap == (_mode == 0);
            return InkWell(
              onTap: () {
                if (_mode == 0) { setState(() { _open = m; _openImap = true; }); }
                else { _openCatcherMail(m['id'] as int); }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: sel ? YmColors.primary.withOpacity(0.08) : YmColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? YmColors.primary.withOpacity(0.4) : Colors.transparent),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text((m['subject'] ?? '(tanpa subjek)').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelMd.copyWith(fontWeight: FontWeight.w700))),
                    Text(_time(m['ts']), style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
                  ]),
                  const SizedBox(height: 2),
                  Text('${tr('dari', 'from')}: ${m['from'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
                  if (otp.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    SoftChip('OTP $otp', icon: Icons.password_rounded, fg: YmColors.onDangerSoft, bg: YmColors.dangerSoft, pill: true, bold: true),
                  ],
                ]),
              ),
            );
          }),
      ]),
    );
  }

  // ---------- detail (dipakai kedua mode) ----------
  Widget _detailCard() {
    final m = _open;
    if (m == null) {
      return HoverCard(
        padding: const EdgeInsets.all(18),
        child: SizedBox(height: 160, child: Center(child: Text(
          tr('Pilih email untuk melihat isinya & tombol login.', 'Pick an email to see its contents & login button.'),
          style: YmTextStyles.bodySm.copyWith(color: YmColors.outline)))),
      );
    }
    final otp = (m['otp'] ?? '').toString();
    final links = ((m['links'] as List?) ?? []).map((e) => e.toString()).toList();
    final text = (m['text'] ?? '').toString();
    final id = m['id'] as int;
    final htmlUrl = _openImap ? Api.instance.imapHtmlUrl(id) : Api.instance.mailHtmlUrl(id);
    return HoverCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((m['subject'] ?? '(tanpa subjek)').toString(), style: YmTextStyles.headlineSm),
        const SizedBox(height: 6),
        Text('${tr('dari', 'from')}: ${m['from'] ?? ''}', style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
        Text('${tr('ke', 'to')}: ${m['to'] ?? ''}', style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse(htmlUrl), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_browser_rounded, size: 16),
            label: Text(tr('Lihat HTML di browser', 'View HTML in browser')),
          ),
        ),
        if (otp.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(tr('Kode OTP', 'OTP code'), style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
          const SizedBox(height: 4),
          Row(children: [
            SelectableText(otp, style: YmTextStyles.mono.copyWith(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 4, color: YmColors.danger)),
            const SizedBox(width: 10),
            OutlinedButton.icon(onPressed: () => _copy(otp), icon: const Icon(Icons.copy_rounded, size: 15), label: Text(tr('Salin', 'Copy'))),
          ]),
        ],
        if (links.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(tr('Link untuk login', 'Login links'), style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
          const SizedBox(height: 6),
          ...links.map((u) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(child: SelectableText(u, style: YmTextStyles.mono.copyWith(color: YmColors.primary), maxLines: 2)),
                  const SizedBox(width: 6),
                  IconButton(tooltip: tr('Salin', 'Copy'), icon: Icon(Icons.copy_rounded, size: 15, color: YmColors.outline), onPressed: () => _copy(u)),
                  ElevatedButton.icon(onPressed: () => launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_new_rounded, size: 15), label: Text(tr('Buka', 'Open'))),
                ]),
              )),
        ],
        if (text.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(tr('Isi email', 'Email body'), style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 240),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
            child: SingleChildScrollView(child: SelectableText(text, style: YmTextStyles.bodySm)),
          ),
        ],
      ]),
    );
  }
}

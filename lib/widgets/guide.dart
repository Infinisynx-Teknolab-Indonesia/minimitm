import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/i18n.dart';

/// Satu langkah panduan: ikon + teks (ID & EN).
class GuideStep {
  final IconData icon;
  final String id;
  final String en;
  const GuideStep(this.icon, this.id, this.en);
}

/// Konten panduan untuk satu menu.
class GuideData {
  final String titleId, titleEn;
  final String introId, introEn;
  final List<GuideStep> steps;
  final String? tipId, tipEn;
  const GuideData({
    required this.titleId, required this.titleEn,
    required this.introId, required this.introEn,
    required this.steps, this.tipId, this.tipEn,
  });
}

/// Footer panduan yang muncul di SEMUA menu (dipasang sekali di shell).
/// Bisa buka/tutup; default terbuka tapi tingginya dibatasi + bisa di-scroll.
class GuideFooter extends StatefulWidget {
  final String id;
  const GuideFooter({super.key, required this.id});
  @override
  State<GuideFooter> createState() => _GuideFooterState();
}

class _GuideFooterState extends State<GuideFooter> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final g = kGuides[widget.id];
    if (g == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: L.instance,
      builder: (context, _) {
        final title = tr(g.titleId, g.titleEn);
        return Container(
          decoration: BoxDecoration(
            color: YmColors.surface,
            border: Border(top: BorderSide(color: YmColors.line)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // --- bar header (klik buka/tutup) ---
            InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(children: [
                  Icon(Icons.menu_book_rounded, size: 18, color: YmColors.primary),
                  const SizedBox(width: 10),
                  Text(tr('Panduan', 'Guide'), style: YmTextStyles.labelMd.copyWith(fontWeight: FontWeight.w800, color: YmColors.textDark)),
                  const SizedBox(width: 8),
                  Flexible(child: Text('— $title', maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelSm.copyWith(color: YmColors.outline))),
                  const Spacer(),
                  Text(_open ? tr('tutup', 'hide') : tr('buka', 'show'), style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
                  const SizedBox(width: 4),
                  Icon(_open ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded, size: 20, color: YmColors.outline),
                ]),
              ),
            ),
            // --- isi panduan ---
            if (_open)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr(g.introId, g.introEn), style: YmTextStyles.bodySm.copyWith(color: YmColors.outline)),
                    const SizedBox(height: 12),
                    ...List.generate(g.steps.length, (i) {
                      final s = g.steps[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          // nomor langkah
                          Container(
                            width: 22, height: 22, alignment: Alignment.center,
                            decoration: BoxDecoration(color: YmColors.surfaceContainerHigh, shape: BoxShape.circle),
                            child: Text('${i + 1}', style: YmTextStyles.labelSm.copyWith(fontWeight: FontWeight.w800, color: YmColors.textMuted)),
                          ),
                          const SizedBox(width: 10),
                          // ikon langkah
                          Container(
                            width: 30, height: 30, alignment: Alignment.center,
                            decoration: BoxDecoration(color: YmColors.primaryFixed, borderRadius: BorderRadius.circular(8)),
                            child: Icon(s.icon, size: 17, color: YmColors.onPrimaryFixed),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(tr(s.id, s.en), style: YmTextStyles.bodySm.copyWith(color: YmColors.textDark)),
                          )),
                        ]),
                      );
                    }),
                    if (g.tipId != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: YmColors.warningSoft.withOpacity(0.5), borderRadius: BorderRadius.circular(9)),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.lightbulb_outline_rounded, size: 16, color: YmColors.onWarningSoft),
                          const SizedBox(width: 8),
                          Expanded(child: Text(tr(g.tipId!, g.tipEn ?? g.tipId!), style: YmTextStyles.labelSm.copyWith(color: YmColors.onWarningSoft))),
                        ]),
                      ),
                    ],
                  ]),
                ),
              ),
          ]),
        );
      },
    );
  }
}

// ===========================================================================
// Konten panduan tiap menu (key = id menu di sidebar). Tambah/ubah di sini saja.
// ===========================================================================
const Map<String, GuideData> kGuides = {
  'dashboard': GuideData(
    titleId: 'Dashboard', titleEn: 'Dashboard',
    introId: 'Ringkasan status proxy, jumlah lalu lintas, dan pintasan cepat.',
    introEn: 'Overview of proxy status, traffic counts, and quick shortcuts.',
    steps: [
      GuideStep(Icons.toggle_on_rounded, 'Lihat status proxy (ON/OFF) dan port yang dipakai.', 'Check proxy status (ON/OFF) and the port in use.'),
      GuideStep(Icons.insights_rounded, 'Pantau ringkasan jumlah request, host, dan temuan.', 'Watch the summary of requests, hosts, and findings.'),
      GuideStep(Icons.bolt_rounded, 'Pakai pintasan untuk loncat ke Proxy, History, atau Scanner.', 'Use shortcuts to jump to Proxy, History, or Scanner.'),
    ],
  ),
  'proxy': GuideData(
    titleId: 'Proxy', titleEn: 'Proxy',
    introId: 'Nyalakan mesin MITM, atur port, dan pasang sertifikat CA ke perangkat uji.',
    introEn: 'Start the MITM engine, set the port, and install the CA on your test device.',
    steps: [
      GuideStep(Icons.play_arrow_rounded, 'Klik "Mulai" untuk menyalakan proxy (default 127.0.0.1:8080).', 'Click "Start" to run the proxy (default 127.0.0.1:8080).'),
      GuideStep(Icons.settings_ethernet_rounded, 'Arahkan proxy HP/PC uji ke IP:port ini.', 'Point your test phone/PC proxy to this IP:port.'),
      GuideStep(Icons.verified_user_rounded, 'Unduh & pasang sertifikat CA agar HTTPS bisa dibaca.', 'Download & install the CA so HTTPS can be read.'),
      GuideStep(Icons.lan_rounded, 'Untuk LAN, pastikan firewall mengizinkan port tersebut.', 'For LAN, make sure the firewall allows that port.'),
    ],
    tipId: 'Hanya untuk perangkat & aplikasi milikmu sendiri.',
    tipEn: 'Only for your own devices & apps.',
  ),
  'history': GuideData(
    titleId: 'HTTP History', titleEn: 'HTTP History',
    introId: 'Semua request/response yang lewat proxy terekam di sini.',
    introEn: 'Every request/response through the proxy is logged here.',
    steps: [
      GuideStep(Icons.list_alt_rounded, 'Klik satu baris untuk lihat detail request & response.', 'Click a row to see request & response details.'),
      GuideStep(Icons.filter_alt_rounded, 'Pakai filter host/method/kata kunci untuk mempersempit.', 'Use host/method/keyword filters to narrow down.'),
      GuideStep(Icons.send_rounded, 'Klik kanan → kirim ke Repeater/Intruder untuk diuji.', 'Right-click → send to Repeater/Intruder to test.'),
    ],
  ),
  'intercept': GuideData(
    titleId: 'Intercept', titleEn: 'Intercept',
    introId: 'Tahan request/response di tengah jalan untuk diperiksa atau diubah sebelum diteruskan.',
    introEn: 'Pause a request/response in flight to inspect or edit before it continues.',
    steps: [
      GuideStep(Icons.toggle_on_rounded, 'Aktifkan switch Intercept supaya lalu lintas ditahan.', 'Turn on the Intercept switch to hold traffic.'),
      GuideStep(Icons.edit_rounded, 'Ubah method, path, header, atau body saat tertahan.', 'Edit method, path, headers, or body while held.'),
      GuideStep(Icons.play_arrow_rounded, 'Klik "Forward" untuk meneruskan, atau "Drop" untuk membuang.', 'Click "Forward" to continue, or "Drop" to discard.'),
      GuideStep(Icons.password_rounded, 'Cari OTP/token di body saat mengetes alur login.', 'Spot OTP/token in the body when testing login flows.'),
    ],
    tipId: 'Matikan Intercept kalau tidak dipakai supaya lalu lintas tidak macet.',
    tipEn: 'Turn Intercept off when unused so traffic does not stall.',
  ),
  'websocket': GuideData(
    titleId: 'WebSocket', titleEn: 'WebSocket',
    introId: 'Pantau pesan WebSocket yang lewat proxy secara langsung.',
    introEn: 'Watch WebSocket messages passing through the proxy live.',
    steps: [
      GuideStep(Icons.swap_horiz_rounded, 'Lihat aliran pesan masuk/keluar per koneksi.', 'See inbound/outbound messages per connection.'),
      GuideStep(Icons.search_rounded, 'Cari kata kunci untuk menyaring pesan penting.', 'Search keywords to filter important messages.'),
      GuideStep(Icons.content_copy_rounded, 'Salin isi pesan untuk dianalisis di tool lain.', 'Copy message content to analyze elsewhere.'),
    ],
  ),
  'usb': GuideData(
    titleId: 'USB (ADB)', titleEn: 'USB (ADB)',
    introId: 'Hubungkan HP Android lewat ADB untuk set proxy & pasang CA otomatis.',
    introEn: 'Connect an Android phone via ADB to set the proxy & push the CA automatically.',
    steps: [
      GuideStep(Icons.usb_rounded, 'Colok HP + aktifkan USB debugging, lalu klik "Cek".', 'Plug the phone + enable USB debugging, then click "Check".'),
      GuideStep(Icons.wifi_tethering_rounded, 'Aktifkan proxy di HP ke IP:port PC via ADB.', 'Enable the phone proxy to the PC IP:port via ADB.'),
      GuideStep(Icons.verified_user_rounded, 'Push sertifikat CA ke HP lalu cek Trusted credentials.', 'Push the CA to the phone then check Trusted credentials.'),
    ],
  ),
  'frida': GuideData(
    titleId: 'Frida', titleEn: 'Frida',
    introId: 'Pasang frida-server & jalankan script hook untuk mem-bypass SSL pinning dsb pada app milikmu.',
    introEn: 'Install frida-server & run hook scripts to bypass SSL pinning etc. on your own app.',
    steps: [
      GuideStep(Icons.download_rounded, 'Klik "Install" untuk pasang frida-server sesuai arsitektur HP.', 'Click "Install" to deploy frida-server for the phone arch.'),
      GuideStep(Icons.apps_rounded, 'Pilih paket aplikasi target dari daftar.', 'Pick the target app package from the list.'),
      GuideStep(Icons.bolt_rounded, 'Pilih/edit script, lalu Run (spawn atau attach).', 'Choose/edit a script, then Run (spawn or attach).'),
      GuideStep(Icons.terminal_rounded, 'Pantau log hook di panel bawah.', 'Watch hook logs in the bottom panel.'),
    ],
    tipId: 'Hanya untuk aplikasi milikmu sendiri.',
    tipEn: 'Only for your own apps.',
  ),
  'scope': GuideData(
    titleId: 'Scope', titleEn: 'Scope',
    introId: 'Batasi host/domain yang diproses supaya fokus ke target dan mengurangi noise.',
    introEn: 'Limit which hosts/domains are processed to focus on the target and cut noise.',
    steps: [
      GuideStep(Icons.add_rounded, 'Tambahkan host/pola domain yang mau difokuskan.', 'Add the host/domain patterns to focus on.'),
      GuideStep(Icons.filter_alt_rounded, 'Aktifkan "hanya dalam scope" agar lainnya diabaikan.', 'Enable "in-scope only" so the rest is ignored.'),
      GuideStep(Icons.cleaning_services_rounded, 'Scope rapi bikin History & Scanner lebih bersih.', 'A tidy scope keeps History & Scanner cleaner.'),
    ],
  ),
  'repeater': GuideData(
    titleId: 'Repeater', titleEn: 'Repeater',
    introId: 'Kirim ulang satu request berkali-kali dengan modifikasi manual untuk uji perilaku server.',
    introEn: 'Re-send a single request repeatedly with manual tweaks to probe server behavior.',
    steps: [
      GuideStep(Icons.input_rounded, 'Kirim request dari History, atau tempel manual.', 'Send a request from History, or paste one manually.'),
      GuideStep(Icons.edit_rounded, 'Ubah header/param/body sesuai yang mau diuji.', 'Edit headers/params/body as needed.'),
      GuideStep(Icons.send_rounded, 'Klik "Send" dan bandingkan respons tiap perubahan.', 'Click "Send" and compare responses per change.'),
    ],
  ),
  'intruder': GuideData(
    titleId: 'Intruder', titleEn: 'Intruder',
    introId: 'Serangan payload otomatis: sisipkan daftar nilai ke titik tertentu (fuzzing, brute, enumerasi).',
    introEn: 'Automated payload attack: inject a list of values at marked points (fuzzing, brute, enumeration).',
    steps: [
      GuideStep(Icons.my_location_rounded, 'Tandai posisi payload di request (mis. §nilai§).', 'Mark payload positions in the request (e.g. §value§).'),
      GuideStep(Icons.list_rounded, 'Isi wordlist/daftar payload.', 'Provide the wordlist/payload set.'),
      GuideStep(Icons.rocket_launch_rounded, 'Jalankan, lalu urutkan hasil berdasar status/panjang respons.', 'Run, then sort results by status/response length.'),
    ],
    tipId: 'Hanya untuk target milikmu/yang kamu diizinkan uji.',
    tipEn: 'Only for targets you own or are authorized to test.',
  ),
  'scanner': GuideData(
    titleId: 'Scanner', titleEn: 'Scanner',
    introId: 'Pindai request di History untuk mencari indikasi kerentanan umum.',
    introEn: 'Scan requests from History for signs of common vulnerabilities.',
    steps: [
      GuideStep(Icons.radar_rounded, 'Klik "Scan" untuk memeriksa lalu lintas yang terkumpul.', 'Click "Scan" to check collected traffic.'),
      GuideStep(Icons.report_rounded, 'Tinjau temuan: tingkat keyakinan & lokasinya.', 'Review findings: confidence & location.'),
      GuideStep(Icons.send_rounded, 'Kirim temuan menarik ke Repeater untuk verifikasi manual.', 'Send interesting findings to Repeater for manual verification.'),
    ],
  ),
  'matchreplace': GuideData(
    titleId: 'Match & Replace', titleEn: 'Match & Replace',
    introId: 'Aturan ganti otomatis pada setiap request/response yang lewat.',
    introEn: 'Auto-replace rules applied to every passing request/response.',
    steps: [
      GuideStep(Icons.add_rounded, 'Buat aturan: bagian mana (header/body) + pola cari.', 'Create a rule: which part (header/body) + match pattern.'),
      GuideStep(Icons.find_replace_rounded, 'Isi teks pengganti, aktifkan aturannya.', 'Set the replacement text, enable the rule.'),
      GuideStep(Icons.sync_rounded, 'Aturan berlaku langsung ke lalu lintas berikutnya.', 'Rules apply immediately to subsequent traffic.'),
    ],
  ),
  'comparer': GuideData(
    titleId: 'Comparer', titleEn: 'Comparer',
    introId: 'Bandingkan dua potongan teks/respons untuk melihat perbedaannya.',
    introEn: 'Compare two pieces of text/responses to see the differences.',
    steps: [
      GuideStep(Icons.content_paste_rounded, 'Tempel teks/respons A dan B.', 'Paste text/response A and B.'),
      GuideStep(Icons.compare_arrows_rounded, 'Lihat perbedaan yang disorot per baris/kata.', 'See highlighted differences per line/word.'),
      GuideStep(Icons.insights_rounded, 'Berguna membandingkan respons sukses vs gagal.', 'Useful to compare success vs failure responses.'),
    ],
  ),
  'collaborator': GuideData(
    titleId: 'Collaborator', titleEn: 'Collaborator',
    introId: 'Server OOB untuk mendeteksi interaksi out-of-band (DNS/HTTP) dari target — bukti SSRF/blind.',
    introEn: 'OOB server to detect out-of-band interactions (DNS/HTTP) from the target — evidence of SSRF/blind bugs.',
    steps: [
      GuideStep(Icons.play_arrow_rounded, 'Nyalakan server & ambil payload domain unik.', 'Start the server & grab a unique payload domain.'),
      GuideStep(Icons.input_rounded, 'Sisipkan payload itu ke parameter yang diuji.', 'Inject that payload into the tested parameter.'),
      GuideStep(Icons.notifications_active_rounded, 'Pantau interaksi masuk sebagai bukti.', 'Watch incoming interactions as evidence.'),
    ],
  ),
  'plugins': GuideData(
    titleId: 'Plugins', titleEn: 'Plugins',
    introId: 'Aktif/nonaktif plugin gaya Burp (scanner & helper) yang berjalan pada lalu lintas.',
    introEn: 'Toggle Burp-style plugins (scanners & helpers) that run on traffic.',
    steps: [
      GuideStep(Icons.toggle_on_rounded, 'Aktifkan plugin yang dibutuhkan untuk sesi ini.', 'Enable the plugins you need for this session.'),
      GuideStep(Icons.play_circle_rounded, 'Sebagian bisa dijalankan manual lewat klik kanan pada flow.', 'Some can be run manually via right-click on a flow.'),
      GuideStep(Icons.refresh_rounded, 'Klik "Reload" setelah menambah file plugin baru.', 'Click "Reload" after adding new plugin files.'),
    ],
  ),
  'decoder': GuideData(
    titleId: 'Decoder', titleEn: 'Decoder',
    introId: 'Encode/decode cepat: Base64, URL, hex, HTML, dll.',
    introEn: 'Quick encode/decode: Base64, URL, hex, HTML, etc.',
    steps: [
      GuideStep(Icons.input_rounded, 'Tempel teks yang mau diubah.', 'Paste the text to transform.'),
      GuideStep(Icons.transform_rounded, 'Pilih operasi (encode/decode) & formatnya.', 'Pick the operation (encode/decode) & format.'),
      GuideStep(Icons.content_copy_rounded, 'Salin hasilnya untuk dipakai di request.', 'Copy the result for use in a request.'),
    ],
  ),
  'jwt': GuideData(
    titleId: 'JWT', titleEn: 'JWT',
    introId: 'Decode, ubah, dan uji token JWT (mis. alg none, brute secret lemah).',
    introEn: 'Decode, edit, and test JWTs (e.g. alg none, brute weak secrets).',
    steps: [
      GuideStep(Icons.vpn_key_rounded, 'Tempel token untuk lihat header & payload.', 'Paste a token to view header & payload.'),
      GuideStep(Icons.edit_rounded, 'Ubah klaim, lalu encode ulang dengan secret/alg.', 'Edit claims, then re-encode with a secret/alg.'),
      GuideStep(Icons.key_rounded, 'Coba wordlist untuk cari secret HS256 yang lemah.', 'Try a wordlist to find a weak HS256 secret.'),
    ],
    tipId: 'Hanya untuk token dari sistem milikmu sendiri.',
    tipEn: 'Only for tokens from your own systems.',
  ),
  'totp': GuideData(
    titleId: 'TOTP / OTP', titleEn: 'TOTP / OTP',
    introId: 'Bangkitkan kode TOTP/OTP dari secret untuk menguji alur 2FA aplikasimu.',
    introEn: 'Generate TOTP/OTP codes from a secret to test your app\'s 2FA flow.',
    steps: [
      GuideStep(Icons.vpn_key_rounded, 'Masukkan secret (Base32) atau nonce.', 'Enter the secret (Base32) or nonce.'),
      GuideStep(Icons.timer_rounded, 'Kode diperbarui tiap periode; salin saat dibutuhkan.', 'Codes refresh each period; copy when needed.'),
      GuideStep(Icons.bookmark_add_rounded, 'Simpan akun 2FA agar cepat dipakai lagi.', 'Save 2FA accounts for quick reuse.'),
    ],
  ),
  'apk': GuideData(
    titleId: 'APK Tools', titleEn: 'APK Tools',
    introId: 'Decompile, patch (trust CA), suntik .so, recompile & tanda tangani ulang APK milikmu.',
    introEn: 'Decompile, patch (trust CA), inject .so, recompile & resign your own APK.',
    steps: [
      GuideStep(Icons.download_rounded, 'Klik "Install tool otomatis" untuk apktool/jadx/signer.', 'Click "Auto-install tools" for apktool/jadx/signer.'),
      GuideStep(Icons.unarchive_rounded, 'Tab 1: Decode (apktool) untuk membongkar APK.', 'Tab 1: Decode (apktool) to unpack the APK.'),
      GuideStep(Icons.vaccines_rounded, 'Tab 5: Suntik .so (engine) → recompile → sign dalam 1 klik.', 'Tab 5: Inject .so (engine) → recompile → sign in one click.'),
      GuideStep(Icons.build_rounded, 'Tab 2: Recompile & Resign untuk build setelah edit manual.', 'Tab 2: Recompile & Resign to build after manual edits.'),
    ],
    tipId: 'Hanya untuk APK milikmu sendiri.',
    tipEn: 'Only for your own APK.',
  ),
  'webscan': GuideData(
    titleId: 'Cek Kelemahan Web', titleEn: 'Web Vuln Scan',
    introId: 'Pemindai AKTIF untuk aplikasi/website milikmu: XSS, SQL Injection, LFI, Open Redirect, CRLF, & misconfig header. Hasil bisa ditanyakan ke AI lokalmu.',
    introEn: 'ACTIVE scanner for your own apps/sites: XSS, SQL Injection, LFI, Open Redirect, CRLF, & header misconfig. Ask your local AI about the results.',
    steps: [
      GuideStep(Icons.link_rounded, 'Isi URL target berikut parameternya (mis. /cari?q=test&id=1).', 'Enter the target URL with its parameters (e.g. /search?q=test&id=1).'),
      GuideStep(Icons.http_rounded, 'Pilih GET/POST; untuk POST isi body form (a=1&b=2).', 'Pick GET/POST; for POST fill the form body (a=1&b=2).'),
      GuideStep(Icons.checklist_rounded, 'Pilih jenis cek (XSS/SQLi/LFI/Redirect/CRLF/Header).', 'Pick the checks (XSS/SQLi/LFI/Redirect/CRLF/Header).'),
      GuideStep(Icons.bug_report_rounded, 'Klik "Pindai sekarang", tinjau temuan beserta tingkat bahayanya.', 'Click "Scan now", review findings with their severity.'),
      GuideStep(Icons.auto_awesome_rounded, 'Klik "Tanya AI" untuk penjelasan & cara perbaikan temuan.', 'Click "Ask AI" for an explanation & how to fix the findings.'),
    ],
    tipId: 'Pemindai AKTIF (mengirim payload) — hanya untuk target milikmu / yang kamu diizinkan uji. Atur AI di Pengaturan > AI.',
    tipEn: 'ACTIVE scanner (sends payloads) — only for targets you own or are authorized to test. Configure AI in Settings > AI.',
  ),
  'spiderfoot': GuideData(
    titleId: 'SpiderFoot', titleEn: 'SpiderFoot',
    introId: 'Pasang & jalankan SpiderFoot (OSINT lengkap) via Docker, lokal atau remote ke VPS/VirtualBox milikmu. UI-nya terbuka di browser (port 5001).',
    introEn: 'Install & run SpiderFoot (full OSINT) via Docker, local or remote to your own VPS/VirtualBox. Its UI opens in the browser (port 5001).',
    steps: [
      GuideStep(Icons.computer_rounded, 'Mode Lokal: butuh Docker Desktop jalan. Mode Remote: isi IP + user/password (atau key) SSH.', 'Local mode: needs Docker Desktop running. Remote mode: enter SSH IP + user/password (or key).'),
      GuideStep(Icons.download_rounded, 'Klik "Auto-install & Jalankan" — otomatis docker pull + run container.', 'Click "Auto-install & Run" — auto docker pull + run the container.'),
      GuideStep(Icons.refresh_rounded, 'Cek status (AKTIF/MATI); "Stop & hapus" untuk mematikan.', 'Check status (RUNNING/STOPPED); "Stop & remove" to shut it down.'),
      GuideStep(Icons.open_in_new_rounded, 'Klik "Buka UI SpiderFoot" untuk mulai scan di browser.', 'Click "Open SpiderFoot UI" to start scanning in the browser.'),
    ],
    tipId: 'UI SpiderFoot tanpa login bawaan — di VPS jangan ekspos ke internet (bind 127.0.0.1 + SSH tunnel / reverse proxy + auth). Untuk aset/penggunaan milikmu.',
    tipEn: 'SpiderFoot UI has no built-in login — on a VPS don\'t expose it (bind 127.0.0.1 + SSH tunnel / reverse proxy + auth). For your own assets/usage.',
  ),
  'recon': GuideData(
    titleId: 'Recon (OSINT)', titleEn: 'Recon (OSINT)',
    introId: 'Passive recon gaya SpiderFoot untuk domain/aset milikmu — kumpulkan info dari sumber publik tanpa menyentuh target secara agresif.',
    introEn: 'SpiderFoot-style passive recon for your own domain/assets — gather info from public sources without aggressively touching the target.',
    steps: [
      GuideStep(Icons.travel_explore_rounded, 'Isi target milikmu: domain, email, atau nomor telepon.', 'Enter your target: domain, email, or phone number.'),
      GuideStep(Icons.tune_rounded, 'Domain/email: pilih modul (DNS, Subdomain crt.sh, WHOIS, Wayback, robots, Fingerprint).', 'Domain/email: pick modules (DNS, Subdomains, WHOIS, Wayback, robots, Fingerprint).'),
      GuideStep(Icons.mark_email_read_outlined, 'Email → audit MX/SPF/DMARC/DKIM domain-nya (bisa di-spoof atau tidak) + recon domain.', 'Email → MX/SPF/DMARC/DKIM audit of its domain + domain recon.'),
      GuideStep(Icons.phone_iphone_rounded, 'Telepon → metadata format saja (negara, kode panggil, E.164).', 'Phone → format metadata only (country, calling code, E.164).'),
      GuideStep(Icons.radar_rounded, 'Klik "Jalankan recon", tinjau hasil, salin subdomain/URL untuk Repeater/Scanner.', 'Click "Run recon", review, copy subdomains/URLs for Repeater/Scanner.'),
    ],
    tipId: 'Semua passive & hanya untuk aset milikmu. Email/telepon dibatasi ke infra & metadata — tidak ada pengumpulan data pribadi/pemilik.',
    tipEn: 'All passive & only for your own assets. Email/phone limited to infra & metadata — no personal/owner data collection.',
  ),
  'email': GuideData(
    titleId: 'Email Login', titleEn: 'Email Login',
    introId: 'Baca OTP dari akun email (IMAP/POP3) atau tangkap email dari aplikasi uji (SMTP).',
    introEn: 'Read OTPs from an email account (IMAP/POP3) or catch email from your test app (SMTP).',
    steps: [
      GuideStep(Icons.login_rounded, 'Mode IMAP/POP3: isi email+password, pilih protokol & port (chip cepat).', 'IMAP/POP3 mode: enter email+password, pick protocol & port (quick chips).'),
      GuideStep(Icons.inbox_rounded, 'Mode SMTP: nyalakan penangkap, arahkan SMTP aplikasimu ke sini.', 'SMTP mode: start the catcher, point your app\'s SMTP here.'),
      GuideStep(Icons.password_rounded, 'OTP & link login diekstrak otomatis; bisa auto-salin.', 'OTP & login links are auto-extracted; can auto-copy.'),
    ],
    tipId: 'Hanya untuk akun/aplikasi/domain milikmu.',
    tipEn: 'Only for your own accounts/apps/domains.',
  ),
  'sms': GuideData(
    titleId: 'SMS Masuk', titleEn: 'Inbound SMS',
    introId: 'Terima SMS lewat webhook dari gateway/provider milikmu, lalu OTP-nya diekstrak otomatis.',
    introEn: 'Receive SMS via webhook from your own gateway/provider, then OTP is auto-extracted.',
    steps: [
      GuideStep(Icons.dns_rounded, 'Isi Host/IP server untuk membentuk URL webhook.', 'Set the server Host/IP to form the webhook URL.'),
      GuideStep(Icons.link_rounded, 'Set inbound webhook gateway-mu ke URL /api/sms/inbound.', 'Point your gateway inbound webhook to /api/sms/inbound.'),
      GuideStep(Icons.vpn_key_rounded, 'Opsional: isi token rahasia agar hanya gateway-mu diterima.', 'Optional: set a secret token so only your gateway is accepted.'),
      GuideStep(Icons.password_rounded, 'SMS masuk tampil + OTP diekstrak (auto-salin).', 'Inbound SMS appears + OTP extracted (auto-copy).'),
    ],
    tipId: 'Webhook dari provider sendiri — bukan menyadap jaringan seluler. Hanya nomor/aplikasi milikmu.',
    tipEn: 'Webhook from your own provider — not cellular interception. Only your own numbers/apps.',
  ),
  'project': GuideData(
    titleId: 'Project', titleEn: 'Project',
    introId: 'Simpan/muat sesi kerja: history, scope, aturan, dan temuan.',
    introEn: 'Save/load your working session: history, scope, rules, and findings.',
    steps: [
      GuideStep(Icons.save_rounded, 'Export untuk menyimpan sesi ke satu berkas.', 'Export to save the session to a single file.'),
      GuideStep(Icons.folder_open_rounded, 'Import untuk melanjutkan sesi sebelumnya.', 'Import to resume a previous session.'),
    ],
  ),
  'settings': GuideData(
    titleId: 'Pengaturan', titleEn: 'Settings',
    introId: 'Atur koneksi AI lokal, path ADB, bahasa, dan preferensi lain.',
    introEn: 'Configure local AI connection, ADB path, language, and other preferences.',
    steps: [
      GuideStep(Icons.smart_toy_rounded, 'Isi URL+model AI lokal (OpenAI-compatible/Ollama) untuk fitur "Tanya AI".', 'Set local AI URL+model (OpenAI-compatible/Ollama) for "Ask AI".'),
      GuideStep(Icons.android_rounded, 'Atur path adb kalau tidak terdeteksi otomatis.', 'Set the adb path if not auto-detected.'),
      GuideStep(Icons.translate_rounded, 'Ganti bahasa ID/EN dari tombol di pojok atas.', 'Switch ID/EN language from the top-corner button.'),
    ],
  ),
};

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, LengthLimitingTextInputFormatter;
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'legal_document.dart';
import 'checkout_embed_stub.dart'
    if (dart.library.js_interop) 'checkout_embed_web.dart';

part 'web_landing.dart';
part 'web_user_panel.dart';
part 'web_booking.dart';
part 'web_auth.dart';
part 'web_videos.dart';

Uri _authenticatedMediaUri(String path) {
  final base = Uri.parse('$_apiBase/');
  final uri = path.startsWith('/api/') || path.startsWith('http')
      ? base.resolve(path)
      : base.resolve(path.replaceFirst(RegExp(r'^/'), ''));
  if (uri.origin != base.origin)
    throw const FormatException('Geçersiz medya adresi');
  return uri;
}

Future<http.Response> _fetchAuthenticatedMedia(String path) async {
  final token = await _storage.read(key: 'access_token');
  final response = await http.get(_authenticatedMediaUri(path), headers: {
    if (token != null) 'Authorization': 'Bearer $token',
  }).timeout(const Duration(minutes: 3));
  if (response.statusCode != 200)
    throw const FormatException('Video yüklenemedi.');
  return response;
}

Future<String> authenticatedMediaUrl(String path) async {
  if (!kIsWeb) return _authenticatedMediaUri(path).toString();
  final response = await _fetchAuthenticatedMedia(path);
  return createWebMediaUrl(
      response.bodyBytes, response.headers['content-type'] ?? 'video/mp4');
}

void revokeAuthenticatedMediaUrl(String url) {
  if (kIsWeb) revokeWebMediaUrl(url);
}

Future<void> downloadAuthenticatedMedia(String path, String name) async {
  final response = await _fetchAuthenticatedMedia(path);
  final mime = response.headers['content-type'] ?? 'video/mp4';
  if (kIsWeb) {
    saveWebMediaBytes(response.bodyBytes, name, mime);
  } else {
    await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(response.bodyBytes, mimeType: mime, name: name)],
        fileNameOverrides: [name]));
  }
}

// The server issues this short-lived URL only for a newly prepared public clip.
// Phones hand it to their download manager instead of presenting a share sheet.
Future<void> downloadPublicClip(String path, String name) async {
  final uri = _authenticatedMediaUri(path);
  if (!uri.path.startsWith('/api/videos/public-clips/')) {
    throw const FormatException('Geçersiz kesit adresi');
  }
  if (kIsWeb) {
    final response = await http.get(uri).timeout(const Duration(minutes: 2));
    if (response.statusCode != 200)
      throw const FormatException('Kesit bağlantısının süresi dolmuş.');
    saveWebMediaBytes(response.bodyBytes, name, 'video/mp4');
  } else if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw const FormatException('İndirme açılamadı.');
  }
}

const _brand = Color(0xff2563eb);
const _storage = FlutterSecureStorage();
const _defaultApiBase =
    kIsWeb ? 'http://localhost:8085/api' : 'http://10.38.218.28:8085/api';
const _apiBase = String.fromEnvironment(
  'API_BASE_URL',
  // Tarayıcıda yerel API, fiziksel telefonda aynı Wi-Fi'daki bilgisayar kullanılır.
  defaultValue: _defaultApiBase,
);

/// Yönetici işlemleri yalnızca web yönetim panelinde yapılır. Mobil uygulama
/// müşteri kullanımına ayrılmıştır.
bool isMobileCustomer(Map<String, dynamic> user) => user['role'] == 'customer';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
  runApp(const YtKampusApp());
}

class Api {
  final http.Client _client;
  Api({http.Client? client}) : _client = client ?? http.Client();
  Future<Map<String, dynamic>> call(
    String method,
    String path, {
    Object? body,
    bool authenticated = true,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      final token =
          authenticated ? await _storage.read(key: 'access_token') : null;
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'X-YT-Kampus-Client': 'mobile',
      };
      if (token != null) headers['Authorization'] = 'Bearer $token';
      final uri = Uri.parse('$_apiBase$path');
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      ).timeout(timeout);
      final dynamic decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300)
        return {'ok': true, 'data': decoded};
      if (response.statusCode == 401)
        await _storage.delete(key: 'access_token');
      return {
        'ok': false,
        'status': response.statusCode,
        'error': decoded is Map
            ? decoded['error'] ?? 'İşlem başarısız'
            : 'İşlem başarısız',
      };
    } on TimeoutException {
      return {
        'ok': false,
        'error':
            'Sunucuya ulaşılamadı. Bağlantınızı kontrol edip tekrar deneyin.'
      };
    } on http.ClientException {
      return {
        'ok': false,
        'error': 'Sunucu bağlantısı kurulamadı. Lütfen tekrar deneyin.'
      };
    } on FormatException {
      return {'ok': false, 'error': 'Sunucudan geçerli bir yanıt alınamadı.'};
    } catch (_) {
      return {
        'ok': false,
        'error': 'İşlem tamamlanamadı. Lütfen tekrar deneyin.'
      };
    }
  }

  Future<Map<String, dynamic>> get(String path, {bool authenticated = true}) =>
      call('GET', path, authenticated: authenticated);
  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    bool authenticated = true,
    Duration timeout = const Duration(seconds: 20),
  }) =>
      call('POST', path,
          body: body, authenticated: authenticated, timeout: timeout);
  Future<Map<String, dynamic>> patch(String path, {Object? body}) =>
      call('PATCH', path, body: body);
}

final api = Api();

class YtKampusApp extends StatelessWidget {
  const YtKampusApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'YT Kampüs',
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: _brand),
          useMaterial3: true,
          fontFamily: 'Inter',
          scaffoldBackgroundColor: const Color(0xfff4f7f9),
          appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0),
          filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      fontSize: 16))),
          inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xfff8fafc),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xffe2e8f0))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xffe2e8f0)))),
        ),
        home: const SessionGate(),
      );
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});
  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final Future<Map<String, dynamic>?> _session = _load();
  Future<Map<String, dynamic>?> _load() async {
    if (await _storage.read(key: 'access_token') == null) return null;
    final result = await api.get('/auth/me');
    if (result['ok'] != true || result['data'] is! Map) return null;
    final user = Map<String, dynamic>.from(result['data']);
    if (!isMobileCustomer(user)) {
      await _storage.delete(key: 'access_token');
      return null;
    }
    return user;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
        future: _session,
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState != ConnectionState.done)
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          return WebLandingPage(user: snapshot.data);
        },
      );
}

class PublicHomePage extends StatelessWidget {
  const PublicHomePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.sports_soccer_rounded, color: _brand),
              SizedBox(width: 8),
              Text('YT Kampüs'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              ),
              child: const Text('Giriş Yap'),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                height: 440,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    color: const Color(0xff081b41),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x22081b41),
                          blurRadius: 24,
                          offset: Offset(0, 12))
                    ]),
                child: Stack(fit: StackFit.expand, children: [
                  Image.asset('assets/images/hero_logo.jpg', fit: BoxFit.cover),
                  const DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                    Color(0xf5081b41),
                    Color(0x661d4ed8),
                    Color(0xdd081b41)
                  ], begin: Alignment.topLeft, end: Alignment.bottomRight))),
                  const Positioned(
                      top: 22,
                      left: 22,
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              color: Color(0x33ffffff),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(22))),
                          child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              child: Text('SPOR VE YAŞAM MERKEZİ',
                                  style: TextStyle(
                                      color: Color(0xffdce9ff),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1))))),
                  const Positioned(
                      bottom: 26,
                      left: 24,
                      right: 24,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sahanı seç,\nmaçını planla.',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 34,
                                    height: 1.04,
                                    letterSpacing: -.8)),
                            SizedBox(height: 12),
                            Text(
                                'YT Kampüs ile uygun saatleri gör, rezervasyonunu dakikalar içinde tamamla.',
                                style: TextStyle(
                                    color: Color(0xffdce9ff),
                                    fontSize: 15,
                                    height: 1.4)),
                          ])),
                ]),
              ),
              const SizedBox(height: 26),
              const Text(
                'Hızlı ve kolay rezervasyon',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              const _PublicFeature(
                icon: Icons.calendar_month_rounded,
                title: 'Uygun saatleri incele',
                text: 'Sahaların müsaitlik durumunu anında gör.',
              ),
              const _PublicFeature(
                icon: Icons.credit_card_rounded,
                title: 'Güvenle ödeme yap',
                text: 'Online veya tesiste ödeme seçeneğini kullan.',
              ),
              const _PublicFeature(
                icon: Icons.notifications_active_rounded,
                title: 'Rezervasyonunu takip et',
                text: 'Bildirimlerle maç saatini kaçırma.',
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: _brand,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterPage()),
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Hemen Üye Ol'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                ),
                child: const Text('Hesabımla giriş yap'),
              ),
            ],
          ),
        ),
      );
}

class _PublicFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _PublicFeature({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: const Color(0xfff5f8ff),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: const Color(0xffdce9ff),
            foregroundColor: _brand,
            child: Icon(icon),
          ),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(text),
        ),
      );
}

class LegacyLoginPage extends StatefulWidget {
  const LegacyLoginPage({super.key});
  @override
  State<LegacyLoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LegacyLoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  Future<void> login() async {
    setState(() => busy = true);
    final result = await api.post(
      '/auth/login',
      authenticated: false,
      body: {'email': email.text.trim(), 'password': password.text},
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (!result['ok'] || result['data']['token'] == null)
      return _message(result['error'] ?? 'Giriş başarısız');
    final user = Map<String, dynamic>.from(result['data']['user']);
    if (!isMobileCustomer(user)) {
      return _message(
          'Yönetici girişleri yalnızca web yönetim panelinden yapılabilir.');
    }
    await _storage.write(key: 'access_token', value: result['data']['token']);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AppShell(user: user),
      ),
    );
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.sports_soccer, size: 62, color: _brand),
                    const SizedBox(height: 16),
                    const Text(
                      'YT KAMPÜS',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 27),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Spor · Sanat · Yaşam',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 38),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-posta',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: password,
                      obscureText: true,
                      onSubmitted: (_) => login(),
                      decoration: const InputDecoration(
                        labelText: 'Şifre',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: busy ? null : login,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: Text(busy ? 'Giriş yapılıyor…' : 'Giriş Yap'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterPage()),
                      ),
                      child: const Text('Hesabın yok mu? Üye ol'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class LegacyRegisterPage extends StatefulWidget {
  const LegacyRegisterPage({super.key});
  @override
  State<LegacyRegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<LegacyRegisterPage> {
  final name = TextEditingController(),
      email = TextEditingController(),
      phone = TextEditingController(),
      password = TextEditingController();
  bool busy = false;
  Future<void> register() async {
    setState(() => busy = true);
    final result = await api.post(
      '/auth/register',
      authenticated: false,
      body: {
        'full_name': name.text.trim(),
        'email': email.text.trim(),
        'phone': phone.text.trim(),
        'password': password.text,
        'kvkk_approved': true,
        'contract_approved': true,
      },
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (!result['ok'] || result['data']['token'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Kayıt yapılamadı')),
      );
      return;
    }
    await _storage.write(key: 'access_token', value: result['data']['token']);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AppShell(user: Map<String, dynamic>.from(result['data']['user'])),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Üye Ol')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Ad soyad',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-posta',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Şifre (en az 8 karakter)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Kayıtla birlikte KVKK ve üyelik sözleşmesini onaylamış olursunuz.',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : register,
              child: Text(busy ? 'Kaydediliyor…' : 'Hesap Oluştur'),
            ),
          ],
        ),
      );
}

class AppShell extends StatefulWidget {
  final Map<String, dynamic> user;
  const AppShell({super.key, required this.user});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  Future<void> logout() async {
    await api.post('/auth/logout');
    await _storage.delete(key: 'access_token');
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PublicHomePage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = widget.user['role'] == 'admin';
    final pages = admin
        ? [
            HomePage(user: widget.user),
            const ReservationsPage(),
            const AdminPage(),
            ProfilePage(user: widget.user, onLogout: logout),
          ]
        : [
            HomePage(user: widget.user),
            const ReservationsPage(),
            const NotificationsPage(),
            ProfilePage(user: widget.user, onLogout: logout),
          ];
    final labels = admin
        ? const ['Ana Sayfa', 'Rezervasyonlar', 'Yönetim', 'Hesabım']
        : const ['Ana Sayfa', 'Rezervasyonlarım', 'Bildirimler', 'Hesabım'];
    final icons = admin
        ? const [
            Icons.home_outlined,
            Icons.calendar_month_outlined,
            Icons.admin_panel_settings_outlined,
            Icons.person_outline,
          ]
        : const [
            Icons.home_outlined,
            Icons.calendar_month_outlined,
            Icons.notifications_none,
            Icons.person_outline,
          ];
    return Scaffold(
      backgroundColor: const Color(0xfff4f7fb),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 4,
        title: Row(children: [
          const Icon(Icons.sports_soccer_rounded, color: _brand),
          const SizedBox(width: 8),
          Text(labels[index],
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Bildirimler',
            onPressed: () => setState(() => index = admin ? 1 : 2),
            icon: Badge(
              isLabelVisible: !admin,
              smallSize: 8,
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 20, 18, 22),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xff0b1f49), _brand]),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      CircleAvatar(
                          backgroundColor: Colors.white,
                          child:
                              Icon(Icons.sports_soccer_rounded, color: _brand)),
                      SizedBox(width: 10),
                      Text('YT Kampüs',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900)),
                    ]),
                    const SizedBox(height: 22),
                    Text('${widget.user['full_name'] ?? 'Üye'}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                    Text(admin ? 'Yönetici hesabı' : 'Kullanıcı Paneli',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ]),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('MENÜ',
                      style: TextStyle(
                          letterSpacing: 1.2,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff8190a8)))),
            ),
            ...List.generate(
                labels.length,
                (i) => ListTile(
                      leading: Icon(icons[i],
                          color: i == index ? _brand : const Color(0xff53647d)),
                      title: Text(labels[i],
                          style: TextStyle(
                              fontWeight: i == index
                                  ? FontWeight.w800
                                  : FontWeight.w600)),
                      selected: i == index,
                      selectedTileColor: const Color(0xffeaf1ff),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      onTap: () {
                        setState(() => index = i);
                        Navigator.pop(context);
                      },
                    )),
            const Spacer(),
            const Divider(),
            ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('Ana Sayfa'),
                onTap: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const PublicHomePage()),
                    (_) => false)),
            ListTile(
                leading:
                    const Icon(Icons.logout_rounded, color: Color(0xffd64545)),
                title: const Text('Çıkış Yap'),
                onTap: logout),
          ]),
        ),
      ),
      body: SafeArea(top: false, child: pages[index]),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: const Color(0xffdce9ff),
          labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
        ),
        child: NavigationBar(
          height: 70,
          selectedIndex: index,
          onDestinationSelected: (v) => setState(() => index = v),
          destinations: List.generate(
              labels.length,
              (i) => NavigationDestination(
                  icon: Icon(icons[i]),
                  selectedIcon: Icon(icons[i], color: _brand),
                  label: labels[i])),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final Map<String, dynamic> user;
  const HomePage({super.key, required this.user});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<dynamic>> fields;
  @override
  void initState() {
    super.initState();
    fields = _fields();
  }

  Future<List<dynamic>> _fields() async {
    final r = await api.get('/fields', authenticated: false);
    return r['ok'] ? List<dynamic>.from(r['data']) : [];
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: () async => setState(() => fields = _fields()),
        child: FutureBuilder<List<dynamic>>(
          future: fields,
          builder: (context, s) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            children: [
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: const Color(0xff0b1f49),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x220b1f49),
                        blurRadius: 22,
                        offset: Offset(0, 10))
                  ],
                ),
                child: Stack(children: [
                  Positioned.fill(
                      child: Image.asset('assets/images/hero_field.jpg',
                          fit: BoxFit.cover,
                          opacity: const AlwaysStoppedAnimation(.36))),
                  Positioned.fill(
                      child: const DecoratedBox(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                    Color(0xee081b41),
                    Color(0xaa1d4ed8)
                  ], begin: Alignment.topLeft, end: Alignment.bottomRight)))),
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('KULLANICI PANELİ',
                              style: TextStyle(
                                  color: Color(0xffb9d2ff),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2)),
                          const SizedBox(height: 10),
                          Text('Merhaba,\n${widget.user['full_name'] ?? 'Üye'}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 27,
                                  height: 1.12,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          const Text(
                              'Sahanı seç, uygun saati bul ve maçını planla.',
                              style: TextStyle(
                                  color: Color(0xffdce9ff), fontSize: 14)),
                          const SizedBox(height: 18),
                          const Row(children: [
                            Icon(Icons.verified_rounded,
                                color: Color(0xffffcb58), size: 17),
                            SizedBox(width: 6),
                            Text('Kolay rezervasyon · Güvenli ödeme',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ]),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
              const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sahalar',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
                    Text('Uygun saatini seç',
                        style: TextStyle(
                            color: _brand,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ]),
              const SizedBox(height: 12),
              if (!s.hasData)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                ...s.data!.map((raw) {
                  final f = Map<String, dynamic>.from(raw);
                  final image = s.data!.indexOf(raw).isEven
                      ? 'assets/images/field_one.jpg'
                      : 'assets/images/field_two.jpg';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x110f2548),
                              blurRadius: 16,
                              offset: Offset(0, 6))
                        ]),
                    child: InkWell(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => BookingPage(field: f))),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                                height: 138,
                                width: double.infinity,
                                child: Stack(fit: StackFit.expand, children: [
                                  Image.asset(image, fit: BoxFit.cover),
                                  const DecoratedBox(
                                      decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                              colors: [
                                        Colors.transparent,
                                        Color(0x99081735)
                                      ],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter))),
                                  Positioned(
                                      left: 13,
                                      bottom: 12,
                                      child: Text(
                                          '${f['type'] ?? 'SPOR SAHASI'}',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: .7))),
                                ])),
                            Padding(
                                padding: const EdgeInsets.all(15),
                                child: Row(children: [
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text('${f['name']}',
                                            style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w900)),
                                        const SizedBox(height: 5),
                                        Text(
                                            '${NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(num.tryParse('${f['price_per_hour']}') ?? 0)}/saat',
                                            style: const TextStyle(
                                                color: Color(0xff178a48),
                                                fontWeight: FontWeight.w800)),
                                      ])),
                                  const CircleAvatar(
                                      backgroundColor: Color(0xffeaf1ff),
                                      foregroundColor: _brand,
                                      child: Icon(Icons.arrow_forward_rounded)),
                                ])),
                          ]),
                    ),
                  );
                }),
            ],
          ),
        ),
      );
}

class BookingPage extends StatefulWidget {
  final Map<String, dynamic> field;
  const BookingPage({super.key, required this.field});
  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  DateTime date = DateTime.now();
  List<dynamic> slots = [];
  bool loading = true, saving = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  String get day => DateFormat('yyyy-MM-dd').format(date);
  Future<void> _load() async {
    setState(() => loading = true);
    final r = await api.get(
      '/slots?date=$day&field_id=${widget.field['id']}',
      authenticated: false,
    );
    if (mounted)
      setState(() {
        slots = r['ok']
            ? List<dynamic>.from(r['data']['slots'])
                .map(
                  (v) => {
                    'time': '$v',
                    'busy': List<dynamic>.from(
                      r['data']['bookedSlots'],
                    ).contains(v),
                  },
                )
                .toList()
            : [];
        loading = false;
      });
  }

  Future<void> _book(String time) async {
    setState(() => saving = true);
    final r = await api.post(
      '/reservations',
      body: {
        'date': day,
        'time_slot': time,
        'field_id': widget.field['id'],
        'duration_hours': 1,
      },
    );
    if (!mounted) return;
    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          r['ok']
              ? 'Rezervasyonunuz oluşturuldu.'
              : r['error'] ?? 'İşlem yapılamadı',
        ),
      ),
    );
    if (r['ok']) {
      await _load();
    }
  }

  Future<void> _startOnlinePayment(String time) async {
    setState(() => saving = true);
    final result = await api.post(
      '/payment/checkout',
      body: {
        'date': day,
        'time_slot': time,
        'field_id': widget.field['id'],
        'duration_hours': 1,
      },
    );
    if (!mounted) return;
    setState(() => saving = false);
    if (!result['ok']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Ödeme başlatılamadı')),
      );
      return;
    }
    final data = Map<String, dynamic>.from(result['data']);
    final intentId = '${data['payment_intent_id'] ?? ''}'.trim();
    final checkoutHtml = '${data['checkoutFormContent'] ?? ''}'.trim();
    if (intentId.isEmpty || checkoutHtml.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Ödeme oturumu eksik oluşturuldu. Lütfen tekrar deneyin.')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentPage(
          html: checkoutHtml,
          intentId: intentId,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _choosePayment(String time) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.field['name']} · $day · $time',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _startOnlinePayment(time);
                },
                icon: const Icon(Icons.credit_card),
                label: const Text('Online ödeme ile devam et'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _book(time);
                },
                icon: const Icon(Icons.storefront_outlined),
                label: const Text('Tesiste ödeme ile rezervasyon yap'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('${widget.field['name']}')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('d MMMM y, EEEE', 'tr_TR').format(date),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() {
                    date = date.subtract(const Duration(days: 1));
                    _load();
                  }),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  onPressed: () => setState(() {
                    date = date.add(const Duration(days: 1));
                    _load();
                  }),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: slots.map((item) {
                  final busy = item['busy'] == true;
                  return FilledButton.tonal(
                    onPressed: busy || saving
                        ? null
                        : () => _choosePayment(item['time']),
                    style: FilledButton.styleFrom(
                      backgroundColor: busy ? Colors.red.shade50 : null,
                      foregroundColor: busy ? Colors.red.shade700 : null,
                    ),
                    child: Text(
                      busy
                          ? '${item['time']} · Dolu'
                          : '${item['time']} · Müsait',
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      );
}

class ReservationsPage extends StatelessWidget {
  const ReservationsPage({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: api.get('/reservations/my'),
        builder: (context, snapshot) {
          final list = snapshot.hasData && snapshot.data!['ok']
              ? List<dynamic>.from(snapshot.data!['data'])
              : <dynamic>[];
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Text(
                'Rezervasyonlarım',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              if (!snapshot.hasData)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Henüz rezervasyonunuz yok.'),
                )
              else
                ...list.map(
                  (r) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.sports_soccer, color: _brand),
                      title: Text('${r['field_name'] ?? 'Saha'}'),
                      subtitle: Text('${r['date']} · ${r['time_slot']}'),
                      trailing: Text(
                        '${r['status']}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: api.get('/notifications'),
        builder: (context, snapshot) {
          final list = snapshot.hasData && snapshot.data!['ok']
              ? List<dynamic>.from(snapshot.data!['data'])
              : <dynamic>[];
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Text(
                'Bildirimler',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ...list.map(
                (n) => Card(
                  color: n['is_read'] == true ? null : const Color(0xffeef5ff),
                  child: ListTile(
                    leading: const Icon(
                      Icons.notifications_active_outlined,
                      color: _brand,
                    ),
                    title: Text('${n['title']}'),
                    subtitle: Text('${n['message']}'),
                  ),
                ),
              ),
            ],
          );
        },
      );
}

class ProfilePage extends StatelessWidget {
  final Map<String, dynamic> user;
  final Future<void> Function() onLogout;
  const ProfilePage({super.key, required this.user, required this.onLogout});
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: _brand,
            child: Text(
              '${user['full_name'] ?? 'U'}'[0].toUpperCase(),
              style: const TextStyle(fontSize: 28, color: Colors.white),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${user['full_name']}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text('${user['email']}',
              style: const TextStyle(color: Colors.blueGrey)),
          const SizedBox(height: 25),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Güvenli çıkış'),
            onTap: onLogout,
          ),
        ],
      );
}

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Yönetim'),
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Özet'),
                Tab(text: 'Rezervasyon'),
                Tab(text: 'Kullanıcılar'),
                Tab(text: 'Sahalar'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              _AdminSummary(),
              _AdminReservations(),
              _AdminUsers(),
              _AdminFields(),
            ],
          ),
        ),
      );
}

class _AdminSummary extends StatelessWidget {
  const _AdminSummary();
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: api.get('/admin/stats'),
        builder: (context, snapshot) {
          final data = snapshot.hasData && snapshot.data!['ok']
              ? Map<String, dynamic>.from(snapshot.data!['data'])
              : <String, dynamic>{};
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _Stat(
                'Toplam rezervasyon',
                '${data['total_reservations'] ?? '—'}',
                Icons.event_available,
              ),
              _Stat(
                'Bugünkü rezervasyon',
                '${data['today_reservations'] ?? '—'}',
                Icons.today,
              ),
              _Stat(
                'Kayıtlı üye',
                '${data['total_customers'] ?? '—'}',
                Icons.people,
              ),
              _Stat(
                'Toplam gelir',
                NumberFormat.currency(
                  locale: 'tr_TR',
                  symbol: '₺',
                ).format(num.tryParse('${data['total_revenue']}') ?? 0),
                Icons.payments_outlined,
              ),
            ],
          );
        },
      );
}

class _AdminReservations extends StatefulWidget {
  const _AdminReservations();
  @override
  State<_AdminReservations> createState() => _AdminReservationsState();
}

class _AdminReservationsState extends State<_AdminReservations> {
  late Future<Map<String, dynamic>> future;
  @override
  void initState() {
    super.initState();
    future = api.get('/admin/reservations');
  }

  void reload() => setState(() => future = api.get('/admin/reservations'));
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snapshot) {
          final rows = snapshot.hasData && snapshot.data!['ok']
              ? List<dynamic>.from(snapshot.data!['data'])
              : <dynamic>[];
          return RefreshIndicator(
            onRefresh: () async => reload(),
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                if (!snapshot.hasData)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  ...rows.map(
                    (r) => Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.event_note_outlined,
                          color: _brand,
                        ),
                        title: Text(
                          '${r['full_name'] ?? 'Kullanıcı'} · ${r['field_name'] ?? 'Saha'}',
                        ),
                        subtitle: Text(
                          '${r['date']} · ${r['time_slot']}\n${r['status']} · ${r['payment_status']}',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (status) async {
                            await api.patch(
                              '/admin/reservations/${r['id']}',
                              body: {'status': status},
                            );
                            reload();
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'confirmed',
                              child: Text('Onayla'),
                            ),
                            PopupMenuItem(
                              value: 'completed',
                              child: Text('Tamamlandı'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
}

class _AdminUsers extends StatefulWidget {
  const _AdminUsers();
  @override
  State<_AdminUsers> createState() => _AdminUsersState();
}

class _AdminUsersState extends State<_AdminUsers> {
  late Future<Map<String, dynamic>> future;
  @override
  void initState() {
    super.initState();
    future = api.get('/admin/users');
  }

  void reload() => setState(() => future = api.get('/admin/users'));
  Future<void> create() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _CreateUserDialog(),
    );
    if (result == null) return;
    final response = await api.post('/admin/users', body: result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response['ok']
              ? 'Kullanıcı oluşturuldu'
              : response['error'] ?? 'Kullanıcı oluşturulamadı',
        ),
      ),
    );
    if (response['ok']) reload();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, s) {
          final users = s.hasData && s.data!['ok']
              ? List<dynamic>.from(s.data!['data'])
              : [];
          return Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              onPressed: create,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Kullanıcı oluştur'),
            ),
            body: RefreshIndicator(
              onRefresh: () async => reload(),
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  if (!s.hasData)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    ...users.map(
                      (u) => Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _brand,
                            child: Text(
                              '${u['full_name']}'[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text('${u['full_name']}'),
                          subtitle: Text(
                            '${u['email']} · ${u['role'] == 'admin' ? 'Yönetici' : 'Üye'}',
                          ),
                          trailing: Switch(
                            value:
                                u['is_active'] == true || u['is_active'] == 1,
                            onChanged: (_) async {
                              await api.patch('/admin/users/${u['id']}/toggle');
                              reload();
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
}

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();
  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final name = TextEditingController(),
      email = TextEditingController(),
      phone = TextEditingController(),
      password = TextEditingController();
  String role = 'customer';
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Yeni kullanıcı'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Ad soyad'),
              ),
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'E-posta'),
              ),
              TextField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Telefon'),
              ),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Geçici şifre'),
              ),
              DropdownButtonFormField(
                value: role,
                items: const [
                  DropdownMenuItem(value: 'customer', child: Text('Üye')),
                  DropdownMenuItem(value: 'admin', child: Text('Yönetici')),
                ],
                onChanged: (v) => setState(() => role = v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'full_name': name.text.trim(),
              'email': email.text.trim(),
              'phone': phone.text.trim(),
              'password': password.text,
              'role': role,
            }),
            child: const Text('Oluştur'),
          ),
        ],
      );
}

class _AdminFields extends StatefulWidget {
  const _AdminFields();
  @override
  State<_AdminFields> createState() => _AdminFieldsState();
}

class _AdminFieldsState extends State<_AdminFields> {
  late Future<Map<String, dynamic>> future;
  @override
  void initState() {
    super.initState();
    future = api.get('/admin/fields');
  }

  void reload() => setState(() => future = api.get('/admin/fields'));
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snapshot) {
          final fields = snapshot.hasData && snapshot.data!['ok']
              ? List<dynamic>.from(snapshot.data!['data']['fields'])
              : <dynamic>[];
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              if (!snapshot.hasData)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                ...fields.map(
                  (f) => Card(
                    child: ListTile(
                      leading:
                          const Icon(Icons.stadium_outlined, color: _brand),
                      title: Text('${f['name']}'),
                      subtitle: Text('Saatlik ücret: ₺${f['price_per_hour']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          final controller = TextEditingController(
                            text: '${f['price_per_hour']}',
                          );
                          final price = await showDialog<String>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text('${f['name']}'),
                              content: TextField(
                                controller: controller,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Saatlik ücret',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Vazgeç'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(context, controller.text),
                                  child: const Text('Kaydet'),
                                ),
                              ],
                            ),
                          );
                          if (price != null) {
                            await api.patch(
                              '/admin/fields/${f['id']}',
                              body: {'price_per_hour': num.tryParse(price)},
                            );
                            reload();
                          }
                        },
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

class _Stat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _Stat(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon, color: _brand),
          title: Text(label),
          trailing: Text(
            value,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
        ),
      );
}

class PaymentPage extends StatefulWidget {
  final String html;
  final String intentId;
  const PaymentPage({super.key, required this.html, required this.intentId});
  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  WebViewController? controller;
  Widget? _webCheckout;
  Timer? _poll;
  bool checking = false;
  bool _returningFromPayment = false;

  /// Iyzico, 3D Secure işlemi bittiğinde formu bu adrese gönderir. Bu sayfa
  /// uygulamanın WebView'ında açılmadan yakalanır; böylece kullanıcı tekrar
  /// web sitesine taşınmadan sonucu doğrudan uygulamada görür.
  bool _isPaymentCallback(String url) {
    final candidate = Uri.tryParse(url);
    // Callback can arrive through a dedicated HTTPS gateway rather than the
    // application's local API address. The payment is never trusted from this
    // navigation alone: checkPayment validates its status on the API with the
    // signed-in user's payment-intent ID.
    return candidate != null && candidate.path == '/api/payment/callback';
  }

  void _onPaymentCallback() {
    if (!mounted || _returningFromPayment) return;
    setState(() => _returningFromPayment = true);
    checkPayment(announce: false);
  }

  Future<void> _showPaymentConfirmed() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.verified_rounded, color: Color(0xff16a34a), size: 48),
        title: const Text('Ödemeniz onaylandı'),
        content: const Text(
          'Ödemeniz başarıyla alındı. Rezervasyonunuz oluşturuldu ve Rezervasyonlarım bölümünde görüntülenebilir.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Rezervasyonlarıma git'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  String _checkoutDocument(String baseUrl) {
    final escapedBase =
        baseUrl.replaceAll('&', '&amp;').replaceAll('"', '&quot;');
    return '<!doctype html><html lang="tr"><head>'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<base href="$escapedBase">'
        '<style>'
        'html,body{margin:0;min-height:100%;background:#fff;overflow-y:auto;-webkit-overflow-scrolling:touch}'
        '#iyzipay-checkout-form{max-width:100%;min-height:1100px}'
        '#iyzipay-checkout-form iframe{display:block;width:100%!important;min-height:1100px!important;height:1100px!important;border:0}'
        '</style>'
        '</head><body>${widget.html}</body></html>';
  }

  @override
  void initState() {
    super.initState();
    final baseUrl = Uri.parse(_apiBase).resolve('/').toString();
    if (kIsWeb) {
      _webCheckout = buildWebCheckout(widget.html, baseUrl);
    } else {
      controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onPageStarted: (url) {
            if (_isPaymentCallback(url)) _onPaymentCallback();
          },
          onNavigationRequest: (request) {
            if (_isPaymentCallback(request.url)) {
              _onPaymentCallback();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ))
        ..loadHtmlString(_checkoutDocument(baseUrl), baseUrl: baseUrl);
    }
    if (widget.intentId.isNotEmpty) {
      _poll = Timer.periodic(
          const Duration(seconds: 6), (_) => checkPayment(announce: false));
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> checkPayment({bool announce = true}) async {
    if (checking || !mounted) return;
    setState(() => checking = true);
    final result = await api.get('/payment/intents/${widget.intentId}/status');
    if (!mounted) return;
    setState(() => checking = false);
    final status = result['ok'] ? result['data']['status'] : null;
    if (status == 'paid') {
      _poll?.cancel();
      await _showPaymentConfirmed();
      return;
    }
    if (status == 'failed' || status == 'expired') {
      _poll?.cancel();
      if (_returningFromPayment) setState(() => _returningFromPayment = false);
    }
    if (!announce) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status == 'pending'
              ? 'Ödeme henüz tamamlanmadı.'
              : result['error'] ?? 'Ödeme doğrulanamadı.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Güvenli Ödeme'),
        ),
        body: Stack(
          children: [
            _webCheckout ?? WebViewWidget(controller: controller!),
            if (_returningFromPayment)
              const ColoredBox(
                color: Color(0xfaffffff),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Ödemeniz uygulama içinde doğrulanıyor…'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}

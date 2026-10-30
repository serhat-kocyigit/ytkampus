part of 'main.dart';

// The public website rebuilt as Flutter widgets. Images and field records stay
// connected to the same API and image store as the public web page.
class WebLandingPage extends StatefulWidget {
  const WebLandingPage({super.key, this.user});
  final Map<String, dynamic>? user;

  @override
  State<WebLandingPage> createState() => _WebLandingPageState();
}

const _landingInk = Color(0xff0f172a);
const _landingText = Color(0xff334155);
const _landingMuted = Color(0xff64748b);
const _landingBlue = Color(0xff2563eb);
const _landingBorder = Color(0xffe2e8f0);
const _landingBackground = Color(0xfff4f7f9);

class _WebLandingPageState extends State<WebLandingPage> {
  final _scaffold = GlobalKey<ScaffoldState>();
  final _scroll = ScrollController();
  final _aboutKey = GlobalKey();
  final _academiesKey = GlobalKey();
  final _fieldsKey = GlobalKey();
  final _applicationsKey = GlobalKey();
  final _galleryKey = GlobalKey();
  final _contactKey = GlobalKey();
  Map<String, dynamic> _siteImages = {};
  List<Map<String, dynamic>> _fields = [];
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadImages();
  }

  void _onScroll() {
    final value = _scroll.offset > 20;
    if (value != _scrolled && mounted) setState(() => _scrolled = value);
  }

  Future<void> _loadImages() async {
    final results = await Future.wait([
      api
          .get('/fields', authenticated: false)
          .catchError((Object error) => <String, dynamic>{'ok': false}),
      api
          .get('/site-images', authenticated: false)
          .catchError((Object error) => <String, dynamic>{'ok': false}),
    ]);
    if (!mounted) return;
    setState(() {
      if (results[0]['ok'] == true && results[0]['data'] is List) {
        _fields = (results[0]['data'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      if (results[1]['ok'] == true && results[1]['data'] is Map) {
        _siteImages = Map<String, dynamic>.from(results[1]['data'] as Map);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String _image(String key, String fallback) =>
      _landingUrl((_siteImages[key] ?? fallback).toString());

  String? get _siteLogo {
    final value = _siteImages['site_logo']?.toString().trim() ?? '';
    return value.isEmpty ? null : _landingUrl(value);
  }

  String _fieldImage(_LandingField card) {
    for (final field in _fields) {
      if (field['id'].toString() == card.id.toString() &&
          field['homepage_image_url'] != null &&
          field['homepage_image_url'].toString().isNotEmpty) {
        return _landingUrl(field['homepage_image_url'].toString());
      }
    }
    return _landingUrl('/assets/images/${card.image}.jpg');
  }

  void _to(GlobalKey key) {
    if (_scaffold.currentState?.isDrawerOpen == true) Navigator.pop(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || key.currentContext == null) return;
      Scrollable.ensureVisible(key.currentContext!,
          duration: const Duration(milliseconds: 480),
          curve: Curves.easeInOut,
          alignment: .11);
    });
  }

  void _login({bool register = false}) {
    if (_scaffold.currentState?.isDrawerOpen == true) Navigator.pop(context);
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) =>
                register ? const RegisterPage() : const LoginPage()));
  }

  void _panel() {
    if (_scaffold.currentState?.isDrawerOpen == true) Navigator.pop(context);
    if (widget.user == null) {
      _login(register: true);
    } else {
      Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => WebUserPanel(user: widget.user!)));
    }
  }

  void _book(_LandingField card) {
    final selected = _fields.firstWhere(
      (field) => field['id'].toString() == card.id.toString(),
      orElse: () => <String, dynamic>{'id': card.id, 'name': card.title},
    );
    if (widget.user == null) {
      Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => WebAuthPage(initialField: selected)));
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => WebUserPanel(user: widget.user!, initialPage: 'booking', initialField: selected)));
  }

  void _videos() {
    if (_scaffold.currentState?.isDrawerOpen == true) Navigator.pop(context);
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => WebVideosPage(user: widget.user)));
  }

  void _lightbox(String url) {
    showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Görseli kapat',
      barrierDismissible: true,
      barrierColor: const Color(0xf20f172a),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => SafeArea(
        child: Stack(children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Center(
                  child: Padding(
                padding: const EdgeInsets.all(20),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _LandingImage(url: url, fit: BoxFit.contain),
                  ),
                ),
              )),
            ),
          ),
          Positioned(
              top: 16,
              right: 18,
              child: IconButton(
                tooltip: 'Kapat',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 34, color: Colors.white),
              )),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width <= 600;
    return Scaffold(
      key: _scaffold,
      backgroundColor: _landingBackground,
      drawerScrimColor: const Color(0x66000000),
      drawer: _drawer(width),
      body: DefaultTextStyle.merge(
          style: const TextStyle(letterSpacing: 0),
          child: SafeArea(
            child: Stack(children: [
              const Positioned.fill(
                  child: CustomPaint(painter: _LandingGrid())),
              SingleChildScrollView(
                controller: _scroll,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _hero(width),
                      if (width > 900) _featuresStrip(),
                      _videoSection(mobile),
                      _aboutSection(mobile),
                      _academiesSection(width),
                      _gallerySection(mobile),
                      _contactSection(mobile),
                      _footer(mobile),
                    ]),
              ),
              Positioned(top: 0, left: 0, right: 0, child: _header(mobile)),
            ]),
          )),
    );
  }

  Widget _header(bool mobile) => AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: _scrolled ? (mobile ? 64 : 70) : (mobile ? 72 : 86),
        padding: EdgeInsets.symmetric(horizontal: mobile ? 14 : 24),
        decoration: BoxDecoration(
          color: const Color(0xf5ffffff),
          border: const Border(bottom: BorderSide(color: Color(0x0d000000))),
          boxShadow: _scrolled
              ? const [
                  BoxShadow(
                      color: Color(0x0a0f172a),
                      blurRadius: 8,
                      offset: Offset(0, 2))
                ]
              : [],
        ),
        child: Row(children: [
          InkWell(
              onTap: () => _scroll.animateTo(0,
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeInOut),
              child: _LandingLogo(small: mobile, logoUrl: _siteLogo)),
          const Spacer(),
          if (!mobile) ...[
            if (widget.user != null)
              _LandingButton('Panele Git', onTap: _panel)
            else ...[
              _LandingButton('Giriş Yap', secondary: true, onTap: _login),
              const SizedBox(width: 12),
              _LandingButton('Üye Ol', onTap: () => _login(register: true)),
            ],
            const SizedBox(width: 12),
          ],
          SizedBox(
            width: mobile ? 42 : 44,
            height: mobile ? 42 : 44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _landingBorder)),
              child: IconButton(
                tooltip: 'Menüyü aç',
                padding: EdgeInsets.zero,
                onPressed: () => _scaffold.currentState?.openDrawer(),
                icon: const Icon(Icons.menu, size: 22, color: _landingInk),
              ),
            ),
          ),
        ]),
      );

  Widget _drawer(double width) => Drawer(
        width: width * .88 < 330 ? width * .88 : 330,
        shape: const RoundedRectangleBorder(),
        backgroundColor: Colors.white,
        child: Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.white, Color(0xfff8fbff)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter)),
          child: SafeArea(
              child: Stack(children: [
            const Positioned(
                top: 34,
                left: 24,
                child: Text('MENÜ',
                    style: TextStyle(
                        fontSize: 13,
                        color: _landingMuted,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5))),
            Positioned(
                top: 24,
                right: 20,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: const Color(0xfff1f5f9),
                      borderRadius: BorderRadius.circular(12)),
                  child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Menüyü kapat',
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.close,
                          size: 23, color: _landingInk)),
                )),
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 110, 16, 20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _drawerLink('🎥 Maç Videoları', _videos, primary: true),
                      _drawerLink('🏟️ Sahalar', () => _to(_fieldsKey)),
                      _drawerLink('✨ Hakkımızda', () => _to(_aboutKey)),
                      _drawerLink('🎓 Akademiler', () => _to(_academiesKey)),
                      _drawerLink('🖼️ Galeri', () => _to(_galleryKey)),
                      _drawerLink('✉️ İletişim', () => _to(_contactKey)),
                      const Spacer(),
                      const Divider(color: _landingBorder, height: 1),
                      const SizedBox(height: 22),
                      if (widget.user != null)
                        _LandingButton('Panele Git', onTap: _panel)
                      else
                        Row(children: [
                          Expanded(
                              child: _LandingButton('Giriş Yap',
                                  secondary: true,
                                  fontSize: 14,
                                  onTap: _login)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _LandingButton('Üye Ol',
                                  fontSize: 14,
                                  onTap: () => _login(register: true))),
                        ]),
                    ])),
          ])),
        ),
      );

  Widget _drawerLink(String text, VoidCallback onTap, {bool primary = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: InkWell(
            onTap: () {
              if (primary && _scaffold.currentState?.isDrawerOpen == true) {
                Navigator.pop(context);
              }
              onTap();
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Text(text,
                    style: TextStyle(
                        fontSize: 15,
                        height: 1.7,
                        fontWeight: primary ? FontWeight.w800 : FontWeight.w600,
                        color:
                            primary ? const Color(0xff1d4ed8) : _landingText))),
          ));

  Widget _hero(double width) {
    final mobile = width <= 600;
    final narrow = width <= 480;
    final content =
        Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        margin: const EdgeInsets.only(bottom: 32),
        decoration: BoxDecoration(
            color: const Color(0x262563eb),
            border: Border.all(color: const Color(0x332563eb)),
            borderRadius: BorderRadius.circular(50)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _landingBlue,
                  boxShadow: [BoxShadow(color: _landingBlue, blurRadius: 10)])),
          const SizedBox(width: 10),
          const Flexible(
              child: Text("KAYSERİ'NİN SPOR VE YAŞAM KAMPÜSÜ",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Color(0xff1d4ed8),
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1))),
        ]),
      ),
      Text('Her sahada',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: mobile ? 42 : 72,
              height: 1.05,
              color: _landingInk,
              fontWeight: FontWeight.w900,
              letterSpacing: mobile ? -1.7 : -2.5)),
      _LandingGradientText('anını yaşa.',
          fontSize: mobile ? 42 : 72,
          height: 1.05,
          letterSpacing: mobile ? -1.7 : -2.5),
      const SizedBox(height: 28),
      ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
              'INTER Academy Türkiye Kayseri; futbol akademisinden tenis, voleybol ve basketbola uzanan modern spor alanlarıyla, maçlarınızı da tek noktada izleyebileceğiniz yeni nesil bir kampüs deneyimi sunar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: mobile ? 16 : 20,
                  height: 1.6,
                  color: _landingText,
                  fontWeight: FontWeight.w400))),
      SizedBox(height: mobile ? 30 : 48),
      SizedBox(
          width: double.infinity,
          child: Wrap(
              spacing: mobile ? 7 : 10,
              runSpacing: mobile ? 7 : 10,
              children: [
                for (final label in const [
                  'Oyun burada başlar.',
                  'Her yaşa, her hedefe alan aç.',
                  'Sahada kal, anını kaydet.'
                ])
                  Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: mobile ? 10 : 12,
                          vertical: mobile ? 7 : 8),
                      decoration: BoxDecoration(
                          color: const Color(0xbfffffff),
                          border: Border.all(color: const Color(0x262563eb)),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x0a0f172a),
                                blurRadius: 16,
                                offset: Offset(0, 6))
                          ]),
                      child: Text.rich(
                          TextSpan(children: [
                            const TextSpan(
                                text: '✦  ',
                                style: TextStyle(color: Color(0xfff59e0b))),
                            TextSpan(text: label),
                          ]),
                          style: TextStyle(
                              color: const Color(0xff1e3a8a),
                              letterSpacing: 0,
                              fontSize: mobile ? 11 : 13,
                              fontWeight: FontWeight.w700))),
              ])),
      SizedBox(height: mobile ? 22 : 26),
      if (narrow)
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _LandingButton(
              widget.user == null ? 'Kayıt Ol & Rezervasyon' : 'Panele Git',
              large: true,
              onTap: _panel),
          const SizedBox(height: 16),
          _LandingButton('Maç Videolarını İzle',
              large: true, secondary: true, onTap: _videos),
        ])
      else
        Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              _LandingButton(
                  widget.user == null ? 'Kayıt Ol & Rezervasyon' : 'Panele Git',
                  large: true,
                  onTap: _panel),
              _LandingButton('Maç Videolarını İzle',
                  large: true, secondary: true, onTap: _videos),
            ]),
      Container(
          width: double.infinity,
          margin: EdgeInsets.only(top: mobile ? 38 : 60),
          padding: EdgeInsets.only(top: mobile ? 26 : 40),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _landingBorder))),
          child: narrow
              ? const Column(children: [
                  _LandingStat('5+', 'FARKLI BRANŞ'),
                  SizedBox(height: 20),
                  _LandingStat('1.000+', 'AKTİF ÖĞRENCİ'),
                  SizedBox(height: 20),
                  _LandingStat('Uzman', 'EĞİTMEN KADROSU'),
                ])
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                      _LandingStat('5+', 'FARKLI BRANŞ'),
                      _LandingStat('1.000+', 'AKTİF ÖĞRENCİ'),
                      _LandingStat('Uzman', 'EĞİTMEN KADROSU'),
                    ])),
      Container(
          margin: const EdgeInsets.only(top: 22),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: const Color(0xb3ffffff),
              border: Border.all(color: const Color(0x1f2563eb)),
              borderRadius: BorderRadius.circular(10)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            DecoratedBox(
                decoration: BoxDecoration(
                    color: Color(0xff22c55e), shape: BoxShape.circle),
                child: SizedBox(width: 8, height: 8)),
            SizedBox(width: 8),
            Flexible(
                child: Text('Rezervasyon ve maç videoları tek merkezde',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xff526783),
                        fontWeight: FontWeight.w700))),
          ])),
    ]);
    final visual = _heroVisual(mobile);
    return Stack(children: [
      Positioned(
        top: 90,
        right: width * .03,
        width: 420,
        height: 420,
        child: const IgnorePointer(child: _LandingOrbit()),
      ),
      Positioned(
        top: mobile ? 40 : -170,
        right: mobile ? -250 : -180,
        width: mobile ? 430 : 760,
        height: mobile ? 430 : 760,
        child: const IgnorePointer(
            child: DecoratedBox(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      Color(0x2e2563eb),
                      Color(0x122563eb),
                      Color(0x002563eb)
                    ], stops: [
                      0,
                      .42,
                      .7
                    ])))),
      ),
      Padding(
          padding: EdgeInsets.fromLTRB(mobile ? 18 : 60, mobile ? 108 : 118,
              mobile ? 18 : 60, mobile ? 48 : 54),
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1350),
                  child: width > 1200
                      ? Row(children: [
                          Expanded(flex: 11, child: content),
                          const SizedBox(width: 60),
                          Expanded(flex: 9, child: visual)
                        ])
                      : Column(children: [
                          content,
                          const SizedBox(height: 40),
                          visual
                        ])))),
    ]);
  }

  Widget _heroVisual(bool mobile) {
    final heroImage = _image('hero_image', '/assets/images/1.jpg');
    final logoImage =
        _image('academy_logo', '/assets/images/inter-academy-logo.webp');
    return Stack(clipBehavior: Clip.none, children: [
      Container(
          padding: EdgeInsets.all(mobile ? 8 : 12),
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _landingBorder),
              borderRadius: BorderRadius.circular(mobile ? 22 : 36),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0f0f172a),
                    blurRadius: 30,
                    offset: Offset(0, 10))
              ]),
          child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                  height: mobile ? 350 : 500,
                  width: double.infinity,
                  child: Stack(fit: StackFit.expand, children: [
                    GestureDetector(
                        onTap: () => _lightbox(heroImage),
                        child: _LandingImage(url: heroImage)),
                    const IgnorePointer(
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                          Color(0xb8031130),
                          Color(0x3d081b41),
                          Color(0x73194ccd)
                        ])))),
                    Positioned(
                        top: mobile ? 48 : 132,
                        left: 0,
                        right: 0,
                        child: Center(
                            child: GestureDetector(
                                onTap: () => _lightbox(logoImage),
                                child: Container(
                                  width: mobile ? 138 : 172,
                                  height: mobile ? 138 : 172,
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0x6b071535),
                                      border: Border.all(
                                          color: const Color(0xd1ffffff),
                                          width: 2),
                                      boxShadow: const [
                                        BoxShadow(
                                            color: Color(0x4d000000),
                                            blurRadius: 48,
                                            offset: Offset(0, 18))
                                      ]),
                                  child: ClipOval(
                                      child: _LandingImage(url: logoImage)),
                                )))),
                    Positioned(
                        left: mobile ? 18 : 32,
                        right: mobile ? 18 : 32,
                        bottom: mobile ? 18 : 32,
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 17, vertical: 15),
                            decoration: BoxDecoration(
                                color: const Color(0x8a03102b),
                                border:
                                    Border.all(color: const Color(0x40ffffff)),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color(0x2e000000),
                                      blurRadius: 30,
                                      offset: Offset(0, 10))
                                ]),
                            child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('INTER Academy Türkiye Kayseri',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          letterSpacing: -.2,
                                          fontWeight: FontWeight.w700)),
                                  SizedBox(height: 7),
                                  Text(
                                      'Futbolun enerjisi, eğitimin disiplini ve sahadaki gelişim bir arada.',
                                      style: TextStyle(
                                          color: Color(0xffe2e8f0),
                                          fontSize: 13,
                                          height: 1.45)),
                                ]))),
                  ])))),
      Positioned(
          top: mobile ? -11 : -20,
          right: mobile ? -6 : -14,
          child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: mobile ? 10 : 13, vertical: mobile ? 8 : 10),
              decoration: BoxDecoration(
                  color: const Color(0xe6ffffff),
                  border: Border.all(color: const Color(0xb3ffffff)),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x240f172a),
                        blurRadius: 30,
                        offset: Offset(0, 14))
                  ]),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('⚡', style: TextStyle(fontSize: mobile ? 14 : 17)),
                const SizedBox(width: 8),
                Text('Yeni nesil\nspor deneyimi',
                    style: TextStyle(
                        color: _landingInk,
                        fontSize: mobile ? 10 : 12,
                        fontWeight: FontWeight.w800)),
              ]))),
    ]);
  }

  Widget _featuresStrip() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      decoration: const BoxDecoration(
          color: Colors.white,
          border:
              Border.symmetric(horizontal: BorderSide(color: _landingBorder))),
      child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 40,
          runSpacing: 40,
          children: [
            for (final item in const [
              '⚽  Futbol Akademisi & Saha',
              '🎾  Tenis Kortu & Dersleri',
              '🏐  Voleybol Sahası',
              '🏀  Basketbol Sahası',
              '🎵  Müzik Stüdyosu',
              '🎨  Sanat Merkezi',
              '💃  Dans Okulu',
              '🏓  Padel Kortu',
              '🏊  Havuz',
              '🎥  Tüm Sahalardan Maç Videoları'
            ])
              Text(item,
                  style: const TextStyle(
                      fontSize: 16,
                      color: _landingText,
                      fontWeight: FontWeight.w600))
          ]));

  Widget _videoSection(bool mobile) => Padding(
      padding: EdgeInsets.fromLTRB(mobile ? 18 : 60, 100, mobile ? 18 : 60, 80),
      child: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1250),
              child: Column(children: [
                Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                        horizontal: mobile ? 24 : 48,
                        vertical: mobile ? 30 : 48),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xff0b1f49), Color(0xff1d4ed8)]),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x381d4ed8),
                              blurRadius: 44,
                              offset: Offset(0, 22))
                        ]),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _LandingLabel('MAÇ VİDEOLARI',
                              color: Color(0xffbfdbfe)),
                          const SizedBox(height: 20),
                          Text('Sadece futbol değil,\ntüm sahalar tek ekranda.',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: mobile ? 31 : 42,
                                  height: 1.1,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.5)),
                          const SizedBox(height: 16),
                          const Text(
                              'Rezervasyon yaptığınız futbol, tenis, voleybol ve basketbol sahalarının kayıtlarına tarih, saat ve saha seçerek güvenle ulaşın. Önemli anları kesit olarak kaydedin.',
                              style: TextStyle(
                                  color: Color(0xffdbeafe),
                                  fontSize: 16,
                                  height: 1.7)),
                          const SizedBox(height: 24),
                          Row(children: [
                            const Text('▶',
                                style: TextStyle(
                                    fontSize: 38, color: Colors.white)),
                            const SizedBox(width: 14),
                            _LandingButton('Videolara Git',
                                white: true, onTap: _videos)
                          ]),
                        ])),
                const SizedBox(height: 18),
                for (final item in const [
                  (
                    '⚡ Enerjini sahaya taşı',
                    'Günün temposundan çık, kendi oyununa dön.'
                  ),
                  (
                    '🤝 Birlikte daha güçlüyüz',
                    'Takımınla buluş, antrenmanınla geliş.'
                  ),
                  (
                    '🎬 Anların kaybolmasın',
                    'Maç videolarına eriş, en güzel kesitlerini sakla.'
                  ),
                ])
                  Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(mobile ? 16 : 20),
                          decoration: BoxDecoration(
                              color: const Color(0xbdffffff),
                              border: Border.all(color: _landingBorder),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x0a0f172a),
                                    blurRadius: 8,
                                    offset: Offset(0, 2))
                              ]),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.$1,
                                    style: const TextStyle(
                                        color: _landingInk,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text(item.$2,
                                    style: const TextStyle(
                                        color: _landingMuted,
                                        fontSize: 13,
                                        height: 1.5)),
                              ]))),
              ]))));

  Widget _aboutSection(bool mobile) {
    final url = _image('about_image', '/assets/images/2.jpg');
    return Padding(
        key: _aboutKey,
        padding: EdgeInsets.symmetric(
            horizontal: mobile ? 18 : 60, vertical: mobile ? 72 : 140),
        child: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1250),
                child: Column(children: [
                  const _LandingLabel('YT KAMPÜS'),
                  const SizedBox(height: 20),
                  _LandingHeading(
                      'Sadece bir tesis değil, ', 'yeni bir yaşam stili.',
                      mobile: mobile),
                  const SizedBox(height: 24),
                  const Text('"Spor ve Sanatla Sağlıklı Bir Yaşam"',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Color(0xff1d4ed8),
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.5)),
                  const SizedBox(height: 20),
                  ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Text(
                          "Spor ve sanatın iyileştirici gücünü kusursuz bir mimaride bir araya getiren YT Kampüs'te; çocuklar, gençler ve yetişkinler için özenle tasarlanmış eğitim programları sunuyoruz.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: _landingText,
                              fontSize: mobile ? 16 : 18,
                              height: 1.8))),
                  const SizedBox(height: 40),
                  Container(
                      height: 450,
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(36),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x0f0f172a),
                                blurRadius: 30,
                                offset: Offset(0, 10))
                          ]),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: GestureDetector(
                              onTap: () => _lightbox(url),
                              child: _LandingImage(url: url)))),
                ]))));
  }

  Widget _academiesSection(double width) {
    final mobile = width <= 600;
    return Padding(
        key: _academiesKey,
        padding: EdgeInsets.fromLTRB(
            mobile ? 18 : 60, 0, mobile ? 18 : 60, mobile ? 72 : 140),
        child: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1300),
                child: Column(children: [
                  const _LandingLabel('YT KAMPÜS BRANŞLARI'),
                  const SizedBox(height: 20),
                  _LandingHeading('Size uygun alanı ', 'keşfedin',
                      mobile: mobile),
                  const SizedBox(height: 24),
                  ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Text(
                          'Saha rezervasyonunuzu online oluşturun; akademi ve eğitim başvuruları için doğrudan WhatsApp’tan bize ulaşın.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: mobile ? 16 : 18,
                              height: 1.8,
                              color: _landingText))),
                  const SizedBox(height: 24),
                  Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        _LandingButton('Saha & Kort Rezervasyonu',
                            secondary: true, onTap: () => _to(_fieldsKey)),
                        _LandingButton('Akademi Başvuruları',
                            onTap: () => _to(_applicationsKey)),
                      ]),
                  const SizedBox(height: 42),
                  _LandingLabel('ONLINE REZERVASYON', key: _fieldsKey),
                  const SizedBox(height: 26),
                  _cardGrid(width, [
                    for (final card in _landingFields) _fieldCard(card, mobile)
                  ]),
                  const SizedBox(height: 72),
                  _LandingLabel('AKADEMİ BAŞVURULARI', key: _applicationsKey),
                  const SizedBox(height: 26),
                  _cardGrid(width, [
                    for (final card in _landingAcademies)
                      _academyCard(card, mobile)
                  ]),
                ]))));
  }

  Widget _cardGrid(double width, List<Widget> cards) =>
      LayoutBuilder(builder: (context, constraints) {
        final columns = width > 1200 ? 3 : (width > 900 ? 2 : 1);
        final gap = width <= 600 ? 18.0 : 32.0;
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final card in cards) SizedBox(width: cardWidth, child: card)
        ]);
      });

  Widget _fieldCard(_LandingField card, bool mobile) {
    final url = _fieldImage(card);
    return _LandingFeatureCard(
      title: card.title,
      description: card.description,
      image: url,
      mobile: mobile,
      comingSoon: card.comingSoon,
      onImageTap: () => _lightbox(url),
      button: _LandingButton(
          card.comingSoon ? 'Çok Yakında · Bilgi Al' : 'Rezervasyon Yap',
          secondary: card.comingSoon,
          onTap: card.comingSoon
              ? () => _landingWhatsApp(card.id == 10 ? 'Havuz' : 'Padel Kortu')
              : () => _book(card)),
    );
  }

  Widget _academyCard(_LandingAcademy card, bool mobile) {
    final url = _image(card.key, '/assets/images/${card.image}.jpg');
    return _LandingFeatureCard(
        title: card.title,
        description: card.description,
        image: url,
        mobile: mobile,
        onImageTap: () => _lightbox(url),
        button: _LandingButton(
            card.team ? 'Eğitmenlerimizle Tanışın' : 'WhatsApp’tan Başvur',
            secondary: card.team,
            onTap: card.team
                ? () => _to(_contactKey)
                : () => _landingWhatsApp(card.title)));
  }

  Widget _gallerySection(bool mobile) => Padding(
      key: _galleryKey,
      padding: EdgeInsets.only(bottom: mobile ? 72 : 140),
      child: Column(children: [
        Padding(
            padding: EdgeInsets.symmetric(horizontal: mobile ? 18 : 60),
            child: Column(children: [
              const _LandingLabel('KOMPLEKSTEN KARELER'),
              const SizedBox(height: 20),
              _LandingHeading('Göz Kamaştıran ', 'Detaylar', mobile: mobile),
              const SizedBox(height: 24),
              Text('Premium tesisimizin her köşesini detaylarıyla inceleyin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _landingText,
                      fontSize: mobile ? 16 : 18,
                      height: 1.8)),
              const SizedBox(height: 50),
            ])),
        _LandingGallery(
          images: [
            for (var id = 21; id <= 28; id++)
              _image('gallery_$id', '/assets/images/$id.jpg'),
          ],
          onImageTap: _lightbox,
        ),
      ]));

  Widget _contactSection(bool mobile) => Container(
      key: _contactKey,
      margin: EdgeInsets.fromLTRB(
          mobile ? 18 : 60, 0, mobile ? 18 : 60, mobile ? 52 : 100),
      padding: EdgeInsets.symmetric(
          horizontal: mobile ? 20 : 80, vertical: mobile ? 46 : 80),
      decoration: BoxDecoration(
          color: _landingInk,
          borderRadius: BorderRadius.circular(mobile ? 24 : 36),
          boxShadow: const [
            BoxShadow(
                color: Color(0x260f172a), blurRadius: 40, offset: Offset(0, 20))
          ]),
      child: Column(children: [
        Text.rich(
            TextSpan(children: const [
              TextSpan(
                  text: 'İletişim & ', style: TextStyle(color: Colors.white)),
              TextSpan(
                  text: 'Ulaşım', style: TextStyle(color: Color(0xfffbbf24))),
            ]),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: mobile ? 34 : 56,
                height: 1.1,
                fontWeight: FontWeight.w900,
                letterSpacing: -2)),
        const SizedBox(height: 20),
        const Text(
            'Sanat ve sporla dolu ayrıcalıklı bir yaşama adım atmak için YT Kampüs ailesine katılın. Tesisimizi ziyaret edin!',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 19, color: Color(0xff94a3b8), height: 1.4)),
        const SizedBox(height: 34),
        _contactCard(
            '📞 İletişim Bilgileri',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _phone('Tel 1:', '+90 553 211 13 58', 'tel:+905532111358'),
              _phone('Tel 2:', '+90 506 808 08 86', 'tel:+905068080886'),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _whatsappButton('💬 WhatsApp Tel 1', '905532111358'),
                _whatsappButton('💬 WhatsApp Tel 2', '905068080886'),
              ]),
              const SizedBox(height: 16),
              _phone('E-Posta:', 'iletisim@ytkampus.com',
                  'mailto:iletisim@ytkampus.com'),
            ])),
        const SizedBox(height: 18),
        _contactCard(
            '📍 Adres & Konum',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Kayseri, Türkiye\nYT Kampüs',
                  style: TextStyle(
                      color: Color(0xffcbd5e1), fontSize: 14, height: 1.7)),
              const SizedBox(height: 16),
              GestureDetector(
                  onTap: () => _landingLaunch(
                      'https://maps.app.goo.gl/3ea84B6T5ei7FhRp8'),
                  child: const Text('Haritada Görüntüle ↗',
                      style: TextStyle(
                          color: Color(0xfffbbf24),
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.underline,
                          decorationColor: Color(0xfffbbf24)))),
            ])),
        const SizedBox(height: 32),
        _LandingButton('Online Kayıt & Rezervasyon',
            large: true, white: true, onTap: () => _login(register: true)),
        const SizedBox(height: 20),
        _LandingButton('Yol Tarifi Al',
            large: true,
            outlineLight: true,
            onTap: () =>
                _landingLaunch('https://maps.app.goo.gl/3ea84B6T5ei7FhRp8')),
      ]));

  Widget _contactCard(String title, Widget content) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: const Color(0xbf334155),
          border: Border.all(color: const Color(0x2effffff)),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: Color(0x29000000), blurRadius: 30, offset: Offset(0, 14))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        content,
      ]));

  Widget _phone(String label, String value, String url) => GestureDetector(
      onTap: () => _landingLaunch(url),
      child: Text.rich(
          TextSpan(children: [
            TextSpan(
                text: '$label ',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Color(0xffcbd5e1))),
            TextSpan(text: value, style: const TextStyle(color: Colors.white)),
          ]),
          style: const TextStyle(fontSize: 14, height: 1.7)));

  Widget _whatsappButton(String label, String number) => GestureDetector(
      onTap: () => _landingLaunch('https://wa.me/$number'),
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
              color: const Color(0xff25d366),
              borderRadius: BorderRadius.circular(9)),
          child: Text(label,
              style: const TextStyle(
                  color: Color(0xff052e16),
                  fontSize: 12,
                  fontWeight: FontWeight.w800))));

  Widget _footer(bool mobile) => Container(
      padding: EdgeInsets.symmetric(
          horizontal: mobile ? 18 : 60, vertical: mobile ? 32 : 50),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _landingBorder))),
      child: Column(children: [
        _LandingLogo(small: true, footer: true, logoUrl: _siteLogo),
        const SizedBox(height: 20),
        const Text('© 2026 YT Kampüs Merkezi. Tüm Hakları Saklıdır.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _landingMuted)),
        const SizedBox(height: 8),
        Text('Bu platform Serhat Koçyiğit tarafından özenle hazırlandı.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12, height: 1.45, color: _landingMuted)),
        const SizedBox(height: 3),
        GestureDetector(
            onTap: () => _landingLaunch('tel:+905447414393'),
            child: const Text('İş birlikleri için: +90 544 741 43 93',
                style: TextStyle(
                    fontSize: 12,
                    color: Color(0xff1d4ed8),
                    fontWeight: FontWeight.w800))),
        const SizedBox(height: 20),
        Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: [
              _footerLink('KVKK Aydınlatma Metni',
                  () => showWebLegalDocument(context, contract: false)),
              _footerLink(
                  'Kullanım Şartları',
                  () => showWebLegalDocument(context, contract: true)),
              _footerLink('İletişim', () => _to(_contactKey)),
            ]),
      ]));

  Widget _footerLink(String text, VoidCallback action) => GestureDetector(
      onTap: action,
      child: Text(text,
          style: const TextStyle(
              color: _landingMuted,
              fontSize: 14,
              fontWeight: FontWeight.w500)));
}

String _landingUrl(String url) => Uri.parse(_apiBase).resolve(url).toString();

Future<void> _landingLaunch(String value) async {
  final uri = Uri.parse(value.startsWith('/') ? _landingUrl(value) : value);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

void _landingWhatsApp(String subject) => _landingLaunch(Uri.https(
    'wa.me',
    '/905532111358',
    {'text': 'Merhaba, $subject hakkında bilgi almak istiyorum.'}).toString());

class _LandingLogo extends StatelessWidget {
  const _LandingLogo({this.small = false, this.footer = false, this.logoUrl});
  final bool small;
  final bool footer;
  final String? logoUrl;

  // Yönetim panelinden eklenen JPEG/PNG logoları bazen geniş beyaz boşlukla
  // gelir. Bunları yalnızca mobil rozet içinde büyütüp ortalıyoruz; SVG'ler
  // zaten kırpılmış vektör oldukları için doğal ölçülerinde kalır.
  bool get _needsBitmapCrop {
    final path = Uri.tryParse(logoUrl ?? '')?.path.toLowerCase() ?? '';
    return logoUrl != null && !path.endsWith('.svg');
  }

  @override
  Widget build(BuildContext context) {
    final logoRadius = BorderRadius.circular(small ? 11 : 14);
    return Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: footer ? 32 : (small ? 36 : 46),
            height: footer ? 32 : (small ? 36 : 46),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(small ? 11 : 14),
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xff0b1f49), Color(0xff1d4ed8)]),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x381d4ed8),
                      blurRadius: 18,
                      offset: Offset(0, 8))
                ]),
            child: logoUrl == null
                ? Text('YT',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: footer ? 11 : (small ? 13 : 16),
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1))
                : ClipRRect(
                    borderRadius: logoRadius,
                    child: SizedBox.expand(
                      child: Transform.scale(
                        // JPEG'teki çevre boşluğunu kırpar; logo rozetin
                        // tamamını dengeli biçimde doldurur.
                        scale: _needsBitmapCrop ? 2.05 : 1,
                        child: Image.network(
                          logoUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                              child: Text('YT',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900))),
                        ),
                      ),
                    ),
                  )),
        SizedBox(width: footer ? 10 : (small ? 8 : 12)),
        Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('YT KAMPÜS',
                  style: TextStyle(
                      color: _landingInk,
                      fontSize: small ? 13 : 18,
                      height: 1.05,
                      letterSpacing: .2,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('SPOR · SANAT · YAŞAM',
                  style: TextStyle(
                      color: const Color(0xff1d4ed8),
                      fontSize: small ? 8 : 10,
                      height: 1.05,
                      letterSpacing: small ? 1 : 1.8,
                      fontWeight: FontWeight.w900)),
            ]),
      ]);
  }
}

class _LandingButton extends StatelessWidget {
  const _LandingButton(this.label,
      {required this.onTap,
      this.secondary = false,
      this.white = false,
      this.outlineLight = false,
      this.large = false,
      this.fontSize});
  final String label;
  final VoidCallback onTap;
  final bool secondary, white, outlineLight, large;
  final double? fontSize;
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.transparent,
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(large ? 16 : 10),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: large ? 42 : 28, vertical: large ? 18 : 14),
            decoration: BoxDecoration(
                color: outlineLight
                    ? Colors.transparent
                    : (secondary || white ? Colors.white : _landingBlue),
                border: secondary
                    ? Border.all(color: _landingBorder)
                    : (outlineLight
                        ? Border.all(color: const Color(0x33ffffff))
                        : null),
                borderRadius: BorderRadius.circular(large ? 16 : 10),
                boxShadow: outlineLight || white
                    ? []
                    : [
                        BoxShadow(
                            color: secondary
                                ? const Color(0x0a0f172a)
                                : const Color(0x332563eb),
                            blurRadius: secondary ? 8 : 24,
                            offset: Offset(0, secondary ? 2 : 8))
                      ]),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: secondary || white ? _landingInk : Colors.white,
                    letterSpacing: 0,
                    fontSize: fontSize ?? (large ? 18 : 16),
                    height: 1.2,
                    fontWeight: FontWeight.w600)),
          )));
}

class _LandingGradientText extends StatelessWidget {
  const _LandingGradientText(this.text,
      {required this.fontSize, this.height = 1.1, this.letterSpacing = -1.5});
  final String text;
  final double fontSize, height, letterSpacing;
  @override
  Widget build(BuildContext context) => ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff1e40af), Color(0xff3b82f6)]).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              height: height,
              letterSpacing: letterSpacing,
              fontWeight: FontWeight.w900)));
}

class _LandingHeading extends StatelessWidget {
  const _LandingHeading(this.before, this.blue, {required this.mobile});
  final String before, blue;
  final bool mobile;
  @override
  Widget build(BuildContext context) => Text.rich(
      TextSpan(children: [
        TextSpan(text: before, style: const TextStyle(color: _landingInk)),
        TextSpan(text: blue, style: const TextStyle(color: Color(0xff2e66ce))),
      ]),
      textAlign: TextAlign.center,
      style: TextStyle(
          fontSize: mobile ? 34 : 52,
          height: 1.1,
          letterSpacing: -1.5,
          fontWeight: FontWeight.w900));
}

class _LandingLabel extends StatelessWidget {
  const _LandingLabel(this.text,
      {super.key, this.color = const Color(0xff1d4ed8)});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 30,
            height: 3,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 12),
        Flexible(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                    color: color))),
      ]);
}

class _LandingStat extends StatelessWidget {
  const _LandingStat(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: const TextStyle(
                fontSize: 27,
                color: Color(0xff1d4ed8),
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                height: 1.2)),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: _landingMuted,
                fontWeight: FontWeight.w600,
                letterSpacing: .6,
                height: 1.2)),
      ]);
}

class _LandingImage extends StatelessWidget {
  const _LandingImage({required this.url, this.fit = BoxFit.cover});
  final String url;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) => Image.network(url,
      fit: fit,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xffe8eef6),
          alignment: Alignment.center,
          child: const Icon(Icons.image_outlined,
              color: Color(0xff94a3b8), size: 32)));
}

class _LandingGallery extends StatefulWidget {
  const _LandingGallery({required this.images, required this.onImageTap});
  final List<String> images;
  final ValueChanged<String> onImageTap;
  @override
  State<_LandingGallery> createState() => _LandingGalleryState();
}

class _LandingGalleryState extends State<_LandingGallery>
    with SingleTickerProviderStateMixin {
  late final _motion =
      AnimationController(vsync: this, duration: const Duration(seconds: 50))
        ..repeat();
  bool _dragging = false;

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cycle = widget.images.length * 384.0;
    return SizedBox(
      height: 320,
      child: MouseRegion(
        onEnter: (_) => _motion.stop(),
        onExit: (_) {
          if (!_dragging) _motion.repeat();
        },
        child: GestureDetector(
          onHorizontalDragStart: (_) {
            _dragging = true;
            _motion.stop();
          },
          onHorizontalDragUpdate: (details) {
            _motion.value = (_motion.value - details.delta.dx / cycle) % 1;
          },
          onHorizontalDragEnd: (_) {
            _dragging = false;
            _motion.repeat();
          },
          child: ClipRect(
              child: AnimatedBuilder(
            animation: _motion,
            builder: (context, child) => OverflowBox(
                minWidth: cycle * 2,
                maxWidth: cycle * 2,
                alignment: Alignment.centerLeft,
                child: Transform.translate(
                    offset: Offset(-cycle * _motion.value, 0), child: child)),
            child: Row(children: [
              for (var index = 0; index < widget.images.length * 2; index++)
                Padding(
                    padding:
                        const EdgeInsets.only(right: 24, top: 30, bottom: 30),
                    child: GestureDetector(
                        onTap: () => widget.onImageTap(
                            widget.images[index % widget.images.length]),
                        child: Container(
                            width: 360,
                            height: 260,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: _landingBorder),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color(0x0a0f172a),
                                      blurRadius: 8,
                                      offset: Offset(0, 2))
                                ]),
                            clipBehavior: Clip.antiAlias,
                            child: _LandingImage(
                                url: widget
                                    .images[index % widget.images.length])))),
            ]),
          )),
        ),
      ),
    );
  }
}

class _LandingFeatureCard extends StatelessWidget {
  const _LandingFeatureCard(
      {required this.title,
      required this.description,
      required this.image,
      required this.mobile,
      required this.button,
      required this.onImageTap,
      this.comingSoon = false});
  final String title, description, image;
  final bool mobile, comingSoon;
  final Widget button;
  final VoidCallback onImageTap;
  @override
  Widget build(BuildContext context) => Container(
      padding: EdgeInsets.all(mobile ? 18 : 28),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _landingBorder),
          borderRadius: BorderRadius.circular(36),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0a0f172a), blurRadius: 8, offset: Offset(0, 2))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GestureDetector(
            onTap: onImageTap,
            child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                    height: mobile ? 210 : 260,
                    child: Stack(fit: StackFit.expand, children: [
                      _LandingImage(url: image),
                      if (comingSoon)
                        Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                    color: const Color(0xfff59e0b),
                                    borderRadius: BorderRadius.circular(6)),
                                child: const Text('YAKINDA',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                        letterSpacing: .5,
                                        color: Colors.black)))),
                    ])))),
        const SizedBox(height: 20),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 22,
                letterSpacing: -.5,
                fontWeight: FontWeight.w800,
                color: _landingInk)),
        const SizedBox(height: 12),
        Text(description,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _landingMuted, fontSize: 15, height: 1.7)),
        const SizedBox(height: 16),
        button,
      ]));
}

class _LandingOrbit extends StatefulWidget {
  const _LandingOrbit();
  @override
  State<_LandingOrbit> createState() => _LandingOrbitState();
}

class _LandingOrbitState extends State<_LandingOrbit>
    with SingleTickerProviderStateMixin {
  late final _turn =
      AnimationController(vsync: this, duration: const Duration(seconds: 28))
        ..repeat();
  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _turn,
      builder: (context, child) =>
          Transform.rotate(angle: _turn.value * math.pi * 2, child: child),
      child: const CustomPaint(painter: _LandingOrbitPainter()));
}

class _LandingOrbitPainter extends CustomPainter {
  const _LandingOrbitPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final ring = Rect.fromLTWH(.5, .5, size.width - 1, size.height - 1);
    final line = Paint()
      ..color = const Color(0x3d2563eb)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (double angle = 0; angle < math.pi * 2; angle += .024) {
      canvas.drawArc(ring, angle, .011, false, line);
    }
    for (final dot in const [
      (Offset(48.5, 48.5), Color(0xfff59e0b)),
      (Offset(379.5, 357.5), Color(0xff2563eb)),
    ]) {
      canvas.drawCircle(
          dot.$1, 14.5, Paint()..color = dot.$2.withValues(alpha: .13));
      canvas.drawCircle(
          dot.$1,
          11,
          Paint()
            ..color = dot.$2.withValues(alpha: .25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
      canvas.drawCircle(dot.$1, 6.5, Paint()..color = dot.$2);
    }
  }

  @override
  bool shouldRepaint(covariant _LandingOrbitPainter oldDelegate) => false;
}

class _LandingGrid extends CustomPainter {
  const _LandingGrid();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const RadialGradient(
                  colors: [Color(0x0a2563eb), Color(0x002563eb)],
                  stops: [0, .6])
              .createShader(const Rect.fromLTWH(-200, -200, 800, 800)));
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const RadialGradient(colors: [
            Color(0x08f59e0b),
            Color(0x00f59e0b)
          ], stops: [
            0,
            .6
          ]).createShader(
              Rect.fromLTWH(size.width - 550, size.height - 550, 700, 700)));
    final paint = Paint()
      ..color = const Color(0x082563eb)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 80)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += 80)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(covariant _LandingGrid oldDelegate) => false;
}

class _LandingField {
  const _LandingField(this.id, this.title, this.description, this.image,
      {this.comingSoon = false});
  final int id, image;
  final String title, description;
  final bool comingSoon;
}

const _landingFields = [
  _LandingField(
      1,
      'Futbol Sahası',
      'UEFA standartlarında profesyonel kapalı futbol sahası. Maçlarınız ve takım antrenmanlarınız için online rezervasyon oluşturun.',
      3),
  _LandingField(
      2,
      'Halı Saha (INTER)',
      'Yüksek kalite sentetik çim zeminli, profesyonel gece aydınlatmalı açık ve kapalı halı saha alanı.',
      4),
  _LandingField(
      3,
      'Tenis Kortu',
      'Uluslararası standartlarda akrilik zeminli, profesyonel gece aydınlatmalı açık ve kapalı tenis kortu.',
      5),
  _LandingField(
      4,
      'Voleybol Sahası',
      'Uluslararası ölçülere sahip, kaymaz profesyonel kaplamalı kapalı salon voleybol sahası.',
      6),
  _LandingField(
      5,
      'Basketbol Sahası',
      'Tam saha potalı, şok emici parke zeminli kapalı basketbol alanı ve antrenman sahası.',
      7),
  _LandingField(
      6,
      'Müzik Stüdyosu',
      'Akustik yalıtımlı, profesyonel ses kayıt ve enstrüman çalışma imkanı sunan modern stüdyo alanı.',
      10),
  _LandingField(
      7,
      'Sanat Atölyesi (Resim)',
      'Geniş, doğal ışık alan, temel ve yaratıcı sanat çalışmalarına uygun ilham verici atölye alanı.',
      11),
  _LandingField(
      8,
      'Dans Stüdyosu',
      'Aynalı, özel dans parkeli ve yüksek kaliteli ses sistemine sahip geniş prova ve ders salonu.',
      12),
  _LandingField(
      9,
      'Padel Kortu',
      'Güçlendirilmiş cam duvarlı, son teknoloji zemin kaplamalı yeni nesil profesyonel padel kortu.',
      8,
      comingSoon: true),
  _LandingField(
      10,
      'Yüzme Havuzu',
      'Yarı olimpik, hijyenik ve tam donanımlı kapalı yüzme havuzu ve su sporları kompleksi.',
      9,
      comingSoon: true),
];

class _LandingAcademy {
  const _LandingAcademy(this.key, this.title, this.description, this.image,
      {this.team = false});
  final String key, title, description;
  final int image;
  final bool team;
}

const _landingAcademies = [
  _LandingAcademy(
      'academy_tennis',
      'YT Tenis Akademi',
      'Çocuk akademisi, özel ders ve grup çalışmalarıyla her seviyeye uygun tenis eğitimi.',
      13),
  _LandingAcademy(
      'academy_inter',
      'Inter Akademi',
      'Çocuklar ve gençler için teknik gelişim, koordinasyon ve takım oyununa odaklanan futbol eğitimleri.',
      14),
  _LandingAcademy(
      'academy_art',
      'Sanat Merkezi (Resim Eğitimi)',
      'Ressam Hasan Gürpınar ile Çocuk, Genç ve Yetişkin gruplarına özel temel sanat, desen ve yaratıcı boya atölyeleri.',
      16),
  _LandingAcademy(
      'academy_dance',
      'YT Dans Okulu',
      'İlk Dans, Zeybek, Oryantal, Zumba, Yöresel Halaylar. Özel ve grup dersi seçenekleriyle ritmi yakalayın.',
      17),
  _LandingAcademy(
      'academy_language',
      'Dil Akademisi',
      'İngilizce ve Korece eğitimlerinde özel ders ve grup dersi seçenekleriyle düzenli öğrenme programları.',
      18),
  _LandingAcademy(
      'academy_kids',
      'Çocuk Akademisi',
      'Çocukların sporla gelişimini destekleyen yaş grubuna uygun temel teknik, koordinasyon ve takım çalışması.',
      19),
  _LandingAcademy(
      'team_image',
      'Uzman Antrenör Kadrosu',
      'Tüm branşlarda, alanında tecrübeli ve pedagojik formasyona sahip elit eğitmenlerle çalışın.',
      20,
      team: true),
];

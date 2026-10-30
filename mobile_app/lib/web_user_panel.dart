part of 'main.dart';

const _PanelInk = Color(0xff0f172a);
const _PanelMuted = Color(0xff64748b);
const _PanelBorder = Color(0xffe2e8f0);
const _PanelBlue = Color(0xff2563eb);
const _PanelBackground = Color(0xfff4f7f9);

/// The native counterpart of pages/user/dashboard.html.  The page hierarchy,
/// spacing, imagery and API operations follow the responsive website.
class WebUserPanel extends StatefulWidget {
  const WebUserPanel({
    super.key,
    required this.user,
    this.initialPage = 'overview',
    this.initialField,
    this.academy = false,
    this.client,
  });

  final Map<String, dynamic> user;
  final String initialPage;
  final Map<String, dynamic>? initialField;
  final bool academy;
  final Api? client;

  @override
  State<WebUserPanel> createState() => _PanelState();
}

class _PanelState extends State<WebUserPanel> {
  final _scaffold = GlobalKey<ScaffoldState>();
  final _profileForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _repeatPassword = TextEditingController();
  late Map<String, dynamic> _user;
  late String _page;
  List<Map<String, dynamic>> _reservations = [];
  List<Map<String, dynamic>> _fields = [];
  Map<String, dynamic>? _selectedBookingField;
  List<Map<String, dynamic>> _notifications = [];
  String _filter = 'all';
  String? _reservationsError;
  String? _fieldsError;
  String? _profileError;
  String? _notificationsError;
  bool _loadingReservations = true;
  bool _loadingFields = true;
  bool _loadingProfile = false;
  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _notificationsOpen = false;
  bool _signingOut = false;
  Api get _client => widget.client ?? api;

  static const _titles = {
    'overview': 'Genel Bakış',
    'booking': 'Rezervasyon Al',
    'my-reservations': 'Rezervasyonlarım',
    'account': 'Hesabım',
  };

  @override
  void initState() {
    super.initState();
    _user = Map<String, dynamic>.from(widget.user);
    _page = _titles.containsKey(widget.initialPage)
        ? widget.initialPage
        : 'overview';
    _fillProfile(_user);
    _loadReservations();
    _loadFields();
    _loadNotifications();
    if (_page == 'account') _loadProfile();
    if (widget.initialField != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openBooking(widget.initialField!);
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _repeatPassword.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _records(Object? data) => data is List
      ? data.whereType<Map>().map(Map<String, dynamic>.from).toList()
      : <Map<String, dynamic>>[];

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? const Color(0xff991b1b) : _PanelInk,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _loadReservations() async {
    if (mounted) {
      setState(() {
        _loadingReservations = true;
        _reservationsError = null;
      });
    }
    try {
      final result = await _client.get('/reservations/my');
      if (!mounted) return;
      setState(() {
        if (result['ok'] == true) {
          _reservations = _records(result['data']);
        } else {
          _reservationsError = result['error']?.toString() ??
              'Rezervasyonlar yüklenemedi. Lütfen tekrar deneyin.';
        }
        _loadingReservations = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingReservations = false;
          _reservationsError = 'Bağlantı kurulamadı. Lütfen tekrar deneyin.';
        });
      }
    }
  }

  Future<void> _loadFields() async {
    if (mounted) {
      setState(() {
        _loadingFields = true;
        _fieldsError = null;
      });
    }
    try {
      final result = await _client.get('/fields');
      if (!mounted) return;
      setState(() {
        if (result['ok'] == true) {
          _fields = _records(result['data']);
          // A home-page reservation link may arrive before its field request
          // finishes. Use the same current field record as the web catalog.
          if (_selectedBookingField != null) {
            final selectedId = _selectedBookingField!['id'].toString();
            final matches =
                _fields.where((field) => field['id'].toString() == selectedId);
            _selectedBookingField = matches.isEmpty ? null : matches.first;
          }
        } else {
          _fieldsError =
              result['error']?.toString() ?? 'Spor alanları yüklenemedi.';
        }
        _loadingFields = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingFields = false;
          _fieldsError = 'Spor alanları yüklenemedi.';
        });
      }
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final result = await _client.get('/notifications');
      if (!mounted) return;
      setState(() {
        if (result['ok'] == true) {
          _notifications = _records(result['data']);
          _notificationsError = null;
        } else {
          _notificationsError =
              result['error']?.toString() ?? 'Bildirimler yüklenemedi.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _notificationsError = 'Bildirimler yüklenemedi.');
      }
    }
  }

  Future<void> _readNotification(Map<String, dynamic> notification) async {
    try {
      final result =
          await _client.patch('/notifications/${notification['id']}/read');
      if (!mounted) return;
      if (result['ok'] == true) {
        setState(() => notification['is_read'] = true);
      } else {
        _toast(result['error']?.toString() ?? 'Bildirim güncellenemedi.',
            error: true);
      }
    } catch (_) {
      _toast('Bağlantı kurulamadı. Lütfen tekrar deneyin.', error: true);
    }
  }

  bool _isRead(Map<String, dynamic> notification) =>
      notification['is_read'] == true ||
      notification['is_read'] == 1 ||
      notification['is_read'] == '1';

  int get _unread => _notifications.where((n) => !_isRead(n)).length;

  void _fillProfile(Map<String, dynamic> user) {
    _name.text = user['full_name']?.toString() ?? '';
    _email.text = user['email']?.toString() ?? '';
    _phone.text = user['phone']?.toString() ?? '';
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });
    try {
      final result = await _client.get('/auth/me');
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
        if (result['ok'] == true && result['data'] is Map) {
          _user.addAll(Map<String, dynamic>.from(result['data']));
          _fillProfile(_user);
        } else {
          _profileError =
              result['error']?.toString() ?? 'Profil bilgileri yüklenemedi.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingProfile = false;
          _profileError = 'Profil bilgileri yüklenemedi.';
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_savingProfile || !(_profileForm.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _savingProfile = true);
    try {
      final result = await _client.patch('/auth/me', body: {
        'full_name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
      });
      if (!mounted) return;
      if (result['ok'] == true) {
        setState(() {
          final data = result['data'];
          if (data is Map && data['user'] is Map) {
            _user.addAll(Map<String, dynamic>.from(data['user']));
          }
        });
        _toast('Profil bilgileriniz güncellendi');
      } else {
        _toast(result['error']?.toString() ?? 'Profil güncellenemedi.',
            error: true);
      }
    } catch (_) {
      _toast('Bağlantı kurulamadı. Lütfen tekrar deneyin.', error: true);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _savePassword() async {
    if (_savingPassword || !(_passwordForm.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _savingPassword = true);
    try {
      final result = await _client.patch('/auth/password', body: {
        'current_password': _currentPassword.text,
        'password': _newPassword.text,
      });
      if (!mounted) return;
      if (result['ok'] == true) {
        _currentPassword.clear();
        _newPassword.clear();
        _repeatPassword.clear();
        _toast('Şifreniz güvenle güncellendi');
      } else {
        _toast(result['error']?.toString() ?? 'Şifre güncellenemedi.',
            error: true);
      }
    } catch (_) {
      _toast('Bağlantı kurulamadı. Lütfen tekrar deneyin.', error: true);
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  void _selectPage(String page) {
    if (_scaffold.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    setState(() {
      _page = page;
      _notificationsOpen = false;
      _selectedBookingField = null;
    });
    if (page == 'overview' || page == 'my-reservations') _loadReservations();
    if (page == 'booking' && _fields.isEmpty) _loadFields();
    if (page == 'account') _loadProfile();
  }

  void _openBooking(Map<String, dynamic> field) {
    final matches =
        _fields.where((item) => item['id'].toString() == field['id'].toString());
    setState(() {
      _page = 'booking';
      _selectedBookingField = matches.isNotEmpty
          ? matches.first
          : _loadingFields || _fieldsError != null
              ? field
              : null;
      _notificationsOpen = false;
    });
  }

  void _bookingCompleted() {
    setState(() {
      _selectedBookingField = null;
      _page = 'my-reservations';
    });
    _loadReservations();
    _loadNotifications();
  }

  void _home() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => WebLandingPage(user: _user)),
      (route) => false,
    );
  }

  void _videos() {
    if (_scaffold.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    setState(() => _notificationsOpen = false);
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => WebVideosPage(user: _user),
    ));
  }

  Future<void> _logout() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await _client.post('/auth/logout');
    } catch (_) {
      // Local credentials must still be cleared if the network is unavailable.
    }
    await _storage.delete(key: 'access_token');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WebLandingPage()),
      (route) => false,
    );
  }

  String _money(Object? value) => NumberFormat.currency(
        locale: 'tr_TR',
        symbol: '₺',
        decimalDigits: 2,
      ).format(num.tryParse(value?.toString() ?? '') ?? 0);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width <= 900;
    final compact = width <= 560;
    final theme = Theme.of(context);
    final panelText =
        theme.textTheme.apply(fontFamily: 'Inter', letterSpacingFactor: 0);
    return Theme(
      data: theme.copyWith(
        textTheme: panelText.copyWith(
          bodyLarge: panelText.bodyLarge?.copyWith(height: 1.2),
          bodyMedium: panelText.bodyMedium?.copyWith(height: 1.2),
          bodySmall: panelText.bodySmall?.copyWith(height: 1.2),
        ),
        primaryTextTheme: theme.primaryTextTheme
            .apply(fontFamily: 'Inter', letterSpacingFactor: 0),
      ),
      child: Scaffold(
        key: _scaffold,
        backgroundColor: _PanelBackground,
        drawerScrimColor: const Color(0x660a1d3a),
        drawer: mobile
            ? SizedBox(
                width: (width * .82).clamp(0, 286).toDouble(),
                child: Drawer(
                  shape: const RoundedRectangleBorder(),
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  child: _sidebar(),
                ),
              )
            : null,
        body: SafeArea(
          child: Row(
            children: [
              if (!mobile)
                Container(
                  width: 260,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(right: BorderSide(color: _PanelBorder)),
                  ),
                  child: _sidebar(),
                ),
              Expanded(
                child: Column(
                  children: [
                    _topBar(compact, mobile),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(child: _body(compact)),
                          if (_notificationsOpen) ...[
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () =>
                                    setState(() => _notificationsOpen = false),
                                child: const SizedBox.expand(),
                              ),
                            ),
                            _notificationPopover(compact),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(bool compact, bool mobile) {
    final menu = _PanelSquareButton(
      size: 40,
      label: 'Menüyü aç',
      onTap: () {
        setState(() => _notificationsOpen = false);
        _scaffold.currentState?.openDrawer();
      },
      child: const Text('☰',
          style: TextStyle(fontSize: 21, color: Color(0xff24466f))),
    );
    final title = Text(
      _titles[_page]!,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
          color: _PanelInk, fontSize: 18, fontWeight: FontWeight.w700),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _bell(),
        const SizedBox(width: 10),
        SizedBox(
          width: compact ? 126 : null,
          height: compact ? 32 : null,
          child: _PanelButton(
            label: '+ Yeni Rezervasyon',
            onTap: () => _selectPage('booking'),
            horizontal: compact ? 10 : 20,
            vertical: compact ? 8 : 10,
            fontSize: compact ? 12 : 14,
            radius: 8,
          ),
        ),
      ],
    );
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 32, vertical: compact ? 12 : 0),
      decoration: BoxDecoration(
        color: compact ? const Color(0xfff8fafc) : Colors.white,
        border: const Border(bottom: BorderSide(color: _PanelBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (mobile) menu,
          if (compact) Flexible(child: title) else Expanded(child: title),
          if (!compact && MediaQuery.sizeOf(context).width > 1100) ...[
            Text(_greeting(),
                style: const TextStyle(color: _PanelMuted, fontSize: 14)),
            const SizedBox(width: 10),
          ],
          actions,
        ],
      ),
    );
  }

  Widget _bell() => Stack(
        clipBehavior: Clip.none,
        children: [
          _PanelSquareButton(
            size: 38,
            label: 'Bildirimler',
            onTap: () {
              setState(() => _notificationsOpen = !_notificationsOpen);
              if (_notificationsOpen) _loadNotifications();
            },
            child: const Text('🔔', style: TextStyle(fontSize: 17)),
          ),
          if (_unread > 0)
            Positioned(
              top: -6,
              right: -6,
              child: IgnorePointer(
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xffdc2626),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(_unread > 9 ? '9+' : '$_unread',
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ),
        ],
      );

  String _greeting() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Günaydın'
        : hour < 18
            ? 'İyi günler'
            : 'İyi akşamlar';
    return '$greeting, ${(_user['full_name'] ?? 'Üye').toString().split(' ').first}!';
  }

  Widget _sidebar() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _home,
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _PanelBorder))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text.rich(
                    TextSpan(text: 'YT', children: [
                      TextSpan(
                          text: 'Kampüs', style: TextStyle(color: _PanelInk)),
                    ]),
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: _PanelInk),
                  ),
                  const SizedBox(height: 2),
                  const Text('Kullanıcı Paneli',
                      style: TextStyle(fontSize: 11, color: _PanelMuted)),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _sidebarSection('GENEL'),
                _nav('📊', 'Genel Bakış', 'overview'),
                _nav('📅', 'Rezervasyon Al', 'booking'),
                _nav('🎥', 'Maç Videoları', null, onTap: _videos),
                _sidebarSection('REZERVASYONLARIM'),
                _nav('🎫', 'Rezervasyonlarım', 'my-reservations'),
                _nav('⚙️', 'Hesabım', 'account'),
                _sidebarSection('HESAP'),
                _nav('🏠', 'Ana Sayfa', null, onTap: _home),
                _nav('🚪', _signingOut ? 'Çıkış yapılıyor…' : 'Çıkış Yap', null,
                    onTap: _logout),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _PanelBorder))),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _avatarColor(),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      (_user['full_name']?.toString().isNotEmpty ?? false)
                          ? _user['full_name'].toString()[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_user['full_name']?.toString() ?? 'Üye',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                color: _PanelInk,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        const Text('Üye',
                            style: TextStyle(fontSize: 11, color: _PanelMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _avatarColor() {
    final raw = _user['avatar_color']?.toString().replaceFirst('#', '') ?? '';
    final value = int.tryParse(raw, radix: 16);
    return value == null ? _PanelBlue : Color(0xff000000 | value);
  }

  Widget _sidebarSection(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: Text(label,
            style: const TextStyle(
                color: _PanelMuted,
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700)),
      );

  Widget _nav(String emoji, String title, String? page, {VoidCallback? onTap}) {
    final active = page != null && _page == page;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: active ? const Color(0xffedf6ff) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap ?? () => _selectPage(page!),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                    width: 20,
                    child: Text(emoji,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 17))),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? const Color(0xff1e40af)
                              : const Color(0xff334155))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _notificationPopover(bool compact) {
    return Positioned(
      top: 12,
      left: compact ? 16 : null,
      right: compact ? 16 : 32,
      width: compact ? null : 360,
      child: Container(
        constraints: BoxConstraints(
            maxHeight: (MediaQuery.sizeOf(context).height - 112)
                .clamp(80, 420)
                .toDouble()),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _PanelBorder),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0x2e0f172a), blurRadius: 42, offset: Offset(0, 18))
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            child: _notificationsError != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Column(children: [
                      Text(_notificationsError!,
                          style: const TextStyle(
                              fontSize: 13, color: _PanelMuted)),
                      TextButton(
                          onPressed: _loadNotifications,
                          child: const Text('Tekrar dene')),
                    ]),
                  )
                : _notifications.isEmpty
                    ? const Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 22, horizontal: 10),
                        child: Text('Henüz bildiriminiz yok.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _PanelMuted, fontSize: 13)),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _notifications.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Material(
                              color: _isRead(item)
                                  ? Colors.white
                                  : const Color(0xffeff6ff),
                              borderRadius: BorderRadius.circular(11),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(11),
                                onTap: () => _readNotification(item),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item['title']?.toString() ?? '',
                                          style: const TextStyle(
                                              color: _PanelInk,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 3),
                                      Text(item['message']?.toString() ?? '',
                                          style: const TextStyle(
                                              color: _PanelMuted,
                                              fontSize: 12,
                                              height: 1.45)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
          ),
        ),
      ),
    );
  }

  Widget _body(bool compact) {
    if (_page == 'booking' && _selectedBookingField != null) {
      if (_loadingFields) return const _PanelLoading();
      if (_fieldsError != null) {
        return _PanelError(message: _fieldsError!, onRetry: _loadFields);
      }
      return WebBookingFlow(
        field: _selectedBookingField!,
        academy: widget.academy,
        client: widget.client,
        embedded: true,
        onBack: () => setState(() => _selectedBookingField = null),
        onCompleted: _bookingCompleted,
      );
    }
    final padding = compact ? 12.0 : 32.0;
    return RefreshIndicator(
      onRefresh: () async {
        await _loadNotifications();
        if (_page == 'account') {
          await _loadProfile();
        } else if (_page == 'booking') {
          await _loadFields();
        } else {
          await _loadReservations();
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: compact && _page == 'my-reservations'
            ? const EdgeInsets.only(top: 26)
            : EdgeInsets.all(padding),
        children: [
          if (_page == 'overview') _overview(compact),
          if (_page == 'booking') _catalog(compact),
          if (_page == 'my-reservations') _myReservations(compact),
          if (_page == 'account') _account(compact),
        ],
      ),
    );
  }

  Widget _overview(bool compact) {
    final total = _reservations.length;
    final active = _reservations
        .where((r) => r['status'] == 'confirmed' || r['status'] == 'pending')
        .length;
    final spent = _reservations
        .where((r) => r['payment_status'] == 'paid')
        .fold<num>(
            0, (sum, r) => sum + (num.tryParse('${r['total_amount']}') ?? 0));
    final statCards = [
      _statCard(
          'TOPLAM REZERVASYON', '$total', 'Tüm zamanlar', _PanelInk, compact),
      _statCard('AKTİF REZERVASYON', '$active', 'Onaylı & bekleyen', _PanelInk,
          compact),
      _statCard(
          'TOPLAM HARCAMA', _money(spent), 'Ödenen toplam', _PanelInk, compact),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compact)
          ...statCards.expand((card) => [card, const SizedBox(height: 12)])
        else
          LayoutBuilder(builder: (context, constraints) {
            final count = MediaQuery.sizeOf(context).width <= 900 ? 2 : 3;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: statCards
                  .map((card) => SizedBox(
                      width: (constraints.maxWidth - (count - 1) * 16) / count,
                      child: card))
                  .toList(),
            );
          }),
        SizedBox(height: compact ? 8 : 32),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _PanelBorder),
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: compact ? 16 : 24, vertical: compact ? 16 : 20),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Son Rezervasyonlar',
                          style: TextStyle(
                              fontSize: 14,
                              color: _PanelInk,
                              fontWeight: FontWeight.w700)),
                    ),
                    InkWell(
                      onTap: () => _selectPage('my-reservations'),
                      child: const Text('Tümünü Gör →',
                          style: TextStyle(fontSize: 13, color: _PanelInk)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: _PanelBorder),
              if (_loadingReservations)
                const _PanelLoading()
              else if (_reservationsError != null)
                _PanelError(
                    message: _reservationsError!, onRetry: _loadReservations)
              else if (_reservations.isEmpty)
                const _PanelEmpty(
                  emoji: '📋',
                  title: 'Henüz rezervasyon yok',
                  subtitle:
                      'Yeni bir rezervasyon almak için sol menüden "Rezervasyon Al" seçeneğine tıklayın.',
                )
              else
                _reservationsTable(_reservations.take(5).toList(),
                    recent: true, compact: compact),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCard(
      String label, String value, String subtitle, Color color, bool compact) {
    return Container(
      height: compact ? 104 : null,
      padding: EdgeInsets.all(compact ? 16 : 24),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _PanelBorder),
          borderRadius: BorderRadius.circular(compact ? 12 : 24),
          boxShadow: compact
              ? const [
                  BoxShadow(
                      color: Color(0x05000000),
                      blurRadius: 8,
                      offset: Offset(0, 2))
                ]
              : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: _PanelMuted,
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .5)),
          SizedBox(height: compact ? 4 : 8),
          Text(_loadingReservations ? '—' : value,
              style: TextStyle(
                  color: color,
                  fontSize: compact ? 28 : 32,
                  fontWeight: FontWeight.w800,
                  height: compact ? 1.18 : 1.2,
                  letterSpacing: 0)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(color: _PanelMuted, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _myReservations(bool compact) {
    const tabs = {
      'all': 'Tümü',
      'pending': 'Ödeme Bekliyor',
      'confirmed': 'Onaylı',
      'cancelled': 'İptal Edildi',
    };
    final reservations = _filter == 'all'
        ? _reservations
        : _reservations.where((r) => r['status'] == _filter).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, constraints) {
          final compactTabs = compact && constraints.maxWidth < 450;
          final tabWeights = [70, 128, 80, 102];
          final buttons = tabs.entries.toList().asMap().entries.map((entry) {
            final tab = entry.value;
            final active = _filter == tab.key;
            Widget button = Padding(
              padding: EdgeInsets.only(right: entry.key == 3 ? 0 : 4),
              child: Material(
                color: active ? const Color(0xfff1f5f9) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => setState(() => _filter = tab.key),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: compactTabs ? 12 : 18, vertical: 8),
                    child: Text(tab.value,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 14,
                            height: 1.25,
                            color: active ? _PanelInk : _PanelMuted,
                            fontWeight:
                                active ? FontWeight.w600 : FontWeight.w500)),
                  ),
                ),
              ),
            );
            if (compactTabs) {
              button = Expanded(flex: tabWeights[entry.key], child: button);
            }
            return button;
          }).toList();
          final tabsWidget = Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _PanelBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: compactTabs ? MainAxisSize.max : MainAxisSize.min,
              children: buttons,
            ),
          );
          return compactTabs
              ? tabsWidget
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal, child: tabsWidget);
        }),
        const SizedBox(height: 28),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _PanelBorder),
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: _loadingReservations
              ? const _PanelLoading()
              : _reservationsError != null
                  ? _PanelError(
                      message: _reservationsError!, onRetry: _loadReservations)
                  : reservations.isEmpty
                      ? const _PanelEmpty(
                          emoji: '📅', title: 'Rezervasyon bulunamadı')
                      : _reservationsTable(reservations,
                          recent: false, compact: compact),
        ),
      ],
    );
  }

  String _date(Object? value) {
    final raw = value?.toString() ?? '';
    final date =
        DateTime.tryParse(raw.length >= 10 ? raw.substring(0, 10) : raw);
    return date == null
        ? '—'
        : DateFormat('dd MMMM yyyy EEEE', 'tr_TR').format(date);
  }

  Widget _reservationsTable(List<Map<String, dynamic>> rows,
      {required bool recent, required bool compact}) {
    final headers = recent
        ? ['SAHA', 'TARİH', 'SAAT', 'TUTAR', 'DURUM', '']
        : [
            'SAHA',
            'TARİH',
            'SAAT',
            'TÜR/PAKET',
            'SÜRE',
            'TUTAR',
            'DURUM',
            'ÖDEME',
            'İŞLEM'
          ];
    final widths = recent
        ? <double>[130, 168, 106, 142, 118, 150]
        : <double>[130, 168, 106, 188, 156, 142, 118, 126, 150];
    final sum = widths.fold<double>(0, (a, b) => a + b);
    return LayoutBuilder(builder: (context, constraints) {
      final scale = constraints.maxWidth > sum ? constraints.maxWidth / sum : 1;
      Widget cell(Widget child, {bool heading = false, bool last = false}) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: heading ? const Color(0xfff8fafc) : null,
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: heading ? 12 : 14,
              color: heading ? const Color(0xff334155) : _PanelInk,
              fontWeight: heading ? FontWeight.w600 : FontWeight.w400,
              letterSpacing: heading ? .5 : 0,
              height: 1.3,
            ),
            child: Align(alignment: Alignment.centerLeft, child: child),
          ),
        );
      }

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: sum * scale,
          child: Table(
            columnWidths: {
              for (var i = 0; i < widths.length; i++)
                i: FixedColumnWidth(widths[i] * scale)
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: const BoxDecoration(
                    color: Color(0xfff8fafc),
                    border: Border(bottom: BorderSide(color: _PanelBorder))),
                children: headers
                    .map((text) => cell(Text(text), heading: true))
                    .toList(),
              ),
              ...rows.asMap().entries.map((entry) {
                final row = entry.value;
                final notes = row['notes']?.toString() ?? '';
                final duration =
                    num.tryParse(row['duration_hours']?.toString() ?? '') ?? 0;
                final widgets = <Widget>[
                  Text(row['field_name']?.toString() ?? 'Spor alanı',
                      style: TextStyle(
                          fontWeight:
                              recent ? FontWeight.w400 : FontWeight.w700)),
                  Text(_date(row['date'])),
                  _PanelBadge(
                      label: row['time_slot']?.toString() ?? '—',
                      background: const Color(0xffdbeafe),
                      color: const Color(0xff1e40af)),
                  if (!recent) ...[
                    Tooltip(
                      message: notes.isEmpty ? 'Saatlik' : notes,
                      child: Text(
                        notes.isEmpty ? 'Saatlik' : notes.split(' | ').first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(duration > 0
                        ? '${row['duration_hours']} saat'
                        : 'Program belirlenecek'),
                  ],
                  Text(_money(row['total_amount']),
                      style: TextStyle(
                          fontWeight:
                              recent ? FontWeight.w400 : FontWeight.w700)),
                  _statusBadge(row['status']?.toString() ?? ''),
                  if (!recent)
                    _PanelBadge(
                        label: row['payment_status'] == 'paid'
                            ? 'Ödendi'
                            : 'Ödenmedi',
                        background: row['payment_status'] == 'paid'
                            ? const Color(0xffdcfce7)
                            : const Color(0xfffee2e2),
                        color: row['payment_status'] == 'paid'
                            ? const Color(0xff166534)
                            : const Color(0xff991b1b)),
                  const Text('İptal edilemez'),
                ];
                return TableRow(
                  decoration: BoxDecoration(
                    border: entry.key == rows.length - 1
                        ? null
                        : const Border(bottom: BorderSide(color: _PanelBorder)),
                  ),
                  children: widgets
                      .map((widget) =>
                          cell(widget, last: entry.key == rows.length - 1))
                      .toList(),
                );
              }),
            ],
          ),
        ),
      );
    });
  }

  Widget _statusBadge(String status) {
    switch (status) {
      case 'confirmed':
        return const _PanelBadge(
            label: 'Onaylı',
            background: Color(0xffdcfce7),
            color: Color(0xff166534));
      case 'pending':
        return const _PanelBadge(
            label: 'Bekliyor',
            background: Color(0xfffef3c7),
            color: Color(0xff92400e));
      case 'cancelled':
        return const _PanelBadge(
            label: 'İptal',
            background: Color(0xfffee2e2),
            color: Color(0xff991b1b));
      default:
        return _PanelBadge(
            label: status == 'completed' ? 'Tamamlandı' : status,
            background: const Color(0xfff1f5f9),
            color: const Color(0xff475569));
    }
  }

  Widget _catalog(bool compact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Spor alanı seçin',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w700, color: _PanelInk)),
        const SizedBox(height: 6),
        const Text('Rezervasyon yapmak istediğiniz alanı seçerek devam edin.',
            style: TextStyle(fontSize: 13, color: _PanelMuted, height: 1.5)),
        const SizedBox(height: 24),
        if (_loadingFields)
          const _PanelLoading()
        else if (_fieldsError != null)
          _PanelError(message: _fieldsError!, onRetry: _loadFields)
        else if (_fields.isEmpty)
          const _PanelEmpty(emoji: '🏟️', title: 'Henüz spor alanı bulunmuyor')
        else
          LayoutBuilder(builder: (context, constraints) {
            final count = compact
                ? 1
                : MediaQuery.sizeOf(context).width <= 900
                    ? 2
                    : 3;
            final width = (constraints.maxWidth - (count - 1) * 16) / count;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _fields
                  .map((field) =>
                      SizedBox(width: width, child: _fieldCard(field)))
                  .toList(),
            );
          }),
      ],
    );
  }

  String _fieldImage(Map<String, dynamic> field) {
    String image = field['image_url']?.toString() ?? '';
    if (image.isEmpty) {
      final text = field['name'].toString().toLowerCase();
      if (text.contains('inter')) {
        image =
            'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?auto=format&fit=crop&w=900&q=80';
      } else if (text.contains('toplant')) {
        image =
            'https://images.unsplash.com/photo-1497366811353-6870744d04b2?auto=format&fit=crop&w=900&q=80';
      } else if (text.contains('hal') || text.contains('futbol')) {
        image = '/assets/images/football-pitch-card.png';
      } else if (text.contains('teni')) {
        image =
            'https://images.unsplash.com/photo-1622279457486-62dcc4a431d6?auto=format&fit=crop&w=900&q=80';
      } else if (text.contains('voley')) {
        image =
            'https://images.unsplash.com/photo-1592656094267-764a45160876?auto=format&fit=crop&w=900&q=80';
      } else if (text.contains('basket')) {
        image =
            'https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&w=900&q=80';
      } else if (text.contains('dans')) {
        image =
            'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?auto=format&fit=crop&w=900&q=80';
      } else if (text.contains('sanat')) {
        image =
            'https://images.unsplash.com/photo-1460661419201-fd4cecdf8a8b?auto=format&fit=crop&w=900&q=80';
      } else if (text.contains('müz') ||
          text.contains('muz') ||
          (text.contains('m') && text.contains('zik'))) {
        image =
            'https://images.unsplash.com/photo-1511379938547-c1f69419868d?auto=format&fit=crop&w=900&q=80';
      } else if (text.contains('padel')) {
        image =
            'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?q=80&w=900&auto=format&fit=crop';
      } else if (text.contains('havuz')) {
        image =
            'https://images.unsplash.com/photo-1530549387789-4c1017266635?auto=format&fit=crop&w=900&q=80';
      }
    }
    if (!image.startsWith('/site-images/') &&
        !image.startsWith('/assets/images/') &&
        !image.startsWith('https://images.unsplash.com/')) {
      image = '/assets/images/football-pitch-card.png';
    }
    if (image.startsWith('/')) {
      return Uri.parse(_apiBase).resolve(image).toString();
    }
    return image;
  }

  Widget _fieldCard(Map<String, dynamic> field) {
    final name = field['name']?.toString() ?? 'Spor alanı';
    final soon = name.toLowerCase().contains('padel') ||
        name.toLowerCase().contains('havuz');
    final price = soon ? 'YAKINDA' : '${_money(field['price_per_hour'])}/saat';
    return Opacity(
      opacity: soon ? .6 : 1,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _PanelBorder)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: soon ? null : () => _openBooking(field),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 132,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(_fieldImage(field),
                        fit: BoxFit.cover,
                        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                        errorBuilder: (context, error, stack) => Image.asset(
                            'assets/images/football-pitch-card.png',
                            fit: BoxFit.cover)),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [.4, 1],
                          colors: [Colors.transparent, Color(0x730a1e11)],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                            color: const Color(0xebffffff),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(name.replaceAll('YT KAMPUS', '').trim(),
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xff166534),
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: const Color(0xcc000000),
                            border: Border.all(color: const Color(0x4dffd700)),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(price,
                            style: const TextStyle(
                                color: Color(0xffffd700),
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 15,
                            color: _PanelInk,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 32),
                      child: Text(
                          field['description']?.toString() ?? 'Spor alanı',
                          style: const TextStyle(
                              color: _PanelMuted, fontSize: 12, height: 1.35)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(price,
                              style: const TextStyle(
                                  color: _PanelInk,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ),
                        if (!soon)
                          const Text('→',
                              style: TextStyle(
                                  color: _PanelInk,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _account(bool compact) {
    if (_loadingProfile) return const _PanelLoading();
    if (_profileError != null) {
      return _PanelError(message: _profileError!, onRetry: _loadProfile);
    }
    final profile = _accountCard(
      compact: compact,
      title: 'Kişisel bilgiler',
      description:
          'İletişim bilgilerinizi güncel tutun; rezervasyon bildirimleri bu bilgilerle yapılır.',
      child: Form(
        key: _profileForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(builder: (context, constraints) {
              final name = _PanelInput(
                label: 'Ad soyad',
                controller: _name,
                maxLength: 100,
                autofillHints: const [AutofillHints.name],
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? 'Ad soyad en az 2 karakter olmalıdır.'
                    : null,
              );
              final phone = _PanelInput(
                label: 'Telefon',
                hint: '05XX XXX XX XX',
                controller: _phone,
                maxLength: 20,
                keyboard: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
              );
              if (compact || constraints.maxWidth < 360) {
                return Column(children: [
                  name,
                  const SizedBox(height: 11),
                  phone,
                ]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: name),
                  const SizedBox(width: 14),
                  Expanded(child: phone),
                ],
              );
            }),
            if (compact) const SizedBox(height: 11),
            _PanelInput(
              label: 'E-posta',
              controller: _email,
              keyboard: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: (value) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                      .hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Geçerli bir e-posta adresi yazın.',
            ),
            const SizedBox(height: 8),
            _PanelButton(
              label: _savingProfile ? 'Kaydediliyor…' : 'Bilgileri Kaydet',
              onTap: _savingProfile ? null : _saveProfile,
            ),
          ],
        ),
      ),
    );
    final password = _accountCard(
      compact: compact,
      password: true,
      title: 'Şifre değiştir',
      description:
          'Hesabınızı korumak için güçlü ve benzersiz bir şifre kullanın.',
      child: Form(
        key: _passwordForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                  color: const Color(0xffeff6ff),
                  borderRadius: BorderRadius.circular(10)),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🔒', style: TextStyle(fontSize: 12)),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text('Yeni şifreniz en az 8 karakter olmalıdır.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xff426183),
                            height: 1.45)),
                  ),
                ],
              ),
            ),
            _PanelInput(
              label: 'Mevcut şifre',
              controller: _currentPassword,
              password: true,
              autofillHints: const [AutofillHints.password],
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Mevcut şifrenizi yazın.' : null,
            ),
            _PanelInput(
              label: 'Yeni şifre',
              controller: _newPassword,
              password: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: (value) => (value?.length ?? 0) < 8
                  ? 'Yeni şifre en az 8 karakter olmalıdır.'
                  : null,
            ),
            _PanelInput(
              label: 'Yeni şifre tekrar',
              controller: _repeatPassword,
              password: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: (value) => value != _newPassword.text
                  ? 'Yeni şifreler aynı değil.'
                  : null,
            ),
            const SizedBox(height: 8),
            _PanelButton(
              label: _savingPassword ? 'Güncelleniyor…' : 'Şifremi Güncelle',
              secondary: true,
              onTap: _savingPassword ? null : _savePassword,
            ),
          ],
        ),
      ),
    );
    if (compact || MediaQuery.sizeOf(context).width < 950) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [profile, const SizedBox(height: 12), password],
      );
    }
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 11, child: profile),
            const SizedBox(width: 18),
            Expanded(flex: 9, child: password),
          ],
        ),
      ),
    );
  }

  Widget _accountCard({
    required bool compact,
    required String title,
    required String description,
    required Widget child,
    bool password = false,
  }) {
    return Container(
      padding: EdgeInsets.all(compact ? 18 : 24),
      decoration: BoxDecoration(
        color: password ? null : Colors.white,
        gradient: password
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xfff7fbff), Colors.white])
            : null,
        border: Border.all(color: _PanelBorder),
        borderRadius: BorderRadius.circular(compact ? 15 : 18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18, color: _PanelInk, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(description,
              style: const TextStyle(
                  fontSize: 13, color: _PanelMuted, height: 1.5)),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _PanelSquareButton extends StatelessWidget {
  const _PanelSquareButton({
    required this.child,
    required this.onTap,
    required this.label,
    required this.size,
  });
  final Widget child;
  final VoidCallback onTap;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
              side: const BorderSide(color: _PanelBorder),
              borderRadius: BorderRadius.circular(size == 40 ? 11 : 12)),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
                width: size, height: size, child: Center(child: child)),
          ),
        ),
      );
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.label,
    required this.onTap,
    this.secondary = false,
    this.horizontal = 28,
    this.vertical = 14,
    this.fontSize = 16,
    this.radius = 10,
  });

  final String label;
  final VoidCallback? onTap;
  final bool secondary;
  final double horizontal;
  final double vertical;
  final double fontSize;
  final double radius;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? .65 : 1,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                  color: secondary
                      ? const Color(0x0a0f172a)
                      : const Color(0x332563eb),
                  blurRadius: secondary ? 8 : 24,
                  offset: Offset(0, secondary ? 2 : 8)),
            ],
          ),
          child: Material(
            color: secondary ? Colors.white : _PanelBlue,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
                side: secondary
                    ? const BorderSide(color: _PanelBorder)
                    : BorderSide.none),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: horizontal, vertical: vertical),
                child: Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        color: secondary ? _PanelInk : Colors.white,
                        fontSize: fontSize,
                        height: 1.2,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      );
}

class _PanelInput extends StatelessWidget {
  const _PanelInput({
    required this.label,
    required this.controller,
    this.hint,
    this.maxLength,
    this.keyboard,
    this.password = false,
    this.validator,
    this.autofillHints,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final int? maxLength;
  final TextInputType? keyboard;
  final bool password;
  final FormFieldValidator<String>? validator;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff334155))),
            const SizedBox(height: 6),
            TextFormField(
              controller: controller,
              maxLength: maxLength,
              obscureText: password,
              keyboardType: keyboard,
              validator: validator,
              autofillHints: autofillHints,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  height: 1.2,
                  color: _PanelInk),
              decoration: InputDecoration(
                hintText: hint,
                counterText: '',
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _PanelBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _PanelBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _PanelBlue)),
              ),
            ),
          ],
        ),
      );
}

class _PanelBadge extends StatelessWidget {
  const _PanelBadge(
      {required this.label, required this.background, required this.color});
  final String label;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: background, borderRadius: BorderRadius.circular(12)),
        child: Text(label.toUpperCase(),
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: .5,
                color: color)),
      );
}

class _PanelLoading extends StatelessWidget {
  const _PanelLoading();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(40),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Text('Yükleniyor...',
                style: TextStyle(color: _PanelMuted, fontSize: 13)),
          ],
        ),
      );
}

class _PanelEmpty extends StatelessWidget {
  const _PanelEmpty({
    required this.emoji,
    required this.title,
    this.subtitle,
  });
  final String emoji;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _PanelMuted,
                    fontSize: 18.72,
                    fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _PanelMuted, fontSize: 16, height: 1.2)),
            ],
          ],
        ),
      );
}

class _PanelError extends StatelessWidget {
  const _PanelError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _PanelMuted, fontSize: 13)),
            const SizedBox(height: 14),
            _PanelButton(
                label: 'Tekrar dene',
                onTap: onRetry,
                secondary: true,
                fontSize: 13,
                horizontal: 18,
                vertical: 10),
          ],
        ),
      );
}

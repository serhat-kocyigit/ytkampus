part of 'main.dart';

Future<void> showWebLegalDocument(BuildContext context,
    {required bool contract}) async {
  final source = Uri.parse(_apiBase).resolve(contract
      ? '/pages/auth/register.html'
      : '/pages/legal/kvkk-aydinlatma.html');
  await Navigator.of(context).push<void>(MaterialPageRoute(
    builder: (_) => LegalDocumentPage(source: source, contract: contract),
  ));
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) => const WebAuthPage();
}

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});
  @override
  Widget build(BuildContext context) => const WebAuthPage(register: true);
}

class WebAuthPage extends StatefulWidget {
  final bool register;
  final Map<String, dynamic>? initialField;
  final bool nextVideos;
  const WebAuthPage(
      {super.key,
      this.register = false,
      this.initialField,
      this.nextVideos = false});
  @override
  State<WebAuthPage> createState() => _WebAuthPageState();
}

class _WebAuthPageState extends State<WebAuthPage> {
  final _form = GlobalKey<FormState>();
  final _values = <String, TextEditingController>{};
  bool _busy = false, _kvkk = false, _contract = false;
  String? _error, _reference, _blood;
  DateTime? _birthDate;
  late int _captchaA, _captchaB;

  @override
  void initState() {
    super.initState();
    _newCaptcha();
  }

  TextEditingController _controller(String key) =>
      _values.putIfAbsent(key, TextEditingController.new);
  String _value(String key) => _controller(key).text.trim();
  void _newCaptcha() {
    final random = math.Random();
    _captchaA = random.nextInt(20) + 1;
    _captchaB = random.nextInt(20) + 1;
    _controller('captcha').clear();
  }

  bool get _minor {
    if (_birthDate == null) return false;
    final now = DateTime.now();
    var age = now.year - _birthDate!.year;
    if (now.month < _birthDate!.month ||
        (now.month == _birthDate!.month && now.day < _birthDate!.day)) age--;
    return age < 18;
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (widget.register) {
      if (_controller('password').text != _controller('password2').text) {
        setState(() => _error = 'Şifreler eşleşmiyor');
        return;
      }
      if (int.tryParse(_value('captcha')) != _captchaA + _captchaB) {
        setState(() {
          _error = 'Güvenlik doğrulaması hatalı. Lütfen tekrar deneyin.';
          _newCaptcha();
        });
        return;
      }
      if (!_kvkk || !_contract) {
        setState(() => _error = 'Lütfen zorunlu sözleşmeleri onaylayın.');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'email': _value('email'),
      'password': _controller('password').text,
      if (widget.register) ...{
        for (final key in [
          'full_name',
          'phone',
          'city',
          'district',
          'address',
          'health_conditions'
        ])
          key: _value(key),
        'birth_date': _birthDate == null
            ? null
            : DateFormat('yyyy-MM-dd').format(_birthDate!),
        'parent_name': _minor ? _value('parent_name') : '',
        'parent_phone': _minor ? _value('parent_phone') : '',
        'reference_source': _reference ?? '',
        'blood_type': _blood ?? '',
        'kvkk_approved': _kvkk,
        'contract_approved': _contract,
      },
    };
    final result = await api.post(
        widget.register ? '/auth/register' : '/auth/login',
        body: body,
        authenticated: false);
    if (!mounted) return;
    if (result['ok'] != true ||
        result['data'] is! Map ||
        result['data']['token'] == null) {
      setState(() {
        _busy = false;
        _error = result['error'] ?? 'Giriş yapılamadı. Lütfen tekrar deneyin.';
      });
      return;
    }
    final user = Map<String, dynamic>.from(result['data']['user']);
    if (!isMobileCustomer(user)) {
      setState(() {
        _busy = false;
        _error =
            'Yönetici girişleri yalnızca web yönetim panelinden yapılabilir.';
      });
      return;
    }
    await _storage.write(key: 'access_token', value: result['data']['token']);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (_) => widget.nextVideos
                ? WebVideosPage(user: user)
                : WebUserPanel(
                    user: user,
                    initialPage:
                        widget.initialField == null ? 'overview' : 'booking',
                    initialField: widget.initialField)),
        (_) => false);
  }

  Future<void> _legal(bool contract) =>
      showWebLegalDocument(context, contract: contract);

  Widget _field(String key, String label,
          {String? hint,
          bool required = false,
          bool password = false,
          int lines = 1,
          TextInputType? keyboard,
          String? icon}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xff334155),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _controller(key),
            obscureText: password,
            maxLines: lines,
            keyboardType: keyboard,
            textInputAction: password && !widget.register
                ? TextInputAction.done
                : TextInputAction.next,
            onFieldSubmitted:
                password && !widget.register ? (_) => _submit() : null,
            style: const TextStyle(fontSize: 14, height: 1.2, letterSpacing: 0),
            decoration: InputDecoration(
                isDense: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 42, minHeight: 40),
                hintText: hint,
                hintStyle:
                    const TextStyle(color: Color(0xff94a3b8), fontSize: 14),
                prefixIcon: icon == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child:
                            Text(icon, style: const TextStyle(fontSize: 16)))),
            validator: (value) {
              if (required && (value == null || value.trim().isEmpty))
                return 'Bu alan zorunludur';
              if (key == 'email' &&
                  !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value ?? ''))
                return 'Geçerli bir e-posta adresi girin';
              if (widget.register &&
                  key == 'password' &&
                  (value?.length ?? 0) < 8)
                return 'Şifreniz en az 8 karakter olmalıdır';
              return null;
            },
          ),
        ]),
      );

  Widget _section(String text) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Container(
          width: double.infinity,
          padding: const EdgeInsets.only(bottom: 8),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xffe2e8f0)))),
          child: Text(text,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff334155)))));

  Widget _select(String label, String? value, List<String> options,
          ValueChanged<String?> changed) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff334155))),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
                initialValue: value,
                isExpanded: true,
                decoration: const InputDecoration(
                    isDense: true,
                    fillColor: Colors.white,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                hint: Text(
                    label == 'Bizi Nereden Duydunuz?'
                        ? 'Seçiniz (Örn: Instagram, Arkadaş vb.)'
                        : 'Seçiniz',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14)),
                items: options
                    .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(
                            label == 'Kan Grubu'
                                ? v
                                    .replaceAll('+', ' RH+')
                                    .replaceAll('-', ' RH-')
                                : v == 'Arkadaş'
                                    ? 'Arkadaş / Tavsiye'
                                    : v == 'Arama Motoru'
                                        ? 'Google / Arama Motoru'
                                        : v,
                            style: const TextStyle(fontSize: 14))))
                    .toList(),
                onChanged: changed),
          ]));

  @override
  void dispose() {
    for (final controller in _values.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
            child: DefaultTextStyle.merge(
                style: const TextStyle(height: 1.2, letterSpacing: 0),
                child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                          child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight),
                              child: Center(
                                  child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 40),
                                child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                        maxWidth: widget.register ? 720 : 460),
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                              onTap: () =>
                                                  Navigator.pushAndRemoveUntil(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (_) =>
                                                              const WebLandingPage()),
                                                      (_) => false),
                                              child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 32),
                                                  child: Text.rich(
                                                      TextSpan(children: [
                                                        TextSpan(text: 'YT'),
                                                        TextSpan(
                                                            text: 'Kampüs',
                                                            style: TextStyle(
                                                                color: widget
                                                                        .register
                                                                    ? _brand
                                                                    : const Color(
                                                                        0xff0f172a)))
                                                      ]),
                                                      style: const TextStyle(
                                                          fontFamily: 'Inter',
                                                          fontSize: 28,
                                                          fontWeight: FontWeight
                                                              .w900)))),
                                          Container(
                                            padding: EdgeInsets.all(
                                                constraints.maxWidth <= 600
                                                    ? 24
                                                    : 40),
                                            decoration: BoxDecoration(
                                                color: Colors.white,
                                                border: Border.all(
                                                    color: const Color(
                                                        0xffe2e8f0)),
                                                borderRadius:
                                                    BorderRadius.circular(36),
                                                boxShadow: [
                                                  BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                              alpha: widget
                                                                      .register
                                                                  ? 0.05
                                                                  : 0.5),
                                                      blurRadius: 60,
                                                      offset:
                                                          const Offset(0, 24))
                                                ]),
                                            child: Form(
                                                key: _form,
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                          widget.register
                                                              ? 'Kayıt Formu 📝'
                                                              : 'Tekrar Hoş Geldiniz 👋',
                                                          style: TextStyle(
                                                              fontSize: widget
                                                                      .register
                                                                  ? 26
                                                                  : 22,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              height: 1.2)),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                          widget.register
                                                              ? 'Lütfen bilgilerinizi eksiksiz doldurarak kayıt işlemini tamamlayın.'
                                                              : 'Hesabınıza giriş yapın ve sahanızı rezerve edin.',
                                                          style: const TextStyle(
                                                              fontSize: 14,
                                                              color: Color(
                                                                  0xff64748b),
                                                              height: 1.5)),
                                                      const SizedBox(
                                                          height: 32),
                                                      if (_error != null)
                                                        Container(
                                                            width:
                                                                double.infinity,
                                                            margin:
                                                                const EdgeInsets.only(
                                                                    bottom: 20),
                                                            padding:
                                                                const EdgeInsets.all(
                                                                    12),
                                                            decoration: BoxDecoration(
                                                                color: const Color(
                                                                    0xfffef2f2),
                                                                border: Border.all(
                                                                    color: const Color(
                                                                        0xfffecaca)),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                        10)),
                                                            child: Text(_error!,
                                                                style: const TextStyle(
                                                                    color:
                                                                        Color(0xffdc2626),
                                                                    fontSize: 13))),
                                                      if (widget.register) ...[
                                                        _section(
                                                            'Sporcu Bilgileri'),
                                                        _field('full_name',
                                                            'Ad Soyad *',
                                                            hint: 'Ad Soyad',
                                                            required: true),
                                                        const Text(
                                                            'Doğum Tarihi',
                                                            style: TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Color(
                                                                    0xff334155))),
                                                        const SizedBox(
                                                            height: 8),
                                                        InkWell(
                                                            onTap: () async {
                                                              final date = await showDatePicker(
                                                                  context:
                                                                      context,
                                                                  initialDate:
                                                                      _birthDate ??
                                                                          DateTime(
                                                                              2000),
                                                                  firstDate:
                                                                      DateTime(
                                                                          1920),
                                                                  lastDate:
                                                                      DateTime
                                                                          .now());
                                                              if (date !=
                                                                      null &&
                                                                  mounted)
                                                                setState(() =>
                                                                    _birthDate =
                                                                        date);
                                                            },
                                                            child: InputDecorator(
                                                                decoration: const InputDecoration(
                                                                    suffixIcon:
                                                                        Icon(Icons
                                                                            .calendar_month_outlined)),
                                                                child: Text(
                                                                    _birthDate ==
                                                                            null
                                                                        ? 'gg.aa.yyyy'
                                                                        : DateFormat('dd.MM.yyyy').format(
                                                                            _birthDate!),
                                                                    style: const TextStyle(
                                                                        fontSize:
                                                                            14)))),
                                                        const SizedBox(
                                                            height: 20),
                                                      ],
                                                      _field(
                                                          'email',
                                                          widget.register
                                                              ? 'E-Posta *'
                                                              : 'E-Posta',
                                                          hint:
                                                              'ornek@email.com',
                                                          required: true,
                                                          keyboard:
                                                              TextInputType
                                                                  .emailAddress,
                                                          icon: widget.register
                                                              ? null
                                                              : '✉'),
                                                      if (widget.register) ...[
                                                        _field(
                                                            'phone', 'Telefon',
                                                            hint:
                                                                '0555 000 00 00',
                                                            keyboard:
                                                                TextInputType
                                                                    .phone),
                                                        if (_minor) ...[
                                                          _section(
                                                              'Veli Bilgileri (18 Yaş Altı İçin)'),
                                                          _field('parent_name',
                                                              'Veli Ad Soyad *',
                                                              hint:
                                                                  'Anne/Baba/Yakını Adı',
                                                              required: true),
                                                          _field('parent_phone',
                                                              'Veli Telefon *',
                                                              hint:
                                                                  '0555 000 00 00',
                                                              required: true,
                                                              keyboard:
                                                                  TextInputType
                                                                      .phone)
                                                        ],
                                                        _section(
                                                            'Adres & Diğer Bilgiler'),
                                                        _field('city', 'Şehir',
                                                            hint: 'İl'),
                                                        _field(
                                                            'district', 'İlçe',
                                                            hint: 'İlçe'),
                                                        _field('address',
                                                            'Açık Adres (İkamet)',
                                                            hint:
                                                                'Mahalle, Sokak...',
                                                            lines: 2),
                                                        _select(
                                                            'Bizi Nereden Duydunuz?',
                                                            _reference,
                                                            [
                                                              'Instagram',
                                                              'Facebook',
                                                              'Reklam',
                                                              'Arkadaş',
                                                              'Arama Motoru',
                                                              'Diğer'
                                                            ],
                                                            (v) => setState(
                                                                () =>
                                                                    _reference =
                                                                        v)),
                                                        _section(
                                                            'Sağlık Bilgileri'),
                                                        _select(
                                                            'Kan Grubu',
                                                            _blood,
                                                            [
                                                              'A+',
                                                              'A-',
                                                              'B+',
                                                              'B-',
                                                              'AB+',
                                                              'AB-',
                                                              '0+',
                                                              '0-'
                                                            ],
                                                            (v) => setState(
                                                                () => _blood =
                                                                    v)),
                                                        _field(
                                                            'health_conditions',
                                                            'Kronik Rahatsızlık / Alerji',
                                                            hint:
                                                                'Varsa belirtiniz (Yoksa boş bırakın)'),
                                                        _section(
                                                            'Güvenlik & Şifre'),
                                                      ],
                                                      _field(
                                                          'password',
                                                          widget.register
                                                              ? 'Şifre (Giriş İçin) *'
                                                              : 'Şifre',
                                                          hint: widget.register
                                                              ? 'Min. 8 karakter'
                                                              : '••••••••',
                                                          required: true,
                                                          password: true,
                                                          icon: widget.register
                                                              ? null
                                                              : '🔒'),
                                                      if (widget.register) ...[
                                                        _field('password2',
                                                            'Şifre Tekrar *',
                                                            hint:
                                                                'Şifreyi tekrar girin',
                                                            required: true,
                                                            password: true),
                                                        _section(
                                                            'Güvenlik Doğrulaması'),
                                                        Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(16),
                                                            decoration: BoxDecoration(
                                                                border: Border.all(
                                                                    color: const Color(
                                                                        0xffe2e8f0)),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8)),
                                                            child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  const Text(
                                                                      'Gösterilen işlemi çözün:',
                                                                      style: TextStyle(
                                                                          fontSize:
                                                                              14)),
                                                                  const SizedBox(
                                                                      height:
                                                                          8),
                                                                  Text(
                                                                      '$_captchaA + $_captchaB = ?',
                                                                      style: const TextStyle(
                                                                          fontFamily:
                                                                              'monospace',
                                                                          fontSize:
                                                                              24,
                                                                          fontWeight: FontWeight
                                                                              .w900,
                                                                          letterSpacing:
                                                                              4)),
                                                                  const SizedBox(
                                                                      height:
                                                                          12),
                                                                  SizedBox(
                                                                      width:
                                                                          140,
                                                                      child: TextFormField(
                                                                          controller: _controller(
                                                                              'captcha'),
                                                                          keyboardType: TextInputType
                                                                              .number,
                                                                          decoration:
                                                                              const InputDecoration(hintText: 'Cevap'))),
                                                                ])),
                                                        _section('Onaylar'),
                                                        Row(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              SizedBox(
                                                                  width: 28,
                                                                  height: 28,
                                                                  child: Checkbox(
                                                                      value:
                                                                          _kvkk,
                                                                      onChanged:
                                                                          (v) =>
                                                                              setState(() => _kvkk = v ?? false))),
                                                              const SizedBox(
                                                                  width: 12),
                                                              Expanded(
                                                                  child: Wrap(
                                                                      children: [
                                                                    InkWell(
                                                                        onTap: () =>
                                                                            _legal(
                                                                                false),
                                                                        child: const Text(
                                                                            'Kişisel verilerin işlenmesine ilişkin aydınlatma metnini',
                                                                            style: TextStyle(
                                                                                color: _brand,
                                                                                fontSize: 13,
                                                                                decoration: TextDecoration.underline))),
                                                                    const Text(
                                                                        ' okudum. *',
                                                                        style: TextStyle(
                                                                            fontSize:
                                                                                13))
                                                                  ]))
                                                            ]),
                                                        const SizedBox(
                                                            height: 16),
                                                        Row(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              SizedBox(
                                                                  width: 28,
                                                                  height: 28,
                                                                  child: Checkbox(
                                                                      value:
                                                                          _contract,
                                                                      onChanged:
                                                                          (v) =>
                                                                              setState(() => _contract = v ?? false))),
                                                              const SizedBox(
                                                                  width: 12),
                                                              Expanded(
                                                                  child: Wrap(
                                                                      children: [
                                                                    InkWell(
                                                                        onTap: () =>
                                                                            _legal(
                                                                                true),
                                                                        child: const Text(
                                                                            'YT KAMPÜS ÜYELİK KAYIT VE TAAHHÜT METNİNİ',
                                                                            style: TextStyle(
                                                                                color: _brand,
                                                                                fontSize: 13,
                                                                                decoration: TextDecoration.underline))),
                                                                    const Text(
                                                                        ' okudum, şartları kabul ediyor ve onaylıyorum. *',
                                                                        style: TextStyle(
                                                                            fontSize:
                                                                                13,
                                                                            height:
                                                                                1.4))
                                                                  ]))
                                                            ]),
                                                        const SizedBox(
                                                            height: 24),
                                                      ],
                                                      SizedBox(
                                                          width: widget.register
                                                              ? double.infinity
                                                              : 156,
                                                          height: 58,
                                                          child: FilledButton(
                                                              onPressed: _busy
                                                                  ? null
                                                                  : _submit,
                                                              style: FilledButton.styleFrom(
                                                                  shape: RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              16))),
                                                              child: _busy
                                                                  ? const SizedBox(
                                                                      width: 22,
                                                                      height:
                                                                          22,
                                                                      child: CircularProgressIndicator(
                                                                          strokeWidth:
                                                                              2,
                                                                          color: Colors
                                                                              .white))
                                                                  : Text(widget.register ? 'Kayıt İşlemini Tamamla' : 'Giriş Yap',
                                                                      style: const TextStyle(
                                                                          fontSize: 18,
                                                                          fontFamily: 'Outfit',
                                                                          fontWeight: FontWeight.w600)))),
                                                      const SizedBox(
                                                          height: 24),
                                                      Center(
                                                          child: Wrap(
                                                              alignment:
                                                                  WrapAlignment
                                                                      .center,
                                                              children: [
                                                            Text(
                                                                widget.register
                                                                    ? 'Zaten hesabınız var mı? '
                                                                    : 'Hesabınız yok mu? ',
                                                                style: const TextStyle(
                                                                    color: Color(
                                                                        0xff64748b),
                                                                    fontSize:
                                                                        14)),
                                                            InkWell(
                                                                onTap: () => Navigator.pushReplacement(
                                                                    context,
                                                                    MaterialPageRoute(
                                                                        builder: (_) => WebAuthPage(
                                                                            nextVideos: widget
                                                                                .nextVideos,
                                                                            register: !widget
                                                                                .register,
                                                                            initialField: widget
                                                                                .initialField))),
                                                                child: Text(
                                                                    widget.register
                                                                        ? 'Giriş Yapın'
                                                                        : 'Üye Olun',
                                                                    style: const TextStyle(
                                                                        color:
                                                                            _brand,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .w600,
                                                                        fontSize:
                                                                            14)))
                                                          ])),
                                                    ])),
                                          ),
                                        ])),
                              ))),
                        )))),
      );
}

part of 'main.dart';

class WebVideosPage extends StatefulWidget {
  const WebVideosPage({super.key, this.user});
  /// Optional session for navigation; viewing and new clip downloads are public.
  final Map<String, dynamic>? user;

  @override
  State<WebVideosPage> createState() => _WebVideosPageState();
}

class _WebVideosPageState extends State<WebVideosPage> {
  List<Map<String, dynamic>> _fields = [];
  DateTime _date = DateTime.now();
  String? _time, _fieldId, _videoUrl;
  String _caption = '';
  int? _videoId;
  VideoPlayerController? _player;
  bool _searching = false, _clipMode = false;
  String? _error;
  int _duration = 60;
  Duration? _previewEnd;
  final _startMin = TextEditingController(text: '00');
  final _startSec = TextEditingController(text: '00');
  final _endMin = TextEditingController(text: '01');
  final _endSec = TextEditingController(text: '00');
  final List<_VideosClip> _clips = [];
  final _playerKey = GlobalKey();
  final _scroll = ScrollController();

  static const _sample =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4';
  static const _times = [
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00',
    '19:00',
    '20:00',
    '21:00',
    '22:00',
    '23:00',
    '00:00',
    '01:00',
  ];

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  Future<void> _loadFields() async {
    final result = await api.get('/fields');
    if (!mounted) return;
    if (result['ok'] == true && result['data'] is List) {
      setState(() => _fields = (result['data'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList());
    } else {
      setState(() =>
          _error = result['error']?.toString() ?? 'Spor alanları yüklenemedi.');
    }
  }

  @override
  void dispose() {
    _player?.removeListener(_listenPlayer);
    _player?.dispose();
    if (_videoUrl != null) revokeAuthenticatedMediaUrl(_videoUrl!);
    for (final controller in [_startMin, _startSec, _endMin, _endSec]) {
      controller.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _notice(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _search() async {
    if (_searching) return;
    if (_time == null || _fieldId == null) {
      _notice('Lütfen tarih, saat ve spor alanı seçin!');
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    final date = DateFormat('yyyy-MM-dd').format(_date);
    final query = Uri(queryParameters: {
      'date': date,
      'time_slot': _time!,
      'field_id': _fieldId!,
    }).query;
    try {
      final result = await api.get('/videos/search?$query');
      if (!mounted) return;
      if (result['ok'] != true) {
        setState(() =>
            _error = result['error']?.toString() ?? 'Maç videosu aranamadı.');
        return;
      }
      final data = Map<String, dynamic>.from(result['data'] as Map);
      final id = int.tryParse('${data['video_id']}');
      String url;
      if (data['success'] == true && id != null) {
        url = await authenticatedMediaUrl('/videos/$id/content');
      } else {
        url = _sample;
        _notice(
            'Bu tarih ve saat için yüklenmiş bir maç videosu bulunamadı. Örnek video gösteriliyor.');
      }
      if (!mounted) {
        revokeAuthenticatedMediaUrl(url);
        return;
      }
      final token = await _storage.read(key: 'access_token');
      final nextPlayer = VideoPlayerController.networkUrl(Uri.parse(url),
          httpHeaders: !kIsWeb && token != null && url != _sample
              ? {'Authorization': 'Bearer $token'}
              : const {});
      final previousPlayer = _player;
      final previousUrl = _videoUrl;
      _player = nextPlayer;
      _videoUrl = url;
      _videoId = id;
      _previewEnd = null;
      _clips.clear();
      _clipMode = false;
      _caption =
          '$date | $_time | ${_fields.firstWhere((field) => '${field['id']}' == _fieldId)['name']}';
      setState(() {});
      previousPlayer?.removeListener(_listenPlayer);
      await previousPlayer?.dispose();
      if (previousUrl != null) revokeAuthenticatedMediaUrl(previousUrl);
      await nextPlayer.initialize();
      if (!mounted || _player != nextPlayer) return;
      nextPlayer.addListener(_listenPlayer);
      setState(() {});
      nextPlayer.play().catchError((Object _) {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _playerKey.currentContext != null) {
          Scrollable.ensureVisible(_playerKey.currentContext!,
              alignment: .1, duration: const Duration(milliseconds: 350));
        }
      });
    } catch (error) {
      if (mounted)
        setState(() => _error =
            'Video yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _listenPlayer() {
    final player = _player;
    if (!mounted || player == null) return;
    if (_previewEnd != null && player.value.position >= _previewEnd!) {
      _previewEnd = null;
      player.pause();
    }
  }

  int _seconds(TextEditingController minutes, TextEditingController seconds) =>
      (int.tryParse(minutes.text) ?? 0) * 60 +
      (int.tryParse(seconds.text) ?? 0);

  void _durationChanged(int seconds) {
    _duration = seconds;
    final end = _seconds(_startMin, _startSec) + seconds;
    _endMin.text = (end ~/ 60).toString().padLeft(2, '0');
    _endSec.text = (end % 60).toString().padLeft(2, '0');
  }

  bool _validRange(int start, int end) {
    if (start < 0 || end <= start) {
      _notice('Bitiş süresi, başlangıç süresinden büyük olmalıdır!');
      return false;
    }
    if (end - start > 300) {
      _notice('Bir kesit en fazla 5 dakika olabilir.');
      return false;
    }
    final duration = _player?.value.duration.inSeconds ?? 0;
    if (duration > 0 && end > duration) {
      _notice('Kesit aralığı videonun toplam süresini aşamaz.');
      return false;
    }
    return true;
  }

  Future<void> _preview() async {
    final start = _seconds(_startMin, _startSec);
    final end = _seconds(_endMin, _endSec);
    if (!_validRange(start, end) || _player == null) return;
    _previewEnd = Duration(seconds: end);
    await _player!.seekTo(Duration(seconds: start));
    await _player!.play();
  }

  void _saveClip() {
    final start = _seconds(_startMin, _startSec);
    final end = _seconds(_endMin, _endSec);
    if (!_validRange(start, end)) return;
    if (_videoId == null) {
      _notice('Önce yüklenmiş bir maç videosu seçin.');
      return;
    }
    setState(() {
      _clips.insert(0, _VideosClip(_clips.length + 1, _videoId!, start, end));
      _clipMode = false;
    });
  }

  Future<void> _downloadClip(_VideosClip clip) async {
    if (clip.busy) return;
    setState(() => clip.busy = true);
    try {
      final result = await api.post('/videos/public-clips', authenticated: false,
          timeout: const Duration(seconds: 90), body: {
        'video_id': clip.videoId,
        'start': clip.start,
        'end': clip.end,
      });
      if (!mounted) return;
      if (result['ok'] != true || result['data']['success'] != true) {
        _notice(result['error']?.toString() ?? 'Video kesilemedi.');
        return;
      }
      await downloadPublicClip(result['data']['clip_url'].toString(),
          'Mac_Kesiti_${clip.start}s.mp4');
      _notice('Kesit indirme başlatıldı.');
    } catch (error) {
      _notice('Kesit indirilemedi. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => clip.busy = false);
    }
  }

  Future<void> _chooseDate() async {
    final next = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        locale: const Locale('tr', 'TR'));
    if (next != null && mounted) setState(() => _date = next);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xfff7faff),
        body: SafeArea(
            child: Column(children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: _landingBorder))),
              child: Row(children: [
                GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: const SizedBox(
                        width: 26,
                        height: 34,
                        child: Center(
                            child: Text('←',
                                style: TextStyle(
                                    fontSize: 24, color: _landingInk))))),
                const SizedBox(width: 12),
                const _LandingLogo(small: true),
              ])),
          Expanded(
              child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(14, 20, 14, 42),
                  child: Center(
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1160),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _intro(),
                                const SizedBox(height: 22),
                                _searchPanel(),
                                if (_error != null)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 14),
                                      child: Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                              color: const Color(0xfffef2f2),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color:
                                                      const Color(0xfffecaca))),
                                          child: Text(_error!,
                                              style: const TextStyle(
                                                  color: Color(0xff991b1b),
                                                  height: 1.5)))),
                                if (_player != null) ...[
                                  const SizedBox(height: 30),
                                  _videoPlayer(),
                                  const SizedBox(height: 16),
                                  _tools(),
                                ],
                              ]))))),
        ])),
      );

  Widget _intro() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff071a3f), Color(0xff1744a0), Color(0xff2563eb)],
              stops: [0, .64, 1]),
          boxShadow: const [
            BoxShadow(
                color: Color(0x381d4ed8), blurRadius: 42, offset: Offset(0, 22))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
                color: const Color(0x14ffffff),
                border: Border.all(color: const Color(0x33ffffff)),
                borderRadius: BorderRadius.circular(999)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              DecoratedBox(
                  decoration: BoxDecoration(
                      color: Color(0xfffbbf24),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0x26fbbf24), spreadRadius: 4)
                      ]),
                  child: SizedBox(width: 7, height: 7)),
              SizedBox(width: 8),
              Flexible(
                  child: Text('VIDEO HUB · YT KAMPÜS',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xffbfdbfe),
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w800))),
            ])),
        const SizedBox(height: 13),
        const Text('Maç videoların burada.',
            style: TextStyle(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.w700,
                height: 1.2)),
        const SizedBox(height: 8),
        const Text(
            'Futbol, tenis, voleybol ve basketbol dahil; rezervasyon yaptığın tüm spor alanlarının kayıtlarına ulaşabilir, unutulmaz anları kesit olarak kaydedebilirsin.',
            style:
                TextStyle(color: Color(0xffdbeafe), fontSize: 14, height: 1.6)),
        Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
                color: const Color(0x47071225),
                border: Border.all(color: const Color(0x33ffffff)),
                borderRadius: BorderRadius.circular(12)),
            child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🕒', style: TextStyle(fontSize: 11)),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: 'Video kayıtları '),
                            TextSpan(
                                text: '7 gün boyunca',
                                style: TextStyle(
                                    color: Color(0xfffcd34d),
                                    fontWeight: FontWeight.w800)),
                            TextSpan(
                                text:
                                    ' erişime açıktır; süre sonunda otomatik olarak silinir.'),
                          ]),
                          style: TextStyle(
                              color: Color(0xffe0ecff),
                              fontSize: 11,
                              height: 1.45,
                              fontWeight: FontWeight.w600))),
                ])),
      ]));

  Widget _searchPanel() => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _landingBorder),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0d0f172a), blurRadius: 30, offset: Offset(0, 14))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Maçını bul',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: _landingInk)),
        const SizedBox(height: 4),
        const Text('Tarih, saat ve spor alanını seç.',
            style: TextStyle(color: _landingMuted, fontSize: 13)),
        const SizedBox(height: 16),
        _fieldLabel('Tarih Seçin'),
        InkWell(
            onTap: _chooseDate,
            child: InputDecorator(
                decoration: _inputDecoration(),
                child: Row(children: [
                  Expanded(
                      child: Text(DateFormat('dd.MM.yyyy').format(_date),
                          style: const TextStyle(
                              fontSize: 14, color: _landingInk))),
                  const Icon(Icons.calendar_today_outlined,
                      size: 18, color: _landingInk)
                ]))),
        const SizedBox(height: 28),
        _fieldLabel('Saat'),
        DropdownButtonFormField<String>(
            initialValue: _time,
            isExpanded: true,
            decoration: _inputDecoration(),
            hint: const Text('Saat Seçin...', style: TextStyle(fontSize: 14)),
            style: const TextStyle(
                color: _landingInk, fontSize: 14, fontFamily: 'Outfit'),
            items: [
              for (final hour in _times)
                DropdownMenuItem(value: hour, child: Text(hour))
            ],
            onChanged: (value) => setState(() => _time = value)),
        const SizedBox(height: 28),
        _fieldLabel('Spor Alanı'),
        DropdownButtonFormField<String>(
            initialValue: _fieldId,
            isExpanded: true,
            decoration: _inputDecoration(),
            hint: const Text('Spor alanı seçin...',
                style: TextStyle(fontSize: 14)),
            style: const TextStyle(
                color: _landingInk, fontSize: 14, fontFamily: 'Outfit'),
            items: [
              for (final field in _fields)
                DropdownMenuItem(
                    value: '${field['id']}',
                    child: Text('${field['name']}',
                        overflow: TextOverflow.ellipsis))
            ],
            onChanged: (value) => setState(() => _fieldId = value)),
        const SizedBox(height: 28),
        _LandingButton(_searching ? 'Aranıyor…' : 'Maçı Bul',
            onTap: _searching ? () {} : _search),
      ]));

  Widget _fieldLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: _landingText)));

  InputDecoration _inputDecoration() => InputDecoration(
        filled: true,
        fillColor: const Color(0xfff8fafc),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _landingBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _landingBlue)),
      );

  Widget _videoPlayer() => Container(
      key: _playerKey,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: const Color(0xff071225),
          border: Border.all(color: const Color(0x3d2563eb)),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: Color(0x290f172a), blurRadius: 40, offset: Offset(0, 20))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _VideosPlayerView(controller: _player!, caption: _caption),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            color: const Color(0xff0b1f49),
            child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Maç kaydın hazır',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.6,
                          fontWeight: FontWeight.w700)),
                  Text('Önemli anlarını hemen kesit olarak kaydet.',
                      style: TextStyle(
                          color: Color(0xffdbeafe), fontSize: 12, height: 1.6)),
                ])),
      ]));

  Widget _tools() => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: const Color(0xf2ffffff),
          border: Border.all(color: _landingBorder),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0f0f172a), blurRadius: 30, offset: Offset(0, 14))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: const Color(0xffe8f0ff),
                  borderRadius: BorderRadius.circular(14)),
              child: const Text('✂',
                  style: TextStyle(fontSize: 20, color: Color(0xff1d4ed8)))),
          const SizedBox(width: 12),
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Önemli anı kes',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _landingInk)),
                SizedBox(height: 3),
                Text(
                    'Başlangıç ve bitiş zamanını seç, videodan kendi kesitini oluştur.',
                    style: TextStyle(
                        fontSize: 12, color: _landingMuted, height: 1.5)),
              ])),
        ]),
        const SizedBox(height: 16),
        if (!_clipMode)
          _LandingButton('✂️  Kesit Oluştur',
              onTap: () => setState(() => _clipMode = true))
        else
          _clipControls(),
        const SizedBox(height: 18),
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Kliplerim',
              style: TextStyle(
                  color: _landingInk,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          Text('Kaydedilen anlar',
              style: TextStyle(color: _landingMuted, fontSize: 11)),
        ]),
        const SizedBox(height: 9),
        const Divider(height: 1, color: _landingBorder),
        const SizedBox(height: 12),
        if (_clips.isEmpty)
          const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Henüz kesit alınmadı.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _landingMuted, fontSize: 13)))
        else
          for (final clip in _clips)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: const Color(0xfff8fafc),
                        border: Border.all(color: _landingBorder),
                        borderRadius: BorderRadius.circular(14)),
                    child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Kesit #${clip.number}',
                                    style: const TextStyle(
                                        color: _landingInk,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(
                                    'Süre: ${_videosTime(clip.start)} - ${_videosTime(clip.end)}',
                                    style: const TextStyle(
                                        fontSize: 13, color: _landingText)),
                              ]),
                          GestureDetector(
                              onTap:
                                  clip.busy ? null : () => _downloadClip(clip),
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 13, vertical: 9),
                                  decoration: BoxDecoration(
                                      color: _landingBlue.withValues(
                                          alpha: clip.busy ? .7 : 1),
                                      borderRadius: BorderRadius.circular(4)),
                                  child: Text(
                                      clip.busy ? 'Hazırlanıyor…' : 'İndir',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)))),
                        ]))),
      ]));

  Widget _clipControls() => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: const Color(0xfff8fbff),
          border: Border.all(color: const Color(0xffdbeafe)),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Kesit aralığını dakika : saniye biçiminde belirle.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _landingMuted)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: _timeBox('BAŞLANGIÇ', _startMin, _startSec, start: true)),
          const SizedBox(width: 4),
          const Text('→',
              style:
                  TextStyle(color: _landingMuted, fontWeight: FontWeight.w800)),
          const SizedBox(width: 4),
          Expanded(child: _timeBox('BİTİŞ', _endMin, _endSec)),
        ]),
        const SizedBox(height: 14),
        const Text('Hızlı süre seç',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: _landingMuted)),
        const SizedBox(height: 8),
        for (var row = 0; row < 2; row++)
          Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(children: [
                for (var col = 0; col < 2; col++) ...[
                  if (col > 0) const SizedBox(width: 7),
                  Expanded(
                      child: _VideosSmallButton(
                          const [
                            '+15 sn',
                            '+30 sn',
                            '+1 dk',
                            '+2 dk'
                          ][row * 2 + col],
                          onTap: () => setState(() => _durationChanged(
                              const [15, 30, 60, 120][row * 2 + col])))),
                ]
              ])),
        const SizedBox(height: 7),
        _VideosSmallButton('▶ Önizle',
            onTap: _preview, fontSize: 13, padding: 12),
        const SizedBox(height: 9),
        _VideosSmallButton('✂ Kesiti Kaydet',
            onTap: _saveClip, primary: true, fontSize: 13, padding: 12),
      ]));

  Widget _timeBox(String label, TextEditingController minutes,
          TextEditingController seconds, {bool start = false}) =>
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xffdbeafe)),
              borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: .8,
                    color: _landingMuted,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _timeInput(minutes, start: start),
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(':',
                      style: TextStyle(
                          color: _landingText, fontWeight: FontWeight.w800))),
              _timeInput(seconds, start: start, seconds: true),
            ]),
          ]));

  Widget _timeInput(TextEditingController controller,
          {bool start = false, bool seconds = false}) =>
      SizedBox(
          width: 36,
          child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(seconds ? 2 : 3)],
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _landingInk),
              decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xfff8fbff),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 7, horizontal: 1),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xffbfdbfe))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _landingBlue))),
              onChanged: (_) {
                final parsed = int.tryParse(controller.text);
                if (parsed != null &&
                    (parsed < 0 || (seconds && parsed > 59))) {
                  controller.text = (seconds ? parsed.clamp(0, 59) : 0)
                      .toString()
                      .padLeft(2, '0');
                }
                if (start) _durationChanged(_duration);
              },
              onTap: () {
                // Varsayılan 00/01 değerini ilk dokunuşta tamamen seçerek
                // kullanıcının üzerine yazmasını kolaylaştır.
                controller.selection = TextSelection(
                    baseOffset: 0, extentOffset: controller.text.length);
              },
              onEditingComplete: () {
                controller.text = (int.tryParse(controller.text) ?? 0)
                    .toString()
                    .padLeft(2, '0');
                FocusScope.of(context).unfocus();
              }));
}

String _videosTime(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

class _VideosClip {
  _VideosClip(this.number, this.videoId, this.start, this.end);
  final int number, videoId, start, end;
  bool busy = false;
}

class _VideosSmallButton extends StatelessWidget {
  const _VideosSmallButton(this.text,
      {required this.onTap,
      this.primary = false,
      this.fontSize = 11,
      this.padding = 8});
  final String text;
  final VoidCallback onTap;
  final bool primary;
  final double fontSize, padding;
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          padding: EdgeInsets.symmetric(vertical: padding, horizontal: 3),
          decoration: BoxDecoration(
              color: primary ? _landingBlue : Colors.white,
              border:
                  Border.all(color: primary ? _landingBlue : _landingBorder),
              borderRadius: BorderRadius.circular(10)),
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: primary ? Colors.white : _landingInk,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600))));
}

class _VideosPlayerView extends StatefulWidget {
  const _VideosPlayerView(
      {required this.controller,
      required this.caption,
      this.fullscreen = false});
  final VideoPlayerController controller;
  final String caption;
  final bool fullscreen;
  @override
  State<_VideosPlayerView> createState() => _VideosPlayerViewState();
}

class _VideosPlayerViewState extends State<_VideosPlayerView> {
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: widget.controller,
        builder: (context, value, _) => AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(fit: StackFit.expand, children: [
              const ColoredBox(color: Color(0xff071225)),
              if (value.isInitialized)
                Center(
                    child: AspectRatio(
                        aspectRatio: value.aspectRatio,
                        child: VideoPlayer(widget.controller)))
              else
                const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
              if (value.hasError)
                Center(
                    child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Text(
                            'Video oynatılamadı. Tekrar arama yaparak yeniden deneyin.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)))),
              Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: const Color(0xbd071225),
                              border:
                                  Border.all(color: const Color(0x2effffff)),
                              borderRadius: BorderRadius.circular(999)),
                          child: Text(widget.caption,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  letterSpacing: .4,
                                  fontWeight: FontWeight.w600))))),
              if (value.isInitialized)
                Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                        padding: const EdgeInsets.fromLTRB(4, 20, 4, 3),
                        decoration: const BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                              Colors.transparent,
                              Color(0xdd000000)
                            ])),
                        child: Column(children: [
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: VideoProgressIndicator(widget.controller,
                                  allowScrubbing: true,
                                  colors: const VideoProgressColors(
                                      playedColor: _landingBlue,
                                      bufferedColor: Color(0x66ffffff),
                                      backgroundColor: Color(0x33ffffff)))),
                          Row(children: [
                            IconButton(
                                onPressed: () => value.isPlaying
                                    ? widget.controller.pause()
                                    : widget.controller.play(),
                                icon: Icon(
                                    value.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 22),
                                visualDensity: VisualDensity.compact),
                            Text(
                                '${_videosTime(value.position.inSeconds)} / ${_videosTime(value.duration.inSeconds)}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10)),
                            const Spacer(),
                            IconButton(
                                onPressed: () => widget.controller
                                    .setVolume(value.volume == 0 ? 1 : 0),
                                icon: Icon(
                                    value.volume == 0
                                        ? Icons.volume_off
                                        : Icons.volume_up,
                                    color: Colors.white,
                                    size: 20),
                                visualDensity: VisualDensity.compact),
                            IconButton(
                                onPressed: () {
                                  if (widget.fullscreen) {
                                    Navigator.pop(context);
                                    return;
                                  }
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                          builder: (_) => Scaffold(
                                              backgroundColor: Colors.black,
                                              appBar: AppBar(
                                                  backgroundColor: Colors.black,
                                                  foregroundColor: Colors.white,
                                                  title: const Text(
                                                      'Maç Videosu')),
                                              body: Center(
                                                  child: _VideosPlayerView(
                                                      controller:
                                                          widget.controller,
                                                      caption: widget.caption,
                                                      fullscreen: true)))));
                                },
                                icon: Icon(
                                    widget.fullscreen
                                        ? Icons.fullscreen_exit
                                        : Icons.fullscreen,
                                    color: Colors.white,
                                    size: 22),
                                visualDensity: VisualDensity.compact),
                          ]),
                        ]))),
            ])),
      );
}

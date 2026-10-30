part of 'main.dart';

// The mobile web booking screen is the source for this native layout.
class WebBookingFlow extends StatefulWidget {
  final Map<String, dynamic> field;
  final bool academy;
  final Api? client;
  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback? onCompleted;
  const WebBookingFlow(
      {super.key,
      required this.field,
      this.academy = false,
      this.client,
      this.embedded = false,
      this.onBack,
      this.onCompleted});

  @override
  State<WebBookingFlow> createState() => _BookingFlowState();
}

DateTime _bookingTurkeyNow() =>
    DateTime.now().toUtc().add(const Duration(hours: 3));

String _bookingIso(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

bool bookingSlotIsPast(String date, String slot, {DateTime? now}) {
  final turkey = now ?? _bookingTurkeyNow();
  final today = _bookingIso(turkey);
  if (date.compareTo(today) < 0) return true;
  if (date.compareTo(today) > 0) return false;
  final hour = int.parse(slot.substring(0, 2));
  final slotMinutes = hour < 9 ? hour * 60 + 1440 : hour * 60;
  final current = turkey.hour * 60 + turkey.minute;
  final nowMinutes = current < 540 ? current + 1440 : current;
  return slotMinutes <= nowMinutes;
}

class _BookingFlowState extends State<WebBookingFlow> {
  static const _ink = Color(0xff0f172a);
  static const _muted = Color(0xff64748b);
  static const _border = Color(0xffe2e8f0);
  final _summaryKey = GlobalKey();
  late DateTime _start;
  Set<String> _busy = {};
  bool _loading = true;
  bool _paying = false;
  String? _error;
  String? _selectedDate;
  String? _selectedTime;
  _BookingPackage? _package;
  List<Map<String, dynamic>> _schedule = [];
  String? _academyGroup;

  static final _hours = [
    for (var i = 9; i < 24; i++) '${i.toString().padLeft(2, '0')}:00',
    '00:00',
    '01:00',
  ];

  String get _name => '${widget.field['name'] ?? ''}';
  Api get _client => widget.client ?? api;
  num get _price => num.tryParse('${widget.field['price_per_hour']}') ?? 0;
  String _currency(num value) =>
      NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(value);

  @override
  void initState() {
    super.initState();
    final now = _bookingTurkeyNow();
    _start = DateTime(now.year, now.month, now.day);
    if (widget.academy) {
      _loading = false;
    } else {
      _loadWeek();
    }
  }

  Future<void> _loadWeek() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _client.get(
          '/slots/week?field_id=${widget.field['id']}&start_date=${_bookingIso(_start)}');
      if (!mounted) return;
      if (result['ok'] != true) {
        setState(() => _error = '${result['error'] ?? 'Takvim yüklenemedi.'}');
        return;
      }
      final occupied = <String>{};
      for (final dynamic item in result['data']['reservations'] ?? []) {
        final date = '${item['date']}'.substring(0, 10);
        final hour = int.tryParse('${item['time_slot']}'.substring(0, 2));
        if (hour == null) continue;
        final duration = num.tryParse('${item['duration_hours'] ?? 1}') ?? 1;
        for (var i = 0; i < duration; i++) {
          occupied
              .add('$date|${((hour + i) % 24).toString().padLeft(2, '0')}:00');
        }
      }
      setState(() => _busy = occupied);
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Takvim yüklenemedi. Bağlantınızı kontrol edin.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeWeek(int offset) {
    final next = _start.add(Duration(days: offset * 7));
    if (_bookingIso(next).compareTo(_bookingIso(_bookingTurkeyNow())) < 0) {
      return;
    }
    setState(() {
      _start = next;
      _selectedDate = null;
      _selectedTime = null;
    });
    _loadWeek();
  }

  void _selectSlot(String date, String time) {
    if (bookingSlotIsPast(date, time) || _busy.contains('$date|$time')) return;
    setState(() {
      _selectedDate = date;
      _selectedTime = time;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _summaryKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target,
            alignment: .12, duration: const Duration(milliseconds: 300));
      }
    });
  }

  Future<void> _choosePackage(_BookingPackage package) async {
    List<Map<String, dynamic>> selection = [];
    if (package.frequency > 0) {
      final result = await showDialog<List<Map<String, dynamic>>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _BookingScheduleDialog(
          fieldId: widget.field['id'],
          package: package,
          client: _client,
        ),
      );
      if (result == null || !mounted) return;
      selection = result;
    }
    setState(() {
      _package = package;
      _schedule = selection;
      _academyGroup = null;
    });
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pay() async {
    if (_paying) return;
    if (!widget.academy && (_selectedDate == null || _selectedTime == null)) {
      return;
    }
    if (widget.academy && _package == null) return;
    setState(() => _paying = true);
    try {
      Map<String, dynamic> payment;
      if (widget.academy) {
        final package = _package!;
        if (_academyGroup == null) {
          final reservation =
              await _client.post('/reservations/academy', body: {
            'field_id': widget.field['id'],
            'package_name': package.name,
            'duration_hours': package.duration,
            'schedule': _schedule,
            'total_amount': package.price,
          });
          if (reservation['ok'] != true ||
              reservation['data']['success'] != true) {
            if (mounted) {
              _message(
                  '${reservation['error'] ?? 'Takvim oluşturulurken hata oluştu.'}');
            }
            return;
          }
          _academyGroup = '${reservation['data']['group_id']}';
        }
        payment = await _client.post('/payment/academy-checkout', body: {
          'group_id': _academyGroup,
          'total_amount': package.price,
          'package_name': package.name,
        });
      } else {
        payment = await _client.post('/payment/checkout', body: {
          'date': _selectedDate,
          'time_slot': _selectedTime,
          'field_id': widget.field['id'],
          'duration_hours': 1,
        });
      }
      if (!mounted) return;
      if (payment['ok'] != true || payment['data']['success'] != true) {
        _message('${payment['error'] ?? 'Ödeme sistemi yüklenemedi.'}');
        return;
      }
      final data = Map<String, dynamic>.from(payment['data']);
      final intentId = '${data['payment_intent_id'] ?? ''}'.trim();
      final checkoutHtml = '${data['checkoutFormContent'] ?? ''}'.trim();
      if (intentId.isEmpty || checkoutHtml.isEmpty) {
        _message('Ödeme oturumu eksik oluşturuldu. Lütfen tekrar deneyin.');
        return;
      }
      final paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPage(
            html: checkoutHtml,
            intentId: intentId,
          ),
        ),
      );
      if (!mounted) return;
      if (paid == true) {
        if (widget.onCompleted != null) {
          widget.onCompleted!();
        } else {
          Navigator.pop(context, true);
        }
      } else if (!widget.academy) {
        await _loadWeek();
      }
    } catch (_) {
      if (mounted) _message('Bağlantı hatası. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.embedded
      ? _content()
      : Scaffold(
          backgroundColor: const Color(0xfff4f7f9),
          appBar: AppBar(
            backgroundColor: const Color(0xfff8fafc),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text(
                widget.academy ? 'Akademi & Abonelik' : 'Yeni Rezervasyon',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: _border),
            ),
          ),
          body: _content(),
        );

  Widget _content() => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _paying
                  ? null
                  : () {
                      if (_package != null) {
                        setState(() {
                          _package = null;
                          _academyGroup = null;
                        });
                      } else if (widget.onBack != null) {
                        widget.onBack!();
                      } else {
                        Navigator.pop(context);
                      }
                    },
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xff2563b9),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 12)),
              child: Text(
                  widget.academy
                      ? '← Saha Seçimine Dön'
                      : '← Tüm spor alanları',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
          if (widget.academy && _package == null) ..._academyCards(),
          if (!widget.academy) _mainCard(),
          if (!widget.academy) const SizedBox(height: 24),
          if (_selectedTime != null || _package != null)
            _summary()
          else if (!widget.academy)
            _emptySummary(),
          const SizedBox(height: 24),
        ],
      );

  Widget _panel(
          {required Widget child,
          EdgeInsets padding = const EdgeInsets.all(20)}) =>
      Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(24),
        ),
        child: child,
      );

  Widget _mainCard() => _panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            for (var index = 0; index < 3; index++) ...[
              if (index > 0)
                const SizedBox(width: 16, child: Divider(color: _border)),
              Expanded(
                  child: Row(children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: Color(0xffe8f5eb), shape: BoxShape.circle),
                  child: Text('${index + 1}',
                      style: const TextStyle(
                          color: Color(0xff15803d),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Flexible(
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(['Saha', 'Zaman', 'Onay'][index],
                            style: const TextStyle(
                                fontSize: 12,
                                color: _muted,
                                fontWeight: FontWeight.w600)))),
              ])),
            ],
          ]),
          const SizedBox(height: 24),
          const Text('Rezervasyon bilgileri',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16, color: _ink)),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xffdcecdf)),
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                  colors: [Color(0xfff7fcf8), Color(0xffeff8f1)]),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SEÇİLEN SPOR ALANI',
                  style: TextStyle(
                      fontSize: 11,
                      color: _muted,
                      letterSpacing: .66,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text('$_name · ${_currency(_price)}/saat',
                  style: const TextStyle(
                      color: _ink,
                      fontSize: 17,
                      height: 1.35,
                      fontWeight: FontWeight.w700)),
              if ('${widget.field['description'] ?? ''}'.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text('${widget.field['description']}',
                    style: const TextStyle(
                        fontSize: 12, color: _muted, height: 1.45)),
              ],
            ]),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: Transform.translate(
              offset: const Offset(-8, 0),
              child: LayoutBuilder(
                  builder: (context, constraints) => OverflowBox(
                      fit: OverflowBoxFit.deferToChild,
                      alignment: Alignment.centerLeft,
                      minWidth: constraints.maxWidth + 16,
                      maxWidth: constraints.maxWidth + 16,
                      child: _weekCard())),
            ),
          ),
        ]),
      );

  Widget _weekCard() {
    final dates =
        List.generate(7, (index) => _start.add(Duration(days: index)));
    final range =
        '${DateFormat('dd MMM', 'tr_TR').format(dates.first)} – ${DateFormat('dd MMM yyyy', 'tr_TR').format(dates.last)}';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14224a80), blurRadius: 24, offset: Offset(0, 10))
        ],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
            Color(0xff0b2e74),
            Color(0xff1555c0),
            Color(0xff2573e8)
          ])),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('🗓️', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Haftalık doluluk takvimi',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(_name,
                      style: const TextStyle(
                          color: Color(0xffc1d1eb), fontSize: 11)),
                ])),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          color: const Color(0xfff8fbff),
          child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info, size: 18, color: Color(0xff90b1e5)),
                SizedBox(width: 9),
                Expanded(
                    child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: '09:00–02:00',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xff24466f))),
                          TextSpan(
                              text:
                                  ' arasında, 1 saatlik rezervasyon yapabilirsiniz. Onaylanan rezervasyonlar iptal edilemez.'),
                        ]),
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xff60728d),
                            height: 1.45))),
              ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: const BoxDecoration(
              color: Colors.white,
              border: Border.symmetric(
                  horizontal: BorderSide(color: Color(0xffe7eef8)))),
          child: Row(children: [
            _navButton(
                '←',
                'Önceki hafta',
                _bookingIso(_start)
                            .compareTo(_bookingIso(_bookingTurkeyNow())) <=
                        0
                    ? null
                    : () => _changeWeek(-1)),
            Expanded(
                child: Text(range,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xff163a70),
                        fontSize: 11,
                        fontWeight: FontWeight.w800))),
            _navButton('→', 'Sonraki hafta', () => _changeWeek(1), next: true),
          ]),
        ),
        if (_loading)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Haftalık takvim yükleniyor…',
                  style: TextStyle(color: _muted, fontSize: 13)))
        else if (_error != null)
          Padding(
              padding: const EdgeInsets.all(18),
              child: Column(children: [
                Text(_error!,
                    style: const TextStyle(color: _muted, fontSize: 13)),
                TextButton(
                    onPressed: _loadWeek, child: const Text('Tekrar dene')),
              ]))
        else ...[
          Table(
            columnWidths: const {0: FixedColumnWidth(46)},
            border: TableBorder.all(color: const Color(0xffedf2f7), width: 1),
            children: [
              TableRow(children: [
                _dayHead('SAAT'),
                for (final date in dates)
                  _dayHead(DateFormat('E', 'tr_TR').format(date).toUpperCase(),
                      number: date.day.toString().padLeft(2, '0')),
              ]),
              for (final time in _hours)
                TableRow(children: [
                  Container(
                      height: 44,
                      color: const Color(0xfff8faff),
                      alignment: Alignment.center,
                      child: Text(time,
                          style: const TextStyle(
                              color: Color(0xff60738e),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.3))),
                  for (final date in dates) _slotCell(_bookingIso(date), time),
                ]),
            ],
          ),
          if (_busy.isNotEmpty) _busySummary(),
        ],
      ]),
    );
  }

  Widget _navButton(String label, String tooltip, VoidCallback? onTap,
          {bool next = false}) =>
      Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 36,
            height: 36,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                side: BorderSide(
                    color: next
                        ? const Color(0xffcfe0fa)
                        : const Color(0xffd9e5f5)),
                backgroundColor: next ? const Color(0xffedf4ff) : Colors.white,
                foregroundColor: const Color(0xff1e5cc4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9)),
              ),
              onPressed: onTap,
              child: Text(label, style: const TextStyle(fontSize: 17)),
            ),
          ));

  Widget _dayHead(String title, {String? number}) => Container(
        height: 54,
        color: const Color(0xfff5f8fd),
        padding: const EdgeInsets.only(top: 9),
        child: Column(children: [
          Text(title,
              style: const TextStyle(
                  color: Color(0xff70819a),
                  fontSize: 8,
                  fontWeight: FontWeight.w700)),
          if (number != null) ...[
            const SizedBox(height: 3),
            Text(number,
                style: const TextStyle(
                    color: Color(0xff183b6d),
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ]),
      );

  Widget _slotCell(String date, String time) {
    final past = bookingSlotIsPast(date, time);
    final busy = _busy.contains('$date|$time');
    final selected = _selectedDate == date && _selectedTime == time;
    final background = past
        ? const Color(0xfff3f6fa)
        : busy
            ? const Color(0xfffff1f1)
            : selected
                ? const Color(0xffe4efff)
                : const Color(0xfff0fcf4);
    return Semantics(
      label:
          '$date $time ${past ? 'Geçti' : busy ? 'Dolu' : selected ? 'Seçili' : 'Müsait'}',
      button: !past && !busy,
      child: Tooltip(
        message: '$date $time ${past ? 'Geçti' : busy ? 'Dolu' : 'Müsait'}',
        child: InkWell(
          onTap: past || busy || _paying ? null : () => _selectSlot(date, time),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: background,
                border: selected
                    ? Border.all(color: const Color(0xff2870e5), width: 2)
                    : null),
            child: past
                ? const Text('—',
                    style: TextStyle(color: Color(0xffa6b2c2), fontSize: 15))
                : busy
                    ? const Text('×',
                        style: TextStyle(
                            color: Color(0xffd95353),
                            fontSize: 17,
                            fontWeight: FontWeight.w800))
                    : Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? const Color(0xff2870e5)
                                : const Color(0xff26b864),
                            boxShadow: [
                              BoxShadow(
                                  color: selected
                                      ? const Color(0x242870e5)
                                      : const Color(0x2126b864),
                                  spreadRadius: 4)
                            ])),
          ),
        ),
      ),
    );
  }

  Widget _busySummary() {
    final sorted = _busy.toList()..sort();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: const Color(0xfffff8f8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: const Color(0xffffe4e4),
                borderRadius: BorderRadius.circular(9)),
            child: const Text('!',
                style: TextStyle(
                    color: Color(0xffd94d4d), fontWeight: FontWeight.w700))),
        const SizedBox(width: 11),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Bu haftadaki dolu saatler',
              style: TextStyle(
                  color: Color(0xffa93a3a),
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Bu zamanlar seçilemez.',
              style: TextStyle(color: Color(0xff9a6565), fontSize: 10)),
          const SizedBox(height: 7),
          Wrap(spacing: 5, runSpacing: 5, children: [
            for (final value in sorted)
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xfff7cccc)),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(
                      '${DateFormat('dd MMM', 'tr_TR').format(DateTime.parse(value.split('|').first))} · ${value.split('|').last}',
                      style: const TextStyle(
                          color: Color(0xffb94646),
                          fontSize: 9,
                          fontWeight: FontWeight.w800))),
          ]),
        ])),
      ]),
    );
  }

  Widget _emptySummary() => _panel(
        child: SizedBox(
            height: 188,
            child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: const Color(0xffecf8ee),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Text('👈', style: TextStyle(fontSize: 24))),
              const SizedBox(height: 14),
              const Text('Saat Seçin',
                  style: TextStyle(
                      color: _ink, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const SizedBox(
                  width: 230,
                  child: Text('Ödeme yapabilmek için önce tarih ve saat seçin.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: _muted, fontSize: 13, height: 1.5))),
            ]))),
      );

  Widget _summary() => Container(
        key: _summaryKey,
        child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(16)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Rezervasyon özeti',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, color: _ink)),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: const Color(0xfff4fbf5),
                    border: Border.all(color: const Color(0xffd7ecda)),
                    borderRadius: BorderRadius.circular(13)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Seçilen zaman',
                          style: TextStyle(color: _muted, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                          widget.academy
                              ? '$_name · ${_package!.name}'
                              : '$_selectedDate · $_selectedTime · 1 saat',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _ink)),
                      const SizedBox(height: 9),
                      Text(_currency(widget.academy ? _package!.price : _price),
                          style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              color: _ink)),
                      if (widget.academy && _schedule.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        for (final slot in _schedule)
                          Text(
                              '${[
                                'Pazartesi',
                                'Salı',
                                'Çarşamba',
                                'Perşembe',
                                'Cuma',
                                'Cumartesi',
                                'Pazar'
                              ][(slot['day'] as int) - 1]} · ${slot['time']} · ${_package!.duration} saat',
                              style: const TextStyle(
                                  fontSize: 12, color: _muted, height: 1.6)),
                      ],
                    ]),
              ),
              const SizedBox(height: 24),
              Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                      color: const Color(0xfffff7ed),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text(
                      'Önemli: Onaylanan rezervasyonlar iptal veya iade edilemez. Lütfen tarih ve saatinizi kontrol ederek devam edin.',
                      style: TextStyle(
                          color: Color(0xff9a3412),
                          fontSize: 12,
                          height: 1.45))),
              const SizedBox(height: 12),
              SizedBox(
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff0284c7),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: _paying ? null : _pay,
                    child: _paying
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white)),
                                SizedBox(width: 10),
                                Text('İşleniyor...'),
                              ])
                        : Text(
                            widget.academy
                                ? 'İyzico ile Aboneliği Başlat'
                                : 'İyzico ile Güvenli Öde',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                  )),
            ])),
      );

  List<Widget> _academyCards() => [
        Text('$_name Akademi & Abonelik Paketleri',
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 6),
        const Text(
            'Size en uygun abonelik paketini seçerek rezervasyon talebinizi oluşturun.',
            style: TextStyle(fontSize: 13, color: _muted, height: 1.5)),
        const SizedBox(height: 20),
        for (final package in _BookingPackage.forField(_name)) ...[
          _packageCard(package),
          const SizedBox(height: 20),
        ],
        if (_name.toLowerCase().contains('dans'))
          _panel(
              child: const Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: 'HALK OYUNLARI BÖLÜMÜ: ',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(
                        text:
                            'İLK DANS  |  ZEYBEK  |  ORYANTAL  |  OYUN HAVALARI'),
                  ]),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: _muted, height: 1.7))),
      ];

  Widget _packageCard(_BookingPackage package) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            color: package.kids ? const Color(0xffeff6ff) : Colors.white,
            border: Border.all(
                color: package.kids ? const Color(0xff93c5fd) : _border),
            borderRadius: BorderRadius.circular(12)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: package.kids ? _brand : const Color(0xfff8fafc),
                  border: const Border(bottom: BorderSide(color: _border))),
              child: Text(package.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color:
                          package.kids ? Colors.white : const Color(0xff1d4ed8),
                      fontSize: 18,
                      fontWeight: FontWeight.w700))),
          Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Text(package.frequencyText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: _ink,
                        fontSize: 14,
                        height: 1.8,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(package.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: _muted, fontSize: 14, height: 1.8)),
                const SizedBox(height: 24),
                Text(
                    '${package.perPerson ? 'Aylık Kişi Başı' : 'Aylık'}: ${NumberFormat('#,##0', 'tr_TR').format(package.price)} TL',
                    style: const TextStyle(
                        color: Color(0xff1d4ed8),
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ])),
          Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                  color: Color(0xfffafafa),
                  border: Border(top: BorderSide(color: _border))),
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: _brand,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: () => _choosePackage(package),
                child: Text(
                    package.name == 'Resim Grup Dersleri'
                        ? 'GÜN VE SAAT SEÇ'
                        : 'BU PAKETİ SEÇ',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              )),
        ]),
      );
}

class _BookingPackage {
  final String name;
  final String title;
  final int frequency;
  final int duration;
  final int price;
  final String frequencyText;
  final String description;
  final bool perPerson;
  final bool kids;
  const _BookingPackage(this.name, this.title, this.frequency, this.duration,
      this.price, this.frequencyText, this.description,
      {this.perPerson = false, this.kids = false});

  static List<_BookingPackage> forField(String name) {
    final field = name.toLowerCase();
    if (field.contains('dans')) {
      return const [
        _BookingPackage(
            'Dans Özel Ders (Haftada 2)',
            'ÖZEL DERS',
            2,
            2,
            16000,
            "Haftada 2 Gün / 2'şer Saat",
            'Ayda 8 Seans\nDilediğiniz gün ve saatlerde'),
        _BookingPackage(
            'Dans Özel Ders (Haftada 3)',
            'ÖZEL DERS (YOĞUN)',
            3,
            3,
            24000,
            "Haftada 3 Gün / 3'er Saat",
            'Ayda 12 Seans\nDilediğiniz gün ve saatlerde'),
        _BookingPackage(
            'Dans Grup (Haftada 2)',
            'GRUP DERSLERİ',
            0,
            2,
            8000,
            "Haftada 2 Gün / 2'şer Saat",
            'Ayda 8 Seans (3-12 Kişilik Gruplar)\nBelirlenen gün ve saatlerde',
            perPerson: true),
        _BookingPackage(
            'Dans Grup (Haftada 3)',
            'GRUP DERSLERİ (YOĞUN)',
            0,
            3,
            12000,
            "Haftada 3 Gün / 3'er Saat",
            'Ayda 12 Seans (3-12 Kişilik Gruplar)\nBelirlenen gün ve saatlerde',
            perPerson: true),
      ];
    }
    if (field.contains('sanat') || field.contains('resim')) {
      return const [
        _BookingPackage(
            'Resim Özel Ders',
            'ÖZEL DERS',
            2,
            1,
            15000,
            'Haftada 2 Gün / Ayda 8 Seans',
            'Dilediğiniz gün ve saatlerde\nDüzenli şekilde resim eğitimi'),
        _BookingPackage(
            'Resim Grup Dersleri',
            'GRUP DERSLERİ',
            2,
            1,
            8000,
            'Haftada 2 Gün / Ayda 8 Seans',
            'Dilediğiniz gün ve saatlerde\nDüzenli şekilde resim eğitimi\n5–15 kişilik gruplar',
            perPerson: true),
      ];
    }
    return const [
      _BookingPackage(
          'Özel Ders',
          'ÖZEL DERS',
          2,
          1,
          16000,
          'Haftada 2 Gün / Ayda 8 Seans',
          'Dilediğiniz gün ve saatlerde\nKişiye özel düzenli eğitim'),
      _BookingPackage(
          '2 Kişilik Grup',
          '2 KİŞİLİK',
          2,
          1,
          12000,
          'Haftada 2 Gün / Ayda 8 Seans',
          'Dilediğiniz gün ve saatlerde\nİki kişilik düzenli eğitim',
          perPerson: true),
      _BookingPackage(
          '3 Kişilik Grup',
          '3 KİŞİLİK',
          2,
          1,
          10000,
          'Haftada 2 Gün / Ayda 8 Seans',
          'Dilediğiniz gün ve saatlerde\nÜç kişilik düzenli eğitim',
          perPerson: true),
      _BookingPackage(
          'Grup Eğitimi',
          'GRUP EĞİTİMİ',
          0,
          1,
          8000,
          'Haftada 2 Gün / Ayda 8 Seans',
          'Belirlenen gün ve saatlerde\n3-8 Kişilik grup eğitimleri',
          perPerson: true),
      _BookingPackage(
          'Çocuk Akademi',
          'ÇOCUK AKADEMİ (KAPSAMLI)',
          0,
          1,
          8000,
          'Haftada 2 Gün / Ayda 8 Seans Spor Eğitimi',
          'Ekstra Hizmetler:\nAyda 8 Seans İngilizce Eğitimi\nAyda 4 Seans Diyetisyen Kontrolü\nTüm Aileye Diyetisyen Desteği\n(Belirlenen gün ve saatlerde 3-8 kişilik gruplar)',
          perPerson: true,
          kids: true),
    ];
  }
}

class _BookingScheduleDialog extends StatefulWidget {
  final dynamic fieldId;
  final _BookingPackage package;
  final Api client;
  const _BookingScheduleDialog(
      {required this.fieldId, required this.package, required this.client});
  @override
  State<_BookingScheduleDialog> createState() => _BookingScheduleDialogState();
}

class _BookingScheduleDialogState extends State<_BookingScheduleDialog> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _availability = {};
  final List<Map<String, dynamic>> _selected = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await widget.client.get(
          '/slots/recurring?field_id=${widget.fieldId}&duration_hours=${widget.package.duration}');
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (result['ok'] == true && result['data']['success'] == true) {
          _availability =
              Map<String, dynamic>.from(result['data']['availability']);
        } else {
          _error = '${result['error'] ?? 'Takvim yüklenemedi.'}';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Takvim yüklenemedi.';
        });
      }
    }
  }

  void _toggle(int day, String time) {
    final index = _selected
        .indexWhere((slot) => slot['day'] == day && slot['time'] == time);
    if (index < 0 && _selected.length >= widget.package.frequency) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Zaten ${widget.package.frequency} adet seçim yaptınız!')));
      return;
    }
    setState(() {
      if (index < 0) {
        _selected.add({'day': day, 'time': time});
      } else {
        _selected.removeAt(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final complete = _selected.length == widget.package.frequency;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: 620, maxHeight: MediaQuery.sizeOf(context).height - 48),
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Expanded(
                    child: Text('Paket Gün & Saat Seçimi',
                        style: TextStyle(
                            color: Color(0xff1d4ed8),
                            fontSize: 20,
                            fontWeight: FontWeight.w700))),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xff999999))),
              ]),
              const SizedBox(height: 10),
              Text(
                  'Lütfen ${widget.package.frequency} adet uygun saat seçin (Süre: ${widget.package.duration} Saat)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xff1d4ed8),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const Text('🟩 Müsait     🟥 Dolu',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 15),
              if (_loading)
                const Padding(
                    padding: EdgeInsets.all(30),
                    child: Column(children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text('Takvim uygunluğu kontrol ediliyor...')
                    ]))
              else if (_error != null)
                Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red)))
              else
                Flexible(
                    child: SingleChildScrollView(
                        child: Table(
                  columnWidths: const {0: FixedColumnWidth(42)},
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(children: [
                      _cellText('Saat', header: true),
                      for (final day in [
                        'Pzt',
                        'Sal',
                        'Çar',
                        'Per',
                        'Cum',
                        'Cmt',
                        'Paz'
                      ])
                        _cellText(day, header: true),
                    ]),
                    for (var hour = 9; hour < 24; hour++)
                      TableRow(children: [
                        _cellText('${hour.toString().padLeft(2, '0')}:00'),
                        for (var day = 1; day <= 7; day++)
                          _scheduleCell(
                              day, '${hour.toString().padLeft(2, '0')}:00'),
                      ]),
                  ],
                ))),
              const SizedBox(height: 20),
              Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('İptal'))),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: _brand,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    onPressed: complete
                        ? () => Navigator.pop(context, _selected)
                        : null,
                    child: Text(
                        complete
                            ? 'Programı Onayla ve Ödemeye Geç'
                            : 'Seçim Bekleniyor (${_selected.length}/${widget.package.frequency})',
                        textAlign: TextAlign.center),
                  )),
            ])),
      ),
    );
  }

  Widget _cellText(String text, {bool header = false}) => Container(
      height: header ? 34 : 40,
      alignment: Alignment.center,
      child: Text(text,
          style: TextStyle(
              fontSize: 10,
              color: header ? const Color(0xff253650) : const Color(0xff888888),
              fontWeight: header ? FontWeight.w700 : FontWeight.w400)));

  Widget _scheduleCell(int day, String time) {
    final free = _availability['$day']?[time] == true;
    final selected =
        _selected.any((slot) => slot['day'] == day && slot['time'] == time);
    return Padding(
        padding: const EdgeInsets.all(2),
        child: InkWell(
          onTap: free ? () => _toggle(day, time) : null,
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: selected
                    ? _brand
                    : free
                        ? const Color(0xffe6f4ea)
                        : const Color(0xfffce8e6),
                border: Border.all(
                    color: selected
                        ? _brand
                        : free
                            ? const Color(0xffceead6)
                            : const Color(0xfffad2cf)),
                borderRadius: BorderRadius.circular(4)),
            child: Text(
                selected
                    ? '✓'
                    : free
                        ? 'Seç'
                        : 'Dolu',
                style: TextStyle(
                    fontSize: 10,
                    color: selected
                        ? Colors.white
                        : free
                            ? const Color(0xff1e8e3e)
                            : const Color(0xffd93025))),
          ),
        ));
  }
}

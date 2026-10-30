import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yt_kampus_mobile/main.dart';

const _user = {
  'id': 7,
  'full_name': 'Mobil Kullanıcı',
  'email': 'mobil@example.invalid',
  'phone': '05551112233',
  'avatar_color': '#2563eb',
};

const _reservations = [
  {
    'id': 1,
    'field_name': 'Onaylı Saha',
    'date': '2026-10-20T00:00:00.000Z',
    'time_slot': '15:00',
    'duration_hours': 1,
    'total_amount': '1000.00',
    'status': 'confirmed',
    'payment_status': 'paid',
  },
  {
    'id': 2,
    'field_name': 'Bekleyen Saha',
    'date': '2026-10-19',
    'time_slot': '16:00',
    'duration_hours': 1,
    'total_amount': '500.00',
    'status': 'pending',
    'payment_status': 'unpaid',
  },
  {
    'id': 3,
    'field_name': 'İptal Saha',
    'date': '2026-10-18',
    'time_slot': '17:00',
    'duration_hours': 1,
    'total_amount': '750.00',
    'status': 'cancelled',
    'payment_status': 'unpaid',
  },
];

class _PanelFixture {
  final requests = <http.Request>[];
  final notifications = <Map<String, dynamic>>[
    {
      'id': 44,
      'title': 'Rezervasyon onaylandı',
      'message': '20 Ekim 2026 Salı · 15:00. Rezervasyonunuz onaylandı.',
      'is_read': 0,
    },
  ];

  late final client = Api(client: MockClient((request) async {
    requests.add(request);
    Object body;
    switch ('${request.method} ${request.url.path}') {
      case 'GET /api/reservations/my':
        body = _reservations;
      case 'GET /api/fields':
        body = [];
      case 'GET /api/notifications':
        body = notifications;
      case 'GET /api/auth/me':
        body = _user;
      case 'PATCH /api/notifications/44/read':
        notifications.single['is_read'] = 1;
        body = {'success': true};
      case 'PATCH /api/auth/me':
        body = {
          'success': true,
          'user': {..._user, ...jsonDecode(request.body) as Map},
        };
      case 'PATCH /api/auth/password':
        body = {'success': true};
      default:
        fail('Unexpected panel request: ${request.method} ${request.url}');
    }
    return http.Response.bytes(utf8.encode(jsonEncode(body)), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
  }));
}

Future<void> _showPanel(WidgetTester tester, _PanelFixture fixture,
    {String page = 'overview', double width = 390}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(fontFamily: 'Inter'),
    home: WebUserPanel(user: _user, initialPage: page, client: fixture.client),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  for (final width in [320.0, 390.0]) {
    testWidgets('panel and left menu fit ${width.toInt()}px', (tester) async {
      final fixture = _PanelFixture();
      await _showPanel(tester, fixture, width: width);
      expect(tester.takeException(), isNull);
      expect(find.text('TOPLAM REZERVASYON'), findsOneWidget);
      expect(find.text('AKTİF REZERVASYON'), findsOneWidget);
      expect(find.text('TOPLAM HARCAMA'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('₺1.000,00'), findsNWidgets(2));
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(
          fixture.requests.every((request) => request.method == 'GET'), isTrue,
          reason: 'Viewing the panel cannot modify reservations.');

      await tester.tap(find.bySemanticsLabel('Menüyü aç'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Kullanıcı Paneli'), findsOneWidget);
      expect(find.text('Hesabım'), findsOneWidget);
      expect(find.text('Çıkış Yap'), findsOneWidget);
      await tester.tap(find.text('Rezervasyonlarım'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Ödeme Bekliyor'), findsOneWidget);
      expect(find.text('İptal Edildi'), findsOneWidget);
      await tester.tap(find.text('Onaylı'));
      await tester.pumpAndSettle();
      expect(find.text('Onaylı Saha'), findsOneWidget);
      expect(find.text('Bekleyen Saha'), findsNothing);
      expect(find.text('İptal Saha'), findsNothing);
      expect(find.text('İptal edilemez'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
          fixture.requests.every((request) => request.method == 'GET'), isTrue);
    });
  }

  testWidgets('notifications use the backend unread flag and read endpoint',
      (tester) async {
    final fixture = _PanelFixture();
    await _showPanel(tester, fixture);
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Bildirimler'));
    await tester.pumpAndSettle();
    expect(find.text('Rezervasyon onaylandı'), findsOneWidget);
    await tester.tap(find.text('Rezervasyon onaylandı'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsNothing);
    final mutation = fixture.requests.where((r) => r.method != 'GET').single;
    expect(mutation.method, 'PATCH');
    expect(mutation.url.path, '/api/notifications/44/read');
    expect(mutation.headers['X-YT-Kampus-Client'], 'mobile');
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile and password send the same payloads as the website',
      (tester) async {
    final fixture = _PanelFixture();
    await _showPanel(tester, fixture, page: 'account');
    expect(tester.takeException(), isNull);
    expect(find.text('Kişisel bilgiler'), findsOneWidget);
    expect(find.text('Mobil Kullanıcı'), findsOneWidget);
    final inputs = find.byType(TextFormField);
    await tester.enterText(inputs.at(0), 'Yeni Kullanıcı');
    await tester.enterText(inputs.at(1), '05559998877');
    await tester.enterText(inputs.at(2), 'yenimobil@example.invalid');
    await tester.ensureVisible(find.text('Bilgileri Kaydet'));
    await tester.tap(find.text('Bilgileri Kaydet'));
    await tester.pumpAndSettle();
    final profile = fixture.requests
        .where((r) => r.method == 'PATCH' && r.url.path == '/api/auth/me')
        .single;
    expect(jsonDecode(profile.body), {
      'full_name': 'Yeni Kullanıcı',
      'phone': '05559998877',
      'email': 'yenimobil@example.invalid',
    });
    // Let the successful-save toast leave before interacting with the bottom
    // password button, just as a user can after its normal display duration.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Şifre değiştir'));
    await tester.enterText(inputs.at(3), 'oldPassword9');
    await tester.enterText(inputs.at(4), 'newPassword10');
    await tester.enterText(inputs.at(5), 'wrongPassword');
    await tester.ensureVisible(find.text('Şifremi Güncelle'));
    await tester.tap(find.text('Şifremi Güncelle'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni şifreler aynı değil.'), findsOneWidget);
    expect(fixture.requests.where((r) => r.url.path == '/api/auth/password'),
        isEmpty);
    await tester.enterText(inputs.at(5), 'newPassword10');
    await tester.ensureVisible(find.text('Şifremi Güncelle'));
    await tester.tap(find.text('Şifremi Güncelle'));
    await tester.pumpAndSettle();
    final password = fixture.requests
        .where((r) => r.url.path == '/api/auth/password')
        .single;
    expect(password.method, 'PATCH');
    expect(jsonDecode(password.body), {
      'current_password': 'oldPassword9',
      'password': 'newPassword10',
    });
    expect(tester.takeException(), isNull);
  });
}

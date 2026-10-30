import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:yt_kampus_mobile/main.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('Istanbul booking hours shared with the mobile website', () {
    test(
        'hour starts exactly now are unavailable, later hours remain selectable',
        () {
      final now = DateTime(2026, 10, 16, 15, 0);
      expect(bookingSlotIsPast('2026-10-16', '14:00', now: now), isTrue);
      expect(bookingSlotIsPast('2026-10-16', '15:00', now: now), isTrue);
      expect(bookingSlotIsPast('2026-10-16', '16:00', now: now), isFalse);
      expect(bookingSlotIsPast('2026-10-17', '09:00', now: now), isFalse);
      expect(bookingSlotIsPast('2026-10-15', '23:00', now: now), isTrue);
    });

    test('00:00 and 01:00 follow 23:00 in the same dated business-day grid',
        () {
      final now = DateTime(2026, 10, 16, 23, 30);
      expect(bookingSlotIsPast('2026-10-16', '23:00', now: now), isTrue);
      expect(bookingSlotIsPast('2026-10-16', '00:00', now: now), isFalse);
      expect(bookingSlotIsPast('2026-10-16', '01:00', now: now), isFalse);
    });

    test(
        'after midnight the website uses its current ISO date and overnight order',
        () {
      final now = DateTime(2026, 10, 17, 0, 30);
      expect(bookingSlotIsPast('2026-10-17', '00:00', now: now), isTrue);
      expect(bookingSlotIsPast('2026-10-17', '01:00', now: now), isFalse);
      expect(bookingSlotIsPast('2026-10-17', '09:00', now: now), isTrue);
      expect(bookingSlotIsPast('2026-10-16', '01:00', now: now), isTrue);
      expect(bookingSlotIsPast('2026-10-18', '09:00', now: now), isFalse);
    });

    test('09:00 starts the next daytime ordering boundary', () {
      expect(
          bookingSlotIsPast('2026-10-17', '09:00',
              now: DateTime(2026, 10, 17, 8, 59)),
          isTrue);
      expect(
          bookingSlotIsPast('2026-10-17', '10:00',
              now: DateTime(2026, 10, 17, 9, 0)),
          isFalse);
      expect(
          bookingSlotIsPast('2026-10-17', '09:00',
              now: DateTime(2026, 10, 17, 9, 0)),
          isTrue);
    });
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('hourly calendar and selected summary fit ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final requests = <http.Request>[];
      final client = Api(client: MockClient((request) async {
        requests.add(request);
        expect(request.method, 'GET',
            reason: 'Rendering and selecting must never start a payment.');
        expect(request.url.path, '/api/slots/week');
        expect(request.url.queryParameters['field_id'], '1');
        return http.Response(jsonEncode({'reservations': []}), 200);
      }));

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'Outfit'),
        home: WebBookingFlow(field: const {
          'id': 1,
          'name': 'Futbol Sahası',
          'price_per_hour': '4000.00',
          'description': 'Kapalı, UEFA Standartlarında profesyonel saha',
        }, client: client),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Rezervasyon bilgileri'), findsOneWidget);
      expect(find.text('Haftalık doluluk takvimi'), findsOneWidget);
      expect(find.text('01:00'), findsOneWidget);
      expect(requests, hasLength(1));

      final start =
          DateTime.parse(requests.single.url.queryParameters['start_date']!);
      final tomorrow =
          DateFormat('yyyy-MM-dd').format(start.add(const Duration(days: 1)));
      final available = find.byTooltip('$tomorrow 09:00 Müsait');
      await tester.ensureVisible(available);
      await tester.pumpAndSettle();
      await tester.tap(available);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Rezervasyon özeti'), 400);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Rezervasyon özeti'), findsOneWidget);
      expect(find.text('$tomorrow · 09:00 · 1 saat'), findsOneWidget);
      expect(find.text('₺4.000,00'), findsOneWidget);
      expect(find.text('İyzico ile Güvenli Öde'), findsOneWidget);
      expect(requests, hasLength(1),
          reason:
              'Choosing a slot is a local selection, not a payment request.');
    });

    testWidgets('academy cards and group summary fit ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = Api(client: MockClient((request) async {
        fail(
            'Group package selection must not create a reservation or payment.');
      }));

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'Outfit'),
        home: WebBookingFlow(field: const {
          'id': 5,
          'name': 'Dans Akademisi',
          'price_per_hour': 400,
        }, academy: true, client: client),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('ÖZEL DERS (YOĞUN)'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('GRUP DERSLERİ'), 300);
      final groupCard = find
          .ancestor(
              of: find.text('GRUP DERSLERİ'), matching: find.byType(Container))
          .last;
      final chooseGroup = find.descendant(
          of: groupCard,
          matching: find.widgetWithText(FilledButton, 'BU PAKETİ SEÇ'));
      await tester.ensureVisible(chooseGroup);
      await tester.pumpAndSettle();
      await tester.tap(chooseGroup);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
          find.text('Dans Akademisi · Dans Grup (Haftada 2)'), findsOneWidget);
      expect(find.text('₺8.000,00'), findsOneWidget);
      expect(find.text('İyzico ile Aboneliği Başlat'), findsOneWidget);
    });
  }
}

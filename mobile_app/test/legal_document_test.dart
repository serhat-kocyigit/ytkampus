import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yt_kampus_mobile/legal_document.dart';

void main() {
  final kvkk =
      File('../frontend/pages/legal/kvkk-aydinlatma.html').readAsStringSync();
  final contract =
      File('../frontend/pages/auth/register.html').readAsStringSync();

  test('KVKK web kaynağının tüm bölümleri ve veri tablosu korunur', () {
    final document = parseLegalDocument(kvkk, contract: false);
    expect(document.querySelector('h1')!.text,
        'Kişisel Verilerin İşlenmesi ve Maç Videoları Hakkında Aydınlatma Metni');
    expect(document.querySelectorAll('h2'), hasLength(11));
    expect(document.querySelectorAll('table tr'), hasLength(6));
    expect(
        document.text, contains('Güncel metin Platform üzerinden yayımlanır.'));
    expect(document.text, contains('YT Kampüs Spor ve Sanat Merkezi'));
    expect(document.text, isNot(contains('class="')));
    expect(document.text, isNot(contains('← Ana sayfaya dön')));
  });

  test('Üyelik metni gerçek modalın tamamını alır, form veya eski KVKK eklemez',
      () {
    final document = parseLegalDocument(contract, contract: true);
    expect(document.querySelectorAll('h4'), hasLength(5));
    expect(document.querySelectorAll('li'), hasLength(9));
    expect(document.text, contains('Saygıdeğer Üye Adayımız,'));
    expect(document.text,
        contains('dijital olarak imzalamış ve taahhüt etmiş sayılıyorum.'));
    expect(document.text,
        isNot(contains('KİŞİSEL VERİLERİN KORUNMASI POLİTİKASI')));
    expect(document.text, isNot(contains('Güvenlik Doğrulaması')));
    expect(document.text, isNot(contains('class="modal-overlay"')));
  });

  for (final width in [320.0, 390.0]) {
    for (final isContract in [false, true]) {
      testWidgets(
          '$width px ${isContract ? 'üyelik' : 'KVKK'} UTF8 yüklenir ve sonuna kayar',
          (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final path = isContract
            ? '/pages/auth/register.html'
            : '/pages/legal/kvkk-aydinlatma.html';
        final client = MockClient((request) async {
          expect(request.url.path, path);
          return http.Response.bytes(
            utf8.encode(isContract ? contract : kvkk),
            200,
            headers: {'content-type': 'text/html'},
          );
        });
        await tester.pumpWidget(MaterialApp(
          home: LegalDocumentPage(
            source: Uri.parse('http://localhost:8085$path'),
            contract: isContract,
            client: client,
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.textContaining('Saygıdeğer', findRichText: true),
            isContract ? findsOneWidget : findsNothing);
        if (!isContract) expect(find.byType(Table), findsOneWidget);
        final scrollable = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const ValueKey('legal-document-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(scrollable.position.maxScrollExtent, greaterThan(0));
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pump();
        final ending = isContract
            ? 'dijital olarak imzalamış ve taahhüt etmiş sayılıyorum.'
            : 'Güncel metin Platform üzerinden yayımlanır.';
        final last = find.textContaining(ending, findRichText: true);
        expect(last, findsOneWidget);
        expect(tester.getRect(last).bottom, lessThanOrEqualTo(844));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Metin yüklenemezse tekrar denemek gerçek kaynağı yeniden yükler',
      (tester) async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return requests == 1
          ? http.Response('error', 503)
          : http.Response.bytes(utf8.encode(kvkk), 200);
    });
    await tester.pumpWidget(MaterialApp(
      home: LegalDocumentPage(
        source:
            Uri.parse('http://localhost:8085/pages/legal/kvkk-aydinlatma.html'),
        contract: false,
        client: client,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Tekrar dene'), findsOneWidget);
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('Tekrar dene'), findsNothing);
    expect(find.byType(Table), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yt_kampus_mobile/main.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('API bağlantı hatasını kullanıcıya gösterilebilir sonuç olarak döndürür',
      () async {
    final api = Api(
        client: MockClient((_) async => throw http.ClientException('offline')));
    final result = await api.get('/fields', authenticated: false);
    expect(result['ok'], false);
    expect(result['error'], contains('bağlantısı'));
  });

  test('API hatalı JSON yanıtında çökmez', () async {
    final api = Api(
        client:
            MockClient((_) async => http.Response('<html>502</html>', 502)));
    final result = await api.get('/fields', authenticated: false);
    expect(result['ok'], false);
    expect(result['error'], contains('geçerli'));
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('$width piksel giriş formu taşmaz ve boş bilgileri kabul etmez',
        (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: WebAuthPage()));
      await tester.tap(find.widgetWithText(FilledButton, 'Giriş Yap'));
      await tester.pump();
      expect(find.text('Bu alan zorunludur'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$width piksel kayıt formunda webdeki tüm alan ve onaylar var',
        (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester
          .pumpWidget(const MaterialApp(home: WebAuthPage(register: true)));
      for (final label in [
        'Sporcu Bilgileri',
        'Adres & Diğer Bilgiler',
        'Sağlık Bilgileri',
        'Güvenlik & Şifre',
        'Güvenlik Doğrulaması',
        'Onaylar'
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byType(Checkbox), findsNWidgets(2));
      final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
      expect(boxes.every((box) => box.value == false), true);
      expect(tester.takeException(), isNull);
    });
  }
}

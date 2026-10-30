import 'dart:ui_web' as ui_web;
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

int _checkoutSequence = 0;

Widget buildWebCheckout(String html, String baseUrl) {
  final viewType = 'yt-kampus-checkout-${_checkoutSequence++}';
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int id) {
    // İyzico Checkout Form, webde olduğu gibi ana belgeye eklenmelidir. Iframe
    // kullanıldığında sağlayıcının yüklediği betik formu oluşturamıyor ve boş
    // hata sayfası görünüyor.
    final host = web.HTMLDivElement()
      ..title = 'İyzico Güvenli Ödeme'
      ..innerHTML = html.toJS;
    host.style.width = '100%';
    host.style.height = '100%';
    host.style.overflowY = 'auto';
    host.style.overflowX = 'hidden';
    host.style.setProperty('touch-action', 'pan-y');
    host.style.setProperty('-webkit-overflow-scrolling', 'touch');
    final paymentStyle = web.HTMLStyleElement()
      ..textContent = '''
        #iyzipay-checkout-form { max-width: 100%; min-height: 1100px; }
        #iyzipay-checkout-form iframe {
          display: block;
          width: 100% !important;
          min-height: 1100px !important;
          height: 1100px !important;
          border: 0;
        }
      ''';
    host.append(paymentStyle);

    // innerHTML ile eklenen script etiketleri çalışmaz. Web panelindeki akışla
    // aynı şekilde bunları çalıştırılabilir yeni etiketler olarak ekliyoruz.
    final scripts = host.querySelectorAll('script');
    for (var index = 0; index < scripts.length; index++) {
      final source = scripts.item(index);
      if (source is! web.HTMLScriptElement) continue;
      final script = web.HTMLScriptElement()..type = source.type;
      if (source.src.isNotEmpty) {
        script.src = source.src;
      } else {
        script.text = source.text;
      }
      web.document.body?.append(script);
    }
    return host;
  });
  return HtmlElementView(viewType: viewType);
}

String createWebMediaUrl(Uint8List bytes, String mime) =>
    web.URL.createObjectURL(
        web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime)));

void revokeWebMediaUrl(String url) {
  if (url.startsWith('blob:')) web.URL.revokeObjectURL(url);
}

void saveWebMediaBytes(Uint8List bytes, String name, String mime) {
  final url = createWebMediaUrl(bytes, mime);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body!.append(link);
  link.click();
  link.remove();
  Future<void>.delayed(
      const Duration(minutes: 1), () => revokeWebMediaUrl(url));
}

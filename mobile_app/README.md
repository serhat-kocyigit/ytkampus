# YT Kampüs Mobil

Bu uygulama mevcut `backend/server.js` API'sine bağlanır. Skorboard uygulamanın kapsamı dışındadır.

## Yerelde çalıştırma

Flutter araç zinciri hazır olduğunda:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8085/api
```

`10.0.2.2`, Android emülatöründen bilgisayarınızdaki `localhost` adresine erişir. Bu bilgisayardaki fiziksel cihaz geliştirme adresi şu anda `http://10.196.19.41:8085/api` olarak ayarlı. Telefon ve bilgisayar aynı Wi-Fi ağında olmalıdır. Ağ değişirse uygulamayı `--dart-define=API_BASE_URL=http://YENI_IP:8085/api` ile başlatın. Canlıda yalnızca HTTPS alan adını kullanın.

Uygulama; giriş/kayıt, saha listesi, saat seçimiyle rezervasyon, tesiste veya İyzico WebView ile online ödeme, rezervasyonlarım, profil, bildirimler ve yönetim ekranlarını aynı API üzerinden kullanır. Skorboard için hiçbir ekran veya API çağrısı yoktur.

## Yönetici özellikleri

- Canlı istatistik özeti
- Rezervasyonları görüntüleme ve durum güncelleme
- Üye veya yönetici hesabı oluşturma
- Kullanıcıyı etkin/pasif yapma
- Saha saatlik ücretini güncelleme

## Mobil web ile eşleştirilen kullanıcı ekranları

Ana sayfa, webdeki bütün spor alanları ve akademiler, galeri, iletişim, giriş ve ayrıntılı kayıt formu; kullanıcı panelindeki genel bakış, sol menü, saha kataloğu, haftalık rezervasyon takvimi, rezervasyon filtreleri, bildirimler, kişisel bilgiler ve şifre değiştirme ekranları Flutter widget'larıyla uygulanmıştır. Maç videolarında tarih/saat/saha araması, yetkili video oynatma ve kesit araçları vardır. Görsel adresleri `/api/site-images` ve `/api/fields` üzerinden web ile aynı kaynaklardan okunur; Outfit ve Inter yazı tipleri uygulamayla paketlenir.

`lib/web_landing.dart`, `lib/web_user_panel.dart`, `lib/web_booking.dart`, `lib/web_auth.dart` ve `lib/web_videos.dart` kullanıcı arayüzünü içerir. Web ödeme formu tarayıcıya uygun gömülü görünümde, Android ödeme formu WebView içinde açılır; ödeme durumu sunucudan doğrulanır.

## Bilgisayarda test

```powershell
flutter pub get
flutter test
flutter build web --no-wasm-dry-run --pwa-strategy=none
python -m http.server 5180 --bind 127.0.0.1 --directory build/web
```

Son komutu çalıştıran pencere açık kalmalıdır. Uygulama: `http://127.0.0.1:5180`. Tarayıcıda API varsayılan olarak `http://localhost:8085/api` adresidir. Yerel backend'in Docker üzerinden çalışması gerekir.

Mobil web referansları ve karşılaştırmalar `visual_reference/index.html` dosyasındadır. Galeriyi aynı sunucuda açmak için derlemeden sonra `Copy-Item -Recurse -Force visual_reference build/web/visual-reference` çalıştırın; `http://127.0.0.1:5180/visual-reference/` adresini açın.

320 ve 390 pikseldeki takvim/akademi, panel/menü, profil/şifre, bildirim, giriş/kayıt doğrulama ve bağlantı hatası testleri `test/` klasöründedir. Testler gerçek rezervasyon veya ödeme oluşturmaz. Yönetici ekranları önceki sürümdeki iş akışlarını korur; görsel eşleştirme ana sayfa ve kullanıcı paneli içindir.

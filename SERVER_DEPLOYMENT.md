# YT Kampüs ve Skorboard sunucu kurulumu

Bu depo iki bağımsız uygulamayı aynı Docker ağı üzerinde çalıştırır:

| Alan adı | Uygulama | Docker servisi |
| --- | --- | --- |
| `ytkampus.com` ve `www.ytkampus.com` | YT Kampüs rezervasyon sistemi | `frontend` + `backend` |
| `scoreboard.ytkampus.com` | Halı saha skorboard sistemi | `scoreboard` + `scoreboard_db` |

Skorboard kaynak kodu `scoreboard/` klasöründedir. Kendi MySQL veritabanını (`scoreboard_db_data`) ve yükleme alanını (`scoreboard_uploads`) kullanır; rezervasyon sisteminin veritabanına dokunmaz.

## Canlıya alma öncesi

Sunucudaki `.env` dosyasında aşağıdaki değerler benzersiz ve güçlü parolalarla tanımlanmalıdır:

```env
SCOREBOARD_DB_PASSWORD=benzersiz-guclu-parola
SCOREBOARD_DB_ROOT_PASSWORD=farkli-benzersiz-guclu-parola
PAYMENT_BASE_URL=https://ytkampus.com
CORS_ORIGIN=https://ytkampus.com
```

Ardından uygulamalar aynı komutla çalışır:

```bash
docker compose up -d --build
```

## DNS ve HTTPS

Sunucunun IP adresine aşağıdaki A kayıtları yönlendirilmelidir:

```text
ytkampus.com              -> sunucu IP adresi
www.ytkampus.com          -> sunucu IP adresi
scoreboard.ytkampus.com   -> sunucu IP adresi
```

Nginx yapılandırmasında iki alan adı için HTTP yönlendirmesi hazırdır. Canlıya çıkarken 80/443 portları ve SSL sertifikaları sunucu tarafında etkinleştirilmelidir. Sertifika sonrası HTTP trafiği HTTPS'e yönlendirilmelidir.

## Yerel doğrulama

DNS beklemeden skorboard yönlendirmesi aşağıdaki Host başlığıyla doğrulanabilir:

```bash
curl -H "Host: scoreboard.ytkampus.com" http://localhost:8085/
```

Bu istek skorboard ana sayfasını döndürmelidir. Socket.IO bağlantıları da Nginx üzerinden WebSocket başlıklarıyla skorboard uygulamasına iletilir.

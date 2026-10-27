# UstaX API v1

Temel yol `/api/v1`. Yanıtlar JSON. Çalışanlar HttpOnly oturum çerezi veya `Authorization: Bearer <token>` kullanır. Takip uç noktaları yalnızca 256-bit müşteri takip anahtarı kullanır. Servis numarasıyla sorgu yoktur. API anahtarı veya takip anahtarı loglanmamalıdır. Tarayıcı yazma istekleri aynı origin olmalıdır. Mobil istekler Bearer kullanmalıdır. API sürümü URL içinde sabittir; gelecekte `/api/v2` ayrılabilir.

## Hatalar

`{ "error": "Kullanıcıya açıklanabilir mesaj" }`. 400 giriş/kod hatası, 401 giriş gerekli, 403 yetki/kaynak hatası, 404 kayıt/bağlantı yok, 409 süreç veya revision çakışması, 429 istek sınırı, 502 dış servis hatası, 503 yapılandırma/bağlantı hatası. Zod doğrulama hatalarında `fields` alanı da döner. İstemci 409 aldığında kaydı yeniden okuyup kullanıcı kararını tekrar istemelidir.

## Uç noktalar

| Yöntem ve yol | Yetki | Sonuç / gövde |
|---|---|---|
| GET `/health` | Herkes | Yapılandırma bayrakları; canlı sağlık denetimi değil |
| GET `/me` | Çalışan | Aktif personel kimliği ve rolü |
| GET `/records` | Çalışan | Servis kayıtları dizisi; UI arama/sıralama yapar |
| POST `/records` | Çalışan | Kabul formu; 201 `{data,token}`; token yalnızca burada görünür |
| GET `/records/{id}` | Çalışan | Tam servis aggregate'ı |
| GET `/customers` | Çalışan | Yeniden kullanılabilir müşteri listesi |
| PATCH `/records/{id}/status` | Çalışan | `{status}`; süreç koşulları uygulanır |
| PATCH `/records/{id}/notes` | Çalışan | `{text,internal:boolean}` |
| PATCH `/records/{id}/email` | Çalışan | `{email}`; takip kaydındaki doğrulama adresini günceller |
| PATCH `/records/{id}/quote` | Çalışan | Yeni teklif sürümü oluşturur; önceki teklif değişmez |
| PATCH `/records/{id}/complete` | Çalışan | `{work,parts,fee,warranty}`; onaylı toplamla eşleşir; hazır aşamasına geçer |
| PATCH `/records/{id}/deliver` | Çalışan | `{note}`; sunucu teslim saatini kaydeder |
| POST `/records/{id}/rotate` | Yönetici | `{token}`; eski müşteri bağlantısını iptal eder |
| POST `/records/{id}/photos` | Çalışan | multipart `file`, `phase`, `visible`; güncel kayıt döner |
| PATCH `/records/{id}/photos` | Çalışan | `{id,visible:boolean}`; fotoğraf görünürlüğü |
| GET `/photos/{recordId}/{photoId}` | Çalışan | Korumalı fotoğraf binary |
| GET `/photos/track/{photoId}?token={token}` | Müşteri | Yalnızca paylaşılan fotoğraf binary |
| GET `/track/{token}` | Müşteri | Güvenli müşteri izdüşümü; iç not/kimlik bilgisi yok |
| POST `/track/{token}/code` | Müşteri | `{}`; gerçek e-posta gönderimi; `{challengeId,message}` |
| POST `/track/{token}/decision` | Müşteri | `{challengeId,code,version,decision}` |
| GET `/users` | Yönetici | Personel listesi |
| POST `/users` | Yönetici | `{name,email,role,password}`; rol `admin` veya `technician` |
| PATCH `/users` | Yönetici | `{id,active? ,role?}`; kendi hesabını değiştiremez |
| POST `/tokens` | Yönetici | `{staffId,days}`; 1–30 gün; `{token,warning}` |
| DELETE `/tokens` | Yönetici | `{staffId}`; çalışanın tüm mobil anahtarlarını iptal eder |

## Kabul gövdesi

```json
{
  "name": "Örnek Müşteri",
  "phone": "+905550000000",
  "email": "musteri@example.com",
  "kind": "Telefon",
  "brand": "Apple",
  "model": "iPhone 14 Pro",
  "serial": "",
  "fault": "Ekran kırık ve dokunmatik çalışmıyor.",
  "condition": "Kasa üzerinde hafif çizikler",
  "accessories": "Şarj kablosu",
  "technician": "Örnek Teknisyen",
  "receivedAt": "2026-10-19T10:00:00.000Z"
}
```

Telefon boşluk/parantezlerden arındırılır. Aynı normalize telefon müşteri kaydını yeniden kullanır. Aynı müşteri + girilmiş seri numarası varsa cihaz yeniden kullanılır; seri yoksa farklı cihazlar aynı modelden dolayı birleştirilmez. Telefonun ülke kodu ile/olmadan yazılması aynı kabul edilmez; ilk sürümde tutarlı ülke koduyla kayıt önerilir.

## Teklif

```json
{
  "diagnosis": "OLED panel hasarlı",
  "work": "Ekran değişimi ve kalibrasyon",
  "parts": [{ "name": "OLED ekran", "amount": 350000 }],
  "labor": 75000,
  "eta": "2026-10-22"
}
```

Tüm para alanları **kuruş** tamsayısıdır. Toplam sunucuda hesaplanır. Teklif sürümü sunucuda artar. Yeni teklif önceki onayı geçersiz kılar; yeni toplam onaylanmadan tamir başlatılamaz. Tamamlanmış veya iptal edilmiş kayıt için yeni teklif yasaktır.

Karar `approved` veya `rejected`. Kod yalnızca geçerli kayıt, teklif sürümü, challenge ve süre ile kullanılır. Aynı kararın tekrarı `{ok:true,alreadyRecorded:true}` döner; aksi karar 409 döner. Aynı karar yanıtında yeni bir değişiklik yapılmaz; bu nedenle ikinci yanıtta kod tekrar tüketilmez. Karar zamanı ve sürümü teklif içinde, olay geçmişiyle birlikte saklanır.

## Durumlar

Teslim alındı → İnceleniyor → Fiyat onayı bekliyor → Tamir ediliyor → Teslime hazır → Teslim edildi.

Tamir/parça bekleniyor arasında yalnızca onaylı teklifle geçilir. Teklif reddedildi müşteri kararından oluşur; çalışan müşteri yerine reddetmiş gibi kayıt oluşturamaz. İnceleme/onay/tamir/parça aşamalarından iptal mümkündür. Teslim edildi ve İptal edildi terminaldir. Tamire başlamadan güncel teklifin approved olması, hazır öncesi tamamlama verisi ve teslim öncesi teslim tarihi zorunludur.

## Sınırlar ve mobil

İlk sürümde liste sonlu bir işletmenin tüm kayıtlarını döndürür; büyük veri için API pagination ve sunucu araması henüz uygulanmamıştır. Dosya JPEG/PNG/WebP en fazla 8 MB. İstek sınırları PostgreSQL'de 15 dakikalık pencerelerle: takip 80/IP, çalışan 180/IP, kod gönderimi 5/IP+kayıt, karar 10/IP+kayıt. Kodun kendisi en fazla 5 kez denenir. Reverse proxy gerçek IP başlığını güvenilir biçimde iletmelidir.

SwiftUI istemcisi JSONDecoder için ISO-8601 tarihleri, String enum durumlarını ve kuruş tamsayılarını kullanmalıdır. Bearer anahtarını Keychain'de saklayın. UI/servis iş mantığı `lib/domain.ts`, `lib/service.ts`, `lib/decision.ts` içinde ayrılmıştır; iOS aynı API'yi kullanır, ayrı bir veritabanı bağlantısı açmaz.

## Dil desteği

Arayüz Türkçe, İngilizce ve Almanca sunulur. `s360-language` çerezi varsa önceliklidir; yoksa `Accept-Language` başlığı, bölge ekleri ve kalite ağırlıklarıyla değerlendirilir. Desteklenmeyen dillerde Türkçe kullanılır. SwiftUI istemcisi `Accept-Language: de` veya `en` gönderebilir.

Hata/bildirim nesnelerinin `error`, `message`, `warning` alanları istek dilinde döner; ek `errorKey`, `messageKey`, `warningKey` alanları istemcinin dil değişiminde yeniden çevirebilmesi için özgün metni taşır. Servis durumları, cihaz türleri ve diğer iş mantığı değerleri API'de değiştirilmez. Tek kullanımlık kod e-postası kod istenen sayfanın dilinde hazırlanır. Çalışanların serbestçe yazdığı müşteri notları, arıza açıklamaları ve teklif metinleri otomatik çevrilmez.

## Bağımsız web girişi

`POST /auth/login`: `{email,password}`; 8 saatlik HttpOnly, SameSite=Lax (üretimde Secure) çerez kurar. `POST /auth/logout`: mevcut çerezin sunucudaki oturumunu iptal eder. Her ikisi de aynı origin gerektirir. Giriş IP ve e-posta/IP kapsamında 15 dakikada 10 denemeyle sınırlıdır. Tarayıcı istekleri kimlik başlıkları göndererek rol alamaz. Çalışan parolaları API yanıtlarında yer almaz; ilk parola ve sıfırlama yönetici paneli veya yetkili CLI ile yapılır.


## Para birimi ve iOS uyumluluğu

POST `/records` alanı `currency`: `EUR`, `TRY` veya `USD`; gönderilmezse `TRY`. Tutarlar seçilen para biriminin yüzde biri olarak tamsayı saklanır. Kur dönüşümü yoktur. Para birimi servis JSONB verisinde saklanır; ek migration gerekmez. GET `/records` ve GET `/track/{token}` para birimini taşır. Önceki para birimi bulunmayan kayıtlar TRY kabul edilir. Mevcut kayıtların para birimini değiştirme uç noktası yoktur.

DELETE `/records/{id}/events/{eventId}` yalnızca yönetici: adım görünümden kaldırılır, özgün bilgi ve denetim izi saklanır. POST `/users` ilk parola için `password` (12–200 karakter) kabul eder. PATCH `/users/password` yönetici tarafından başka bir çalışan için `{id,password}` alır, mevcut oturumları iptal eder. İstemciye parolanın hash değeri dönmez.


## Fotoğraf silme

DELETE `/records/{recordId}/photos/{photoId}`: yönetici veya teknisyen oturumu gerekir, müşteri takip bağlantısıyla kullanılamaz. Fotoğraf yalnızca ilgili servisten kaldırılır. Kayıt değişikliği ve denetim izi atomiktir; çakışmada 409. Depolama silmesi sonradan yürütülür; geçici hatada özel JSONB kuyruğunda saklanır ve `warning` içeren güncel kayıt döner. Aynı DELETE isteği temizliği yeniden deneyebilir; `pnpm photos:cleanup` bekleyenleri işler. `photoDeletionQueue` müşteri izdüşümünde yer almaz.


## Teklif silme

DELETE `/records/{recordId}/quotes/{version}` yetkili çalışan içindir. Silinen teklif deletedAt/deletedBy ile denetim için saklanır. Teklif sürümü yeniden kullanılmaz; eski sürümler otomatik aktif olmaz. Bekleyen güncel teklif silinince incelemeye dönülür. Kod iptali ve audit aynı atomik sorgudadır. Aktif/teslim edilmiş tamirin güncel teklifinin silinmesi 409 döndürür. GET `/health` capabilities alanı `features.quoteDelete: true` döndürür.


## İptali geri alma

POST `/records/{recordId}/reopen` yönetici/teknisyen içindir. Sunucu önceki durumu ve gerekli güncel onay/tamamlama bilgilerini kontrol ederek hedefi belirler; bilinmeyen veya uygun olmayan aşama İnceleniyor'a döner. Teslim edilmiş cihaz açılamaz. Kayıt, kullanılmamış doğrulama kodları ve audit atomik güncellenir. Yinelenen başarılı istek değişiklik yapmadan mevcut kaydı döndürür. GET `/health` içinde `features.reopenRecord: true` kontrol edilebilir.

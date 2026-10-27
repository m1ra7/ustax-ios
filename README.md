UstaX, teknik servisler için servis ve tamir takip sistemidir. Mirac Suicmez tarafından geliştirilmiştir.

Son güncelleme: HAKKINDA-VE-IOS-UYUMU.md

# UstaX iOS

Native SwiftUI teknik servis uygulaması. Xcode **14.2**, Swift **5.7**, iOS/iPadOS **16.0+** hedeflenir. Harici Swift paketi veya CocoaPods kurulumu gerektirmez.

`UstaX.xcodeproj` dosyasını açın. İlk çalıştırma için `KURULUM.md` dosyasını izleyin.

## Ekranlar

- Çalışan e-posta/parola girişi; sunucu adresi ayarı; güvenli Keychain oturumu.
- Günlük özet, servis listesi, arama, cihaz/durum filtreleri, tarih sıralaması.
- Müşteri/cihaz kabulü; mevcut müşteriyi seçme; cihaz ve müşteri servis geçmişi.
- Sunucudaki iş kurallarıyla durum güncelleme; açık/iç notlar ve zaman çizelgesi.
- Parça ve işçilik bedelli, sürümlü teklifler; tamir tamamlanması ve teslim kaydı.
- Çoklu fotoğraf seçme, kamera, aşama, müşteri görünürlüğü ve büyütme.
- Yeni kayıtta güvenli takip bağlantısı ve QR kod; paylaşma/kopyalama; yönetici için yenileme.
- Müşteri takip sayfası; e-posta koduyla teklif onayı/reddi.
- Yönetici için çalışan ekleme, rol ve erişim yönetimi.
- Türkçe, İngilizce ve Almanca; Dynamic Type; sistem bileşenleri; açık/koyu tema.

Uygulama bir web görünümü değildir. URLSession ile mevcut `/api/v1` API'sine bağlanır. PostgreSQL ve dosya depolama anahtarları telefona konulmaz.

## Backend gereksinimi

Bu uygulama **UstaX-Web.zip içindeki bağımsız e-posta/parola girişli backend** ile çalışır. Web backend'deki migration'lar uygulanmalı, çalışan parolası tanımlanmalı ve backend erişilebilir olmalıdır. Sunucu `GET /api/v1/health` yanıtında `auth: "email-password"` döndürmelidir.

Bağımsız web paketini kurmak, iOS uygulamasını açmadan önce tamamlanmalıdır. Sahibe özel barındırma geçidi, iOS istemcisinin yerine geçebileceği bir çalışan oturumu sağlamaz.

Müşteri teklif kodu gönderimi için backend'de çalışan Resend hesabı ve doğrulanmış gönderici gerekir. Eksik sağlayıcı yapılandırması uygulamada hata olarak gösterilir; sahte onay veya örnek başarı yoktur. Yeni çalışana parola ilk kez sunucudaki yetkili `scripts/password.ts` komutuyla verilir. iOS'ta kamuya açık çalışan kaydı veya parola sıfırlama yoktur.

## Güvenlik

Oturum Keychain'de `WhenUnlockedThisDeviceOnly` erişimiyle saklanır. E-posta/parola bellekte giriş isteği için kullanılır; parola diske yazılmaz. API önbelleği kapalıdır. Farklı sunucuya yönlendirmede oturum iletilmez. Genel sunucularda HTTPS zorunludur. Yetkilendirme ve iş kuralları backend'de uygulanır; iOS kontrolleri yalnızca kullanılabilirliği iyileştirir.

Takip anahtarları uygulama ayarlarına veya kayıtlara yazılmaz. Yeni servis bağlantısını ilk gösterimde paylaşın; hash saklandığı için eski bağlantı daha sonra geri okunamaz. Yenileme eski bağlantıyı geçersiz kılar. Fotoğraflar yetkili API üzerinden indirilir; sağlayıcı anahtarları veya kalıcı açık URL'ler kullanılmaz.

Ücretler kuruş cinsinden tamsayıdır. Ekranda TRY/TL gösterilir; dil değişimi döviz dönüşümü yapmaz. Kullanıcı tarafından girilen serbest metinler çevrilmez. Çoklu yüklemede ilerleme tamamlanan dosya sayısıyla gösterilir. Hata olursa daha önce yüklenen dosyalar korunur; kalanları yeniden seçebilirsiniz.

## Doğrulama durumu

Swift kaynaklarının sözdizimi bir Swift ayrıştırıcısıyla kontrol edildi. API alanları, proje referansları, çeviri anahtarları ve Xcode sürüm ayarları statik olarak denetlendi. `UstaXTests` hedefinde dokuz XCTest senaryosu vardır: tutar ayrıştırma, takip anahtarı, sunucu URL doğrulaması, herkese açık API verisi ve onaysız tamir geçişi.

**Bu çalışma ortamında macOS, Xcode veya iOS Simulator bulunmadığı için Xcode derlemesi ve XCTest çalıştırması yapılmadı.** İlk Mac derlemesi ve gerçek backend üzerinde uçtan uca doğrulama gereklidir. Paket derlenmiş IPA içermez.

Yerleşik kamera fiziksel cihaz gerektirir. QR okuma ve Universal Links yetkileri bu sürümde yoktur; müşteri takip bağlantısını yapıştırır. Bildirimler, çevrimdışı yazma, iCloud, ödeme ve stok kapsam dışıdır. Üç uygulama simgesi dahildir. App Store dağıtım imzası ve güncel SDK gereklilikleri ayrıca tamamlanmalıdır.

## Uygulama simgeleri

Lacivert U varsayılandır. Ayarlar > Uygulama simgesi ekranından petrol yeşili X veya açık zeminli U seçilebilir. Aynı ekran giriş sayfasından da açılır. 1024 piksel PNG dosyaları `Logos` klasöründe; iPhone/iPad boyutları projeye eklenmiştir.

## Performans güncellemesi

Tarih/ücret biçimlendiricileri yeniden kullanılır. Özet sayıları, müşteri/cihaz geçmişi ve kimlik dizinleri veri değiştiğinde bir defa hazırlanır. Liste araması 180 ms beklemeyle arka planda çalışır; eski arama sonucu yeni aramanın üstüne yazılmaz. JSON çözümleme arka plan kuyruğundadır. Eşzamanlı liste yenilemeleri tek ağ isteğini paylaşır.

Fotoğraf listesi 640, büyütme görünümü 2400 piksel sınırında ImageIO ile açılır. JPEG hazırlama arka plandadır. Aynı fotoğraf/çözünürlük isteği paylaşılır; aynı anda en fazla üç fotoğraf indirilir. Bellek önbelleği hedef sınırı 24 MiB/40 görseldir (NSCache bu sınırları sistem koşullarına göre uygular), ömrü 60 saniyedir; sunucu/oturum değişimi, arka plana geçiş veya bellek uyarısında temizlenir. Diske fotoğraf önbelleği yazılmaz.

Gerçek cihazda FPS, açılış süresi veya pil tüketimi ölçülmedi. Bu değişiklikler kod düzeyindeki gereksiz işi azaltır; belirli bir hızlanma yüzdesi vaat edilmez. Backend hâlâ bütün servis kayıtlarını döndürür; çok büyük veri için API sayfalaması ayrıca gerekir. `PERFORMANS.md` cihazda doğrulama adımlarını açıklar.

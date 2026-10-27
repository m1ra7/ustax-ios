# UstaX hakkında ve iOS uyumu

UstaX, telefon, tablet ve bilgisayar teknik servisleri için geliştirilmiş bir servis ve tamir takip sistemidir. Müşteri ve cihaz kabulünden fiyat teklifine, müşteri onayından tamir ve teslim aşamalarına kadar süreci tek yerde yönetir. Müşteriler, güvenli takip bağlantılarıyla cihazlarının güncel durumunu görüntüleyebilir.

Mirac Suicmez tarafından geliştirilmiştir.

## Hakkında bölümüne erişim

iOS'ta Ayarlar > UstaX hakkında üzerinden açılır. Giriş ekranında ve müşteri takip ekranında da bağlantısı vardır. Webde Ayarlar içinde, giriş ekranında, panel alt bilgisinde ve müşteri takibinde Hakkında bağlantısı bulunur. /hakkinda sayfası giriş yapmadan açılır. Geliştirici adı sayfa metadata'sında da yer alır. Türkçe, Almanca ve İngilizce metinler sağlanır.

## iOS ve web davranışları

Güncel müşteri onayı, tamire başlanmadan önce yeşil Müşteri onayladı olarak görünür. Onaylanan kayıt bekleyenler sayısından çıkar ve ayrı filtreyle bulunur. Yeni teklif hazırlanırsa tekrar onay beklenir; silinmiş veya eski bir teklifin kararı yeni teklif için geçerli olmaz. Gerçek iş aşamaları sunucuda yönetilir; onay otomatik tamir veya ödeme değildir.

iOS kayıtları uygulama ön plandayken yaklaşık 15 saniyede bir yeniler; arka planda periyodik sorgu yapmaz. Uygulamaya geri dönünce yeniler. Aynı veri geldiğinde katalog yeniden yayımlanmaz. Yerel değişiklikler devam ederken eski yanıtın onları ezmesini önleyen sürüm kontrolü korunur. Webin görünür panel yenilemesi de devam eder.

Fotoğraf yükleme/silme, teklif silme, geçmiş adımı kaldırma, iptal edilmiş kaydı yeniden aktif etme, güvenli takip bağlantısı/QR, para birimi ve çalışan parola yönetimi önceki sürümlerden korunur. iOS seçimleri aynı ekranda menü olarak açılır. Tema ve açılış arka planı değiştirilmedi.

## Kurulum

Önce UstaX-Web.zip içeriğini mevcut web Git projenize uygulayın. Yeni app/hakkinda/page.tsx ve app/about-content.tsx dosyaları dahil app ve lib değişikliklerini gönderin. Ortam değişkenlerinizi ve .git klasörünü koruyun. Vercel'de yeni commit Ready olmalıdır. Veritabanı migration gerekmiyor.

Sonra iOS ZIP'ini yeni klasöre çıkarın. UstaX.xcodeproj dosyasını Xcode 14.2 ile açın. Signing & Capabilities içindeki Team seçiminizi yapın ve çalıştırın. Eski/yeni Swift dosyalarını aynı projeye birlikte eklemeyin. Sunucu adresini güncel Vercel yayınının kök HTTPS adresiyle eşleştirin.

## Doğrulama

44 web testi, TypeScript denetimi ve üretim derlemesi geçti. Hakkında sayfasının üç dilde mobil görünümü, geliştirici metni, metadata ve giriş/ayarlar/takip bağlantıları tarayıcıda kontrol edildi. iOS kaynak, çeviri ve Swift sözdizimi kontrolleri geçti. Native onay durumu/sayaç/filtre uyumu için XCTest eklendi; Xcode derlemesi ve XCTest burada çalıştırılmadı. Yayındaki sunucu otomatik değiştirilmedi.

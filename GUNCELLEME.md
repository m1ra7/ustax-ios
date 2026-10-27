## Servis durumu alanı

Bu sürüm için DURUM-GUNCELLEME.md dosyasına bakın.

Son güncelleme: **HAKKINDA-VE-IOS-UYUMU.md**.

İptal edilen kaydı açma güncellemesi: **YENIDEN-AKTIF-ETME.md**. Önce web/backend sürümünü yayınlayın.

Teklif silme güncellemesi: **TEKLIF-SILME.md**. Önce web backend sürümünü yayınlayın.

Son fotoğraf silme ve boşluk düzenlemesi: **FOTOGRAF-SILME.md**.

# Yükleme hatasını ayırt etme

Yükleme hatasında HTTP kodu uygulamadaki mesajın sonunda gösterilir. Debug derlemesinde Xcode konsoluna yalnızca durum kodu veya hata alanı/kodu yazılır; parola, oturum anahtarı, fotoğraf veya müşteri verisi yazılmaz. HTTP kodu varsa istek sunucu yanıtı almıştır. Kod yoksa fotoğrafı alma veya ağ aşaması ayrıca incelenmelidir.

UstaX-Web.zip içindeki lib/s3-transport.ts düzeltmesinin Vercel'e yayınlandığından emin olun. Sadece iOS ZIP'ini değiştirmek yayındaki web backend'ini değiştirmez. iOS Ayarlar > Sunucu adresi ile güncel Vercel projesinin adresi aynı olmalıdır. Güncel kodun depolama hataları farklı açıklamalar taşır; eski genel hata mesajı eski backend sürümüne işaret edebilir.

# Menü seçimleri ve otomatik fotoğraf yükleme

Bu sürüm önceki ayrı seçim ekranlarını ve manuel yükleme düğmesini kaldırır.

- Dil, para birimi ve aşama aynı ekran üzerinde standart açılır menüyle seçilir. Seçim için yeni sayfa açılmaz.
- Fotoğraf seçildiğinde yükleme otomatik başlar; ayrı yükleme düğmesi yoktur.
- Fotoğraf arşivi PHPicker kullanır. preferredAssetRepresentationMode = .current ile orijinal görsel istenir; orijinal dosya geçici erişim süresi içinde okunur. HEIC/JPEG/PNG kaynakları ImageIO ile uygulama içinde 3 MB sınırında JPEG olarak hazırlanır. Photos yardımcısının uyumluluk dönüşümüne ihtiyaç azaltılır.
- Arşivden dosya alınamazsa açıklayıcı hata görünür. Alternatif Dosyalardan fotoğraf seç işlemi de otomatik yükler. Kamera seçeneği korunur. Bir dosyanın hatası sonraki seçili dosyaların yüklenmesini engellemez.
- Aşama ve müşteri görünürlüğü yükleme başladığında sabitlenir. Yükleme sırasında değiştirilirse yeni seçim sonraki yüklemeye uygulanır.

## Kurulum

ZIP'i yeni klasöre çıkarın, UstaX.xcodeproj dosyasını Xcode 14.2 ile açın. Team seçiminizi yapın. Product > Clean Build Folder ardından Command+R ile çalıştırın. Eski Swift dosyalarıyla birleştirmeyin. Önceki UstaX-Web paketindeki sunucu 501 düzeltmesi Vercel'de yayınlanmış olmalıdır; bu iOS paketi yayındaki backend'i değiştirmez.

## Kontrol

Dil/para birimi/aşama menüsünü açın ve seçenek seçin. Fotoğraf arşivinden bir JPEG ve bir HEIC görsel seçip otomatik yüklemeyi, fotoğraf listesinde görünmelerini kontrol edin. Kamera ve Dosyalar yolunu da deneyin. Kaynak fotoğraf alınamaması ile sunucu yükleme hatası farklı aşamalardır. Verilen NSCocoaErrorDomain 4101 / PAMediaConversionServiceErrorDomain 2 logu fotoğraf dışa aktarma aşamasındadır; bir HTTP sunucu hatası değildir.

Simulatorün Fotoğraflar servisi aynı hatayı vermeyi sürdürürse küçük bir JPEG'i simulator penceresine sürükleyerek içe aktarın ve yeniden seçin; ayrıca Dosyalar seçeneğini veya gerçek iPhone'u deneyin. Simulator verilerini silmek gerekmez. Gerçek iPhone'da iCloud fotoğrafının özgün dosyasının indirilebildiğini kontrol edin.

Swift kaynak sözdizimi, proje kaynakları ve çeviriler kontrol edildi. Dosyadan orijinal veri okuma/JPEG hazırlama ve büyük dosya reddi için XCTest eklendi; testler ve Xcode derlemesi bu Linux ortamında çalıştırılmadı. Xcode'da Command+U ve gerçek cihazda seçim/yükleme kontrolü gerekir.

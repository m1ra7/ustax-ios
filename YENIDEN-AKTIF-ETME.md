# İptal edilen servis kaydını yeniden aktif etme

## Kurulum

Önce güncel UstaX-Web.zip dosyasını mevcut web projenize uygulayıp yeni dosya lib/reopen.ts dahil commit/push yapın. Ortam değişkenlerinizi ve .git klasörünüzü koruyun. Vercel'de yeni commit Ready olmalıdır. Ek migration gerekmez. Sunucu /api/v1/health yanıtında features.reopenRecord:true ve release:reopen-record-v1 görünmelidir. Eski commit'i yeniden yayınlamak yeni endpoint'i eklemez.

Ardından iOS ZIP'ini yeni klasöre çıkarın, UstaX.xcodeproj dosyasını Xcode 14.2 ile açın, Team ayarınızı seçip Command+R yapın. Swift dosyalarını eski sürümle aynı projeye iki kez eklemeyin. iOS'un Sunucu adresi güncel web yayınının kök HTTPS adresi olmalıdır.

## Kullanım

Webde iptal edilen servis detayını açın; üstteki Yeniden aktif et düğmesine basıp onaylayın. iOS'ta servis detayındaki İşlemler > Yeniden aktif et / Erneut aktivieren seçeneğini kullanın. Bu işlem yönetici ve yetkili teknisyen içindir. Müşteri takip sayfası yeniden açamaz.

Bu sürümden sonra iptal edilirken önceki aşama servis verisinde saklanır. Yeniden açıldığında, mevcut teklif/onay/tamamlama bilgileri o aşamaya uygunsa aynı aşamaya dönülür. Eski iptal edilmiş kayıtlarda önceki aşama saklanmadığı için İnceleniyor olarak açılır; tarihçedeki serbest metinden durum tahmin edilmez.

Tamir ediliyor / Parça bekleniyor için güncel teklifin onayı gerekir. Teslime hazır için aynı onaylı teklif tutarıyla tamamlanma kaydı gerekir. Bu koşullar eksikse İnceleniyor aşamasına dönülür. Onayı reddedilmiş güncel teklifle Fiyat onayı bekliyor aşamasına dönülmez. Fiilen teslim edilmiş cihaz yeniden aktif edilemez.

Müşteri, cihaz, fotoğraflar, teklifler, kararlar ve eski olaylar korunur. Takip bağlantısı değişmez. Yeni işlem tarih, saat ve çalışan bilgisiyle geçmişe, ayrıca denetim kaydına eklenir. Kayıt değişikliği, eski doğrulama kodlarının iptali ve denetim kaydı tek atomik SQL ifadesindedir. Eşzamanlı değişiklik 409 döndürür; aynı başarılı işlemi tekrar göndermek ikinci bir olay/audit oluşturmaz. Tekrar iptal edildiğinde yeni önceki durum kaydedilir.

İptal edilmiş veya teslim edilmiş kayıtlar için müşteri kod gönderme/onay endpoint'leri kapalıdır. Yeniden açılan onay bekleyen kayıtta gerekiyorsa yeni doğrulama kodu alınır. Genel durum güncelleme endpoint'iyle iptal durumundan onaysız geçiş hâlâ yapılamaz; ayrı yeniden açma endpoint'i kullanılır.

## API

POST /api/v1/records/{recordId}/reopen. Yetkili çalışan oturumu veya Bearer gerekir. İstemci hedef aşamayı seçmez; sunucu mevcut kayıttan belirler. Yanıt güncel ServiceRecord. JSONB verisine isteğe bağlı cancelledFromStatus ve reopenedAt alanları eklenir; müşteri izdüşümünde bu iç alanlar verilmez.

## Kontroller

43 web testi ve üretim derlemesi geçti. Testler önceki aşamaya dönüşü, eski kayıtları, onay/tamamlama korumalarını, teslim edilmiş cihazın engellenmesini ve atomik kod iptali/audit işlemini kapsar. Tarayıcıda taklit API ile iptal, hata ve mobil yeniden açma akışı kontrol edildi. Gerçek müşteri kayıtları test için değiştirilmedi. iOS kaynak, çeviri ve Swift sözdizimi kontrolleri geçti; Xcode derlemesi ve cihaz testi bu ortamda yapılmadı.

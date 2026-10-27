# Fotoğraf silme ve kart boşlukları

## Kurulum

Önce bu sürümün UstaX-Web.zip içeriğini web projenize uygulayıp Vercel'e yayınlayın. iOS'un Sunucu adresi güncel web yayınıyla aynı olmalıdır. Yeni endpoint eski backend'de olmadığı için yalnızca iOS'u güncellemek silme özelliğini çalıştırmaz. Ek veritabanı migration gerekmiyor; silme temizleme kuyruğu servis JSONB verisinde tutuluyor.

Ardından iOS ZIP'ini yeni klasöre çıkarın. UstaX.xcodeproj dosyasını Xcode 14.2 ile açın, Team ayarınızı seçin ve Command+R ile çalıştırın.

## Kullanım

Servis detayı > Fotoğraflar bölümünde her fotoğrafın altında Fotoğrafı sil düğmesi vardır. Dokunup silmeyi onaylayın. Sunucu başarılı yanıt verince fotoğraf listeden ve müşteri takibinden kaldırılır; uygulamanın fotoğraf önbelleği temizlenir. Hata olursa fotoğraf istemcide önceden gizlenmez ve anlaşılır mesaj gösterilir. Yönetici ve teknisyen yapabilir; müşteriler için silme endpoint'i açık değildir.

Fotoğraf kartları ve teklif geçmişindeki teklif kartları 16 piksel iç boşluk ve üst/alt 8'er piksel dış boşluk kullanır. Teklif sürümü, tutar ve onay bilgileri değiştirilmez. Dil/para birimi/aşama menüleri aynı ekranda açılır. Otomatik fotoğraf yükleme korunur.

## Depolama temizliği

Fotoğraf bağlantısını kaldırma ve denetim kaydı tek atomik sorguda yapılır; eşzamanlı kayıt değişikliği 409 döndürür. Sonra dosya S3 veya Cloudinary'den silinir. Başarısız depolama silmesi kaydı geri açmaz: özel temizlik kuyruğunda kalır ve uygulama uyarı gösterir. Sunucuda silme yetkisi bulunmalıdır. Aynı DELETE isteği tekrarlandığında kuyruk yeniden işlenir; ikinci bir geçmiş/denetim adımı oluşturulmaz. Bekleyen dosyalar sunucu veya yerel yönetim ortamında `pnpm photos:cleanup` ile tekrar temizlenebilir (.env.local gerekli). Bu komut yalnızca kuyrukta bulunan silinmiş fotoğrafları işler; aktif fotoğrafları silmez. Anahtarları günlüklere yazmaz. Servis kayıtları veya teklifler silinmez. Depolama sağlayıcısının sürüm/yedekleme kuralları önceki dosya sürümlerini tutabilir.

API: DELETE /api/v1/records/{recordId}/photos/{photoId}. Yetkili oturum veya Bearer gerekir. Yanıt güncel ServiceRecord; depolama temizliği bekliyorsa warning eklenir. Müşteri fotoğraf yolu kayıttaki photos dizisini doğruladığından kaldırılan fotoğrafı sunmaz.

## Doğrulama

Web tarafında 32 test ve üretim derlemesi geçti; ek iki depolama DELETE protokol testi de çalıştırıldı. Silme atomikliği, revision çakışması, müşteri izdüşümü ve tekrar deneme kontrol edildi. Gerçek müşteri fotoğrafları test amacıyla silinmedi. Swift sözdizimi/çeviri/kaynak kontrolleri geçti. Xcode derlemesi, XCTest ve iPhone ekran görüntüsü doğrulaması bu ortamda yapılamadı.

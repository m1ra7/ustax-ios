# Xcode 14.2 düzeltmesi

Forms.swift içindeki dört actor izolasyonu hatası için Task/defer kullanımı kaldırıldı. Başarı ve hata yolları tamamlandıktan sonra busy durumu doğrudan MainActor üzerinde sıfırlanır. Aynı kalıp fotoğraf, ekip, giriş, takip ve servis detayı ekranlarında da güncellendi. AppState yükleme temizliği de aynı kurala uyar.

Mevcut projenizde yalnızca UstaX kaynak klasörünü bu sürümdeki UstaX klasörüyle değiştirin; .xcodeproj dosyasını değiştirmeniz gerekmez. Böylece Team ve Bundle Identifier ayarlarınız korunur. Xcode’da Product > Clean Build Folder, ardından Build çalıştırın.

Sözdizimi ve proje referansları kontrol edildi. Bu ortamda Xcode olmadığı için Xcode derlemesi çalıştırılmadı.

## Müşteri listesi tip denetimi

RecordsView.swift içindeki iç içe müşteri/detay/geçmiş görünümü ayrı küçük SwiftUI bileşenlerine ayrıldı. Müşteri filtreleme ve sıralama açık türlerle ayrı hesaplanır. Bu güncelleme için yalnızca UstaX/Views/RecordsView.swift dosyasını değiştirmek yeterlidir. Önceki actor izolasyonu düzeltmeleri de pakette korunur.

## Sunucu adresini normalleştirme

Sunucu alanında protokol yazılmadığında HTTPS eklenir. Büyük harfli protokol/alan adı ve sondaki bölü çizgisi normalleştirilir; genel HTTP adresleri HTTPS’e yükseltilir. Yerel geliştirme için açıkça yazılan HTTP adresleri korunur. Kimlik bilgisi, sorgu veya sayfa yolu içeren adresler reddedilmeye devam eder. Bu değişiklik için UstaX/Networking/APIClient.swift dosyasını değiştirin.

## Performans güncellemesi

Tekrar kullanılan biçimlendiriciler; önceden hesaplanan kayıt dizinleri; arka plan arama, JSON çözümleme ve fotoğraf hazırlama; sınırlandırılmış fotoğraf indirme ve bellekte görsel önbelleği eklendi. İki yeni Swift dosyası proje referanslarına dahil edildi. Bu nedenle bu sürümü ayrı klasörde açın; önceki Team/Bundle Identifier değerlerinizi yeniden seçin.

## PhotoPipeline bildirim yakalaması

Bellek ve arka plan bildirimlerinde içteki Task artık dış closure’ın değişken weak self yakalamasını kullanmaz. Önce değişmez bir pipeline referansı alınır, sonra MainActor görevi bu referansı açıkça yakalar. Swift 5.7 eşzamanlılık denetimine uygundur.

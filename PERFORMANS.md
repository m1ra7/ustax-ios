# Performans değişiklikleri ve cihazda kontrol

## Uygulanan değişiklikler

- Tarih ve para biçimlendiricileri her satırda yeniden oluşturulmaz. En fazla 512 tarih metni bellekte yeniden kullanılır; dil/saat dilimi değişiminde temizlenir.
- Özet sayıları tek geçişte hazırlanır. Kayıt, müşteri ve cihaz kimliği dizinleri gövde çiziminde tekrar hesaplanmaz. Katalog yalnızca servis verisi değiştiğinde yeniden kurulur. Giriş, oturum geri yükleme ve liste yenilemedeki toplu sıralama/indeksleme ayrı kuyrukta yapılır; tek kayıt güncellemeleri mevcut eşzamanlı yerel yoldan uygulanır.
- Servis arama metni veri değişiminde normalize edilir. Arama 180 ms beklemeli arka plan kuyruğunda çalışır. İptal edilen arama sonucunun yeni ekranı değiştirmesi önlenir. Listeler önceden sıralandığından her aramada yeniden sıralama yapılmaz.
- JSON çözümleme ana iş parçacığından ayrıdır. Çalışan oturumu yoksa açılışta gereksiz /me ve /records istekleri yapılmaz. Aynı anda başlayan yenilemeler tek /records isteğini paylaşır. Yenileme sırasında bir mutasyon tamamlanırsa eski yenileme yanıtı yerel değişikliğin üstüne yazılmaz; tam eşitleme için tekrar yenilenebilir.
- Keychain'den oturum her HTTP isteğinde tekrar okunmaz. Sunucu değişiminde ve girişte güncellenir, çıkışta silinir. Eski oturum/sunucuya ait gecikmiş yanıtlar yeni oturuma uygulanmaz.
- Fotoğraflar ImageIO ile hedef çözünürlüğe doğrudan açılır. Listede 640 piksel, büyütmede 2400 piksel sınırı vardır. İki görünüm farklı çözünürlük anahtarları kullanır.
- Aynı görsel isteği paylaşılır; indirme ve çözümleme aşamalarını birlikte kapsayan en fazla üç aktif fotoğraf işi vardır. İndirilmiş büyük dosyaların çözümleme kuyruğunda birikmesi azaltılır. Seri görsel işleme kuyruğu aynı anda çok sayıda yüksek çözünürlüklü açma/sıkıştırmayı engeller. Seçilen fotoğraflar sırayla işlenir.
- Oturum, sunucu, müşteri anahtarı, görünürlük ve boyuta göre ayrılan görsel önbelleği yalnızca bellektedir. 60 saniye sonunda sunucu erişimi yeniden kontrol edilir. Oturum temizleme, arka plan ve bellek uyarısı önbelleği boşaltır. Liste dışında kalan görselin View içindeki kopyası serbest bırakılır.

NSCache sınırları sistem tarafından uygulanır; toplam uygulama belleğinin kesin üst sınırı değildir. Görsel indirme boyutu API tarafından belirlenir; küçük önizleme için de orijinal dosya ağdan gelir, istemci onu küçük boyutta açar. Sunucu thumbnail API'si bu sürüme eklenmemiştir. Sunucu hâlâ kayıtların tamamını döndürür; yüz binlerce kayıt ölçeği için API sayfalaması gerekir.

- Müşteri adı/telefon araması için normalize metin katalog hazırlanırken saklanır; her tuşta yeniden oluşturulmaz. Boşluklardan oluşan arama tüm müşterileri döndürür.
- QR kodu takip bağlantısı sayfasının ömrü boyunca yeniden kullanılır. Her görünüm güncellemesinde görsel tekrar üretilmez.
- Arka plan indeksleme bittikten sonra oturum/sunucu kapsamı yeniden kontrol edilir; eski yanıt ekrana uygulanmaz.

## Mac'te doğrulama

1. Yeni `UstaX.xcodeproj` dosyasını açın. Team ve Bundle Identifier'ı kendi değerlerinize ayarlayın.
2. Command + U ile dokuz XCTest senaryosunu çalıştırın. Yeni kontroller katalog sırası/sayıları/geçmiş, JSON işlemenin ana iş parçacığında olmaması ve görsel piksel sınırıdır.
3. Fiziksel iPhone seçip Product > Profile (Command + I) ile Release sürümünü açın. Time Profiler'da servis listesinde kaydırın ve hızlı arama yapın. JSON/image işlemlerinin ana iş parçacığını meşgul etmediğini inceleyin.
4. Allocations ile fotoğraf listesini açın, büyütün, geri dönün. Bellek kullanımını izleyin. Uygulamayı arka plana gönderip tekrar açın.
5. Fotoğraf görünürlüğünü ve çalışan oturumunu değiştirin. Eski oturumun önbelleğiyle yeni kullanıcıya görsel gösterilmediğini kontrol edin.
6. Web panelinden başka bir kayıt ekleyip iOS listesini yenileyin. Aynı anda yapılan yazma ve yenilemenin kayıt kaybına neden olmadığını doğrulayın.
7. İnterneti kapatıp liste yenileyin, sonra açın. Yanlış başarı mesajı veya boş ekran yerine hata durumunu kontrol edin.

Bu ortamda macOS/iOS araçları bulunmadığından cihaz ölçümü, Instruments profili, Xcode derlemesi ve XCTest çalıştırması yapılmamıştır. Sözdizimi, kaynak/proje referansları ve statik sözleşme kontrolleri yapılmıştır.

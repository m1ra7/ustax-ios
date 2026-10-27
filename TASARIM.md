# Arayüz güncellemesi

- Ana panel: uyarlanabilir özet kartları, tam genişlikte yeni servis butonu ve ayrı son kayıt kartları.
- Sistem yazı tipi ve Dynamic Type; başlık, açıklama ve yardımcı metinlerde ortak hiyerarşi.
- Açık ve koyu görünüm için ayrı lacivert vurgu; sistemin uyarlanabilir yüzey renkleri.
- Servis satırlarında cihaz simgesi, servis numarası, tarih, müşteri ve durum hiyerarşisi.
- Cihaz detayı ve işlem geçmişinde daha belirgin başlıklar ve zaman çizelgesi.
- Form, liste, müşteri ve ayarlarda ortak arka plan ve boşluklar.
- Koyu mod anahtarı giriş ve ayar ekranlarında en alttadır. Türkçe, İngilizce ve Almanca korunmuştur.

## Kontrol

Kaynak doğrulama betiği çalıştırılmıştır. Xcode 14.2 derlemesi ve görsel cihaz kontrolü macOS üzerinde yapılmalıdır. Buradaki ortamda Xcode ve iOS simülatörü yoktur.

Xcode'da hem açık hem koyu görünümde küçük iPhone, büyük yazı boyutu ve iPad düzenini kontrol edin. Yeni paketi ayrı klasöre çıkartın ve proje imzalama ayarlarında kendi Team / Bundle Identifier değerlerinizi seçin.

## Giriş ekranı

Giriş ekranı ortalanmış, en fazla 520 pt genişlikte bir sütun kullanır. UstaX başlığının altında hesap kartı, müşteri takip bağlantısı ve tercihler yer alır. Sunucu adresi ilk kullanımda açık gösterilir; kayıtlı adres varsa bölüm kapalıdır ve alan adı görünür. Parola görünürlüğü değiştirilebilir. Klavyenin İleri / Git tuşları alanlar arasında geçiş ve giriş işlemini destekler. İstek sürerken tekrar gönderim engellenir. Koyu mod anahtarı en alttadır.

## Açılış ekranı

LaunchScreen.storyboard gerçek iOS açılış ekranıdır. Ortadaki UstaX adı iPhone ve iPad ekranına Auto Layout ile uyarlanır. Arka plan ve yazı rengi sistemin açık/koyu görünümüne göre değişir. Bu statik ekran uygulama içindeki kayıtlı tema tercihini okuyamaz; uygulama çalıştığında kayıtlı tercih uygulanır. Oturum geri yüklenirken aynı görsel düzen ve bir yüklenme göstergesi kullanılır. Ek bekleme süresi eklenmemiştir. iOS açılış ekranını önbelleğe alabilir; değişikliği görmek için uygulamayı tamamen kapatıp yeniden başlatın. Xcode 14.2 üzerinde storyboard derlemesi ve cihazda açılış kontrolü yapılmalıdır.

## Ortak kontrol rengi

Buton, metin eylemi, anahtar ve seçicilerin vurgu rengi ButtonBlue / AccentColor ortak paletinden gelir. Giriş butonu istek sırasında devre dışı kalsa bile beyaz yazısını ve beyaz yüklenme göstergesini korur. Durum çubuğu uygulama kökünde ve girişte açıkça görünürdür; iOS açık/koyu görünüme göre yazı rengini seçer.

### Açılış tema renkleri

Açık: #F7F9FC arka plan, #17395F UstaX yazısı. Koyu: #0C1727 arka plan, #F3F6FA UstaX yazısı. Oturum yüklenirken gösterge yazı rengini kullanır. iOS ilk statik ekran için telefonun temasını seçer; uygulama açıldıktan sonraki ekran uygulamada kaydedilmiş koyu mod ayarına uyar.

## Güncel tema paleti

Açık görünümde ana işlem mavisi #1B416F, koyu görünümde #3B78B2 kullanılır. Dolu butonlarda yazı beyazdır. Koyu zemin #182737, kart ve liste yüzeyleri #23364A olarak açılmıştır. Tüm metin butonları ve anahtarların etkin durumu ortak mavi paleti kullanır. Giriş butonu yüklenirken beyaz metin ve göstergeyi korur; tekrar gönderim engellenir. Durum çubuğu görünürdür.

## Koyu görünüm kontrastı

Metin eylemleri ve cihaz simgeleri koyu temada #9DC8F5 açık mavi kullanır. Dolu buton ve anahtarların mavi zeminleri korunur. Cihaz ve müşteri takip simgeleri #304E6B yüzey üzerinde gösterilir; simge/yüzey ve metin/kart kontrastları en az 4.5:1 olarak doğrulanır.

## Açılış ekranının tema eşleştirmesi

Açılış arka planı güncel AppCanvas paletiyle, UstaX yazısı güncel AccentColor paletiyle eşleştirilmiştir. Açık görünüm: #F5F7FB zemin ve #1B416F yazı. Koyu görünüm: #182737 zemin ve #9DC8F5 yazı. iOS'un ilk statik açılış ekranı sistem temasını kullanır; oturum yükleme görünümü uygulamadaki kayıtlı temayı kullanır.

## Açılış arka planı düzeltmesi

Yalnızca açılış arka planı güncellendi: açık temada #FFFFFF, koyu temada #23364A. Önceki UstaX başlığı, yerleşimi ve açılış davranışı korundu; minimum bekleme süresi eklenmedi.

## Aynı arka plan kaynağı

Launch storyboard ve uygulama içi açılış görünümü artık doğrudan AppCanvas rengini kullanır. Açık görünüm #F5F7FB, koyu görünüm #182737: uygulamanın ana arka planıyla birebir aynıdır.

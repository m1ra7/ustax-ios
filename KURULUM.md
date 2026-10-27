Bu sürümün güncelleme adımları: **GUNCELLEME.md**.

# Xcode 14.2 ile açma

1. ZIP'i çıkarın. `UstaX.xcodeproj` dosyasına çift tıklayın. Yeni proje oluşturmayın; Swift dosyalarını tek tek taşımayın.
2. Üstte scheme olarak **UstaX** seçin. Simulator olarak Xcode 14.2 içindeki iOS 16.x iPhone'lardan birini seçin.
3. Simulator eksikse Xcode > Settings/Preferences > Platforms bölümünden o Xcode sürümünün desteklediği simulatorü yükleyin.
4. **Command + R** ile çalıştırın. Deployment Target 16.0, Swift Language Version 5 ve proje biçimi Xcode 14 olarak hazırdır. XcodeGen, SPM veya CocoaPods gerekmez.
5. Telefonunuzda denemek için solda UstaX projesi > UstaX target > Signing & Capabilities bölümünde **Automatically manage signing** açık olsun. **Team** alanında kendi Apple hesabınızı seçin. Gerekirse Bundle Identifier'ı size özel bir değerle değiştirin.
6. Xcode 14.2'nin desteklediği bir iOS sürümüne sahip cihaz kullanın. Daha yeni bir iOS sürümündeki cihazı eski Xcode tanımayabilir; bu durumda uygun simulatorü kullanın. Simulator için ücretli geliştirici üyeliği gerekmez.

# Backend'i bağlama

Bu ZIP yalnızca native iOS istemcisidir. Daha önce verilen **UstaX-Web.zip** backend'i ve PostgreSQL'i sağlar.

Önce web paketini kurun:

```bash
pnpm install --frozen-lockfile
cp .env.example .env.local
```

Web paketinin kurulum rehberindeki Neon bağlantılarını doldurun. Mevcut UstaX yönetici hesabına parola vermek için `.env.local` dosyasında `STAFF_EMAIL` ve en az 12 karakter `STAFF_PASSWORD` tanımlayın:

```bash
node --env-file=.env.local --import tsx scripts/migrate.ts
node --env-file=.env.local --import tsx scripts/password.ts
pnpm dev
```

İşiniz bittikten sonra `STAFF_PASSWORD` değerini dosyadan kaldırın. Tamamen yeni veritabanı kullanıyorsanız web rehberindeki `admin.ts` adımını uygulayın. Giriş hesabı ve yetki bilgileri web ile ortaktır.

## Simulator ile yerel backend

1. Mac'te web sunucusunu `pnpm dev` ile çalıştırın.
2. iOS uygulamasındaki **Sunucu** alanına `http://localhost:3000` yazın.
3. Aynı adres web `.env.local` dosyasında `APP_URL=http://localhost:3000` olsun.
4. E-posta/parolanızla giriş yapın.

## Yayındaki backend

Sunucu alanına bağımsız web sitenizin kök adresini yazın, örneğin `https://servis.alanadiniz.com`. `/api/v1` veya `/yonetim/giris` eklemeyin. Web `.env.local` veya yayın ortamında **APP_URL tam olarak aynı kök adres** olmalıdır. Sonunda `/` kullanmayın. Alan adını değiştirdiğinizde yeniden giriş gerekir.

Fiziksel iPhone'da `localhost` telefonun kendisidir; Mac'iniz değildir. Fiziksel cihaz için HTTPS ile erişilebilen backend kullanın. Yerel ağ adresleri için Apple'ın ağ izinleri ve ATS kuralları ayrıca geçerlidir; uygulama genel HTTP erişimini açmaz.

Genel veritabanı veya storage anahtarlarını Xcode'a eklemeyin. Resend ve fotoğraf sağlayıcısı anahtarları yalnızca backend'de kalır. Resend bağlanmadan müşteri teklif kodu gönderilemez.

# Kullanım

- **Genel bakış:** günlük cihaz sayıları ve son servisler.
- **Servis kayıtları:** arama, filtreleme, yeni kayıt ve detaylar.
- **Müşteriler:** müşteri geçmişi ve yeniden servis açma.
- **Ayarlar:** sunucu, dil, yönetici ekip ekranı, çıkış; en altta tek dokunuş koyu mod.
- **Servis detayı:** işlemler, teklif, tamamlama, teslim, notlar, fotoğraflar ve geçmiş.
- **Cihazımı takip et:** üyelik olmadan takip bağlantısını/64 karakterlik anahtarı yapıştırma ve e-posta koduyla teklif kararı. Takip bağlantısı seçilen sunucuya ait olmalıdır.

Yeni kaydı oluşturunca bağlantı/QR sayfası açılır. Paylaşın veya kopyalayın. Bu sayfa kapatıldıktan sonra aynı bağlantı geri alınamaz. Yönetici yeni bağlantı oluşturabilir; eski bağlantı iptal olur.

Fotoğraflar uygulamada JPEG'e dönüştürülür; en uzun kenar 2400 piksele indirilir. Her fotoğrafı kabul/tamir öncesi/tamir sonrası olarak işaretleyin. Müşteri görünürlüğü varsayılan kapalıdır.

Servis iletişim telefonunu göstermek isterseniz `UstaX/Info.plist` içindeki **ServicePhone** değerine uluslararası biçimde işletme telefonunu yazın.

# Test etme

Xcode'da **Product > Test** veya **Command + U** ile `UstaXTests` hedefini çalıştırın. Terminal alternatifi:

```bash
xcodebuild -project UstaX.xcodeproj -scheme UstaX -destination 'platform=iOS Simulator,name=iPhone 14,OS=16.2' test
```

Simulator adını/sürümünü kendi kurulumunuza göre değiştirin.

Gerçek API kabul kontrolü: giriş/çıkış, yeni servis ve sayfayı yeniden açma, fotoğraf yükleme/gizleme, teklif sürümü, onaysız tamir reddi, gerçek e-posta koduyla karar, tamamlama, teslim, teknisyen rol kısıtları. Ağ kapalıyken hata görünmeli; veri yazılmış gibi gösterilmemelidir.

Bu ortamda Xcode derlemesi çalıştırılamamıştır. Mac'te ilk derlemede bir hata görürseniz Xcode Issue Navigator'daki ilk hatayı ve dosya adını paylaşın.

# Logo ve uygulama simgesi güncellemesi

Üç simge arasından uygulama içindeki **Ayarlar > Uygulama simgesi** ekranında seçim yapabilirsiniz. Giriş ekranında da aynı seçenek vardır. İlk simge lacivert U’dur. Simge değişikliği sırasında iOS bir bilgilendirme gösterebilir.

Bu sürümde kaynak dosyaları yanında proje kaynak referansları ve Info.plist de değişti. Güncel ZIP’i ayrı klasöre çıkarıp `UstaX.xcodeproj` dosyasını açın. Team ve size özel Bundle Identifier’ı yeniden seçin. Önceki sunucu adresi, actor izolasyonu ve müşteri ekranı düzeltmeleri korunur.

# Performans sürümünü kurma

Bu sürüm iki yeni Swift kaynak dosyası ve Xcode proje referansları içerir. ZIP’i yeni klasöre çıkarıp içindeki UstaX.xcodeproj dosyasını açın; Team ve Bundle Identifier değerlerini kendi projenizle aynı yapın. Sunucu/veritabanı migration değişikliği gerekmez. Önceki oturum, uygulama simgeleri ve iş akışları korunmuştur. Ayrıntılar PERFORMANS.md dosyasındadır.

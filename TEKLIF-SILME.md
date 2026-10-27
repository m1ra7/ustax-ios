# Kostenvoranschlag / teklif silme

## Kurulum

Önce bu sürümün UstaX-Web.zip içeriğini mevcut web projenize uygulayıp GitHub'a commit/push yapın. Vercel'de yeni commit Ready olmalıdır. .env.local ve .git klasörünüzü koruyun. Yeni dosya lib/quote-deletion.ts dahil olmak üzere değişiklikleri gönderin. Ek veritabanı migration gerekmiyor; tekliflere isteğe bağlı deletedAt/deletedBy alanları eklenir.

Sunucunuzun `/api/v1/health` yanıtında `features.quoteDelete: true` ve `release: "reopen-record-v1"` görünmelidir. Görünmüyorsa eski yayın vardır. Eski commit için Redeploy yapmak yeni kodu eklemez. iOS Sunucu alanı bu web yayınının kök HTTPS adresi olmalıdır.

Sonra iOS ZIP'ini yeni klasöre çıkarın. UstaX.xcodeproj dosyasını Xcode 14.2 ile açın, Team seçin ve çalıştırın. Swift dosyalarını eski dosyalarla aynı projeye birlikte eklemeyin.

## Kullanım ve kurallar

- iOS: Servis detayı > Teklif geçmişi / Kostenvoranschläge > Teklifi sil / Kostenvoranschlag löschen.
- Web: Servis detayı > Fiyat teklifi > Teklifi sil.
- Yönetici ve teknisyen silme yapabilir. Onay sorusu iptal edilirse istek gönderilmez. Müşteri silme yapamaz.
- Silme, teklifi çalışan ve müşteri ekranlarından kaldırır. Karar ve kapsam verileri denetim için veritabanında korunur; fiziksel olarak kaybedilmez.
- Güncel teklif silinirse ona ait tek kullanımlık kodlar geçersizleşir. Fiyat onayı bekliyor / Teklif reddedildi durumundaki servis İnceleniyor durumuna döner. Eski onaylı teklif kendiliğinden aktif olmaz.
- Yeni teklifin sürümü artmaya devam eder. Silinmiş sürüm numarası yeniden kullanılmaz.
- Tamir ediliyor, Parça bekleniyor, Teslime hazır veya Teslim edildi durumundaki servisin güncel teklifi silinemez. Önceki teklif geçmişinden kullanılmayan bir sürüm kaldırılabilir. Bu koruma sunucuda da uygulanır.
- Silme, doğrulama kodu iptali ve denetim kaydı tek atomik SQL ifadesinde yapılır. Eşzamanlı değişiklik 409 döndürür; yenileyip tekrar deneyin. Aynı silmeyi tekrar göndermek mükerrer denetim kaydı oluşturmaz.

## API

DELETE `/api/v1/records/{recordId}/quotes/{version}`. Çalışan oturumu/Bearer gerekir. Yanıt güncel servis kaydıdır. Çalışan JSON yanıtında silinen teklifin deletedAt/deletedBy bilgisi denetim için korunur. Müşteri izdüşümü silinen teklifleri içermez. Güncel sürüm silinmişse eski sürümler aktif teklif olarak sunulmaz; takip quotes dizisi boş döner.

## Kontroller

Webde 37 otomatik test ve üretim derlemesi geçti. Yeni testler eski onayın canlanmaması, sürüm numarası, iş aşaması koruması ve atomik OTP iptalini kapsar. Tarayıcıda iptal, başarısız silme, başarılı silme ve yenileme akışı taklit API ile kontrol edildi; gerçek müşteri teklifleri test için silinmedi. iOS kaynak/sözdizimi/çeviri kontrolleri geçti. Yeni istemci davranışı için XCTest eklendi; Xcode derlemesi ve XCTest bu ortamda çalıştırılmadı.

# Servis durumu güncelleme

Servis detayında İşlemler altındaki Süreci güncelle / Bearbeitungsstatus aktualisieren alanını kullanın. Menü aynı ekranda açılır ve dokuz durumu içerir:

1. Teslim alındı
2. İnceleniyor
3. Fiyat onayı bekliyor
4. Tamir ediliyor
5. Parça bekleniyor
6. Teslime hazır
7. Teslim edildi
8. Teklif reddedildi
9. İptal edildi

Güncelle düğmesi seçili durum mevcut durumdan farklıysa kullanılabilir. Normal geçişler onay sorusu sonrası ortak API'ye gönderilir. Webde olduğu gibi geçiş kuralları sunucuda kontrol edilir; geçersiz geçişin hata mesajı detay ekranında gösterilir. Müşteri onayı çalışan tarafından verilmez.

Teslime hazır için gerekli tamamlanma bilgileri ve Teslim edildi için teslim açıklaması ilgili formlardan kaydedilir. Fiyat onayı bekliyor seçildiğinde henüz teklif yoksa ve mevcut aşama uygunsa teklif formu açılır. Yanlışlıkla iptal edilen kayıt mevcut Yeniden aktif et düğmesiyle açılır.

Bu sürüm, istenmeyen cihaz arşivi ve teklif listesi bağlantılarını kaldırır. Önceki fotoğraf, teklif, QR, müşteri takibi ve yeniden aktifleştirme işlevleri korunur.

Mevcut projede yalnızca UstaX/Views/RecordDetailView.swift ve UstaX/Resources/Translations.json dosyalarını değiştirmek yeterlidir. Tam proje paketinde ilave arşiv ekranları bulunmaz. Product > Clean Build Folder ardından Run uygulayın.

Kaynak, çeviri ve proje kontrolleri yapıldı. Bu ortamda Xcode build, XCTest ve Simulator çalıştırılmadı.

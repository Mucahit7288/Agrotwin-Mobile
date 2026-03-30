# 🌿 AGROTWIN Mobile

**AGROTWIN**, KOBİ ölçekli işletmeler için tasarlanmış, **Yapay Zeka destekli topraksız tarım dijital ikiz** platformudur. Bu depo (repository), projenin mobil uygulama kısmını içermektedir.

## 🚀 Proje Hakkında
Geleneksel tarım yöntemlerini dijitalleştirerek verimliliği artırmayı hedefleyen AGROTWIN; sensör verilerini işleyerek seranın dijital bir kopyasını oluşturur ve çiftçilere anlık takip ile karar destek mekanizmaları sunar.

### ✨ Temel Özellikler
* **Anlık İzleme:** Sıcaklık, nem, pH ve EC değerlerinin gerçek zamanlı takibi.
* **Dijital İkiz Entegrasyonu:** Fiziksel seranın dijital ortamda görselleştirilmesi.
* **AI Destekli Analiz:** Bitki sağlığı ve hasat tahmini için uçta çalışan (Edge AI) yapay zeka çıkarımları.
* **Akıllı Bildirimler:** Kritik eşik değerleri aşıldığında kullanıcıyı uyarma.

## 🛠️ Kullanılan Teknolojiler
* **Mobile:** Flutter
* **Backend:** Java Spring Boot Entegrasyonu (Tamamlanmadı)
* **Data:** MQTT (Yapılıyor.)
* **AI:** -- (Tamamlanmadı)

## 📐 Mimari ve Veri Akışı
Sistem gerçek zamanlı hız ve güvenlik sağlamak üzere tasarlanmıştır:
1. Seradaki sensörlerden alınan topraksız tarım verileri **MQTT Broker**'a düşer.
2. Veriler **Turkcell Bulut** üzerinde koşan **Firebase Realtime Database** yapısında tutulur.
3. Güncel bilgiler **REST API** üzerinden Flutter mobil uygulamasına anlık olarak yansıtılır.
4. Uygulama içerisine gömülü yapay zeka modeli, bu verileri kullanarak akıllı tahminler ve analizler yapar.

## 📦 Kurulum (Installation)
Projeyi yerel makinenizde çalıştırmak için aşağıdaki komutları sırasıyla terminalinizde çalıştırın:

```bash
# 1. Depoyu klonlayın
git clone https://github.com/kullanici-adin/agrotwin-mobile.git

# 2. Proje klasörünün içine girin
cd agrotwin-mobile

# 3. Gerekli Flutter paketlerini indirin
flutter pub get

# 4. Uygulamayı çalıştırın
flutter run
# 🌱 AgroTwin - AI Destekli Topraksız Tarım Dijital İkizi

AgroTwin, modern tarım tekniklerini yapay zeka ve dijital ikiz teknolojisiyle birleştiren, düşük maliyetli ve yüksek verimli bir akıllı tarım platformudur.

## 🚀 Proje Hakkında
Bu proje, küçük ve orta ölçekli üreticilerin topraksız tarım sistemlerini uzaktan izlemesini, kontrol etmesini ve yapay zeka destekli karar mekanizmalarıyla verimi artırmasını hedefler.

### ✨ Temel Özellikler
* **Canlı Sensör İzleme:** Sıcaklık, Nem, pH, Işık ve Su Seviyesi verilerinin anlık takibi.
* **Dijital İkiz:** Fiziksel sistemin mobil uygulama üzerinden görsel ve verisel simülasyonu.
* **AI Karar Mekanizması:** Sensör verilerine göre Pompa, Fan ve Isıtıcı gibi eyleyicilerin otomatik yönetimi.
* **Analitik Grafik:** Geçmişe dönük verilerin görselleştirilmesi ve verimlilik analizi.
* **Bulut Entegrasyonu:** MQTT (HiveMQ Cloud) üzerinden dünyanın her yerinden erişim.

## 🛠️ Teknoloji Yığını
* **Frontend:** Flutter (Dart) - State Management: Provider/ChangeNotifier
* **Backend:** Java Spring Boot - Veritabanı: Sqlite
* **Haberleşme:** MQTT (HiveMQ Cloud) & REST API
* **IoT/Donanım:** ESP32, DHT22, Su Seviye ve sıcaklık Sensörü, Işık Sensörü , ortam nem ve sıcaklık sensörü

## 📁 Proje Yapısı
Proje iki ana klasörden oluşmaktadır:
- `/Frontend`: Flutter mobil uygulama kodları.
- `/Backend`: Spring Boot API ve veri işleme kodları.

## 👷 Kurulum (Geliştiriciler İçin)

### Mobil Uygulama
1. Flutter SDK'nın yüklü olduğundan emin olun.
2. `cd Frontend`
3. `flutter pub get`
4. `flutter run`

### Backend
1. JDK 17+ yüklü olduğundan emin olun.
2. `cd Backend`
3. `./mvnw spring-boot:run`

## 👥 Ekip
* **Muhammet Mücahit** - [GitHub Profilin](https://github.com/Mucahit7288)
* **Arda Tekgöz** - [GitHub Profili](https://github.com/ArdaTekgoz)
* **Hasan Recep Müslim**-[GitHub Profili](https://github.com/HasanMuslim)

---
Bu Proje Turkcell Yarının Teknoloji Liderleri kapsamında geliştirilmiştir.

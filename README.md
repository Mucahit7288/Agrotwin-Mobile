# 🌱 AgroTwin - AI Destekli Topraksız Tarım Dijital İkizi

<<<<<<< HEAD
AgroTwin, modern tarım tekniklerini yapay zeka, IoT ve dijital ikiz yaklaşımıyla birleştiren düşük maliyetli bir akıllı tarım platformudur.

Bu proje, Turkcell Yarının Teknoloji Liderleri yarışması kapsamında geliştirilmiştir ve toplam 829 proje arasında ilk 38 projeye seçilerek yarı final aşamasına kadar yükselmiştir.

## 🇹🇷 Türkçe

### 🚀 Proje Özeti
AgroTwin; topraksız tarım sistemlerinde sensör verilerini toplayan, mobil uygulama üzerinden izleme ve kontrol sağlayan, makine öğrenmesi destekli öneriler üreten uçtan uca bir dijital ikiz platformudur.

### 📱 Mobil
- Flutter tabanlı mobil arayüz ile anlık sistem takibi yapılır.
- Sensör verileri grafiksel olarak görüntülenir ve geçmiş veriler izlenir.
- Kullanıcı, pompa, fan ve ısıtıcı gibi eyleyicileri uzaktan kontrol eder.
- REST API ve MQTT entegrasyonu ile gerçek zamanlı veri akışı sağlanır.

### 🌐 IoT
- ESP32 tabanlı edge node, sahadaki sensör verilerini toplar.
- DHT22, su sıcaklık sensörü, su seviye sensörü ve ışık sensörü ile çevresel durum takip edilir.
- MQTT üzerinden buluta veri gönderimi ve komut alma mekanizması çalışır.
- Bağlantı kesintilerinde sistemin güvenli çalışmasını sürdüren yerel kontrol kurgusu bulunur.

### 🤖 ML
- Toplanan veriler ile karar destek süreçleri için yapay zeka/ML modelleri beslenir.
- Ortam koşullarına göre üretim verimini artırmaya yönelik öneriler üretilir.
- Dijital ikiz yaklaşımı ile fiziksel sistem davranışı veriye dayalı şekilde modellenir.
- AI/ML bileşenleri, otomasyon ve analiz katmanına destek verir.

### 🛠️ Teknoloji Yığını
- **Mobil:** Flutter (Dart), Provider/ChangeNotifier
- **Backend:** Java Spring Boot, SQLite
- **Haberleşme:** MQTT (HiveMQ Cloud), REST API
- **IoT/Donanım:** ESP32, DHT22, su seviye ve sıcaklık sensörleri, ışık sensörü

### 📁 Proje Yapısı
- `/Frontend`: Flutter mobil uygulama kodları
- `/Backend`: Spring Boot API ve veri işleme kodları
- `/AI/ML`: Yapay zeka, makine öğrenmesi ve chatbot (LLM) kodları

### 👷 Kurulum (Geliştiriciler İçin)
#### Mobil Uygulama
=======
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
- `/AI/ML`:Yapay Zeka, ML ve Chatbot (LLM) kodları.

## 👷 Kurulum (Geliştiriciler İçin)

### Mobil Uygulama
>>>>>>> 158ee7c0f6ef0ba034ec84f0acef01096ed51837
1. Flutter SDK'nın yüklü olduğundan emin olun.
2. `cd Frontend`
3. `flutter pub get`
4. `flutter run`

<<<<<<< HEAD
#### Backend
=======
### Backend
>>>>>>> 158ee7c0f6ef0ba034ec84f0acef01096ed51837
1. JDK 17+ yüklü olduğundan emin olun.
2. `cd Backend`
3. `./mvnw spring-boot:run`

<<<<<<< HEAD
## 🇬🇧 English

### 🚀 Project Summary
AgroTwin is an end-to-end digital twin platform for soilless agriculture that collects sensor data, provides mobile monitoring and control, and generates machine-learning-assisted insights.

This project was developed within the scope of Turkcell Tomorrow's Technology Leaders competition, and it advanced to the semi-final stage by being selected among the top 38 projects out of 829 total submissions.

### 📱 Mobile
- A Flutter-based mobile interface provides real-time system monitoring.
- Sensor data is visualized with charts, including historical tracking.
- Users can remotely control actuators such as pump, fan, and heater.
- Real-time data flow is enabled through REST API and MQTT integration.

### 🌐 IoT
- An ESP32-based edge node collects sensor data from the field.
- Environmental conditions are monitored using DHT22, water temperature, water level, and light sensors.
- MQTT is used for cloud telemetry publishing and control command handling.
- A local fail-safe logic keeps the system operating safely during connectivity loss.

### 🤖 ML
- Collected data feeds AI/ML models for decision-support workflows.
- The platform generates recommendations to improve production efficiency based on environmental conditions.
- The digital twin approach models physical system behavior in a data-driven way.
- AI/ML components support automation and analytics layers.

### 🛠️ Tech Stack
- **Mobile:** Flutter (Dart), Provider/ChangeNotifier
- **Backend:** Java Spring Boot, SQLite
- **Communication:** MQTT (HiveMQ Cloud), REST API
- **IoT/Hardware:** ESP32, DHT22, water level and temperature sensors, light sensor

### 📁 Project Structure
- `/Frontend`: Flutter mobile application code
- `/Backend`: Spring Boot API and data processing code
- `/AI/ML`: AI, machine learning, and chatbot (LLM) code

### 👥 Team
- **Muhammet Mücahit** - [GitHub Profile](https://github.com/Mucahit7288)
- **Arda Tekgöz** - [GitHub Profile](https://github.com/ArdaTekgoz)
- **Hasan Recep Müslim** - [GitHub Profile](https://github.com/HasanMuslim)
=======
## 👥 Ekip
* **Muhammet Mücahit** - [GitHub Profilin](https://github.com/Mucahit7288)
* **Arda Tekgöz** - [GitHub Profili](https://github.com/ArdaTekgoz)
* **Hasan Recep Müslim**- [GitHub Profili](https://github.com/HasanMuslim)

---
Bu Proje Turkcell Yarının Teknoloji Liderleri kapsamında geliştirilmiştir.
>>>>>>> 158ee7c0f6ef0ba034ec84f0acef01096ed51837

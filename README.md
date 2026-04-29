# 🌱 AgroTwin - AI Destekli Topraksız Tarım Dijital İkizi

AgroTwin; topraksız tarım süreçlerini mobil uygulama, IoT altyapısı ve yapay zeka destekli karar mekanizmalarıyla bir araya getiren uçtan uca dijital ikiz platformudur.

Bu proje, Turkcell Yarının Teknoloji Liderleri programı kapsamında geliştirilmiş ve 829 proje arasından ilk 38'e girerek yarı final aşamasına yükselmiştir.

---

## 🇹🇷 Türkçe

### 🚀 Proje Özeti
AgroTwin'in amacı, küçük ve orta ölçekli üreticilerin üretim ortamını uzaktan takip etmesini, kritik eyleyicileri kontrol etmesini ve veriye dayalı önerilerle verimi artırmasını sağlamaktır.

### ✨ Temel Özellikler
- **Canlı sensör izleme:** Ortam verilerinin anlık takibi.
- **Uzaktan kontrol:** Pompa, fan ve ısıtıcı gibi eyleyicilerin mobil uygulama üzerinden yönetimi.
- **Dijital ikiz yaklaşımı:** Fiziksel sistem davranışının yazılım tarafında modellenmesi.
- **Yapay zeka destekli analiz:** Sensör verileriyle karar destek ve optimizasyon önerileri üretimi.
- **Bulut haberleşmesi:** MQTT ve REST API tabanlı gerçek zamanlı veri akışı.

### 🛠️ Teknoloji Yığını
- **Mobil:** Flutter (Dart), Provider/ChangeNotifier
- **Backend:** Java Spring Boot
- **Veri/Kayıt:** SQLite, CSV
- **Haberleşme:** MQTT (HiveMQ Cloud), REST API
- **IoT/Donanım:** ESP32, DHT22, su seviye ve sıcaklık sensörleri, ışık sensörü
- **YZ/ML:** Python tabanlı modelleme ve veri analitiği

### 📁 Proje Yapısı
- `Mobile/Frontend`: Flutter mobil uygulaması
- `Mobile/Backend`: Spring Boot servis katmanı
- `IoT`: ESP32 firmware ve sahadaki sensör/eyleyici entegrasyonları
- `YZ_ML`: Yapay zeka, makine öğrenmesi, veri setleri ve model dosyaları

### 👷 Kurulum (Geliştiriciler İçin)
#### Mobil Uygulama (Flutter)
1. Flutter SDK kurulu olmalıdır.
2. `cd Mobile/Frontend`
3. `flutter pub get`
4. `flutter run`

#### Backend (Spring Boot)
1. JDK 17+ kurulu olmalıdır.
2. `cd Mobile/Backend`
3. Windows için: `mvnw.cmd spring-boot:run`
4. macOS/Linux için: `./mvnw spring-boot:run`

#### IoT (ESP32)
1. `IoT/AgroTwin_ESP32_1.ino` dosyasını Arduino IDE veya PlatformIO ile açın.
2. Wi-Fi ve MQTT ayarlarını kendi ortamınıza göre güncelleyin.
3. Kodu ESP32 karta yükleyin.

#### YZ/ML Servisleri
1. Python 3.10+ önerilir.
2. `cd YZ_ML`
3. Gerekli paketleri kurun (projenin kullandığı ortama göre `pip install ...`).
4. API ve model betiklerini ihtiyaca göre çalıştırın (ör. `api.py`, `agrotwin_ai_v5_final.py`).

### 👥 Ekip
- **Muhammet Mücahit** - [GitHub](https://github.com/Mucahit7288)
- **Arda Tekgöz** - [GitHub](https://github.com/ArdaTekgoz)
- **Hasan Recep Müslim** - [GitHub](https://github.com/HasanMuslim)

---

## 🇬🇧 English

### 🚀 Project Summary
AgroTwin is an end-to-end digital twin platform for soilless agriculture, combining mobile monitoring, IoT telemetry, and AI-assisted decision support.

The project was developed under Turkcell's Tomorrow's Technology Leaders program and advanced to the semi-finals by ranking in the top 38 out of 829 projects.

### ✨ Core Features
- **Live sensor monitoring:** Real-time tracking of environmental data.
- **Remote actuator control:** Mobile control for pump, fan, and heater operations.
- **Digital twin model:** Data-driven representation of physical system behavior.
- **AI-assisted insights:** Decision-support and optimization recommendations from sensor data.
- **Cloud communication:** Real-time data flow over MQTT and REST APIs.

### 🛠️ Tech Stack
- **Mobile:** Flutter (Dart), Provider/ChangeNotifier
- **Backend:** Java Spring Boot
- **Storage/Data:** SQLite, CSV
- **Communication:** MQTT (HiveMQ Cloud), REST API
- **IoT/Hardware:** ESP32, DHT22, water level/temperature sensors, light sensor
- **AI/ML:** Python-based model training and analytics

### 📁 Project Structure
- `Mobile/Frontend`: Flutter mobile application
- `Mobile/Backend`: Spring Boot service layer
- `IoT`: ESP32 firmware and sensor/actuator integrations
- `YZ_ML`: AI/ML scripts, datasets, and model artifacts

### 👷 Setup (For Developers)
#### Mobile App (Flutter)
1. Ensure Flutter SDK is installed.
2. `cd Mobile/Frontend`
3. `flutter pub get`
4. `flutter run`

#### Backend (Spring Boot)
1. Ensure JDK 17+ is installed.
2. `cd Mobile/Backend`
3. On Windows: `mvnw.cmd spring-boot:run`
4. On macOS/Linux: `./mvnw spring-boot:run`

#### IoT (ESP32)
1. Open `IoT/AgroTwin_ESP32_1.ino` with Arduino IDE or PlatformIO.
2. Update Wi-Fi and MQTT credentials for your environment.
3. Upload firmware to the ESP32 board.

#### AI/ML Services
1. Python 3.10+ is recommended.
2. `cd YZ_ML`
3. Install required dependencies for your runtime.
4. Run the needed scripts such as `api.py` or `agrotwin_ai_v5_final.py`.

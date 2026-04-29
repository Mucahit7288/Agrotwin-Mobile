// ============================================================================
// AGROTWIN - ESP32 Edge Node Firmware
// AGROTWIN - ESP32 Uc Dugum Yazilimi
//
// Author / Yazar      : Arda TEKGOZ
// Project / Proje     : AI-supported digital twin for soilless agriculture /
//                       Topraksiz tarim icin yapay zeka destekli dijital ikiz
// Board / Kart        : ESP32 DevKit V1
// Version / Surum     : 1.0.0
// Year / Yil          : 2025
// IDE                 : Arduino IDE (ESP32 Arduino Core 2.x)
//
// Required libraries / Gerekli kutuphaneler:
// - PubSubClient
// - ArduinoJson
// - DHT Sensor Library
// - DallasTemperature
// - OneWire
// ============================================================================

#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <OneWire.h>
#include <DallasTemperature.h>

// --- Hardware pins / Donanim pinleri ---
#define PIN_DHT22        4    // DHT22 air temperature and humidity / ortam sicaklik ve nem
#define PIN_DS18B20      5    // DS18B20 water temperature / su sicakligi
#define PIN_HCSR04_TRIG 12    // HC-SR04 trigger
#define PIN_HCSR04_ECHO 14    // HC-SR04 echo
#define PIN_LDR          34   // LDR analog input / analog giris

// Relay module is configured as active-low / Role modulu aktif-low olarak ayarlandi.
#define PIN_ROLE_POMPA    25  // Water pump / su pompasi
#define PIN_ROLE_FAN      26  // Cooling fan / sogutucu fan
#define PIN_ROLE_ISITICI  27  // Heater or lamp / isitici veya ampul

#define RELE_AC_SEVIYESI     LOW
#define RELE_KAPALI_SEVIYESI HIGH

// --- User configuration / Kullanici ayarlari ---
const char* WIFI_SSID     = "AGROTWIN_AG";
const char* WIFI_PAROLA   = "agrotwin2025";

const char* MQTT_SUNUCU   = "192.168.1.100";
const int   MQTT_PORT     = 1883;
const char* MQTT_KULLANICI = "";
const char* MQTT_SIFRE     = "";
const char* MQTT_CLIENT_ID = "AGROTWIN-EdgeNode-01";

const char* TOPIC_SENSORLER = "agrotwin/sensorler";
const char* TOPIC_KOMUTLAR  = "agrotwin/komutlar";

const unsigned long SURE_SENSOR_OKUMA_MS    = 5000UL;
const unsigned long SURE_WIFI_DENEME_MS     = 10000UL;
const unsigned long SURE_MQTT_DENEME_MS     = 5000UL;
const unsigned long SURE_OFFLINE_ESIK_MS    = 300000UL;
const unsigned long SURE_HCSR04_TIMEOUT_US  = 30000UL;

#define FILTRE_PENCERE_BOYUTU 5  // Moving average size / hareketli ortalama boyutu

const float ESIK_SU_SICAKLIK_MAX    = 28.0;
const float ESIK_ORTAM_SICAKLIK_MIN = 15.0;
const float ESIK_ORTAM_NEM_MAX      = 85.0;
const float MESAFE_TANK_MIN_CM      = 5.0;

// --- Sensor and client objects / Sensor ve istemci nesneleri ---
DHT dht(PIN_DHT22, DHT22);

OneWire oneWireBus(PIN_DS18B20);
DallasTemperature ds18b20(&oneWireBus);

WiFiClient   wifiIstemci;
PubSubClient mqttIstemci(wifiIstemci);

// --- Runtime state / Calisma durumu ---
float tamponDHT_Sicaklik[FILTRE_PENCERE_BOYUTU] = {0};
float tamponDHT_Nem[FILTRE_PENCERE_BOYUTU]       = {0};
float tamponDS18B20[FILTRE_PENCERE_BOYUTU]        = {0};
int   filtreIndex = 0;
bool  filtreIsindiMi = false;

float ortamSicaklik_C  = 0.0;
float ortamNem_Yuzde   = 0.0;
float suSicaklik_C     = 0.0;
float suMesafe_cm      = 0.0;
int   isikAnalog       = 0;

bool rolePompa_Durum   = false;
bool roleFan_Durum     = false;
bool roleIsitici_Durum = false;

unsigned long sonSensorOkuma_ms   = 0;
unsigned long sonWiFiDeneme_ms    = 0;
unsigned long sonMQTTDeneme_ms    = 0;
unsigned long sonMQTTIletisim_ms  = 0;

bool offlineMod_Aktif = false;

/**
 * @brief Adds the latest sample to the shared moving-average buffer.
 * Son okumayi hareketli ortalama tamponuna ekler.
 */
void filtreYaz(float tampon[], float yeniDeger) {
  tampon[filtreIndex] = yeniDeger;
}

/**
 * @brief Returns the current moving average.
 * Guncel hareketli ortalamayi hesaplar.
 */
float filtreOrtalamaHesapla(float tampon[]) {
  float toplam = 0.0;
  int   sayi   = filtreIsindiMi ? FILTRE_PENCERE_BOYUTU : (filtreIndex + 1);
  if (sayi == 0) return 0.0;
  for (int i = 0; i < sayi; i++) {
    toplam += tampon[i];
  }
  return toplam / (float)sayi;
}

/**
 * @brief Advances the shared ring-buffer index.
 * Ortak halka tampon indisinin bir sonraki konuma gecmesini saglar.
 */
void filtreIndexIlerlet() {
  filtreIndex++;
  if (filtreIndex >= FILTRE_PENCERE_BOYUTU) {
    filtreIndex    = 0;
    filtreIsindiMi = true;
  }
}

/**
 * @brief Updates a relay only when its state really changes.
 * Roleyi sadece durum degistiginde gunceller.
 */
void roleAyarla(int pin, bool &durumRef, bool acMi, const char* isim) {
  if (durumRef == acMi) return;
  durumRef = acMi;
  digitalWrite(pin, acMi ? RELE_AC_SEVIYESI : RELE_KAPALI_SEVIYESI);
  Serial.printf("[RÖLE] %s -> %s\n", isim, acMi ? "AÇIK" : "KAPALI");
}

/**
 * @brief Reads distance from the HC-SR04 sensor with a timeout.
 * HC-SR04 sensorunden zaman asimli mesafe okur.
 */
float hcsr04Oku_cm() {
  // Start the measurement / olcumu baslat
  digitalWrite(PIN_HCSR04_TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(PIN_HCSR04_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(PIN_HCSR04_TRIG, LOW);

  long sure_us = pulseIn(PIN_HCSR04_ECHO, HIGH, SURE_HCSR04_TIMEOUT_US);

  if (sure_us == 0) {
    Serial.println("[UYARI] HC-SR04: Zaman aşımı veya nesne algılanamadı.");
    return -1.0;
  }
  return (sure_us / 2.0) * 0.0343;
}

/**
 * @brief Reads sensors, updates filters, and refreshes shared values.
 * Sensorleri okur, filtreleri gunceller ve ortak degerleri yeniler.
 */
void sensorleriOku() {
  float dhtSicaklik = dht.readTemperature();
  float dhtNem      = dht.readHumidity();

  if (!isnan(dhtSicaklik) && !isnan(dhtNem)) {
    filtreYaz(tamponDHT_Sicaklik, dhtSicaklik);
    filtreYaz(tamponDHT_Nem,      dhtNem);
  } else {
    Serial.println("[UYARI] DHT22: Geçersiz okuma, filtre güncellenmedi.");
  }

  ds18b20.requestTemperatures();
  float suSic = ds18b20.getTempCByIndex(0);
  if (suSic != DEVICE_DISCONNECTED_C && suSic > -50.0) {
    filtreYaz(tamponDS18B20, suSic);
  } else {
    Serial.println("[UYARI] DS18B20: Sensör bağlı değil veya geçersiz okuma.");
  }

  float mesafe = hcsr04Oku_cm();
  if (mesafe > 0) {
    suMesafe_cm = mesafe;
  }

  isikAnalog = analogRead(PIN_LDR);

  filtreIndexIlerlet();

  ortamSicaklik_C = filtreOrtalamaHesapla(tamponDHT_Sicaklik);
  ortamNem_Yuzde  = filtreOrtalamaHesapla(tamponDHT_Nem);
  suSicaklik_C    = filtreOrtalamaHesapla(tamponDS18B20);

  Serial.printf("[SENSÖR] T_ortam=%.1f°C  H_ortam=%.1f%%  T_su=%.1f°C  Mesafe=%.1fcm  Isik=%d\n",
                ortamSicaklik_C, ortamNem_Yuzde, suSicaklik_C, suMesafe_cm, isikAnalog);
}

/**
 * @brief Runs fallback rules when MQTT is unavailable.
 * MQTT yokken yedek kural setini calistirir.
 */
void offlineGuvenliModu_Calistir() {
  Serial.println("[OFFLİNE MOD] Otonom kural motoru çalışıyor...");

  if (suSicaklik_C > ESIK_SU_SICAKLIK_MAX && suMesafe_cm > MESAFE_TANK_MIN_CM) {
    roleAyarla(PIN_ROLE_POMPA, rolePompa_Durum, true, "Pompa");
  } else if (suSicaklik_C <= ESIK_SU_SICAKLIK_MAX - 1.0) {
    roleAyarla(PIN_ROLE_POMPA, rolePompa_Durum, false, "Pompa");
  }

  if (suMesafe_cm > 0 && suMesafe_cm <= MESAFE_TANK_MIN_CM) {
    roleAyarla(PIN_ROLE_POMPA, rolePompa_Durum, false, "Pompa (Kuru Koruma)");
    Serial.println("[UYARI] Su seviyesi kritik! Pompa devre dışı.");
  }

  if (ortamSicaklik_C < ESIK_ORTAM_SICAKLIK_MIN) {
    roleAyarla(PIN_ROLE_ISITICI, roleIsitici_Durum, true, "Isıtıcı/Ampul");
  } else if (ortamSicaklik_C >= ESIK_ORTAM_SICAKLIK_MIN + 1.5) {
    roleAyarla(PIN_ROLE_ISITICI, roleIsitici_Durum, false, "Isıtıcı/Ampul");
  }

  if (ortamNem_Yuzde > ESIK_ORTAM_NEM_MAX) {
    roleAyarla(PIN_ROLE_FAN, roleFan_Durum, true, "Fan");
  } else if (ortamNem_Yuzde <= ESIK_ORTAM_NEM_MAX - 5.0) {
    roleAyarla(PIN_ROLE_FAN, roleFan_Durum, false, "Fan");
  }
}

/**
 * @brief Handles incoming MQTT control messages.
 * Gelen MQTT kontrol mesajlarini isler.
 */
void mqttMesajAlindi(char* topic, byte* payload, unsigned int uzunluk) {
  String mesaj = "";
  for (unsigned int i = 0; i < uzunluk; i++) {
    mesaj += (char)payload[i];
  }
  Serial.printf("[MQTT ↓] Kanal: %s | Mesaj: %s\n", topic, mesaj.c_str());

  sonMQTTIletisim_ms = millis();

  if (offlineMod_Aktif) {
    offlineMod_Aktif = false;
    Serial.println("[SİSTEM] Yapay Zekâ iletişimi yeniden kuruldu. Online moda geçildi.");
  }

  StaticJsonDocument<128> jsonBelge;
  DeserializationError hata = deserializeJson(jsonBelge, mesaj);
  if (hata) {
    Serial.printf("[HATA] JSON ayrıştırma başarısız: %s\n", hata.c_str());
    return;
  }

  if (!jsonBelge.containsKey("cihaz") || !jsonBelge.containsKey("durum")) {
    Serial.println("[HATA] Komut JSON'ında 'cihaz' veya 'durum' alanı eksik.");
    return;
  }

  String cihaz = jsonBelge["cihaz"].as<String>();
  String durum = jsonBelge["durum"].as<String>();
  cihaz.toLowerCase();
  durum.toUpperCase();

  bool acMi = (durum == "ON");

  if (cihaz == "pompa") {
    if (acMi && suMesafe_cm > 0 && suMesafe_cm <= MESAFE_TANK_MIN_CM) {
      Serial.println("[GÜVENLİK] Yapay Zekâ pompa açmak istedi, ancak su seviyesi kritik. Komut reddedildi.");
      return;
    }
    roleAyarla(PIN_ROLE_POMPA, rolePompa_Durum, acMi, "Pompa");
  }
  else if (cihaz == "fan") {
    roleAyarla(PIN_ROLE_FAN, roleFan_Durum, acMi, "Fan");
  }
  else if (cihaz == "isitici" || cihaz == "isitici/ampul" || cihaz == "ampul") {
    roleAyarla(PIN_ROLE_ISITICI, roleIsitici_Durum, acMi, "Isıtıcı/Ampul");
  }
  else {
    Serial.printf("[UYARI] Bilinmeyen cihaz komutu: '%s'\n", cihaz.c_str());
  }
}

/**
 * @brief Publishes filtered sensor data as JSON.
 * Filtrelenmis sensor verilerini JSON olarak yayinlar.
 */
void mqttVeriYayinla() {
  if (!mqttIstemci.connected()) return;

  StaticJsonDocument<200> jsonBelge;
  jsonBelge["T_ortam"]      = serialized(String(ortamSicaklik_C, 1));
  jsonBelge["H_ortam"]      = serialized(String(ortamNem_Yuzde,  1));
  jsonBelge["T_su"]         = serialized(String(suSicaklik_C,    1));
  jsonBelge["Su_Mesafe_cm"] = serialized(String(suMesafe_cm,     1));
  jsonBelge["Isik_Analog"]  = isikAnalog;

  char jsonBuffer[200];
  size_t uzunluk = serializeJson(jsonBelge, jsonBuffer);

  bool basarili = mqttIstemci.publish(TOPIC_SENSORLER, jsonBuffer, uzunluk);
  if (basarili) {
    Serial.printf("[MQTT ↑] %s -> %s\n", TOPIC_SENSORLER, jsonBuffer);
    sonMQTTIletisim_ms = millis();
  } else {
    Serial.println("[HATA] MQTT yayın başarısız!");
  }
}

/**
 * @brief Keeps the Wi-Fi connection alive.
 * Wi-Fi baglantisini ayakta tutar.
 */
bool wifiBaglantiKontrol() {
  if (WiFi.status() == WL_CONNECTED) return true;

  unsigned long simdi = millis();
  if (simdi - sonWiFiDeneme_ms < SURE_WIFI_DENEME_MS) return false;
  sonWiFiDeneme_ms = simdi;

  Serial.printf("[Wi-Fi] Bağlanılıyor: %s ...\n", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PAROLA);

  unsigned long bekBasi = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - bekBasi < 8000UL) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("[Wi-Fi] Bağlandı! IP: %s\n", WiFi.localIP().toString().c_str());
    return true;
  } else {
    Serial.println("[Wi-Fi] Bağlantı başarısız, sonraki periyotta yeniden denecek.");
    return false;
  }
}

/**
 * @brief Keeps the MQTT broker connection alive.
 * MQTT broker baglantisini ayakta tutar.
 */
bool mqttBaglantiKontrol() {
  if (mqttIstemci.connected()) return true;
  if (WiFi.status() != WL_CONNECTED) return false;

  unsigned long simdi = millis();
  if (simdi - sonMQTTDeneme_ms < SURE_MQTT_DENEME_MS) return false;
  sonMQTTDeneme_ms = simdi;

  Serial.printf("[MQTT] Broker'a bağlanılıyor: %s:%d ...\n", MQTT_SUNUCU, MQTT_PORT);

  bool baglandimi;
  if (strlen(MQTT_KULLANICI) > 0) {
    baglandimi = mqttIstemci.connect(MQTT_CLIENT_ID, MQTT_KULLANICI, MQTT_SIFRE);
  } else {
    baglandimi = mqttIstemci.connect(MQTT_CLIENT_ID);
  }

  if (baglandimi) {
    Serial.println("[MQTT] Broker'a bağlandı.");
    mqttIstemci.subscribe(TOPIC_KOMUTLAR);
    Serial.printf("[MQTT] Abone olundu: %s\n", TOPIC_KOMUTLAR);
    sonMQTTIletisim_ms = millis();
    return true;
  } else {
    Serial.printf("[MQTT] Bağlantı başarısız. Hata kodu: %d\n", mqttIstemci.state());
    return false;
  }
}

/**
 * @brief Switches to safe mode if MQTT stays silent for too long.
 * MQTT uzun sure sessiz kalirsa sistemi guvenli moda alir.
 */
void watchdogKontrol() {
  unsigned long simdi = millis();
  if (!offlineMod_Aktif &&
      (simdi - sonMQTTIletisim_ms > SURE_OFFLINE_ESIK_MS)) {
    offlineMod_Aktif = true;
    Serial.println("╔══════════════════════════════════════════════════╗");
    Serial.println("║  [WATCHDOG] OFFLİNE GÜVENLİ MOD AKTİF!          ║");
    Serial.println("║  5 dakikadır yapay zekâdan iletişim yok.         ║");
    Serial.println("║  Bitki kurtarma kuralları devreye alındı.        ║");
    Serial.println("╚══════════════════════════════════════════════════╝");
  }
}

void setup() {
  Serial.begin(115200);
  while (!Serial && millis() < 3000);
  Serial.println("\n\n[AGROTWIN] Edge Node v1.0.0 başlatılıyor...");

  pinMode(PIN_HCSR04_TRIG, OUTPUT);
  pinMode(PIN_HCSR04_ECHO, INPUT);
  pinMode(PIN_LDR,         INPUT);

  // Set relay outputs to idle before enabling the pins / Roleleri tetiklemeden baslat
  digitalWrite(PIN_ROLE_POMPA,   RELE_KAPALI_SEVIYESI);
  digitalWrite(PIN_ROLE_FAN,     RELE_KAPALI_SEVIYESI);
  digitalWrite(PIN_ROLE_ISITICI, RELE_KAPALI_SEVIYESI);
  pinMode(PIN_ROLE_POMPA,   OUTPUT);
  pinMode(PIN_ROLE_FAN,     OUTPUT);
  pinMode(PIN_ROLE_ISITICI, OUTPUT);
  Serial.println("[SETUP] Röle pinleri KAPALI konumunda başlatıldı.");

  dht.begin();
  Serial.println("[SETUP] DHT22 başlatıldı.");

  ds18b20.begin();
  ds18b20.setResolution(12);
  ds18b20.setWaitForConversion(false);
  Serial.println("[SETUP] DS18B20 başlatıldı (12-bit çözünürlük).");

  digitalWrite(PIN_HCSR04_TRIG, LOW);
  Serial.println("[SETUP] HC-SR04 hazır.");

  mqttIstemci.setServer(MQTT_SUNUCU, MQTT_PORT);
  mqttIstemci.setCallback(mqttMesajAlindi);
  mqttIstemci.setKeepAlive(60);
  mqttIstemci.setSocketTimeout(10);
  Serial.printf("[SETUP] MQTT hedef: %s:%d\n", MQTT_SUNUCU, MQTT_PORT);

  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.persistent(false);

  sonMQTTIletisim_ms = millis();

  Serial.println("[SETUP] Başlangıç yapılandırması tamamlandı.");
  Serial.println("[SETUP] Ana döngü başlıyor...\n");
}

void loop() {
  unsigned long simdi = millis();

  bool wifiBagliMi = wifiBaglantiKontrol();

  if (wifiBagliMi) {
    mqttBaglantiKontrol();
  }

  if (mqttIstemci.connected()) {
    mqttIstemci.loop();
  }

  if (simdi - sonSensorOkuma_ms >= SURE_SENSOR_OKUMA_MS) {
    sonSensorOkuma_ms = simdi;

    sensorleriOku();

    watchdogKontrol();

    if (offlineMod_Aktif || !mqttIstemci.connected()) {
      offlineGuvenliModu_Calistir();
    } else {
      mqttVeriYayinla();
    }
  }

  // Main loop stays responsive by relying on millis() / Ana dongu millis() ile akici kalir
}

// End of file / Dosya sonu

# ============================================================================
#
#   ___  ___  ____  ____  ____  __    __  ____  _  _
#  / __)/ __)(  _ \(  _ \(_  _)/  \  (_  )(_  _)( \/ )
# ( (_ \) _)  )   / )   / _)( ( () )  )(   )(   )  (
#  \___/(____)(_)\_)(_)\_)(____)\ __/  (__) (__) (_/\_)
#
#  AGROTWIN — Master Node v6.0.0 (Bodrum Papatyası Reçetesi)
#  Topraksız Tarım için Yapay Zekâ Destekli Dijital İkiz
#
#  Versiyon  : 6.0.0
#  Bitki     : Osteospermum (Bodrum Papatyası)
#  Python    : 3.10+
#
#  Kurulum:
#    pip install paho-mqtt tensorflow pandas scikit-learn numpy requests joblib
#
# ============================================================================
#  ⚙️  HIZLI REFERANS
# ============================================================================
#
#  [1] EĞİTİM VERİ SETİ
#      ogretmen.py'yi çalıştır → agrotwin_data.csv etiketlenir.
#      Windows  : set AGROTWIN=/veri/agrotwin_data.csv
#      Linux/Mac: export AGROTWIN=/veri/agrotwin_data.csv
#
#  [2] MQTT BROKER
#      KONFIG.mqtt_sunucu → şu an: mqtt-dashboard.com:1883
#
#  [3] SQLite (Grafana)
#      Otomatik oluşturulur: ./agrotwin_data.db
#
#  [4] EPİAŞ API (kamuya açık, token gerekmez)
#      https://seffaflik.epias.com.tr/electricity-service/v1/markets/dam/data/mcp
#
#  [5] BODRUM PAPATYASI REÇETESİ
#      Sıcaklık  : 15–24°C (kritik: 5–30°C)
#      Nem       : %40–60 ideal, %70 üstü fan devreye girer
#      Işık      : 25000–45000 Lux optimal, <25000 Lux Growlight açılır
#      Sulama    : Her saatin ilk 10 dakikasında (döngüsel pompa)
#
#  [6] MANUEL MOD
#      MQTT topic "agrotwin/mod" → "MANUEL" veya "OTONOM" yayınla.
#
# ============================================================================
#
#  v5 → v6 Değişiklikleri:
#    - [REÇETE] Bodrum Papatyası parametreleri config'e entegre edildi
#    - [YENİ] Işık (Isik_Lux) özelliği eklendi, Growlight çıkışı eklendi
#    - [KALDIRILDI] Tahliye (tahliye_karar) tamamen çıkarıldı
#    - [YENİ] Manuel/Otonom mod (topic_mod)
#    - [YENİ] Veriye dayalı chatbot: pred güven %, trend, feature importance
#    - [YENİ] GlobalState'e son_pred_degerler, son_trend, son_feature_imp eklendi
#    - [YENİ] su_sicaklik kararı kaldırıldı (Papatya su sıcaklığı gerektirmez)
#
# ============================================================================

from __future__ import annotations

import csv
import json
import logging
import os
import sqlite3
import threading
import time
from collections import deque
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional

import joblib
import numpy as np
import pandas as pd
import paho.mqtt.client as mqtt
import requests
from sklearn.metrics import accuracy_score, f1_score, roc_auc_score
from sklearn.preprocessing import MinMaxScaler
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau
from tensorflow.keras.layers import LSTM, Dense, Dropout
from tensorflow.keras.models import Sequential, load_model

# Enerji optimizasyon modülü (agrotwin_enerji.py aynı dizinde olmalı)
try:
    from agrotwin_enerji import EnerjiModulu
    _ENERJI_MODUL_MEVCUT = True
except ImportError:
    _ENERJI_MODUL_MEVCUT = False
    EnerjiModulu = None  # type: ignore

# ============================================================================
# BÖLÜM 1: YAPILANDIRMA SABİTLERİ
# ============================================================================

@dataclass(frozen=True)
class AgroTwinConfig:
    """
    Tüm sabitler tek yerde.
    Reçete değiştirmek istersen yalnızca bu bloğu düzenle.
    """
    # --- MQTT ---
    mqtt_sunucu:    str = "mqtt-dashboard.com"
    mqtt_port:      int = 1883
    mqtt_kullanici: str = ""
    mqtt_sifre:     str = ""
    mqtt_client_id: str = "clientId-qjfDCmOy5n"

    # --- MQTT Topic'leri ---
    topic_sensorler:  str = "agrotwin/sensorler"
    topic_komutlar:   str = "agrotwin/komutlar"
    topic_ai_log:     str = "agrotwin/ai_log"
    topic_chat_soru:  str = "agrotwin/chat/soru"
    topic_chat_cevap: str = "agrotwin/chat/cevap"
    topic_mod:        str = "agrotwin/mod"   # MANUEL / OTONOM

    # ── Bodrum Papatyası (Osteospermum) Reçetesi ──────────────────────────
    # Sıcaklık
    gunduz_baslangic:   int   = 6
    gunduz_bitis:       int   = 18
    gunduz_sicaklik_min: float = 15.0  # °C — gündüz optimum alt
    gunduz_sicaklik_max: float = 24.0  # °C — gündüz optimum üst
    gece_sicaklik_min:  float = 10.0  # °C — gece optimum alt
    gece_sicaklik_max:  float = 15.0  # °C — gece optimum üst
    esik_sicaklik_krit_max: float = 30.0  # °C — üstü: fan zorunlu (sıcaklık stresi)
    esik_sicaklik_krit_min: float = 5.0   # °C — altı: ısıtıcı zorunlu (don riski)

    # Nem
    esik_nem_max:       float = 70.0    # % — üstü: fan aç (mantar riski)
    esik_nem_ideal_max: float = 60.0    # % — ideal üst sınır

    # Işık (kapalı ortam; doğal gün ışığına bağlı değil)
    # Bodrum Papatyası için hedef: analog 0-4096 aralığı
    esik_isik_analog_min:      float = 400.0   # analog < 400 => Growlight aç
    esik_isik_analog_max:      float = 3600.0  # analog > 3600 => Growlight kapat
    esik_isik_min:             float = 25000.0 # Lux alt sınır (backward uyum)
    esik_isik_optimal:         float = 45000.0 # Lux üst sınır (backward uyum)

    # Sulama döngüsü (her saatin X. ile Y. dakikası arası pompa açık)
    # Sulama döngüsü: saatte 10 dakika çalıştır
    pompa_dakika_baslangic: int = 0
    pompa_dakika_bitis:     int = 10

    # Elektrik maliyet eşiği
    esik_elektrik_pahali:     float = 2000.0
    varsayilan_elektrik_fiyat: float = 1500.0

    # ── ML ────────────────────────────────────────────────────────────────
    ml_veri_esigi:      int   = 50
    lookback_window:    int   = 3     # 3 mesajda LSTM devreye girer
    epochs:             int   = 50
    batch_size:         int   = 32
    validation_split:   float = 0.15
    test_split:         float = 0.15
    lstm_units_1:       int   = 64
    lstm_units_2:       int   = 32
    dropout_rate:       float = 0.2
    early_stop_patience: int  = 7

    # Girdi özellikleri (feature engineering sonrası — model bunu görür)
    # 16 özellik: 6 ham + 3 MA + 3 dT + 4 prev
    tum_ozellikler: tuple = (
        "DHT_temp", "DHT_humidity",
        "Isik_Lux", "elektrik_fiyati", "hour", "dakika",
        "MA_DHT_temp", "MA_Isik_Lux", "MA_elektrik_fiyati",
        "dT_DHT_temp", "dT_Isik_Lux", "dT_elektrik_fiyati",
        "prev_pompa", "prev_fan", "prev_isitici", "prev_isik",
    )

    # CSV sütunları (canlı veri birikimi)
    csv_sutunlar: tuple = (
        "timestamp", "DHT_temp", "DHT_humidity",
        "Isik_Lux", "elektrik_fiyati",
        "pompa_karar", "fan_karar", "isitici_karar", "isik_karar",
    )

    # --- Dosya Yolları ---
    dataset_dosya: str = field(
        default_factory=lambda: os.environ.get("AGROTWIN", "agrotwin_data.csv")
    )
    veritabani:        str = "agrotwin_data.db"
    model_kayit_yolu:  str = "agrotwin_lstm_model.keras"
    scaler_kayit_yolu: str = "agrotwin_scaler.save"

    # --- EPİAŞ ---
    epias_api_url:      str = (
        "https://seffaflik.epias.com.tr"
        "/electricity-service/v1/markets/dam/data/mcp"
    )
    epias_fiyat_aralik: int = 300   # 5 dakika


KONFIG = AgroTwinConfig()

# ============================================================================
# BÖLÜM 2: LOGLAMA
# ============================================================================

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("agrotwin_master.log", encoding="utf-8"),
    ],
)
log = logging.getLogger("AGROTWIN")

# ============================================================================
# BÖLÜM 3: GLOBAL DURUM (Thread-Safe)
# ============================================================================

class GlobalState:
    """
    Kilit hiyerarşisi (deadlock yok):
      veri_kilidi  → sensör verisi + kararlar
      fiyat_kilidi → elektrik fiyatı
      tf_kilidi    → model.predict() + model.fit()
    """
    def __init__(self) -> None:
        self.veri_kilidi  = threading.Lock()
        self.fiyat_kilidi = threading.Lock()
        self.tf_kilidi    = threading.Lock()

        self.son_sensor_verisi: dict = {
            "T_ortam": 20.0, "H_ortam": 50.0,
            "Isik_Lux": 20000,
        }
        self.son_elektrik_fiyati: float = KONFIG.varsayilan_elektrik_fiyat
        self.son_kararlar: dict = {
            "pompa":   "BILINMIYOR",
            "fan":     "BILINMIYOR",
            "isitici": "BILINMIYOR",
            "isik":    "BILINMIYOR",
        }

        self.predict_buffer: deque = deque(maxlen=KONFIG.lookback_window)

        self.ml_modeli: Optional[Sequential] = None
        self.ml_hazir:  bool = False
        self.scaler:    MinMaxScaler = MinMaxScaler(feature_range=(0, 1))
        self.son_metrikler: dict = {}

        # Veriye dayalı chatbot
        self.son_pred_degerler: dict = {}   # {"pompa": 0.82, "fan": 0.31, ...}
        self.son_trend:         dict = {}   # {"T_ortam": "artıyor", ...}
        self.son_feature_imp:   dict = {}   # {"DHT_temp": 0.012, ...}
        self.son_karar_aciklamalari: list[str] = []  # en son alınan kararların kısa açıklamaları

        # Çalışma modu
        self.sistem_modu: str = "OTONOM"

        self.mqtt_istemci: Optional[mqtt.Client] = None
        self.enerji: Optional[object] = None


durum = GlobalState()

# ============================================================================
# BÖLÜM 4: VERİTABANI (SQLite)
# ============================================================================

def veritabani_baslat() -> None:
    try:
        with sqlite3.connect(KONFIG.veritabani) as bag:
            bag.execute("""
                CREATE TABLE IF NOT EXISTS sensor_logs (
                    id              INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp       TEXT    NOT NULL,
                    T_ortam         REAL,
                    H_ortam         REAL,
                    Isik_Lux        REAL,
                    elektrik_fiyati REAL,
                    pompa_karar     TEXT,
                    fan_karar       TEXT,
                    isitici_karar   TEXT,
                    isik_karar      TEXT
                )
            """)
            bag.commit()
        log.info("[DB] SQLite hazır: %s", KONFIG.veritabani)
    except sqlite3.Error as e:
        log.critical("[DB] Başlatma hatası: %s", e)
        raise


def veritabanina_kaydet(sensor: dict, fiyat: float, kararlar: dict) -> None:
    try:
        with sqlite3.connect(KONFIG.veritabani) as bag:
            bag.execute("""
                INSERT INTO sensor_logs
                    (timestamp, T_ortam, H_ortam, Isik_Lux, elektrik_fiyati,
                     pompa_karar, fan_karar, isitici_karar, isik_karar)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                datetime.now().isoformat(timespec="seconds"),
                sensor.get("T_ortam"),    sensor.get("H_ortam"),
                sensor.get("Isik_Lux"),   fiyat,
                kararlar.get("pompa"),    kararlar.get("fan"),
                kararlar.get("isitici"),  kararlar.get("isik"),
            ))
            bag.commit()
    except sqlite3.Error as e:
        log.error("[DB] Kayıt hatası: %s", e)

# ============================================================================
# BÖLÜM 5: CSV VERİ KAYDI
# ============================================================================

def csv_kaydet(sensor: dict, fiyat: float, kararlar: dict) -> None:
    dosya_var = os.path.isfile(KONFIG.dataset_dosya)
    try:
        with open(KONFIG.dataset_dosya, "a", newline="", encoding="utf-8") as f:
            yazar = csv.DictWriter(f, fieldnames=KONFIG.csv_sutunlar)
            if not dosya_var:
                yazar.writeheader()
            yazar.writerow({
                "timestamp":       datetime.now().isoformat(timespec="seconds"),
                "DHT_temp":        sensor.get("T_ortam"),
                "DHT_humidity":    sensor.get("H_ortam"),
                "Isik_Lux":        sensor.get("Isik_Lux"),
                "elektrik_fiyati": fiyat,
                "pompa_karar":     kararlar.get("pompa"),
                "fan_karar":       kararlar.get("fan"),
                "isitici_karar":   kararlar.get("isitici"),
                "isik_karar":      kararlar.get("isik"),
            })
    except OSError as e:
        log.error("[CSV] Yazma hatası: %s", e)

# ============================================================================
# BÖLÜM 6: EPİAŞ ELEKTRİK FİYATI
# ============================================================================

def epias_fiyat_cek() -> float:
    """EPİAŞ REST API'ye POST atar, güncel PTF'yi döner (token gerekmez)."""
    try:
        simdi   = datetime.now()
        payload = {
            "startDate": simdi.strftime("%Y-%m-%dT00:00:00+03:00"),
            "endDate":   simdi.strftime("%Y-%m-%dT23:00:00+03:00"),
        }
        resp = requests.post(
            KONFIG.epias_api_url,
            headers={"Content-Type": "application/json"},
            json=payload,
            timeout=10,
        )
        resp.raise_for_status()

        # Bazen EPİAŞ HTML döner — content-type kontrol
        if "application/json" not in resp.headers.get("Content-Type", ""):
            log.warning("[EPİAŞ] JSON olmayan yanıt, varsayılan kullanılıyor.")
            return KONFIG.varsayilan_elektrik_fiyat

        try:
            veri = resp.json()
        except ValueError:
            log.warning("[EPİAŞ] JSON parse hatası, varsayılan kullanılıyor.")
            return KONFIG.varsayilan_elektrik_fiyat

        hedef = simdi.strftime("%Y-%m-%dT%H:00:00+03:00")
        for item in veri.get("items", []):
            if item.get("date") == hedef:
                fiyat = float(item.get("price", KONFIG.varsayilan_elektrik_fiyat))
                log.info("[EPİAŞ] PTF: %.0f TL/MWh", fiyat)
                return fiyat
        log.warning("[EPİAŞ] Bu saate ait fiyat bulunamadı.")
    except requests.Timeout:
        log.warning("[EPİAŞ] Zaman aşımı.")
    except requests.HTTPError as e:
        log.warning("[EPİAŞ] HTTP hatası: %s", e)
    except Exception as e:
        log.error("[EPİAŞ] Hata: %s", e)
    return KONFIG.varsayilan_elektrik_fiyat


def epias_arkaplan_guncelle() -> None:
    """5 dakikada bir EPİAŞ fiyatını güncelleyen daemon thread."""
    log.info("[EPİAŞ] Fiyat güncelleme thread'i başladı.")
    while True:
        yeni = epias_fiyat_cek()
        with durum.fiyat_kilidi:
            durum.son_elektrik_fiyati = yeni
        time.sleep(KONFIG.epias_fiyat_aralik)


def guncel_fiyat_al() -> float:
    """Thread-safe anlık elektrik fiyatı okuyucu."""
    with durum.fiyat_kilidi:
        return durum.son_elektrik_fiyati

# ============================================================================
# BÖLÜM 7: MQTT KOMUT GÖNDERME
# ============================================================================

def role_komutu_gonder(cihaz: str, durum_str: str) -> None:
    """ESP32'ye JSON röle komutu: {"cihaz": "pompa", "durum": "ON"}"""
    istemci = durum.mqtt_istemci
    if istemci is None or not istemci.is_connected():
        log.warning("[MQTT] Bağlantı yok: %s -> %s", cihaz, durum_str)
        return
    mesaj = json.dumps({"cihaz": cihaz, "durum": durum_str}, ensure_ascii=False)
    istemci.publish(KONFIG.topic_komutlar, mesaj, qos=1)
    log.info("[MQTT ↑] %s", mesaj)


def ai_log_gonder(metin: str) -> None:
    """Karar açıklamasını Flutter'a gönderir."""
    istemci = durum.mqtt_istemci
    if istemci and istemci.is_connected():
        istemci.publish(KONFIG.topic_ai_log, metin, qos=0)

# ============================================================================
# BÖLÜM 8: FEATURE ENGINEERING
# ============================================================================

def feature_engineering(df: pd.DataFrame) -> pd.DataFrame:
    """
    Ham veriye mühendislenmiş özellikler ekler:
      MA_*   : 3 adımlık hareketli ortalama
      dT_*   : Birinci türev / trend
      prev_* : t-1 anındaki karar (otoregresif)
      dakika : Pompa döngüsü için dakika özelliği
    """
    df = df.copy()
    df.columns = df.columns.str.strip()

    # Eksik sütunları doldur
    if "Isik_Lux"       not in df.columns: df["Isik_Lux"]       = 20000.0
    if "elektrik_fiyati" not in df.columns: df["elektrik_fiyati"] = 1500.0
    if "pompa_karar"    not in df.columns: df["pompa_karar"]    = "OFF"
    if "fan_karar"      not in df.columns: df["fan_karar"]       = "OFF"
    if "isitici_karar"  not in df.columns: df["isitici_karar"]  = "OFF"
    if "isik_karar"     not in df.columns: df["isik_karar"]     = "OFF"

    # Zaman özellikleri
    df["timestamp"] = pd.to_datetime(df["timestamp"], errors="coerce", format="mixed")
    df = df.dropna(subset=["timestamp"])
    df["hour"]   = df["timestamp"].dt.hour
    df["dakika"] = df["timestamp"].dt.minute

    # Moving Average + Delta Trend
    for kolon in ["DHT_temp", "Isik_Lux", "elektrik_fiyati"]:
        if kolon in df.columns:
            df[kolon] = pd.to_numeric(df[kolon], errors="coerce").ffill()
            df[f"MA_{kolon}"] = df[kolon].rolling(window=3, min_periods=1).mean()
            df[f"dT_{kolon}"] = df[kolon].diff().fillna(0)

    # Geçmiş kararlar (t-1)
    eslesme = {
        "prev_pompa":   "pompa_karar",
        "prev_fan":     "fan_karar",
        "prev_isitici": "isitici_karar",
        "prev_isik":    "isik_karar",
    }
    for yeni_ad, eski_ad in eslesme.items():
        if eski_ad in df.columns:
            df[yeni_ad] = (df[eski_ad] == "ON").astype(int).shift(1).fillna(0)
        else:
            df[yeni_ad] = 0

    return df

# ============================================================================
# BÖLÜM 9: MODEL EĞİTİMİ
# ============================================================================

def ml_model_egit_lstm() -> bool:
    """
    Bodrum Papatyası reçetesiyle etiketlenmiş CSV'den LSTM eğitir.

    Çıkışlar (4 adet):
      0 → pompa    (döngüsel sulama)
      1 → fan      (sıcaklık/nem kontrolü)
      2 → isitici  (soğuk hava koruması)
      3 → isik     (Growlight)
    """
    if not os.path.exists(KONFIG.dataset_dosya):
        log.error("[LSTM] Dataset bulunamadı: %s", KONFIG.dataset_dosya)
        return False

    try:
        df = pd.read_csv(KONFIG.dataset_dosya, encoding="utf-8")
        if len(df) < KONFIG.ml_veri_esigi:
            log.info("[LSTM] Yetersiz veri: %d/%d", len(df), KONFIG.ml_veri_esigi)
            return False

        df = feature_engineering(df)
        ozellikler = list(KONFIG.tum_ozellikler)

        eksik = set(ozellikler) - set(df.columns)
        if eksik:
            log.error("[LSTM] Eksik sütunlar: %s — ogretmen.py çalıştırıldı mı?", eksik)
            return False

        # Etiket matrisi (4 çıkış)
        Y = np.column_stack([
            (df["pompa_karar"]   == "ON").astype(int).values,
            (df["fan_karar"]     == "ON").astype(int).values,
            (df["isitici_karar"] == "ON").astype(int).values,
            (df["isik_karar"]    == "ON").astype(int).values,
        ])
        X_raw = df[ozellikler].values

        # Etiket dağılımı — class imbalance teşhisi
        for i, isim in enumerate(["pompa", "fan", "isitici", "isik"]):
            on  = int(Y[:, i].sum())
            oran = on / len(Y) * 100
            log.info("[LSTM] [%s] ON: %d / %d  (%.1f%%)", isim.upper(), on, len(Y), oran)
            if on == 0:
                log.error("[LSTM] [%s] için hiç ON yok! ogretmen.py'yi çalıştır.", isim.upper())

        # Train / Val / Test split (%70 / %15 / %15, zamansal sıra korunur)
        n           = len(X_raw)
        train_bitis = int(n * (1 - KONFIG.test_split - KONFIG.validation_split))
        val_bitis   = int(n * (1 - KONFIG.test_split))

        X_tr_raw, Y_tr = X_raw[:train_bitis],         Y[:train_bitis]
        X_vl_raw, Y_vl = X_raw[train_bitis:val_bitis], Y[train_bitis:val_bitis]
        X_te_raw, Y_te = X_raw[val_bitis:],            Y[val_bitis:]

        # Scaler sadece train'e fit → veri sızıntısı yok
        X_tr = durum.scaler.fit_transform(X_tr_raw)
        X_vl = durum.scaler.transform(X_vl_raw)
        X_te = durum.scaler.transform(X_te_raw)

        # Sliding window
        def pencere(X_sc, Y_arr):
            win = KONFIG.lookback_window
            if len(X_sc) <= win:
                return None, None
            Xw = np.array([X_sc[i - win:i] for i in range(win, len(X_sc))])
            Yw = np.array([Y_arr[i]         for i in range(win, len(Y_arr))])
            return Xw, Yw

        X_tr, Y_tr = pencere(X_tr, Y_tr)
        X_vl, Y_vl = pencere(X_vl, Y_vl)
        X_te, Y_te = pencere(X_te, Y_te)

        if X_tr is None or len(X_tr) == 0:
            log.warning("[LSTM] Pencere oluşturulamadı — veri çok az.")
            return False

        # LSTM Mimarisi
        model = Sequential([
            LSTM(KONFIG.lstm_units_1, return_sequences=True,
                 input_shape=(KONFIG.lookback_window, X_tr.shape[2])),
            Dropout(KONFIG.dropout_rate),
            LSTM(KONFIG.lstm_units_2),
            Dropout(KONFIG.dropout_rate),
            Dense(4, activation="sigmoid"),  # pompa | fan | ısıtıcı | ışık
        ])
        model.compile(optimizer="adam", loss="binary_crossentropy", metrics=["accuracy"])

        callbacks = [
            EarlyStopping(monitor="val_loss", patience=KONFIG.early_stop_patience,
                          restore_best_weights=True, verbose=0),
            ReduceLROnPlateau(monitor="val_loss", factor=0.5,
                              patience=3, min_lr=1e-6, verbose=0),
        ]

        # Class imbalance düzeltmesi
        agirlik = np.ones(len(Y_tr))
        for c in range(Y_tr.shape[1]):
            on_mask = Y_tr[:, c] == 1
            on_oran = on_mask.sum() / len(Y_tr)
            if on_oran > 0:
                w = min((1.0 / on_oran) * 0.5, 6.0)
                agirlik[on_mask] = np.maximum(agirlik[on_mask], w)
        log.info("[LSTM] Sample weight max: %.2f", agirlik.max())

        val_data = (X_vl, Y_vl) if X_vl is not None and len(X_vl) > 0 else None

        gecmis = model.fit(
            X_tr, Y_tr,
            epochs=KONFIG.epochs,
            batch_size=KONFIG.batch_size,
            validation_data=val_data,
            callbacks=callbacks,
            sample_weight=agirlik,
            verbose=0,
        )
        log.info("[LSTM] Eğitim %d epoch'ta tamamlandı.", len(gecmis.history["loss"]))

        # Test metrikleri
        metrikler = {}
        if X_te is not None and len(X_te) > 0:
            prob = model.predict(X_te, verbose=0)
            pred = (prob > 0.5).astype(int)
            for i, isim in enumerate(["pompa", "fan", "isitici", "isik"]):
                acc = accuracy_score(Y_te[:, i], pred[:, i])
                f1  = f1_score(Y_te[:, i], pred[:, i], zero_division=0, average="binary")
                try:
                    auc = roc_auc_score(Y_te[:, i], prob[:, i])
                except ValueError:
                    auc = float("nan")
                metrikler[isim] = {"accuracy": acc, "f1": f1, "auc": auc}
                log.info("[LSTM] [%s] Acc: %.3f | F1: %.3f | AUC: %.3f",
                         isim.upper(), acc, f1, auc)

        if X_te is not None and len(X_te) > 0:
            _feature_importance_logla(model, X_te, Y_te, ozellikler)

        model.save(KONFIG.model_kayit_yolu)
        joblib.dump(durum.scaler, KONFIG.scaler_kayit_yolu)
        log.info("[LSTM] Model + Scaler kaydedildi.")

        with durum.tf_kilidi:
            durum.ml_modeli     = model
            durum.ml_hazir      = True
            durum.son_metrikler = metrikler

        return True

    except Exception as e:
        log.error("[LSTM] Eğitim hatası: %s", e, exc_info=True)
        return False


def _feature_importance_logla(model, X_test, Y_test, ozellik_isimleri) -> None:
    """Permutation-based feature importance + chatbot için saklama."""
    try:
        baz      = model.predict(X_test, verbose=0)
        baz_loss = np.mean((baz - Y_test) ** 2)
        scores   = {}
        for i, isim in enumerate(ozellik_isimleri):
            Xk = X_test.copy()
            np.random.shuffle(Xk[:, :, i])
            kayip = np.mean((model.predict(Xk, verbose=0) - Y_test) ** 2)
            scores[isim] = max(0.0, kayip - baz_loss)

        sirali   = sorted(scores.items(), key=lambda x: x[1], reverse=True)
        max_skor = max(v for _, v in sirali) or 1
        log.info("[EXPLAINABILITY] Feature Importance (üst 8):")
        for isim, skor in sirali[:8]:
            bar = "█" * int(skor / max_skor * 20 + 1)
            log.info("  %-22s | %s %.5f", isim, bar, skor)

        # Chatbot için üst 5'i sakla
        durum.son_feature_imp = {isim: round(skor, 5) for isim, skor in sirali[:5]}

    except Exception as e:
        log.warning("[EXPLAINABILITY] Hesaplanamadı: %s", e)

# ============================================================================
# BÖLÜM 10: CANLI TAHMİN
# ============================================================================

def ml_tahmin_yap_lstm(sensor: dict, fiyat: float) -> Optional[tuple[dict, list[str]]]:
    """
    Sensör verisini buffer'a ekler, LSTM tahmini yapar.
    Buffer dolmadan None döner → kural motoru devreye girer.

    Fiziksel güvenlik katmanı:
      Sıcaklık ≥ 30°C → fan zorla ON
      Sıcaklık ≤  5°C → ısıtıcı zorla ON
      Işık < 15000 Lux → growlight zorla ON (LSTM'den bağımsız)
    """
    saat   = datetime.now().hour
    dakika = datetime.now().minute

    with durum.veri_kilidi:
        prev_p = 1 if durum.son_kararlar.get("pompa")   == "ON" else 0
        prev_f = 1 if durum.son_kararlar.get("fan")     == "ON" else 0
        prev_i = 1 if durum.son_kararlar.get("isitici") == "ON" else 0
        prev_k = 1 if durum.son_kararlar.get("isik")    == "ON" else 0

    # İndeksler: DHT_temp=0, Isik_Lux=2, elektrik_fiyati=3
    IDX_TEMP = 0; IDX_ISIK = 2; IDX_ELEK = 3

    buf = list(durum.predict_buffer)
    if len(buf) >= 3:
        son3  = np.array(buf[-3:])
        ma_t  = float(np.mean(son3[:, IDX_TEMP]))
        ma_k  = float(np.mean(son3[:, IDX_ISIK]))
        ma_e  = float(np.mean(son3[:, IDX_ELEK]))
        dt_t  = float(sensor["T_ortam"]  - son3[-1, IDX_TEMP])
        dt_k  = float(sensor["Isik_Lux"] - son3[-1, IDX_ISIK])
        dt_e  = float(fiyat              - son3[-1, IDX_ELEK])
    else:
        ma_t  = sensor["T_ortam"]
        ma_k  = sensor.get("Isik_Lux", 20000)
        ma_e  = fiyat
        dt_t  = dt_k = dt_e = 0.0

    # tum_ozellikler ile BİREBİR aynı sıra (16 özellik)
    yeni_satir = [
        sensor["T_ortam"],           # DHT_temp        idx 0
        sensor["H_ortam"],           # DHT_humidity     idx 1
        sensor.get("Isik_Lux", 20000), # Isik_Lux      idx 2
        fiyat,                       # elektrik_fiyati  idx 3
        saat,                        # hour             idx 4
        dakika,                      # dakika           idx 5
        ma_t, ma_k, ma_e,            # MA_*             idx 6-8
        dt_t, dt_k, dt_e,            # dT_*             idx 9-11
        prev_p, prev_f, prev_i, prev_k,  # prev_*       idx 12-15
    ]

    durum.predict_buffer.append(yeni_satir)

    if len(durum.predict_buffer) < KONFIG.lookback_window:
        log.info("[LSTM] Tampon: %d/%d", len(durum.predict_buffer), KONFIG.lookback_window)
        return None

    try:
        recent  = np.array(list(durum.predict_buffer))
        scaled  = durum.scaler.transform(recent)
        X_input = scaled.reshape(1, KONFIG.lookback_window, len(KONFIG.tum_ozellikler))

        with durum.tf_kilidi:
            pred = durum.ml_modeli.predict(X_input, verbose=0)[0]

        aciklamalar = [
            "[YZ] LSTM modelinden alınan kararlar işleniyor.",
            f"[YZ] Riske göre top4 olasılıklar: pompa %{pred[0]*100:.0f}, fan %{pred[1]*100:.0f}, ısıtıcı %{pred[2]*100:.0f}, ışık %{pred[3]*100:.0f}."
        ]

        # Pompa için YZ: net onay/ret aralığı (0.4-0.6 = belirsiz)
        if pred[0] > 0.60:
            pompa_ai = "ON"
        elif pred[0] < 0.40:
            pompa_ai = "OFF"
        else:
            pompa_ai = "N/A"

        karar = {
            "pompa":   pompa_ai if pompa_ai in ("ON", "OFF") else "N/A",
            "fan":     "ON" if pred[1] > 0.50 else "OFF",
            "isitici": "ON" if pred[2] > 0.50 else "OFF",
            "isik":    "ON" if pred[3] > 0.40 else "OFF",  # ışık için biraz daha duyarlı
        }

        # YZ karar özetini ekle
        for cihaz, durum_str in karar.items():
            if durum_str in ("ON", "OFF"):
                aciklamalar.append(
                    f"[YZ] {cihaz.capitalize()} için model kararı: {durum_str}."
                )
            else:
                aciklamalar.append(
                    f"[YZ] {cihaz.capitalize()} için model belirsiz: {durum_str}. Kural karşılaştırması yapılıyor."
                )

        # ── Fiziksel Güvenlik Katmanı ──────────────────────────────────────
        t       = sensor["T_ortam"]
        analog  = sensor.get("Isik_Analog")
        if analog is not None:
            lux   = _analog_lux_hesapla(analog)
        else:
            lux   = sensor.get("Isik_Lux", 20000)
        pahali  = fiyat > KONFIG.esik_elektrik_pahali

        # Sıcaklık kritik üst → fan zorla ON
        if t >= KONFIG.esik_sicaklik_krit_max:
            karar["fan"] = "ON"
            aciklamalar.append(f"Kritik sıcaklık (%.1f°C) => Fan zorla ON." % t)
            log.info("[GÜVENLİK] Kritik sıcaklık (%.1f°C) → Fan zorlandı.", t)

        # Sıcaklık optimum üst → fan tavsiye (elektrik ucuzsa)
        elif t > KONFIG.esik_sicaklik_max and karar["fan"] == "OFF" and not pahali:
            karar["fan"] = "ON"
            aciklamalar.append(f"Sıcaklık yüksek (%.1f°C) ve elektrik uygun => Fan ON." % t)
            log.info("[GÜVENLİK] Yüksek sıcaklık (%.1f°C) → Fan override ON.", t)

        # Sıcaklık serin → fan kesinlikle OFF
        elif t < KONFIG.esik_sicaklik_min - 3.0 and karar["fan"] == "ON":
            karar["fan"] = "OFF"
            aciklamalar.append(f"Sıcaklık serin (%.1f°C) => Fan OFF." % t)
            log.info("[GÜVENLİK] Hava serin (%.1f°C) → Fan override OFF.", t)

        h = sensor.get("H_ortam", 50.0)
        # İç mekan için tek senaryo: sabit ideal aralık
        min_ideal = KONFIG.gunduz_sicaklik_min
        max_ideal = KONFIG.gunduz_sicaklik_max
        aciklama_sure = "Sabit ideal aralık"
        # Normal aralıkta ısıtıcı kapalı, ancak dışına çıkarsa ısıtma/fan devreye gir
        if min_ideal <= t <= max_ideal and h <= KONFIG.esik_nem_max:
            if karar["isitici"] == "ON":
                karar["isitici"] = "OFF"
                aciklamalar.append(f"{aciklama_sure} {t:.1f}°C => Isıtıcı OFF ({min_ideal}-{max_ideal}°C).")
            if karar["fan"] == "ON" and t <= max_ideal:
                karar["fan"] = "OFF"
                aciklamalar.append(f"{aciklama_sure} {t:.1f}°C, nem %{h:.0f} => Fan OFF.")

        if t > KONFIG.gunduz_sicaklik_max:
            karar["isitici"] = "OFF"
            karar["fan"] = "ON"
            aciklamalar.append(f"Sıcaklık {t:.1f}°C > 24°C => Fan ON, Isıtıcı OFF.")

        if t < KONFIG.gunduz_sicaklik_min:
            karar["isitici"] = "ON"
            aciklamalar.append(f"{aciklama_sure} {t:.1f}°C < {min_ideal}°C => Isıtıcı ON.")

        # Sıcaklık kritik alt → ısıtıcı zorla ON (güvenlik öncelikli)
        if t <= KONFIG.esik_sicaklik_krit_min:
            karar["isitici"] = "ON"
            aciklamalar.append(f"Kritik soğuk (%.1f°C) => Isıtıcı zorla ON." % t)
            log.info("[GÜVENLİK] Kritik sıcaklık (%.1f°C) → Isıtıcı zorlandı.", t)

        # Reçete altı (15°C altı) → ısıtıcı ON (elektrik pahalı olsa bile)
        elif t < KONFIG.esik_sicaklik_min:
            karar["isitici"] = "ON"
            aciklamalar.append(f"Soğuk (%.1f°C) => Isıtıcı ON." % t)
            log.info("[GÜVENLİK] Soğuk (%.1f°C) → Isıtıcı reçeteye göre ON.", t)

        # Sıcaklık yeterli ise ısıtıcı kapat
        elif t > KONFIG.esik_sicaklik_max + 3.0 and karar["isitici"] == "ON":
            karar["isitici"] = "OFF"
            aciklamalar.append(f"Sıcaklık yeterli (%.1f°C) => Isıtıcı OFF." % t)
            log.info("[GÜVENLİK] Sıcaklık yüksek (%.1f°C) → Isıtıcı OFF.", t)

        analog = sensor.get("Isik_Analog")
        # Analog ışık kontrolü (0-4096 aralığı) önceliklendirme
        if analog is not None:
            if analog < KONFIG.esik_isik_analog_min:
                karar["isik"] = "ON"
                aciklamalar.append(
                    f"Analog ışık değeri {analog:.0f} < {KONFIG.esik_isik_analog_min:.0f}: Growlight ON (YZ kontrol)."
                )
                log.info("[GÜVENLİK] Analog ışık %s < %s → Growlight zorlandı.", analog, KONFIG.esik_isik_analog_min)
            elif analog >= KONFIG.esik_isik_analog_max and karar["isik"] == "ON":
                karar["isik"] = "OFF"
                aciklamalar.append(
                    f"Analog ışık değeri {analog:.0f} >= {KONFIG.esik_isik_analog_max:.0f}: Growlight OFF."
                )
                log.info("[GÜVENLİK] Analog ışık %s >= %s → Growlight OFF.", analog, KONFIG.esik_isik_analog_max)
            else:
                if karar["isik"] == "ON":
                    aciklamalar.append(
                        f"Analog ışık {analog:.0f} aralıkta; mevcut Growlight ON durumu korunuyor."
                    )
                else:
                    aciklamalar.append(
                        f"Analog ışık {analog:.0f} ara aralıkta; Growlight OFF."
                    )
        else:
            # Isik_Lux varsa kalan destek
            if lux < KONFIG.esik_isik_min:
                karar["isik"] = "ON"
                aciklamalar.append(f"Işık kritik düşük (%.0f Lux) => Growlight ON." % lux)
                log.info("[GÜVENLİK] Işık yetersiz (%.0f Lux) → Growlight zorlandı.", lux)
            elif lux >= KONFIG.esik_isik_optimal and karar["isik"] == "ON":
                karar["isik"] = "OFF"
                aciklamalar.append(f"Işık yeterli (%.0f Lux) => Growlight OFF." % lux)
                log.info("[GÜVENLİK] Işık yeterli (%.0f Lux) → Growlight OFF.", lux)

        # Pompa döngüsü — normalde saatte 10 dakika
        saatlik_pompa = (dakika % 60) < 10
        if pompa_ai in ("ON", "OFF"):
            karar["pompa"] = pompa_ai
            aciklamalar.append(
                f"YZ pompa kararı: {pompa_ai} (Net YZ tahmini). Saatlik 10 dk kuralı ancak YZ öncelikli."
            )
        else:
            karar["pompa"] = "ON" if saatlik_pompa else "OFF"
            aciklamalar.append(
                f"YZ belirsiz (karar yok). Saatlik 10 dakikalık varsayılan: {'ON' if saatlik_pompa else 'OFF'}."
            )

        # ── Veriye Dayalı Chatbot için pred + trend sakla ──────────────────
        with durum.veri_kilidi:
            durum.son_pred_degerler = {
                "pompa":   float(pred[0]),
                "fan":     float(pred[1]),
                "isitici": float(pred[2]),
                "isik":    float(pred[3]),
            }
            analog = sensor.get("Isik_Analog")
            if analog is not None:
                prev_analog = None
                with durum.veri_kilidi:
                    prev_analog = durum.son_sensor_verisi.get("Isik_Analog")
                analog_dt = analog - prev_analog if prev_analog is not None else 0
            else:
                analog_dt = 0

            durum.son_trend = {
                "T_ortam":   "artıyor" if dt_t > 0.5 else ("azalıyor" if dt_t < -0.5 else "sabit"),
                "Isik_Analog": "artıyor" if analog_dt > 50 else ("azalıyor" if analog_dt < -50 else "sabit"),
                "elektrik":  "artıyor" if dt_e > 50  else ("azalıyor" if dt_e < -50  else "sabit"),
            }
            durum.son_karar_aciklamalari = aciklamalar

        return karar, aciklamalar

    except Exception as e:
        log.error("[LSTM] Tahmin hatası: %s", e, exc_info=True)
        return None

# ============================================================================
# BÖLÜM 11: KURAL TABANLI KARAR MOTORU (Bodrum Papatyası Reçetesi)
# ============================================================================

def kural_bazli_karar_al(sensor: dict, fiyat: float) -> tuple[dict, list[str]]:
    """
    ML hazır olmadan önce veya tampon dolarken çalışır.
    Bodrum Papatyası büyüme koşullarına göre deterministik karar.
    """
    kararlar:    dict      = {}
    aciklamalar: list[str] = []

    t      = sensor.get("T_ortam", 20.0)
    h      = sensor.get("H_ortam", 50.0)
    lux    = sensor.get("Isik_Lux", 20000)
    dakika = datetime.now().minute
    pahali = fiyat > KONFIG.esik_elektrik_pahali

    # ── Fan (iç mekan sabit koşulları) ─────────────────────────────────
    min_ideal = KONFIG.gunduz_sicaklik_min
    max_ideal = KONFIG.gunduz_sicaklik_max

    if t > max_ideal or h > KONFIG.esik_nem_max:
        kararlar["fan"] = "OFF" if pahali else "ON"
        neden = f"T={t:.1f}°C" if t > max_ideal else f"Nem=%{h:.0f}"
        aciklamalar.append(
            f"{neden} → Fan {'OFF (elektrik pahalı)' if pahali else 'ON'}."
        )
    else:
        kararlar["fan"] = "OFF"
        aciklamalar.append(f"Hava ideal ({t:.1f}°C, %{h:.0f} nem). Fan OFF.")

    # ──  Isıtıcı (iç mekan sabit reçetesi) ─────────────────────────
    min_ideal = KONFIG.gunduz_sicaklik_min
    max_ideal = KONFIG.gunduz_sicaklik_max

    su_sicaklik = sensor.get("Su_sicaklik") if sensor is not None else None
    if su_sicaklik is not None:
        if not (min_ideal <= su_sicaklik <= max_ideal):
            aciklamalar.append(
                f"Su sıcaklığı {su_sicaklik:.1f}°C (ideal {min_ideal}-{max_ideal}°C) — istisnai durum." 
            )

    if t <= KONFIG.esik_sicaklik_krit_min:
        kararlar["isitici"] = "ON"
        aciklamalar.append(
            f"Kritik sıcaklık ({t:.1f}°C <= {KONFIG.esik_sicaklik_krit_min:.1f}°C) → Isıtıcı ZORLA ON."
        )
    elif t < min_ideal:
        kararlar["isitici"] = "ON"
        aciklamalar.append(
            f"Sıcaklık düşük ({t:.1f}°C < {min_ideal:.1f}°C) → Isıtıcı ON."
        )
    elif t > max_ideal:
        kararlar["isitici"] = "OFF"
        aciklamalar.append(
            f"Sıcaklık yüksek ({t:.1f}°C > {max_ideal:.1f}°C) → Isıtıcı OFF."
        )
    else:
        kararlar["isitici"] = "OFF"
        aciklamalar.append(
            f"Sıcaklık ideal ({t:.1f}°C, hedef {min_ideal:.1f}-{max_ideal:.1f}°C) → Isıtıcı OFF."
        )

    # ── Growlight (analog 0-4096) ──────────────────────────────────────
    analog = sensor.get("Isik_Analog")
    if analog is not None:
        if analog < KONFIG.esik_isik_analog_min:
            kararlar["isik"] = "ON"
            aciklamalar.append(
                f"Analog ışık yetersiz ({analog:.0f} < {KONFIG.esik_isik_analog_min:.0f}). Growlight ON (YZ kontrol)."
            )
        elif analog >= KONFIG.esik_isik_analog_max:
            kararlar["isik"] = "OFF"
            aciklamalar.append(
                f"Analog ışık yeterli ({analog:.0f} >= {KONFIG.esik_isik_analog_max:.0f}). Growlight OFF."
            )
        else:
            kararlar["isik"] = "OFF"
            aciklamalar.append(
                f"Analog ışık ideal aralıkta ({analog:.0f}). Growlight OFF."
            )
    else:
        # Backward uyum: Lux mevcutsa eskiden olduğu gibi çalış
        if lux < KONFIG.esik_isik_min:
            kararlar["isik"] = "ON"
            aciklamalar.append(
                f"Işık yetersiz ({lux:.0f} Lux < {KONFIG.esik_isik_min:.0f}). Growlight ON."
            )
        elif lux >= KONFIG.esik_isik_optimal:
            kararlar["isik"] = "OFF"
            aciklamalar.append(
                f"Işık yeterli ({lux:.0f} Lux >= {KONFIG.esik_isik_optimal:.0f}). Growlight OFF."
            )
        else:
            kararlar["isik"] = "OFF"
            aciklamalar.append(
                f"Işık ideal ({lux:.0f} Lux). Growlight OFF."
            )

    # ── Pompa (Zaman döngüsü) ──────────────────────────────────────────────
    # Kapalı alanda saatte 10 dakika ON / 50 dakika OFF olarak çalışır
    dakika = datetime.now().minute

    if KONFIG.pompa_dakika_baslangic <= dakika < KONFIG.pompa_dakika_bitis:
        kararlar["pompa"] = "ON"
        aciklamalar.append(f"Döngüsel sulama (Dakika: {dakika} -> Pompa ON).")
        aciklamalar.append("[YZ] Pompa kararı: Zaman tabanlı döngü (10dk/sa), YZ destekli kontrol.")
    else:
        kararlar["pompa"] = "OFF"
        aciklamalar.append(f"Pompa periyod dışında (dakika {dakika}) OFF.")
        aciklamalar.append("[YZ] Pompa kararı: Döngü dışı, gereken süre boyunca kapalı tutuldu.")

    aciklamalar.append("[YZ] Tüm cihaz kararları YZ destekli kural motoru tarafından belirlendi.")
    return kararlar, aciklamalar


def _enerji_ve_guvenlik_on_aksiyon(
    sensor: dict,
    fiyat: float,
    kararlar: dict,
    aciklamalar: list[str],
) -> None:
    """
    Son güvenlik/ekonomi katmanı:
      - Nem çok yüksekse fan güvenlik nedeniyle zorla ON.
      - 2 saat sonrası fiyat artacaksa uygun koşullarda fan/pompa önden çalıştırılır.
    """
    t = float(sensor.get("T_ortam", 20.0))
    h = float(sensor.get("H_ortam", 50.0))
    dakika = datetime.now().minute

    # 1) Güvenlik: nem kritik yüksekse (>= %75) fan her durumda çalışsın.
    if h >= (KONFIG.esik_nem_max + 5.0) and kararlar.get("fan") != "ON":
        kararlar["fan"] = "ON"
        aciklamalar.append(
            f"Nem kritik (%{h:.0f}) -> mantar riski nedeniyle fan zorla ON."
        )

    # 2) Ekonomi: yaklaşan pahalı periyottan önce sistemi hazırla.
    if durum.enerji is None:
        return

    try:
        hazirlik = durum.enerji.hazirlik_penceresi(onceki_saat=2)
        iki_saat_sonra = durum.enerji.saat_sonrasi_fiyat(2)
    except Exception:
        hazirlik = None
        iki_saat_sonra = None

    if hazirlik is not None:
        simdi = datetime.now()
        if hazirlik["hazirlik_baslangic"] <= simdi < hazirlik["hazirlik_bitis"]:
            # Hazırlık penceresinde ortamı hedef banda çek.
            if h >= KONFIG.esik_nem_ideal_max and kararlar.get("fan") != "ON":
                kararlar["fan"] = "ON"
                aciklamalar.append("Yaklaşan pahalı saat öncesi nem düşürme: fan ON.")
            if t < KONFIG.esik_sicaklik_min and kararlar.get("isitici") != "ON":
                kararlar["isitici"] = "ON"
                aciklamalar.append("Yaklaşan pahalı saat öncesi ısı hazırlığı: ısıtıcı ON.")
            if (dakika % 10 >= 3) and h < 55.0 and kararlar.get("pompa") != "ON":
                kararlar["pompa"] = "ON"
                aciklamalar.append("Yaklaşan pahalı saat öncesi ön sulama: pompa ON.")

    if iki_saat_sonra is None:
        return

    fiyat_artis = iki_saat_sonra - fiyat
    if fiyat_artis < 150.0:
        return

    # Fan ön aksiyon: sıcak/nem üst sınıra yaklaşmışsa pahalı saatten önce çalıştır.
    fan_uygun = t >= (KONFIG.esik_sicaklik_max - 1.0) or h >= KONFIG.esik_nem_ideal_max
    if fan_uygun and kararlar.get("fan") != "ON":
        kararlar["fan"] = "ON"
        aciklamalar.append(
            f"2 saat sonra fiyat +{fiyat_artis:.0f} TL bekleniyor -> fan önden ON."
        )

    # Pompa ön aksiyon: normal döngü dışındaysa ve ortam kuruysa kısa ön sulama.
    pompa_uygun = (dakika % 10 >= 3) and (h < 55.0) and (15.0 <= t <= 28.0)
    if pompa_uygun and kararlar.get("pompa") != "ON":
        kararlar["pompa"] = "ON"
        aciklamalar.append(
            f"2 saat sonra fiyat artışı bekleniyor -> pompa önden ON (ön sulama)."
        )

# ============================================================================
# BÖLÜM 12: ANA KARAR DÖNGÜSÜ
# ============================================================================

def _csv_satir_sayisi() -> int:
    if not os.path.isfile(KONFIG.dataset_dosya):
        return 0
    try:
        with open(KONFIG.dataset_dosya, encoding="utf-8", errors="replace") as f:
            return max(0, sum(1 for _ in f) - 1)
    except OSError:
        return 0


def karar_dongusu_calistir(sensor: dict, fiyat: float) -> None:
    """
    Tam karar döngüsü:
      1. Manuel mod kontrolü — aktifse yalnızca kayıt yap, çık
      2. LSTM veya kural motoru kararı
      3. ESP32'ye komutlar
      4. Flutter'a log
      5. Global durum güncelle
      6. CSV + SQLite kaydet
      7. Gerekirse arka planda eğitim tetikle
    """
    # Manuel modda YZ müdahale etmez
    if durum.sistem_modu == "MANUEL":
        log.info("[KARAR] MANUEL MOD — YZ pasif.")
        csv_kaydet(sensor, fiyat, durum.son_kararlar)
        veritabanina_kaydet(sensor, fiyat, durum.son_kararlar)
        return

    kararlar = None
    aciklamalar: list[str] = []

    if durum.ml_hazir and durum.ml_modeli is not None:
        sonuc = ml_tahmin_yap_lstm(sensor, fiyat)
        if sonuc:
            kararlar, aciklamalar = sonuc
            log.info("[KARAR] LSTM modeli kullandı.")
        else:
            log.info("[KARAR] Tampon doluyor → kural motoru.")

    if kararlar is None:
        kararlar, aciklamalar = kural_bazli_karar_al(sensor, fiyat)
        log.info("[KARAR] Kural motoru. Veri: %d/%d",
                 _csv_satir_sayisi(), KONFIG.ml_veri_esigi)

    # Enerji modülü programlı saat geldiyse pompa/ısıtıcıyı enerjiye göre zorla aç
    if durum.enerji is not None:
        for cihaz in ("pompa", "isitici"):
            if durum.enerji.programli_mi(cihaz) and kararlar.get(cihaz) != "ON":
                kararlar[cihaz] = "ON"
                aciklamalar.append(
                    f"{cihaz.capitalize()} enerji planına göre çalıştırıldı."
                )

    _enerji_ve_guvenlik_on_aksiyon(sensor, fiyat, kararlar, aciklamalar)

    for cihaz, durum_str in kararlar.items():
        role_komutu_gonder(cihaz, durum_str)

    ai_log_gonder(" | ".join(aciklamalar))

    with durum.veri_kilidi:
        durum.son_kararlar.update(kararlar)

    csv_kaydet(sensor, fiyat, kararlar)
    veritabanina_kaydet(sensor, fiyat, kararlar)

    if not durum.ml_hazir:
        threading.Thread(
            target=ml_model_egit_lstm, daemon=True, name="TrainThread"
        ).start()

# ============================================================================
# BÖLÜM 13: VERİYE DAYALI CHATBOT
# ============================================================================

def chatbot_cevap_uret(soru: str) -> str:
    """
    Gerçek LLM tarzı Türkçe chatbot.
    Bağlamı anlayarak doğal, açıklayıcı ve yardımcı cevaplar verir.
    """
    s = soru.lower().strip()

    with durum.veri_kilidi:
        sensor    = dict(durum.son_sensor_verisi)
        karar     = dict(durum.son_kararlar)
        pred      = dict(durum.son_pred_degerler)
        trend     = dict(durum.son_trend)
        feat_imp  = dict(durum.son_feature_imp)
        mod       = durum.sistem_modu
    fiyat = guncel_fiyat_al()

    # --- 🌟 YENİ EKLENEN KISIM: ENERJİ TAHMİNİ ---
    # Eğer soru gelecekle/maliyetle ilgiliyse ve enerji modülü hazırsa ona sor
    if hasattr(durum, 'enerji') and durum.enerji is not None:
        tavsiye = durum.enerji.chatbot_tavsiye(soru)
        if tavsiye:
            return f"Merhaba! Enerji konusunda size yardımcı olabilirim:\n\n{tavsiye}\n\nBaşka bir konuda yardıma ihtiyacınız var mı?"

    def gp(k: str) -> str:
        return f"%{pred.get(k, 0)*100:.0f}"

    # ── Selamlaşma ve Genel Yardım ────────────────────────────────────────────
    if any(k in s for k in ["merhaba", "selam", "meraba", "hi", "hello", "günaydın", "iyi günler"]):
        return (
            "Merhaba! Ben AGROTWIN'in akıllı asistanıyım. Bodrum Papatyası yetiştirme sisteminizi yönetiyorum.\n\n"
            f"Şu anda {mod} modundayım ve sisteminizi optimize ediyorum. "
            "Soru sormak için şu konularda yardımcı olabilirim:\n"
            "• Sistem durumu ve sensör verileri\n"
            "• Cihaz kararları ve nedenleri\n"
            "• Elektrik maliyeti ve tasarruf\n"
            "• Bitki reçetesi ve parametreler\n"
            "• Yapay zeka modeli bilgileri\n\n"
            "Ne öğrenmek istersiniz?"
        )

    # ── Teşekkür ve Vedalaşma ─────────────────────────────────────────────────
    if any(k in s for k in ["teşekkür", "sağ ol", "teşekkürler", "thanks", "thank you", "görüşürüz", "bye", "hoşça kal"]):
        return "Rica ederim! Sistem her zaman burada, sorularınız için hazır. Başka bir şey olursa sormaktan çekinmeyin. 🌱"

    # ── Manuel/Otonom mod ────────────────────────────────────────────────────
    if any(k in s for k in ["mod", "manuel", "otonom", "kontrol", "geçiş"]):
        return (
            f"Mevcut sistem modu: **{mod}**\n\n"
            "• **Otonom Mod**: Yapay zeka Bodrum Papatyası reçetesine göre tüm kararları alıyor. "
            "Sensör verilerini analiz edip cihazları otomatik yönetiyor.\n"
            "• **Manuel Mod**: Tüm kontrolleri siz yapıyorsunuz, YZ sadece tavsiyelerde bulunuyor.\n\n"
            f"Geçiş yapmak için MQTT kanalına '{KONFIG.topic_mod}' yazın: 'MANUEL' veya 'OTONOM'.\n\n"
            "Hangi modu tercih edersiniz?"
        )

    # ── Neden bu karar? (Ana veriye dayalı açıklama) ─────────────────────────
    if any(k in s for k in ["neden", "niye", "sebep", "açıkla", "karar", "güven", "tahmin", "nasıl karar"]):
        if not pred:
            return (
                "Henüz yeterli veri toplamadıktan dolayı şu anda kural tabanlı karar mekanizması çalışıyor. "
                f"Toplanan veri: {_csv_satir_sayisi()}/{KONFIG.ml_veri_esigi} satır.\n\n"
                "YZ modeli hazır olduğunda daha akıllı kararlar verebilecek. "
                "Şimdilik güvenlik kurallarına göre hareket ediyorum."
            )

        aciklama = (
            f"📊 **YZ Karar Analizi** ({mod} modu):\n\n"
            "• **Pompa**: {karar.get('pompa','?')} (güven: {gp('pompa')})\n"
            "• **Fan**: {karar.get('fan','?')} (güven: {gp('fan')})\n"
            "• **Isıtıcı**: {karar.get('isitici','?')} (güven: {gp('isitici')})\n"
            "• **Growlight**: {karar.get('isik','?')} (güven: {gp('isik')})\n\n"
            f"📈 **Trendler**: Sıcaklık {trend.get('T_ortam','?')}, Işık {trend.get('Isik_Analog','?')}, Elektrik {trend.get('elektrik','?')}\n\n"
        )

        if durum.son_karar_aciklamalari:
            aciklama += "**Son karar detayları**:\n" + "\n".join(f"• {acik}" for acik in durum.son_karar_aciklamalari[-3:]) + "\n\n"

        if feat_imp:
            top = sorted(feat_imp.items(), key=lambda x: x[1], reverse=True)
            aciklama += f"🎯 **En etkili faktörler**: {', '.join(k for k, _ in top[:3])}\n\n"

        aciklama += "💡 Bu kararlar YZ destekli motor tarafından verildi ve Bodrum Papatyası'nın optimum büyüme koşulları için optimize edildi."

        return aciklama

    # ── Işık / Growlight ─────────────────────────────────────────────────────
    if any(k in s for k in ["ışık", "isik", "lux", "growlight", "aydınlat", "güneş", "ışıklandırma"]):
        analog  = sensor.get("Isik_Analog")
        k_guv   = f" (YZ güven: {gp('isik')})" if pred else ""
        durum_str = karar.get("isik", "?")

        if analog is not None:
            analog_not = f"Analog ışık sensörü: {analog:.0f}/4096"
        else:
            analog_not = "Analog ışık verisi henüz alınmadı"

        if durum_str == "ON":
            durum_acik = "etkin"
            yorum = "YZ, bitkinin optimum fotosentez için gerekli ışığı sağlıyor."
        else:
            durum_acik = "kapalı"
            yorum = f"Analog değer {KONFIG.esik_isik_analog_min:.0f}'ın altına düştüğünde otomatik açılacak."

        return (
            f"🌞 **Işık Durumu**\n\n"
            f"• Sensör: {analog_not}\n"
            f"• Growlight: {durum_acik}{k_guv}\n"
            f"• Reçete: {KONFIG.esik_isik_analog_min:.0f} altında ON, {KONFIG.esik_isik_analog_max:.0f} üzerinde OFF\n\n"
            f"{yorum}\n\n"
            "Bodrum Papatyası için ideal ışık seviyesi 25,000-50,000 Lux arasıdır."
        )

    # ── Sıcaklık / Nem / Fan / Isıtıcı ───────────────────────────────────────
    if any(k in s for k in ["sıcaklık", "sıcak", "soğuk", "nem", "hava", "ısı", "fan", "ısıtıcı", "klima"]):
        t     = sensor.get("T_ortam", "?")
        h     = sensor.get("H_ortam", "?")
        f_guv = f" (YZ: {gp('fan')})"     if pred else ""
        i_guv = f" (YZ: {gp('isitici')})" if pred else ""

        return (
            f"🌡️ **Hava Durumu Analizi**\n\n"
            f"• Sıcaklık: {t}°C (ideal: 15-24°C, trend: {trend.get('T_ortam','?')})\n"
            f"• Nem: %{h} (ideal: 40-60%)\n"
            f"• Fan: {karar.get('fan','?')}{f_guv}\n"
            f"• Isıtıcı: {karar.get('isitici','?')}{i_guv}\n\n"
            "Bodrum Papatyası için sıcaklık kritik aralık dışında kalırsa sistem otomatik müdahale eder. "
            "Elektrik maliyeti yüksekse fan kullanımı optimize edilir."
        )

    # ── Pompa / Sulama ────────────────────────────────────────────────────────
    if any(k in s for k in ["pompa", "sulama", "su", "döngü", "sulama"]):
        dakika = datetime.now().minute
        p_guv  = f" (YZ: {gp('pompa')})" if pred else ""
        pencere = f"{KONFIG.pompa_dakika_baslangic}-{KONFIG.pompa_dakika_bitis}"

        return (
            f"💧 **Sulama Sistemi**\n\n"
            f"• Program: Saat başına 10 dakika ({pencere}. dakikalar arası)\n"
            f"• Şu an: Dakika {dakika}, Pompa: {karar.get('pompa','?')}{p_guv}\n\n"
            "YZ, elektrik maliyetini ve bitki nem ihtiyacını dikkate alarak sulama zamanlarınızı optimize ediyor. "
            "Topraksız sistemde kök çürümesini önlemek için periyodik sulama şarttır."
        )

    # ── Elektrik / Maliyet ────────────────────────────────────────────────────
    if any(k in s for k in ["elektrik","elektirik", "fiyat", "maliyet", "para", "enerji", "fatura", "tasarruf"]):
        d = "uygun" if fiyat <= KONFIG.esik_elektrik_pahali else "pahalı"
        return (
            f"⚡ **Elektrik Maliyeti**\n\n"
            f"• Güncel fiyat: {fiyat:.0f} TL/MWh ({d})\n"
            f"• Trend: {trend.get('elektrik','?')}\n"
            f"• Cihaz durumları: Fan {karar.get('fan','?')}, Isıtıcı {karar.get('isitici','?')}, Growlight {karar.get('isik','?')}\n\n"
            "YZ, elektrik fiyatlarını takip ederek pahalı saatlerde enerji tüketimini minimize ediyor. "
            "Growlight ışık ihtiyacına göre çalışırken, fan ve ısıtıcı ekonomik koşullara göre ertelenir."
        )

    # ── Genel Durum ───────────────────────────────────────────────────────────
    if any(k in s for k in ["durum", "nasıl", "özet", "rapor", "iyi mi", "çalışıyor", "sistem"]):
        guven_str = ""
        if pred:
            guven_str = (
                f"\n\n🎯 **YZ Güven Oranları**:\n"
                f"• Pompa: {gp('pompa')} • Fan: {gp('fan')}\n"
                f"• Isıtıcı: {gp('isitici')} • Growlight: {gp('isik')}"
            )

        return (
            f"📋 **AGROTWIN Sistem Özeti** [{mod}]\n\n"
            f"🌱 **Bitki**: Bodrum Papatyası (Osteospermum)\n"
            f"🌡️ **Ortam**: {sensor.get('T_ortam','?')}°C, %{sensor.get('H_ortam','?')} nem\n"
            f"💡 **Işık**: {sensor.get('Isik_Analog','?')} analog ({trend.get('Isik_Analog','?')})\n"
            f"⚙️ **Cihazlar**: Pompa {karar.get('pompa','?')} | Fan {karar.get('fan','?')} | Isıtıcı {karar.get('isitici','?')} | Growlight {karar.get('isik','?')}\n"
            f"⚡ **Elektrik**: {fiyat:.0f} TL/MWh"
            f"{guven_str}\n\n"
            "Sistem Bodrum Papatyası'nın optimum büyüme koşulları için 7/24 çalışıyor."
        )

    # ── YZ Model Bilgisi ──────────────────────────────────────────────────────
    if any(k in s for k in ["yapay zeka","ai", "model", "metrik", "doğruluk", "skor", "öğren", "makine", "zeka"]):
        veri = _csv_satir_sayisi()
        if durum.ml_hazir and durum.son_metrikler:
            ozet = "\n".join(
                f"• {k.upper()}: Doğruluk {v['accuracy']:.1%}, F1 {v['f1']:.2f}, AUC {v.get('auc',float('nan')):.2f}"
                for k, v in durum.son_metrikler.items()
            )
            imp_str = ""
            if feat_imp:
                top = sorted(feat_imp.items(), key=lambda x: x[1], reverse=True)
                imp_str = f"\n\n🎯 **En Önemli Faktörler**: {', '.join(k for k, _ in top[:3])}"
            return (
                f"🤖 **YZ Model Durumu**\n\n"
                f"• Mod: {mod}\n"
                f"• Eğitim verisi: {veri} satır\n"
                f"• Performans metrikleri:{ozet}{imp_str}\n\n"
                "LSTM tabanlı derin öğrenme modeli, sensör verilerinden gelecekteki cihaz ihtiyaçlarını tahmin ediyor."
            )
        return (
            f"📊 **YZ Model Hazırlığı**\n\n"
            f"• Toplanan veri: {veri}/{KONFIG.ml_veri_esigi} satır\n"
            f"• Durum: {'Hazır' if durum.ml_hazir else 'Eğitim bekliyor'}\n\n"
            "YZ modeli yeterli veri toplandığında otomatik olarak eğitilecek ve daha akıllı kararlar verecek."
        )

    # ── Reçete bilgisi ────────────────────────────────────────────────────────
    if any(k in s for k in ["eşik","reçete", "bitki", "papatya", "osteospermum", "parametre", "ayar", "ideal"]):
        return (
            f"🌸 **Bodrum Papatyası Reçetesi**\n\n"
            f"🌡️ **Sıcaklık**: 15-24°C ideal (kritik: 5-30°C)\n"
            f"💧 **Nem**: %40-60 ideal, %70 üstü fan çalışır\n"
            f"💡 **Işık**: 25,000-50,000 Lux optimal\n"
            f"   • Analog < {KONFIG.esik_isik_analog_min:.0f} → Growlight ON\n"
            f"🚿 **Sulama**: Saat başına {KONFIG.pompa_dakika_baslangic}-{KONFIG.pompa_dakika_bitis}. dakika\n\n"
            "Bu parametreler Bodrum iklimine ve Osteospermum türüne özel olarak optimize edildi."
        )

    # ── Kimlik ve Tanıtım ─────────────────────────────────────────────────────
    if any(k in s for k in ["sen kimsin", "kimsin", "tanıt", "kendini tanıt", "adın ne", "ne yapıyorsun"]):
        return (
            "🤖 **Ben AGROTWIN'in Akıllı Asistanıyım!**\n\n"
            "Merhaba! Ben Bodrum Papatyası (Osteospermum) yetiştirme sisteminizin dijital ikizi olan AGROTWIN'in yapay zeka destekli asistanıyım.\n\n"
            "**Görevlerim:**\n"
            "• 🌱 Bodrum Papatyası bitkilerinin optimum büyüme koşullarını sağlamak\n"
            "• 📊 Sensör verilerini analiz edip akıllı kararlar almak\n"
            "• ⚡ Elektrik maliyetini optimize etmek\n"
            "• 💧 Sulama, ısıtma, havalandırma ve aydınlatma sistemlerini yönetmek\n\n"
            "**Teknolojim:**\n"
            "• LSTM tabanlı derin öğrenme modelleri\n"
            "• Gerçek zamanlı sensör veri analizi\n"
            "• Enerji fiyat optimizasyonu\n"
            "• Türkçe doğal dil işleme\n\n"
            "Size nasıl yardımcı olabilirim?"
        )

    # ── Yardım ve Bilinmeyen Sorular ──────────────────────────────────────────
    if any(k in s for k in ["yardım", "help", "komut", "ne yapabilir", "nasıl çalışır"]):
        return (
            "🤖 **AGROTWIN Yardım**\n\n"
            "Ben Bodrum Papatyası yetiştirme sisteminizin akıllı asistanıyım. "
            "Şu konularda size yardımcı olabilirim:\n\n"
            "• **Sensör verileri**: Sıcaklık, nem, ışık durumu\n"
            "• **Cihaz kontrolleri**: Pompa, fan, ısıtıcı, growlight\n"
            "• **YZ kararları**: Neden bu kararlar alındı?\n"
            "• **Elektrik optimizasyonu**: Maliyet ve tasarruf\n"
            "• **Bitki reçetesi**: Optimum büyüme koşulları\n"
            "• **Sistem durumu**: Genel özet ve raporlar\n\n"
            "Soru sormak için doğal dil kullanabilirsiniz. Örneğin:\n"
            "\"Sıcaklık nasıl?\" veya \"Neden fan çalışıyor?\"\n\n"
            "Ne öğrenmek istersiniz?"
        )

    # ── Bilinmeyen Sorular ────────────────────────────────────────────────────
    return (
        "🤔 Bu soru biraz karmaşık geldi, ya da AGROTWIN'in uzmanlık alanı dışında kaldı.\n\n"
        "Size şu konularda daha iyi yardımcı olabilirim:\n"
        "• Sistem durumu ve sensör verileri\n"
        "• Cihaz kararları ve açıklamaları\n"
        "• Elektrik maliyeti ve optimizasyon\n"
        "• Bodrum Papatyası yetiştirme reçetesi\n"
        "• Yapay zeka model bilgileri\n\n"
        "Sorunuzu biraz daha açık hale getirirseniz sevinirim! 🌱"
    )

# ============================================================================
# BÖLÜM 14: MQTT CALLBACK'LERİ
# ============================================================================

def mqtt_baglandinda(client, userdata, flags, reason_code, properties) -> None:
    if reason_code == 0:
        log.info("[MQTT] Bağlandı: %s:%d", KONFIG.mqtt_sunucu, KONFIG.mqtt_port)
        client.subscribe(KONFIG.topic_sensorler, qos=1)
        client.subscribe(KONFIG.topic_chat_soru, qos=1)
        client.subscribe(KONFIG.topic_mod,       qos=1)
    else:
        log.error("[MQTT] Bağlantı reddedildi: %s", reason_code)


def mqtt_kesildiginde(client, userdata, disconnect_flags, reason_code, properties) -> None:
    log.warning("[MQTT] Kesildi: %s. Yeniden bağlanılıyor...", reason_code)


def mqtt_mesaj_alindi(client, userdata, mesaj) -> None:
    konu = mesaj.topic
    try:
        ham = mesaj.payload.decode("utf-8")
    except UnicodeDecodeError:
        log.error("[MQTT] Çözme hatası: %s", konu)
        return

    if konu == KONFIG.topic_sensorler:
        threading.Thread(target=_sensor_mesajini_isle, args=(ham,),
                         daemon=True, name="SensorThread").start()
    elif konu == KONFIG.topic_chat_soru:
        threading.Thread(target=_chatbot_sorusunu_isle, args=(ham,),
                         daemon=True, name="ChatbotThread").start()
    elif konu == KONFIG.topic_mod:
        _mod_degistir(ham)


def _mod_degistir(ham: str) -> None:
    """MQTT üzerinden gelen MANUEL / OTONOM komutunu işler."""
    mod = ham.upper().strip()
    if mod in ("MANUEL", "OTONOM"):
        with durum.veri_kilidi:
            durum.sistem_modu = mod
        log.info("[MOD] Sistem modu değişti: %s", mod)
        ai_log_gonder(f"Sistem {mod} moda alındı.")
    else:
        log.warning("[MOD] Geçersiz mod komutu: %s", ham)


def _analog_lux_hesapla(analog_deger: float) -> float:
    """Analog ışık sensöründen tahmini Lux değerine çevirme."""
    try:
        analog = float(analog_deger)
    except Exception:
        return KONFIG.esik_isik_min

    # Bodrum Papatyası için analog 0-4096 aralığını 0-45000 Lux'e eşle
    if analog <= 0:
        return 0.0

    maks_analog = 4096.0
    lux = (min(max(analog, 0.0), maks_analog) / maks_analog) * KONFIG.esik_isik_optimal

    # Daha düşük mevcut değerler 25000'e eşikleyerek kontrol için uygun
    return float(np.clip(lux, 0.0, KONFIG.esik_isik_optimal))


def _sensor_mesajini_isle(ham: str) -> None:
    """
    ESP32'den gelen JSON'ı işler.
    Beklenen alanlar: T_ortam, H_ortam, Isik_Lux
    (Su sensörü yok — Bodrum Papatyası döngüsel sulanır)
    """
    try:
        veri = json.loads(ham)
    except json.JSONDecodeError as e:
        log.error("[SENSÖR] JSON hatası: %s", e)
        return

    # Isik_Lux verilmemiş ancak Isik_Analog veya Isik_analog gelmiş olabilir.
    if "Isik_Lux" not in veri and "Isik_Analog" in veri:
        veri["Isik_Lux"] = _analog_lux_hesapla(veri["Isik_Analog"])
        log.info("[SENSÖR] Isik_Analog -> Isik_Lux dönüştürüldü: %s -> %.0f", veri["Isik_Analog"], veri["Isik_Lux"])

    zorunlu = {"T_ortam", "H_ortam", "Isik_Lux"}
    if eksik := zorunlu - veri.keys():
        log.warning("[SENSÖR] Eksik anahtarlar: %s", eksik)
        return

    log.info("[SENSÖR] ← T=%.1f°C  H=%.1f%%  Lux=%.0f",
             veri["T_ortam"], veri["H_ortam"], veri["Isik_Lux"])

    with durum.veri_kilidi:
        durum.son_sensor_verisi.update(veri)

    karar_dongusu_calistir(veri, guncel_fiyat_al())


def _chatbot_sorusunu_isle(soru: str) -> None:
    log.info("[CHATBOT] ← %s", soru)
    try:
        # Bazı istemciler soruyu JSON olarak yollar: {"soru":"..."}
        temiz_soru = soru
        try:
            aday = json.loads(soru)
            if isinstance(aday, dict):
                temiz_soru = str(aday.get("soru") or aday.get("message") or soru)
        except json.JSONDecodeError:
            pass

        cevap = chatbot_cevap_uret(temiz_soru).strip()
        if not cevap:
            cevap = "Şu an cevap üretemedim. Lütfen sorunuzu tekrar yazın."
    except Exception as e:
        log.error("[CHATBOT] Cevap üretim hatası: %s", e, exc_info=True)
        cevap = "Chatbot geçici bir hata yaşadı. Lütfen tekrar deneyin."

    istemci = durum.mqtt_istemci
    if istemci and istemci.is_connected():
        # Uygulama tarafı hem düz metni hem JSON gövdeyi okuyabilsin diye JSON yayınla.
        payload = json.dumps(
            {"cevap": cevap, "ts": datetime.now().isoformat(timespec="seconds")},
            ensure_ascii=False
        )
        istemci.publish(KONFIG.topic_chat_cevap, payload, qos=1)


# ============================================================================
# BÖLÜM 14.5: DİREKT TEST/FUNC HİZMETİ
# ============================================================================

def test_karar_uret(sensor_json: str, fiyat: float | None = None) -> dict:
    """Verilen JSON formatındaki sensör verisi için karar üretir."""
    try:
        sensor = json.loads(sensor_json)
        if not isinstance(sensor, dict):
            raise ValueError("Geçersiz JSON; dict bekleniyor.")
    except Exception as e:
        raise ValueError(f"sensör JSON çözümlenirken hata: {e}")

    if fiyat is None:
        try:
            fiyat = guncel_fiyat_al()
        except Exception:
            fiyat = KONFIG.varsayilan_elektrik_fiyat

    if "Isik_Lux" not in sensor and "Isik_Analog" in sensor:
        sensor["Isik_Lux"] = _analog_lux_hesapla(sensor["Isik_Analog"])

    # Model hazırsa AI (LSTM), değilse kural tabanlı
    if durum.ml_hazir and durum.ml_modeli is not None:
        sonuc = ml_tahmin_yap_lstm(sensor, float(fiyat))
        if sonuc:
            kararlar, aciklamalar = sonuc
        else:
            kararlar, aciklamalar = kural_bazli_karar_al(sensor, float(fiyat))
    else:
        kararlar, aciklamalar = kural_bazli_karar_al(sensor, float(fiyat))

    return {
        "sensor": sensor,
        "fiyat": float(fiyat),
        "mod": durum.sistem_modu,
        "kararlar": kararlar,
        "aciklamalar": aciklamalar,
    }


# ============================================================================
# BÖLÜM 15: MQTT İSTEMCİSİ
# ============================================================================

def mqtt_istemci_olustur() -> mqtt.Client:
    istemci = mqtt.Client(
        mqtt.CallbackAPIVersion.VERSION2,
        client_id=KONFIG.mqtt_client_id,
        clean_session=True,
    )
    if KONFIG.mqtt_kullanici:
        istemci.username_pw_set(KONFIG.mqtt_kullanici, KONFIG.mqtt_sifre)
    istemci.on_connect    = mqtt_baglandinda
    istemci.on_disconnect = mqtt_kesildiginde
    istemci.on_message    = mqtt_mesaj_alindi
    istemci.reconnect_delay_set(min_delay=2, max_delay=30)
    return istemci

# ============================================================================
# BÖLÜM 16: GİRİŞ NOKTASI
# ============================================================================

def main() -> None:
    """AGROTWIN Master Node v6.0.0 — Bodrum Papatyası."""
    log.info("=" * 60)
    log.info("  AGROTWIN Master Node v6.0.0 başlatılıyor...")
    log.info("  Reçete: Bodrum Papatyası (Osteospermum)")
    log.info("=" * 60)

    veritabani_baslat()

    if _ENERJI_MODUL_MEVCUT:
        try:
            durum.enerji = EnerjiModulu(db_yolu=KONFIG.veritabani)
            durum.enerji.baslat()
            log.info("[ENERJİ] Tahmin + planlama modülü aktif.")
        except Exception as e:
            log.warning("[ENERJİ] Modül başlatılamadı: %s", e)
    else:
        log.warning("[ENERJİ] agrotwin_enerji.py bulunamadı; enerji tahmini pasif.")

    # Model yükleme / yeniden eğitim kararı
    model_var   = os.path.exists(KONFIG.model_kayit_yolu)
    scaler_var  = os.path.exists(KONFIG.scaler_kayit_yolu)
    dataset_var = os.path.exists(KONFIG.dataset_dosya)

    model_yukle = False
    if model_var and scaler_var:
        model_zaman   = os.path.getmtime(KONFIG.model_kayit_yolu)
        dataset_zaman = os.path.getmtime(KONFIG.dataset_dosya) if dataset_var else 0
        model_yasi_sn = time.time() - model_zaman
        if dataset_zaman <= model_zaman and model_yasi_sn < 3600:
            model_yukle = True

    if model_yukle:
        try:
            with durum.tf_kilidi:
                durum.ml_modeli = load_model(KONFIG.model_kayit_yolu)
                durum.scaler    = joblib.load(KONFIG.scaler_kayit_yolu)
                durum.ml_hazir  = True
            log.info("[ML] Güncel model yüklendi.")
        except Exception as e:
            log.warning("[ML] Model yüklenemedi (%s), yeniden eğitilecek.", e)
            model_yukle = False

    if not model_yukle:
        for dosya in [KONFIG.model_kayit_yolu, KONFIG.scaler_kayit_yolu]:
            if os.path.exists(dosya):
                os.remove(dosya)
                log.info("[ML] Eski dosya silindi: %s", dosya)
        log.info("[ML] Eğitim başlıyor...")
        if ml_model_egit_lstm():
            log.info("[ML] Model hazır.")
        else:
            log.info("[ML] Cold-Start: %d veri bekleniyor.", KONFIG.ml_veri_esigi)

    # EPİAŞ arka plan thread'i
    threading.Thread(
        target=epias_arkaplan_guncelle, daemon=True, name="EpiasThread"
    ).start()
    log.info("[EPİAŞ] Fiyat thread'i başladı.")

    # MQTT
    durum.mqtt_istemci = mqtt_istemci_olustur()
    try:
        durum.mqtt_istemci.connect(KONFIG.mqtt_sunucu, KONFIG.mqtt_port, keepalive=60)
    except (OSError, ConnectionRefusedError) as e:
        log.error("[MQTT] İlk bağlantı başarısız: %s", e)

    log.info("[SİSTEM] MQTT döngüsü başladı. Sensörler bekleniyor...")
    try:
        durum.mqtt_istemci.loop_forever()
    except KeyboardInterrupt:
        log.info("[SİSTEM] Durduruldu (Ctrl+C).")
    finally:
        durum.mqtt_istemci.disconnect()
        log.info("[SİSTEM] AGROTWIN kapatıldı.")


if __name__ == "__main__":
    main()

# ============================================================================
#  AGROTWIN Master Node v6.0.0 — Bodrum Papatyası Reçetesi
#  "Topraksız tarımda, yapay zekâ hiç uyumaz." ™
# ============================================================================
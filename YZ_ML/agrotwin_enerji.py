# ============================================================================
#
#  AGROTWIN — Enerji Fiyat Tahmin ve Maliyet Optimizasyon Modülü
#  Dosya: agrotwin_enerji.py
#
#  Bu dosyayı agrotwin_ai_v6.py ile aynı dizine koy.
#  Ana kodda: from agrotwin_enerji import EnerjiModulu
#
#  Kurulum (ek paketler):
#    pip install numpy pandas scikit-learn tensorflow joblib requests
#    (tensorflow zaten kuruluysa ekstra paket gerekmez)
#
#  Özellikler:
#    1. EPİAŞ'tan 168 saatlik PTF geçmişi çekme
#    2. Seq2Seq LSTM ile 24 saatlik fiyat tahmini
#    3. Akıllı zamanlayıcı: en ucuz saatlere göre program
#    4. SQLite'a gerçek + tahmin fiyatları kayıt (Grafana için)
#    5. Chatbot entegrasyonu: proaktif enerji tavsiyeleri
#
# ============================================================================

from __future__ import annotations

import json
import logging
import os
import re
import sqlite3
import threading
import time
from datetime import datetime, timedelta
from typing import Optional

import joblib
import numpy as np
import pandas as pd
import requests
from sklearn.preprocessing import MinMaxScaler
from tensorflow.keras.layers import LSTM, Dense, RepeatVector, TimeDistributed
from tensorflow.keras.models import Sequential, load_model
from tensorflow.keras.callbacks import EarlyStopping

log = logging.getLogger("AGROTWIN.Enerji")

# ============================================================================
# BÖLÜM 1: SABITLER
# ============================================================================

EPIAS_API_URL   = ("https://seffaflik.epias.com.tr"
                   "/electricity-service/v1/markets/dam/data/mcp")
LOOKBACK_HOURS  = 168          # 1 hafta geçmiş — model girdisi
FORECAST_HOURS  = 24           # 24 saat tahmin
PAHALI_ESIK     = 2000.0       # TL/MWh — bu üstü "pahalı"
UCUZ_ESIK       = 1400.0       # TL/MWh — bu altı "ucuz"
# Programlanabilir cihazlar (enerji yoğun): sulama + ısıtıcı
PROGRAMLANABILIR_CIHAZLAR = ["pompa", "isitici"]

# ============================================================================
# BÖLÜM 2: SQLite ŞEMA (Grafana için)
# ============================================================================

TABLO_FIYAT_TAHMIN = """
CREATE TABLE IF NOT EXISTS price_forecasts (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp       TEXT NOT NULL,          -- Tahmin yapılma zamanı
    forecast_hour   TEXT NOT NULL,          -- Tahmin edilen saat (ISO)
    gercek_fiyat    REAL,                   -- Gerçek PTF (sonradan doldurulur)
    tahmin_fiyat    REAL NOT NULL,          -- Model tahmini
    pahali_mi       INTEGER DEFAULT 0,      -- 1 = pahalı
    ucuz_mu         INTEGER DEFAULT 0       -- 1 = ucuz
)
"""

INDEX_FIYAT_TAHMIN_UNIQUE = """
CREATE UNIQUE INDEX IF NOT EXISTS idx_price_forecasts_forecast_hour
ON price_forecasts (forecast_hour)
"""

TABLO_PROGRAM = """
CREATE TABLE IF NOT EXISTS energy_schedule (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    olusturulma     TEXT NOT NULL,
    cihaz           TEXT NOT NULL,          -- pompa / isitici
    planlanan_saat  TEXT NOT NULL,          -- çalışacağı saat (ISO)
    beklenen_fiyat  REAL,
    aktif_mi        INTEGER DEFAULT 1       -- 0 = iptal edildi
)
"""

# ============================================================================
# BÖLÜM 3: EPİAŞ VERİ ÇEKME
# ============================================================================

def epias_gecmis_cek(saat: int = 8760) -> pd.DataFrame:
    """
    1 yıllık EPİAŞ verisini 'epias_data.csv' dosyasından okur.
    Tarih formatlarındaki (nokta, tire, saniye eksikliği) tüm sorunları otomatik çözer.
    """
    dosya_adi = "epias_data.csv"
    
    if not os.path.exists(dosya_adi):
        log.error(f"[ENERJİ] HATA: {dosya_adi} dosyası bulunamadı!")
        return pd.DataFrame()

    try:
        # CSV ayraçları farklı olabilir (TR Excel çoğunlukla ';')
        aday_sep = [";", ",", "\t", None]
        df = pd.DataFrame()
        for sep in aday_sep:
            try:
                if sep is None:
                    deneme = pd.read_csv(dosya_adi, sep=None, engine="python", encoding="utf-8-sig")
                else:
                    deneme = pd.read_csv(dosya_adi, sep=sep, engine="python", encoding="utf-8-sig")
                if deneme.shape[1] >= 3:
                    df = deneme
                    break
            except Exception:
                continue

        if df.empty:
            log.error("[ENERJİ] CSV okunamadı veya sütunlar ayrıştırılamadı.")
            return pd.DataFrame()

        df.columns = [str(c).strip() for c in df.columns]
        ust_map = {c.upper(): c for c in df.columns}

        # Beklenen başlıklar: Tarih + Saat + PTF (TL/MWh)
        tarih_kol = next((c for c in df.columns if "TARIH" in c.upper()), None)
        saat_kol = next((c for c in df.columns if "SAAT" in c.upper()), None)
        ptf_kol = next(
            (c for c in df.columns if "PTF" in c.upper() and "TL" in c.upper()),
            None
        )
        if ptf_kol is None:
            ptf_kol = next((c for c in df.columns if "PTF" in c.upper()), None)

        if ptf_kol is None:
            log.error("[ENERJİ] PTF sütunu bulunamadı. Sütunlar: %s", list(df.columns))
            return pd.DataFrame()

        # Zaman sütunu oluştur
        if tarih_kol and saat_kol:
            ds_raw = (
                df[tarih_kol].astype(str).str.strip() + " " +
                df[saat_kol].astype(str).str.strip()
            )
        elif tarih_kol:
            ds_raw = df[tarih_kol].astype(str).str.strip()
        else:
            # Son çare: ilk sütunu tarih kabul et
            ilk = list(ust_map.values())[0]
            ds_raw = df[ilk].astype(str).str.strip()

        # TR sayı formatını normalize et: 2.900,03 -> 2900.03
        ptf_raw = (
            df[ptf_kol]
            .astype(str)
            .str.strip()
            .str.replace(".", "", regex=False)
            .str.replace(",", ".", regex=False)
        )

        out = pd.DataFrame({
            "ds": pd.to_datetime(ds_raw, dayfirst=True, errors="coerce"),
            "ptf": pd.to_numeric(ptf_raw, errors="coerce"),
        })

        out = out.dropna(subset=["ds", "ptf"]).sort_values("ds").reset_index(drop=True)
        out = out.tail(saat)

        if out.empty:
            log.error("[ENERJİ] HATA: Tarih/fiyat dönüşümünden sonra veri kalmadı.")
            return pd.DataFrame()

        log.info(
            "[ENERJİ] CSV'den %d saatlik veri başarıyla çekildi. Min: %.0f Max: %.0f",
            len(out), out["ptf"].min(), out["ptf"].max()
        )
        return out[["ds", "ptf"]]

    except Exception as e:
        log.error("[ENERJİ] CSV okuma hatası: %s", e)
        return pd.DataFrame()


def epias_gercek_fiyat_guncelle(db_yolu: str) -> None:
    """
    price_forecasts tablosundaki geçmiş saatlerin gercek_fiyat sütununu
    EPİAŞ API'den gelen gerçek değerlerle günceller.
    Grafana'daki 'Gerçek vs. Tahmin' grafiğini besler.
    """
    try:
        gercek = epias_gecmis_cek(saat=48)
        if gercek.empty:
            return

        with sqlite3.connect(db_yolu) as bag:
            for _, satir in gercek.iterrows():
                saat_str = satir["ds"].isoformat()
                bag.execute("""
                    UPDATE price_forecasts
                    SET gercek_fiyat = ?
                    WHERE forecast_hour = ? AND gercek_fiyat IS NULL
                """, (satir["ptf"], saat_str))
            bag.commit()
        log.info("[ENERJİ] Gerçek fiyatlar güncellendi.")
    except Exception as e:
        log.error("[ENERJİ] Gerçek fiyat güncelleme hatası: %s", e)

# ============================================================================
# BÖLÜM 4: FEATURE ENGINEERING (Zaman Serisi)
# ============================================================================

def zaman_ozellik_ekle(df: pd.DataFrame) -> pd.DataFrame:
    """
    Ham PTF verisine mevsimsellik + döngüsellik özellikleri ekler.

    Eklenen özellikler:
      hour_sin/cos   : Günlük döngü (24 saatlik periyot)
      dow_sin/cos    : Haftalık döngü (7 günlük periyot)
      month_sin/cos  : Yıllık mevsimsellik
      is_weekend     : Hafta sonu dummy (talep örüntüsü farklı)
      ptf_lag1/lag24 : Bir önceki saat ve aynı saatin dünkü değeri
      ptf_ma6/ma24   : 6 ve 24 saatlik hareketli ortalama
    """
    df = df.copy()
    df["hour"]  = df["ds"].dt.hour
    df["dow"]   = df["ds"].dt.dayofweek
    df["month"] = df["ds"].dt.month

    # Döngüsel kodlama (sin/cos) → modelin periyodikliği öğrenmesini sağlar
    df["hour_sin"]  = np.sin(2 * np.pi * df["hour"]  / 24)
    df["hour_cos"]  = np.cos(2 * np.pi * df["hour"]  / 24)
    df["dow_sin"]   = np.sin(2 * np.pi * df["dow"]   / 7)
    df["dow_cos"]   = np.cos(2 * np.pi * df["dow"]   / 7)
    df["month_sin"] = np.sin(2 * np.pi * df["month"] / 12)
    df["month_cos"] = np.cos(2 * np.pi * df["month"] / 12)

    df["is_weekend"] = (df["dow"] >= 5).astype(int)

    # Lag özellikleri
    df["ptf_lag1"]  = df["ptf"].shift(1).fillna(method="bfill")
    df["ptf_lag24"] = df["ptf"].shift(24).fillna(method="bfill")

    # Hareketli ortalama
    df["ptf_ma6"]  = df["ptf"].rolling(6,  min_periods=1).mean()
    df["ptf_ma24"] = df["ptf"].rolling(24, min_periods=1).mean()

    return df

# ============================================================================
# BÖLÜM 5: SEQ2SEQ LSTM MODELİ
# ============================================================================

OZELLIKLER = [
    "ptf", "hour_sin", "hour_cos", "dow_sin", "dow_cos",
    "month_sin", "month_cos", "is_weekend",
    "ptf_lag1", "ptf_lag24", "ptf_ma6", "ptf_ma24",
]

MODEL_KAYIT  = "agrotwin_enerji_model.keras"
SCALER_KAYIT = "agrotwin_enerji_scaler.save"
PTF_SCALER_KAYIT = "agrotwin_ptf_scaler.save"


def seq2seq_model_olustur(n_ozellik: int) -> Sequential:
    """
    Encoder-Decoder Seq2Seq LSTM.

    Encoder : 168 zaman adımı, N özellik → 64 gizli durum
    Decoder : 64 gizli durumu 24 kez tekrar → 24 adım PTF tahmini
    """
    model = Sequential([
        # Encoder: geçmiş 168 saati özetle
        LSTM(64, activation="tanh",
             input_shape=(LOOKBACK_HOURS, n_ozellik),
             return_sequences=False),
        # Encoder çıkışını 24 kez tekrar et (decoder girdisi)
        RepeatVector(FORECAST_HOURS),
        # Decoder: 24 adım üret
        LSTM(64, activation="tanh", return_sequences=True),
        # Her adım için tek değer (PTF tahmini)
        TimeDistributed(Dense(1)),
    ])
    model.compile(optimizer="adam", loss="mse", metrics=["mae"])
    return model


def model_egit(db_yolu: str,
               model_kayit: str = MODEL_KAYIT,
               scaler_kayit: str = SCALER_KAYIT,
               ptf_scaler_kayit: str = PTF_SCALER_KAYIT) -> bool:
    """
    Geçmiş EPİAŞ verisini çekip Seq2Seq modeli eğitir.
    En az 300 saatlik veri gereklidir (168 giriş + 24 çıkış + pay).

    Returns:
        bool: Eğitim başarılıysa True.
    """
    log.info("[ENERJİ] Model eğitimi başlıyor...")
    df = epias_gecmis_cek(saat=8760)  # 1 yıl

    if len(df) < LOOKBACK_HOURS + FORECAST_HOURS + 50:
        log.warning("[ENERJİ] Yetersiz veri: %d saat. En az %d gerekli.",
                    len(df), LOOKBACK_HOURS + FORECAST_HOURS + 50)
        return False

    df = zaman_ozellik_ekle(df)
    df = df.dropna().reset_index(drop=True)

    # Özellik scaler (tüm özellikler)
    scaler = MinMaxScaler(feature_range=(-1, 1))
    X_scaled = scaler.fit_transform(df[OZELLIKLER].values)

    # PTF scaler (sadece hedef, ters dönüşüm için)
    ptf_scaler = MinMaxScaler(feature_range=(-1, 1))
    ptf_idx = OZELLIKLER.index("ptf")
    ptf_scaler.fit(df[["ptf"]].values)

    # Sliding window: X=(168, N_ozellik), Y=(24, 1)
    X_list, Y_list = [], []
    for i in range(len(X_scaled) - LOOKBACK_HOURS - FORECAST_HOURS + 1):
        X_list.append(X_scaled[i : i + LOOKBACK_HOURS])
        Y_list.append(X_scaled[i + LOOKBACK_HOURS : i + LOOKBACK_HOURS + FORECAST_HOURS,
                                ptf_idx:ptf_idx + 1])

    X = np.array(X_list)  # (N, 168, n_ozellik)
    Y = np.array(Y_list)  # (N, 24, 1)

    # Train / val split (%85 / %15, zamansal sıra korunur)
    split = int(len(X) * 0.85)
    X_tr, X_vl = X[:split], X[split:]
    Y_tr, Y_vl = Y[:split], Y[split:]

    model = seq2seq_model_olustur(n_ozellik=len(OZELLIKLER))
    cb = EarlyStopping(monitor="val_loss", patience=5,
                       restore_best_weights=True, verbose=0)

    model.fit(X_tr, Y_tr,
              validation_data=(X_vl, Y_vl),
              epochs=50, batch_size=32,
              callbacks=[cb], verbose=0)

    model.save(model_kayit)
    joblib.dump(scaler,     scaler_kayit)
    joblib.dump(ptf_scaler, ptf_scaler_kayit)

    val_loss = model.evaluate(X_vl, Y_vl, verbose=0)[0]
    log.info("[ENERJİ] Model eğitildi. Val MSE: %.2f", val_loss)
    return True


def tahmin_uret(model_kayit:     str = MODEL_KAYIT,
                scaler_kayit:    str = SCALER_KAYIT,
                ptf_scaler_kayit: str = PTF_SCALER_KAYIT) -> list[dict]:
    """
    Mevcut modeli kullanarak önümüzdeki 24 saatin PTF tahminini üretir.

    Returns:
        list[dict]: [{"saat": datetime, "tahmin": float}, ...]
                    Başarısız olursa boş liste.
    """
    if not all(os.path.exists(p) for p in [model_kayit, scaler_kayit, ptf_scaler_kayit]):
        log.warning("[ENERJİ] Model dosyaları bulunamadı — önce model_egit() çalıştır.")
        return []

    df = epias_gecmis_cek(saat=LOOKBACK_HOURS + 24)
    if len(df) < LOOKBACK_HOURS:
        log.warning("[ENERJİ] Tahmin için yetersiz geçmiş veri.")
        return []

    df = zaman_ozellik_ekle(df)
    df = df.dropna()

    try:
        model      = load_model(model_kayit)
        scaler     = joblib.load(scaler_kayit)
        ptf_scaler = joblib.load(ptf_scaler_kayit)

        son_168 = df.tail(LOOKBACK_HOURS)[OZELLIKLER].values
        son_168_sc = scaler.transform(son_168)
        X_input    = son_168_sc.reshape(1, LOOKBACK_HOURS, len(OZELLIKLER))

        pred_sc  = model.predict(X_input, verbose=0)[0]     # (24, 1)
        pred_ptf = ptf_scaler.inverse_transform(pred_sc)    # (24, 1)

        son_zaman = df["ds"].iloc[-1]
        now_floor = datetime.now().replace(minute=0, second=0, microsecond=0)
        base_zaman = max(son_zaman, now_floor)
        sonuclar  = []
        for i in range(FORECAST_HOURS):
            saat   = base_zaman + timedelta(hours=i + 1)
            fiyat  = float(max(0, pred_ptf[i, 0]))
            sonuclar.append({"saat": saat, "tahmin": fiyat})

        log.info("[ENERJİ] 24 saatlik tahmin üretildi. "
                 "Min: %.0f Max: %.0f TL/MWh",
                 min(r["tahmin"] for r in sonuclar),
                 max(r["tahmin"] for r in sonuclar))
        return sonuclar

    except Exception as e:
        log.error("[ENERJİ] Tahmin hatası: %s", e, exc_info=True)
        return []

# ============================================================================
# BÖLÜM 6: AKILLI ZAMANLAYICI (SCHEDULER)
# ============================================================================

def program_olustur(tahmin: list[dict], db_yolu: str) -> dict:
    """
    24 saatlik fiyat tahmininden programlanabilir cihazlar için
    en ucuz çalışma saatlerini seçer ve SQLite'a kaydeder.

    Strateji:
      - Pompa: Günde 1 kez çalışır, en ucuz 1 saatte
      - Isıtıcı: Günde 3 kez çalışabilir, en ucuz 3 saatte
        (sıcak havalarda bu sayı azalır — buraya sensör bağlanabilir)

    Returns:
        dict: {"pompa": [saat_str, ...], "isitici": [saat_str, ...]}
    """
    if not tahmin:
        return {}

    # Sırala: ucuzdan pahalıya
    sirali = sorted(tahmin, key=lambda x: x["tahmin"])

    program = {}

    # Pompa: en ucuz 1 saat
    pompa_saatleri = [sirali[0]["saat"]]
    program["pompa"] = pompa_saatleri

    # Isıtıcı: en ucuz 3 saat (gece saatlerini tercih et)
    isitici_adaylar = [r for r in sirali if r["tahmin"] < PAHALI_ESIK][:3]
    if not isitici_adaylar:
        isitici_adaylar = sirali[:3]
    program["isitici"] = [r["saat"] for r in isitici_adaylar]

    # SQLite'a kaydet
    try:
        with sqlite3.connect(db_yolu) as bag:
            bag.execute("""
                UPDATE energy_schedule SET aktif_mi = 0
                WHERE olusturulma < datetime('now', '-1 day')
            """)
            simdi = datetime.now().isoformat(timespec="seconds")
            for cihaz, saatler in program.items():
                for saat in saatler:
                    fiyat = next(
                        (r["tahmin"] for r in tahmin if r["saat"] == saat), None
                    )
                    bag.execute("""
                        INSERT INTO energy_schedule
                            (olusturulma, cihaz, planlanan_saat, beklenen_fiyat, aktif_mi)
                        VALUES (?, ?, ?, ?, 1)
                    """, (simdi, cihaz, saat.isoformat(), fiyat))
            bag.commit()
        log.info("[ENERJİ] Program SQLite'a kaydedildi.")
    except Exception as e:
        log.error("[ENERJİ] Program kayıt hatası: %s", e)

    return program


def programli_mi(cihaz: str, db_yolu: str, tolerans_dk: int = 30) -> bool:
    """
    Bu cihazın şu an için planlanmış bir çalışma zamanı var mı?
    Tolerans: planlanan saatten ±30 dakika içindeyse True döner.
    Ana karar motorunda kullanılır: programlanmışsa çalıştır.
    """
    simdi = datetime.now()
    pencere_baslangic = (simdi - timedelta(minutes=tolerans_dk)).isoformat()
    pencere_bitis     = (simdi + timedelta(minutes=tolerans_dk)).isoformat()

    try:
        with sqlite3.connect(db_yolu) as bag:
            c = bag.execute("""
                SELECT COUNT(*) FROM energy_schedule
                WHERE cihaz = ?
                  AND aktif_mi = 1
                  AND planlanan_saat BETWEEN ? AND ?
            """, (cihaz, pencere_baslangic, pencere_bitis))
            return c.fetchone()[0] > 0
    except Exception:
        return False

# ============================================================================
# BÖLÜM 7: GRAFANA SQL SORGULARI
# ============================================================================

GRAFANA_SORGULAR = {
    "gercek_vs_tahmin": """
        -- Gerçek PTF vs. Model Tahmini (son 48 saat)
        -- Grafana: Time series, timestamp=forecast_hour
        SELECT
            forecast_hour   AS time,
            gercek_fiyat    AS "Gerçek PTF (TL/MWh)",
            tahmin_fiyat    AS "Tahmin (TL/MWh)"
        FROM price_forecasts
        WHERE forecast_hour >= datetime('now', '-48 hours')
        ORDER BY forecast_hour ASC
    """,

    "pahali_saatler": """
        -- Pahalı saatler (Grafana: Bar chart veya Annotations)
        SELECT
            forecast_hour   AS time,
            tahmin_fiyat    AS "Fiyat (TL/MWh)"
        FROM price_forecasts
        WHERE pahali_mi = 1
          AND forecast_hour >= datetime('now', '-2 hours')
        ORDER BY forecast_hour ASC
    """,

    "onumuzdeki_24_saat": """
        -- Önümüzdeki 24 saatin tahmin fiyatları
        SELECT
            forecast_hour   AS time,
            tahmin_fiyat    AS "Tahmin (TL/MWh)",
            CASE WHEN pahali_mi = 1 THEN 'Pahalı'
                 WHEN ucuz_mu   = 1 THEN 'Ucuz'
                 ELSE 'Normal' END AS durum
        FROM price_forecasts
        WHERE forecast_hour > datetime('now')
          AND forecast_hour < datetime('now', '+24 hours')
        ORDER BY forecast_hour ASC
    """,

    "enerji_program": """
        -- Planlanmış cihaz çalışma saatleri
        SELECT
            planlanan_saat  AS time,
            cihaz,
            beklenen_fiyat  AS "Beklenen Fiyat (TL/MWh)"
        FROM energy_schedule
        WHERE aktif_mi = 1
          AND planlanan_saat > datetime('now', '-1 hour')
        ORDER BY planlanan_saat ASC
    """,

    "tahmin_hatasi": """
        -- Model doğruluk takibi (MAPE benzeri)
        SELECT
            DATE(forecast_hour) AS gun,
            AVG(ABS(gercek_fiyat - tahmin_fiyat)
                / NULLIF(gercek_fiyat, 0) * 100) AS "Ortalama Hata (%)"
        FROM price_forecasts
        WHERE gercek_fiyat IS NOT NULL
        GROUP BY DATE(forecast_hour)
        ORDER BY gun DESC
        LIMIT 30
    """,
}


def grafana_sorgu_yazdir() -> None:
    """Tüm Grafana sorgularını log'a yazar (kurulum için kopyala-yapıştır)."""
    log.info("[ENERJİ] ── Grafana SQL Sorguları ──")
    for ad, sorgu in GRAFANA_SORGULAR.items():
        log.info("[ENERJİ] === %s ===\n%s", ad, sorgu)

# ============================================================================
# BÖLÜM 8: ANA MODÜL SINIFI
# ============================================================================

class EnerjiModulu:
    """
    AGROTWIN ana koduna entegre edilecek enerji optimizasyon modülü.

    Kullanım (agrotwin_ai_v6.py içinde):

        from agrotwin_enerji import EnerjiModulu
        enerji = EnerjiModulu(db_yolu="agrotwin_data.db")
        enerji.baslat()  # arka plan thread'leri başlatır

        # Karar motorunda:
        if enerji.programli_mi("pompa"):
            kararlar["pompa"] = "ON"  # planlanmış saatte zorla aç

        # Chatbot'ta:
        tavsiye = enerji.chatbot_tavsiye("yarın maliyet")
    """

    def __init__(self, db_yolu: str = "agrotwin_data.db") -> None:
        self.db_yolu    = db_yolu
        self.tahmin     = []       # Son 24 saatlik tahmin listesi
        self.program    = {}       # Cihaz → saat listesi
        self._kilit     = threading.Lock()
        self._hazir     = False
        self.son_guncelleme: Optional[datetime] = None

        self._db_hazirla()

    def _db_hazirla(self) -> None:
        try:
            with sqlite3.connect(self.db_yolu) as bag:
                bag.execute(TABLO_FIYAT_TAHMIN)
                bag.execute(INDEX_FIYAT_TAHMIN_UNIQUE)
                bag.execute(TABLO_PROGRAM)
                bag.commit()
            log.info("[ENERJİ] Veritabanı tabloları hazır.")
        except Exception as e:
            log.error("[ENERJİ] DB hazırlık hatası: %s", e)

    def baslat(self) -> None:
        """Arka plan thread'lerini başlatır. Ana kodda bir kez çağrılır."""
        # İlk tahmin (başlangıçta model yoksa eğitir)
        threading.Thread(target=self._ilk_yukle,
                         daemon=True, name="EnerjiIlkYukle").start()

        # Her 6 saatte bir tahmin güncelle
        threading.Thread(target=self._periyodik_guncelle,
                         daemon=True, name="EnerjiGuncelle").start()

        log.info("[ENERJİ] Enerji modülü başlatıldı.")

    def _ilk_yukle(self) -> None:
        """Başlangıçta model yoksa eğitir, varsa tahmin üretir."""
        if not os.path.exists(MODEL_KAYIT):
            log.info("[ENERJİ] Model bulunamadı, eğitim başlıyor (~5 dk)...")
            if not model_egit(self.db_yolu):
                log.warning("[ENERJİ] Model eğitimi başarısız — enerji tahmini devre dışı.")
                return
        self._tahmin_ve_program_guncelle()

    def _periyodik_guncelle(self) -> None:
        """Her 1 saatte bir tahmin ve programı yeniler."""
        while True:
            time.sleep(3600)
            self._tahmin_ve_program_guncelle()
            epias_gercek_fiyat_guncelle(self.db_yolu)

    def _tahmin_ve_program_guncelle(self) -> None:
        yeni_tahmin = tahmin_uret()
        if not yeni_tahmin:
            return

        yeni_program = program_olustur(yeni_tahmin, self.db_yolu)

        # SQLite'a kaydet
        self._tahmin_db_kaydet(yeni_tahmin)

        with self._kilit:
            self.tahmin  = yeni_tahmin
            self.program = yeni_program
            self._hazir  = True
            self.son_guncelleme = datetime.now()

        log.info("[ENERJİ] Tahmin ve program güncellendi.")

    def _tahmin_db_kaydet(self, tahmin: list[dict]) -> None:
        try:
            simdi = datetime.now().isoformat(timespec="seconds")
            with sqlite3.connect(self.db_yolu) as bag:
                for r in tahmin:
                    bag.execute("""
                        INSERT INTO price_forecasts
                            (timestamp, forecast_hour, tahmin_fiyat, pahali_mi, ucuz_mu)
                        VALUES (?, ?, ?, ?, ?)
                        ON CONFLICT(forecast_hour) DO UPDATE SET
                            timestamp = excluded.timestamp,
                            tahmin_fiyat = excluded.tahmin_fiyat,
                            pahali_mi = excluded.pahali_mi,
                            ucuz_mu = excluded.ucuz_mu
                    """, (
                        simdi,
                        r["saat"].isoformat(),
                        r["tahmin"],
                        1 if r["tahmin"] > PAHALI_ESIK else 0,
                        1 if r["tahmin"] < UCUZ_ESIK  else 0,
                    ))
                bag.commit()
        except Exception as e:
            log.error("[ENERJİ] Tahmin DB kayıt hatası: %s", e)

    def programli_mi(self, cihaz: str) -> bool:
        """Bu an için cihazın planlanmış çalışması var mı?"""
        return programli_mi(cihaz, self.db_yolu)

    def guncel_tahmin(self) -> list[dict]:
        with self._kilit:
            return list(self.tahmin)

    def tahminleri_tazele(self, force: bool = False, max_yas_dk: int = 60) -> None:
        """
        Tahmini gerektiğinde anlık günceller.
        Chatbot çağrılarında "her saat değişsin" beklentisi için kullanılır.
        """
        with self._kilit:
            son = self.son_guncelleme
            hazir = self._hazir

        if force or (not hazir) or (son is None) or ((datetime.now() - son).total_seconds() > max_yas_dk * 60):
            self._tahmin_ve_program_guncelle()

    def saat_sonrasi_fiyat(self, saat: int = 2) -> Optional[float]:
        """N saat sonrası tahmin fiyatını döner."""
        with self._kilit:
            tahmin = list(self.tahmin)

        if not tahmin or saat < 1:
            return None

        hedef_zaman = datetime.now().replace(minute=0, second=0, microsecond=0) + timedelta(hours=saat)
        for r in tahmin:
            if r["saat"] >= hedef_zaman:
                return float(r["tahmin"])

        # Eğer doğrudan bulunamazsa son indeksle fallback
        return float(tahmin[-1]["tahmin"]) if tahmin else None

    def saat_araligi_tahmin(self, baslangic_saat: int, bitis_saat: int) -> list[dict]:
        """Belirli saat aralığındaki tahminleri döner (1-indexed, dahil)."""
        if baslangic_saat < 1 or bitis_saat < baslangic_saat:
            return []
        with self._kilit:
            tahmin = list(self.tahmin)
        bas_idx = baslangic_saat - 1
        bit_idx = min(bitis_saat, len(tahmin))
        if bas_idx >= len(tahmin):
            return []
        return tahmin[bas_idx:bit_idx]

    def sonraki_pahali_periyot(self) -> Optional[dict]:
        """
        Önümüzdeki 24 saatte en uzun pahalı periyodu bulur.
        Chatbot tavsiyesi için kullanılır.
        Returns:
            {"baslangic": datetime, "bitis": datetime, "max_fiyat": float}
            veya None.
        """
        with self._kilit:
            tahmin = list(self.tahmin)

        if not tahmin:
            return None

        pahali = [r for r in tahmin if r["tahmin"] > PAHALI_ESIK]
        if not pahali:
            return None

        # Ardışık pahalı saatleri grupla
        gruplar = []
        grup = [pahali[0]]
        for i in range(1, len(pahali)):
            onceki = pahali[i - 1]["saat"]
            simdi_s = pahali[i]["saat"]
            if (simdi_s - onceki).seconds <= 3600:
                grup.append(pahali[i])
            else:
                gruplar.append(grup)
                grup = [pahali[i]]
        gruplar.append(grup)

        # En uzun grubu seç
        en_uzun = max(gruplar, key=len)
        return {
            "baslangic": en_uzun[0]["saat"],
            "bitis":     en_uzun[-1]["saat"],
            "max_fiyat": max(r["tahmin"] for r in en_uzun),
            "sure_saat": len(en_uzun),
        }

    def en_ucuz_saatler(self, n: int = 3) -> list[dict]:
        """Önümüzdeki 24 saatin en ucuz N saatini döner."""
        with self._kilit:
            tahmin = list(self.tahmin)
        return sorted(tahmin, key=lambda x: x["tahmin"])[:n]

    def saatlik_tahmin_ozeti(self, saat_sayisi: int = 24) -> str:
        """
        Saatlik fiyat tahmin tablosunu metin olarak döner.
        Chat arayüzünde "enerji tahmini yap" komutunda kullanılır.
        """
        with self._kilit:
            tahmin = list(self.tahmin)[:max(1, saat_sayisi)]

        if not tahmin:
            return "Saatlik enerji tahmini henüz hazır değil."

        satirlar = ["Saatlik enerji maliyet tahmini (TL/MWh):"]
        for r in tahmin:
            durum = "PAHALI" if r["tahmin"] > PAHALI_ESIK else ("UCUZ" if r["tahmin"] < UCUZ_ESIK else "NORMAL")
            satirlar.append(
                f"  - {r['saat'].strftime('%d/%m %H:%M')} -> {r['tahmin']:.0f} ({durum})"
            )
        return "\n".join(satirlar)

    def hazirlik_penceresi(self, onceki_saat: int = 2) -> Optional[dict]:
        """
        Yaklaşan pahalı bloğun öncesindeki hazırlık penceresini döner.
        Returns:
            {"hazirlik_baslangic", "hazirlik_bitis", "pahali_baslangic", "pahali_bitis"}
        """
        p = self.sonraki_pahali_periyot()
        if not p:
            return None
        hazirlik_bitis = p["baslangic"]
        hazirlik_baslangic = hazirlik_bitis - timedelta(hours=max(1, onceki_saat))
        return {
            "hazirlik_baslangic": hazirlik_baslangic,
            "hazirlik_bitis": hazirlik_bitis,
            "pahali_baslangic": p["baslangic"],
            "pahali_bitis": p["bitis"],
            "pahali_sure": p["sure_saat"],
        }

    def _saat_etiket(self, r: dict) -> str:
        durum = "PAHALI" if r["tahmin"] > PAHALI_ESIK else ("UCUZ" if r["tahmin"] < UCUZ_ESIK else "NORMAL")
        return f"{r['saat'].strftime('%d/%m %H:%M')} -> {r['tahmin']:.0f} ({durum})"

    def _parse_horizon(self, soru: str) -> Optional[dict]:
        s = soru.lower()
        m = re.search(r"(\d+)\s*[-–]\s*(\d+)\s*saat", s)
        if m:
            a, b = int(m.group(1)), int(m.group(2))
            if a > b:
                a, b = b, a
            return {"tip": "aralik", "a": a, "b": b}
        m = re.search(r"(\d+)\s*saat\s*sonra", s)
        if m:
            return {"tip": "tek", "n": int(m.group(1))}

        # Kelime tabanlı saat ifadeleri eklendi: bir, iki, üç, ...
        kelime_sayi = {
            "bir": 1, "iki": 2, "üç": 3, "dört": 4, "beş": 5,
            "altı": 6, "yedi": 7, "sekiz": 8, "dokuz": 9, "on": 10,
            "on bir": 11, "on iki": 12, "on üç": 13, "on dört": 14,
            "on beş": 15, "on altı": 16, "on yedi": 17, "on sekiz": 18,
            "on dokuz": 19, "yirmi": 20, "yirmi bir": 21, "yirmi iki": 22,
            "yirmi üç": 23, "yirmi dört": 24
        }
        for k, v in kelime_sayi.items():
            if k in s and "saat" in s:
                return {"tip": "tek", "n": v}

        return None

    def chatbot_tavsiye(self, soru: str) -> Optional[str]:
        """
        Chatbot sorusunu analiz edip enerji tavsiyesi üretir.
        Cevap üretemezse None döner (chatbot genel cevabına devam eder).

        Tetikleyici kelimeler:
          'yarın', 'maliyet', 'pahalı', 'ucuz', 'ne zaman çalıştır',
          'enerji', 'fatura', 'fiyat tahmini', 'plan', 'program'
        """
        self.tahminleri_tazele(force=False, max_yas_dk=60)

        if not self._hazir:
            return "Enerji tahmini henüz hazır değil — model yükleniyor."

        s = soru.lower()
        horizon = self._parse_horizon(soru)
        if horizon:
            if horizon["tip"] == "tek":
                n = horizon["n"]
                f = self.saat_sonrasi_fiyat(n)
                if f is None:
                    return f"{n} saat sonrası için tahmin bulunamadı."
                with self._kilit:
                    tahmin = list(self.tahmin)
                if n - 1 < len(tahmin):
                    r = tahmin[n - 1]
                    return f"{n} saat sonrası tahmin: {self._saat_etiket(r)}"
                return f"{n} saat sonrası için tahmin bulunamadı."
            a, b = horizon["a"], horizon["b"]
            secim = self.saat_araligi_tahmin(a, b)
            if not secim:
                return f"{a}-{b} saat aralığı için tahmin bulunamadı."
            satirlar = [f"{a}-{b} saat aralığı tahminleri:"]
            satirlar.extend(f"  - {self._saat_etiket(r)}" for r in secim)
            return "\n".join(satirlar)

        if "enerji tahmini yap" in s or "saatlik tahmin" in s:
            return self.saatlik_tahmin_ozeti(24)

        enerji_anahtar = [
            "yarın", "maliyet", "pahalı", "ucuz", "enerji",
            "fatura", "fiyat tahmini", "plan", "program", "ne zaman",
            "tahmin", "elektrik fiyat",
        ]
        if not any(k in s for k in enerji_anahtar):
            return None

        with self._kilit:
            tahmin = list(self.tahmin)

        if not tahmin:
            return "24 saatlik fiyat tahmini şu an mevcut değil."

        pahali_periyot = self.sonraki_pahali_periyot()
        ucuz_saatler   = self.en_ucuz_saatler(3)

        # Zaman formatlayıcı
        def sf(dt: datetime) -> str:
            return dt.strftime("%H:%M")

        cevap_parcalari = []

        # Pahalı uyarısı
        if pahali_periyot:
            p = pahali_periyot
            cevap_parcalari.append(
                f"Dikkat: {p['baslangic'].strftime('%d/%m %H:%M')}–"
                f"{sf(p['bitis'])} arası {p['sure_saat']} saat boyunca "
                f"elektrik pahalı (maks. {p['max_fiyat']:.0f} TL/MWh). "
                f"Bu saatlerde sulama ve ısıtma yapmaktan kaçınmanızı öneririm."
            )

        # Ucuz saatler
        if ucuz_saatler:
            ucuz_str = ", ".join(
                f"{r['saat'].strftime('%H:%M')} ({r['tahmin']:.0f} TL)"
                for r in ucuz_saatler
            )
            cevap_parcalari.append(
                f"En ekonomik saatler: {ucuz_str}. "
                f"Sulama ve ısıtmayı bu saatlere planladım."
            )

        # Program özeti
        if self.program:
            for cihaz, saatler in self.program.items():
                s_str = ", ".join(s.strftime("%H:%M") for s in saatler)
                cevap_parcalari.append(
                    f"{cihaz.capitalize()} planı: {s_str}."
                )

        return "\n".join(cevap_parcalari) if cevap_parcalari else None

# ============================================================================
# BÖLÜM 9: ANA KODA ENTEGRASYON TALİMATLARI
# ============================================================================
#
#  agrotwin_ai_v6.py içine şunları ekle:
#
#  ── İmport bölümüne ──────────────────────────────────────────────────────
#  from agrotwin_enerji import EnerjiModulu
#
#  ── GlobalState.__init__ içine ───────────────────────────────────────────
#  self.enerji: Optional[EnerjiModulu] = None
#
#  ── main() içine, EPİAŞ thread'inden ÖNCE ────────────────────────────────
#  durum.enerji = EnerjiModulu(db_yolu=KONFIG.veritabani)
#  durum.enerji.baslat()
#  log.info("[ENERJİ] Enerji optimizasyon modülü başlatıldı.")
#
#  ── karar_dongusu_calistir() içinde kural motorundan ÖNCE ────────────────
#  # Programlanmış saatlerde enerji-yoğun cihazları zorla aç
#  if durum.enerji and durum.enerji.programli_mi("pompa"):
#      log.info("[PROGRAM] Pompa planlanmış saatte — enerji optimize.")
#      # Kararı override et (kural veya LSTM'den bağımsız)
#
#  ── chatbot_cevap_uret() içinde, genel cevaptan ÖNCE ─────────────────────
#  if durum.enerji:
#      tavsiye = durum.enerji.chatbot_tavsiye(soru)
#      if tavsiye:
#          return tavsiye
#
# ============================================================================

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO,
                        format="%(asctime)s [%(levelname)s] %(message)s")
    print("AGROTWIN Enerji Modülü — Test Modu")
    print("Grafana sorguları:")
    grafana_sorgu_yazdir()

    modul = EnerjiModulu()
    modul.baslat()
    time.sleep(5)

    tahmin = modul.guncel_tahmin()
    if tahmin:
        print(f"\nİlk 5 tahmin saati:")
        for r in tahmin[:5]:
            print(f"  {r['saat'].strftime('%Y-%m-%d %H:%M')} → {r['tahmin']:.0f} TL/MWh")

    tavsiye = modul.chatbot_tavsiye("yarın maliyet nasıl")
    print(f"\nChatbot tavsiyesi:\n{tavsiye}")

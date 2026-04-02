from __future__ import annotations

import os
from datetime import datetime

import pandas as pd

import agrotwin_enerji as enerji


def _log(mesaj: str) -> None:
    print(f"[OGRETMEN] {mesaj}")


def _csv_var_mi(path: str) -> bool:
    return os.path.exists(path) and os.path.isfile(path)


def _satir_sayisi(path: str) -> int:
    try:
        with open(path, encoding="utf-8", errors="ignore") as f:
            return max(0, sum(1 for _ in f) - 1)
    except OSError:
        return 0


def _epias_kontrol(path: str = "epias_data.csv") -> None:
    if not _csv_var_mi(path):
        raise FileNotFoundError(
            f"{path} bulunamadı. 1 yıllık EPİAŞ datasetini bu dosya adıyla koy."
        )

    df = pd.read_csv(path)
    if len(df) < (enerji.LOOKBACK_HOURS + enerji.FORECAST_HOURS + 50):
        raise ValueError(
            "EPİAŞ dataseti yetersiz. En az "
            f"{enerji.LOOKBACK_HOURS + enerji.FORECAST_HOURS + 50} saatlik veri gerekli."
        )
    _log(f"EPİAŞ dataset hazır: {len(df)} satır")


def enerji_modelini_egit(db_yolu: str = "agrotwin_data.db") -> bool:
    _epias_kontrol("epias_data.csv")
    _log("Enerji tahmin modeli eğitiliyor (24 saat ileri fiyat tahmini)...")
    ok = enerji.model_egit(db_yolu=db_yolu)
    if not ok:
        _log("Enerji modeli eğitilemedi.")
        return False

    tahmin = enerji.tahmin_uret()
    if not tahmin:
        _log("Model eğitildi ama tahmin üretilemedi.")
        return False

    program = enerji.program_olustur(tahmin, db_yolu=db_yolu)
    _log(f"Tahmin üretildi: {len(tahmin)} saat")
    _log(f"Program oluşturuldu: {', '.join(program.keys()) if program else 'yok'}")
    return True


def agrotwin_modelini_egit(dataset_path: str = "agrotwin_data.csv") -> bool:
    """
    Ana AGROTWIN karar modelini (LSTM) eğitir.
    Not: Bu eğitim için etiketli cihaz karar sütunları zorunludur.
    """
    if not _csv_var_mi(dataset_path):
        _log(f"{dataset_path} yok; ana AGROTWIN model eğitimi atlandı.")
        return False

    _log(
        "Ana model eğitimi için "
        f"{dataset_path} bulundu ({_satir_sayisi(dataset_path)} satır). "
        "Bu dosyayı çalıştırmadan önce ana node'u (agrotwin_ai_v5_final.py) başlat."
    )
    return True


def main() -> None:
    _log("Eğitim başlatıldı.")
    _log(f"Zaman: {datetime.now().isoformat(timespec='seconds')}")

    enerji_ok = False
    try:
        enerji_ok = enerji_modelini_egit(db_yolu="agrotwin_data.db")
    except Exception as e:
        _log(f"Enerji eğitimi hatası: {e}")

    _ = agrotwin_modelini_egit("agrotwin_data.csv")

    if enerji_ok:
        _log("Tamam: Enerji tahmin modeli hazır.")
        _log("Grafana için tablolar: price_forecasts, energy_schedule")
    else:
        _log("Enerji modeli tamamlanamadı. epias_data.csv formatını kontrol et.")


if __name__ == "__main__":
    main()

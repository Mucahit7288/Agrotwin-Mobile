import sqlite3

def tabloyu_kur():
    # agrotwin_data.db dosyasını açar (yoksa yaratır)
    db_yolu = "agrotwin_data.db"
    conn = sqlite3.connect(db_yolu)
    cursor = conn.cursor()
    
    print(f"🛠️ {db_yolu} kontrol ediliyor...")

    # Tabloyu senin YZ kodundaki sütun yapısına %100 uyumlu şekilde kuruyoruz
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS sensor_verileri (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            zaman TEXT,
            t_ortam REAL,
            h_ortam REAL,
            t_su REAL,
            mesafe REAL,
            isik REAL,
            elektrik_fiyati REAL,
            pompa TEXT,
            fan TEXT,
            isitici TEXT,
            tahliye TEXT,
            ai_aktif_mi INTEGER
        )
    ''')
    
    conn.commit()
    conn.close()
    print("✅ Tablo başarıyla oluşturuldu! Artık v5 kodun hata vermeden çalışacak.")

if __name__ == "__main__":
    tabloyu_kur()
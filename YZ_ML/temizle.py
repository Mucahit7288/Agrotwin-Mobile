import pandas as pd

print("Excel'in bozduğu dosya onarılıyor...")
# Karışık ayraçları otomatik algılar ve alttaki o bozuk 4 satırı çöpe atar (skip)
df = pd.read_csv('agrotwin_data.csv', sep=None, engine='python', on_bad_lines='skip')

# Tüm dosyayı %100 yapay zeka standardına (virgüllü) çevirip üzerine yazar
df.to_csv('agrotwin_data.csv', index=False)
print("🎉 MÜKEMMEL! Dosya %100 standartlara uygun hale getirildi.")
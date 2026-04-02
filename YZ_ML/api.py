from flask import Flask, jsonify, request
import sqlite3

app = Flask(__name__)

DB = "agrotwin_data.db"

@app.route("/")
def root():
    return jsonify({
        "service": "Agrotwin API",
        "status": "ok",
        "endpoints": ["/health", "/tahmin"]
    })

@app.route("/health")
def health():
    return jsonify({"status": "ok"})

@app.route("/tahmin")
def tahmin():
    limit = request.args.get("limit", default=200, type=int)
    from_ts = request.args.get("from")
    to_ts = request.args.get("to")

    where_parts = []
    params = []
    if from_ts:
        where_parts.append("forecast_hour >= ?")
        params.append(from_ts)
    if to_ts:
        where_parts.append("forecast_hour <= ?")
        params.append(to_ts)

    where_sql = f"WHERE {' AND '.join(where_parts)}" if where_parts else ""

    with sqlite3.connect(DB) as conn:
        c = conn.cursor()
        c.execute(f"""
            SELECT forecast_hour, tahmin_fiyat
            FROM price_forecasts
            {where_sql}
            ORDER BY forecast_hour ASC
            LIMIT ?
        """, (*params, max(1, min(limit, 2000))))
        data = c.fetchall()

    return jsonify([
        {"time": row[0], "value": row[1]}
        for row in data
    ])

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
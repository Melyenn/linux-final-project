from psycopg2.extras import RealDictCursor
import os
from flask import Flask, request, jsonify
import psycopg2
from dotenv import load_dotenv

# Nạp các biến môi trường từ file .env
load_dotenv()

DB_DATABASE = os.getenv("DB_DATABASE", default="appdb")
DB_USER = os.getenv("DB_USER", default="appuser")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST", default="127.0.0.1")
DB_PORT = os.getenv("DB_PORT", default="5432")

app = Flask(__name__)

def get_db_connection():
    return psycopg2.connect(
        database=DB_DATABASE,
        user=DB_USER,
        password=DB_PASSWORD,
        host=DB_HOST,
        port=DB_PORT,
        cursor_factory=RealDictCursor
    )

@app.get("/products")
def getProduct():
    try:
        db = get_db_connection()
        cur = db.cursor()
        cur.execute("SELECT * FROM product;")
        data = cur.fetchall()
        cur.close()
        db.close()
        return jsonify(data), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.post("/products")
def createProduct():
    if request.is_json:   
        data = request.get_json()
        name = data.get("name")
        if not name:
            return jsonify({"error": "Missing product name"}), 400
            
        try:
            db = get_db_connection()
            cur = db.cursor()
            cur.execute("INSERT INTO product (name) VALUES (%s) RETURNING *;", (name,))
            new_product = cur.fetchone()
            db.commit()
            cur.close()
            db.close()
            return jsonify(new_product), 201
        except Exception as e:
            return jsonify({"error": str(e)}), 500

    return jsonify({"error": "Request must be JSON"}), 400

if __name__ == "__main__":
    app.run(debug=True)
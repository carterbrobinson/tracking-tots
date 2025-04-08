from flask import Flask, request, jsonify
import sqlite3
from flask_cors import CORS
from flask_bcrypt import Bcrypt
import datetime
import os
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

app = Flask(__name__)
CORS(app)

DATABASE = 'baby_tracker.db'

def get_db_connection():
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    return conn

bcrypt = Bcrypt(app)

def init_db():
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.executescript('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS feedings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            type TEXT NOT NULL,
            left_breast_duration INTEGER,
            right_breast_duration INTEGER,
            bottle_amount INTEGER,
            start_time DATETIME NOT NULL,
            end_time DATETIME NOT NULL,
            notes TEXT
        );

        CREATE TABLE IF NOT EXISTS sleeps (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            start_time DATETIME NOT NULL,
            end_time DATETIME NOT NULL,
            wake_window INTEGER,
            notes TEXT
        );

        CREATE TABLE IF NOT EXISTS diaper_changes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            type TEXT NOT NULL,
            time DATETIME NOT NULL,
            notes TEXT
        );

        CREATE TABLE IF NOT EXISTS tummy_times (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            start_time DATETIME NOT NULL,
            end_time DATETIME NOT NULL,
            duration INTEGER NOT NULL,
            notes TEXT
        );

        CREATE TABLE IF NOT EXISTS todos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            time DATETIME NOT NULL,
            notes TEXT,
            completed BOOLEAN DEFAULT FALSE
        );

        CREATE TABLE IF NOT EXISTS reminders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            category TEXT NOT NULL,
            reminder_time DATETIME NOT NULL,
            notified BOOLEAN DEFAULT FALSE
        );
    ''')

    conn.commit()
    conn.close()

@app.route('/register', methods=['POST'])
def register():
    data = request.json
    hashed_password = bcrypt.generate_password_hash(data['password']).decode('utf-8')
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('INSERT INTO users (name, email, password) VALUES (?, ?, ?)',
                   (data['name'], data['email'], hashed_password))
    conn.commit()
    conn.close()
    return jsonify({"message": "User registered successfully!"}), 201

@app.route('/login', methods=['POST'])
def login():
    data = request.json
    email = data['email']
    password = data['password']
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM users WHERE email = ?', (email,))
    user = cursor.fetchone()
    conn.close()

    if user and bcrypt.check_password_hash(user['password'], password):
        return jsonify({
            "message": "Login successful!",
            "user_id": user['id'],
            "name": user['name'],
            "email": user['email']
        }), 200
    else:
        return jsonify({"message": "Invalid email or password"}), 401

@app.route('/feeding/<int:user_id>', methods=['POST'])
def add_feeding(user_id):
    data = request.json
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('''
        INSERT INTO feedings (user_id, type, left_breast_duration, right_breast_duration, bottle_amount, start_time, end_time, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
        (user_id, data['type'], data.get('left_breast_duration'), data.get('right_breast_duration'),
         data.get('bottle_amount'), data['start_time'], data['end_time'], data.get('notes')))
    conn.commit()
    conn.close()
    return jsonify({"message": "Feeding record added!"}), 201

@app.route('/sleeping/<int:user_id>', methods=['POST'])
def add_sleep(user_id):
    data = request.json
    start_time = datetime.datetime.fromisoformat(data['start_time'])
    end_time = datetime.datetime.fromisoformat(data['end_time'])
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT end_time FROM sleeps WHERE user_id = ? ORDER BY end_time DESC LIMIT 1', (user_id,))
    last_sleep = cursor.fetchone()
    wake_window = None
    if last_sleep:
        wake_window = int((start_time - datetime.datetime.fromisoformat(last_sleep['end_time'])).total_seconds() / 60)
    cursor.execute('INSERT INTO sleeps (user_id, start_time, end_time, wake_window, notes) VALUES (?, ?, ?, ?, ?)',
                   (user_id, start_time, end_time, wake_window, data.get('notes')))
    conn.commit()
    conn.close()
    return jsonify({"message": "Sleep record added!", "wake_window": wake_window}), 201

@app.route('/sleeping/<int:user_id>', methods=['GET'])
def get_sleep_data(user_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM sleeps WHERE user_id = ? ORDER BY start_time DESC', (user_id,))
    sleeps = cursor.fetchall()
    conn.close()
    return jsonify([{k: s[k] for k in s.keys()} for s in sleeps])

@app.route('/diaper-change/<int:user_id>', methods=['POST'])
def add_diaper_change(user_id):
    data = request.json
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('INSERT INTO diaper_changes (user_id, type, time, notes) VALUES (?, ?, ?, ?)',
                   (user_id, data['type'], data['time'], data.get('notes')))
    conn.commit()
    conn.close()
    return jsonify({"message": "Diaper change recorded!"}), 201

@app.route('/diaper-change/<int:user_id>', methods=['GET'])
def get_diaper_changes(user_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM diaper_changes WHERE user_id = ? ORDER BY time DESC', (user_id,))
    changes = cursor.fetchall()
    conn.close()
    return jsonify([{k: c[k] for k in c.keys()} for c in changes])

@app.route('/todo/<int:user_id>', methods=['POST'])
def add_todo(user_id):
    data = request.json
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('INSERT INTO todos (user_id, time, notes, completed) VALUES (?, ?, ?, ?)',
                   (user_id, data['time'], data.get('notes'), False))
    conn.commit()
    conn.close()
    return jsonify({"message": "Task added!"}), 201

@app.route('/todo/<int:user_id>', methods=['GET'])
def get_todos(user_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM todos WHERE user_id = ? ORDER BY time DESC', (user_id,))
    todos = cursor.fetchall()
    conn.close()
    return jsonify([{k: t[k] for k in t.keys()} for t in todos])

@app.route('/todo/<int:todo_id>/toggle', methods=['PATCH'])
def toggle_todo(todo_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT completed FROM todos WHERE id = ?', (todo_id,))
    todo = cursor.fetchone()
    if not todo:
        return jsonify({"success": False, "message": "Todo not found"}), 404
    new_status = not todo['completed']
    cursor.execute('UPDATE todos SET completed = ? WHERE id = ?', (new_status, todo_id))
    conn.commit()
    conn.close()
    return jsonify({"success": True, "completed": new_status}), 200

@app.route('/tummy-time/<int:user_id>', methods=['POST'])
def add_tummy_time(user_id):
    data = request.json
    start_time = datetime.datetime.fromisoformat(data['start_time'])
    end_time = datetime.datetime.fromisoformat(data['end_time'])
    duration = int((end_time - start_time).total_seconds() / 60)
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('INSERT INTO tummy_times (user_id, start_time, end_time, duration, notes) VALUES (?, ?, ?, ?, ?)',
                   (user_id, start_time, end_time, duration, data.get('notes')))
    conn.commit()
    conn.close()
    return jsonify({"message": "Tummy time recorded!"}), 201

@app.route('/tummy-time/<int:user_id>', methods=['GET'])
def get_tummy_times(user_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM tummy_times WHERE user_id = ? ORDER BY start_time DESC', (user_id,))
    tummy_times = cursor.fetchall()
    conn.close()
    return jsonify([{k: t[k] for k in t.keys()} for t in tummy_times])

@app.route('/homepage/<int:user_id>', methods=['GET'])
def get_homepage_data(user_id):
    try:
        # Get pagination parameters
        page = request.args.get('page', 1, type=int)
        limit = request.args.get('limit', 10, type=int)
        offset = (page - 1) * limit

        conn = get_db_connection()
        cursor = conn.cursor()

        # Get all activities from different tables
        activities = []

        # Get feedings
        cursor.execute('SELECT *, "Feeding" as activity_type FROM feedings WHERE user_id = ?', (user_id,))
        feedings = cursor.fetchall()
        for f in feedings:
            activities.append({
                "id": f['id'],
                "type": "Feeding",
                "time": f['start_time'],
                "end_time": f['end_time'],
                "details": f"Type: {f['type']}, Duration: {datetime.datetime.fromisoformat(f['end_time']) - datetime.datetime.fromisoformat(f['start_time'])}",
                "notes": f['notes']
            })

        # Get sleeps
        cursor.execute('SELECT *, "Sleep" as activity_type FROM sleeps WHERE user_id = ?', (user_id,))
        sleeps = cursor.fetchall()
        for s in sleeps:
            activities.append({
                "id": s['id'],
                "type": "Sleep",
                "time": s['start_time'],
                "end_time": s['end_time'],
                "details": f"Duration: {datetime.datetime.fromisoformat(s['end_time']) - datetime.datetime.fromisoformat(s['start_time'])}",
                "notes": s['notes']
            })

        # Get diaper changes
        cursor.execute('SELECT *, "Diaper Change" as activity_type FROM diaper_changes WHERE user_id = ?', (user_id,))
        changes = cursor.fetchall()
        for c in changes:
            activities.append({
                "id": c['id'],
                "type": "Diaper Change",
                "time": c['time'],
                "details": f"Type: {c['type']}",
                "notes": c['notes']
            })

        # Get tummy times
        cursor.execute('SELECT *, "Tummy Time" as activity_type FROM tummy_times WHERE user_id = ?', (user_id,))
        tummy_times = cursor.fetchall()
        for t in tummy_times:
            activities.append({
                "id": t['id'],
                "type": "Tummy Time",
                "time": t['start_time'],
                "end_time": t['end_time'],
                "details": f"Duration: {t['duration']} minutes",
                "notes": t['notes']
            })

        # Sort activities by time in descending order
        activities.sort(key=lambda x: x['time'], reverse=True)

        # Get total count before pagination
        total_count = len(activities)

        # Apply pagination
        paginated_activities = activities[offset:offset + limit]

        conn.close()

        return jsonify({
            "success": True,
            "activities": paginated_activities,
            "total": total_count,
            "page": page,
            "has_more": (offset + limit) < total_count
        }), 200

    except Exception as e:
        print(f"Error fetching homepage data: {e}")
        return jsonify({
            "success": False,
            "message": "Error fetching homepage data"
        }), 500

@app.route("/", methods=["GET"])
def index():
    return "🎉 Baby Tracker API is Live!"

if __name__ == '__main__':
    init_db()
    port = int(os.environ.get("PORT", 5001))
    app.run(debug=True, host='0.0.0.0', port=port)

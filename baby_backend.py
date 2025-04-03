from flask import Flask, request, jsonify, make_response
from flask_sqlalchemy import SQLAlchemy
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

# SQLite Database Configuration
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:////tmp/baby_tracker.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)
bcrypt = Bcrypt(app)

# Database Models
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(100), unique=True, nullable=False)
    password = db.Column(db.String(255), nullable=False)

class Feeding(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    type = db.Column(db.String(10), nullable=False)
    left_breast_duration = db.Column(db.Integer, nullable=True)
    right_breast_duration = db.Column(db.Integer, nullable=True)
    bottle_amount = db.Column(db.Integer, nullable=True)
    start_time = db.Column(db.DateTime, nullable=False)
    end_time = db.Column(db.DateTime, nullable=False)
    notes = db.Column(db.Text, nullable=True)

class Sleep(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    start_time = db.Column(db.DateTime, nullable=False)
    end_time = db.Column(db.DateTime, nullable=False)
    wake_window = db.Column(db.Integer, nullable=True)
    notes = db.Column(db.Text, nullable=True)

class DiaperChange(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    type = db.Column(db.String(10), nullable=False)
    time = db.Column(db.DateTime, nullable=False)
    notes = db.Column(db.Text, nullable=True)

class TummyTime(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    start_time = db.Column(db.DateTime, nullable=False)
    end_time = db.Column(db.DateTime, nullable=False)
    duration = db.Column(db.Integer, nullable=False)
    notes = db.Column(db.Text, nullable=True)

class Todo(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    time = db.Column(db.DateTime, nullable=False)
    notes = db.Column(db.Text, nullable=True)
    completed = db.Column(db.Boolean, default=False, nullable=False)

class Reminder(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    category = db.Column(db.String(50), nullable=False)
    reminder_time = db.Column(db.DateTime, nullable=False)
    notified = db.Column(db.Boolean, default=False)

# API Endpoints

@app.route('/register', methods=['POST'])
def register():
    data = request.json
    hashed_password = bcrypt.generate_password_hash(data['password']).decode('utf-8')
    new_user = User(name=data['name'], email=data['email'], password=hashed_password)
    db.session.add(new_user)
    db.session.commit()
    return jsonify({"message": "User registered successfully!"}), 201

@app.route('/login', methods=['POST'])
def login():
    data = request.json
    email = data['email']
    password = data['password']

    user = User.query.filter_by(email=email).first()

    if user and bcrypt.check_password_hash(user.password, password):
        return jsonify({
            "message": "Login successful!",
            "user_id": user.id,
            "name": user.name,
            "email": user.email
        }), 200
    else:
        return jsonify({"message": "Invalid email or password"}), 401
        

@app.route('/feeding/<int:user_id>', methods=['POST'])
def add_feeding(user_id):
    data = request.json
    new_feeding = Feeding(
        user_id=user_id,
        type=data['type'],
        left_breast_duration=data.get('left_breast_duration'),
        right_breast_duration=data.get('right_breast_duration'),
        bottle_amount=data.get('bottle_amount'),
        start_time=datetime.datetime.fromisoformat(data['start_time']),
        end_time=datetime.datetime.fromisoformat(data['end_time']),
        notes=data.get('notes')
    )
    db.session.add(new_feeding)
    db.session.commit()
    return jsonify({"message": "Feeding record added!"}), 201

@app.route('/sleeping/<int:user_id>', methods=['POST'])
def add_sleep(user_id):
    data = request.json
    start_time = datetime.datetime.fromisoformat(data['start_time'])
    end_time = datetime.datetime.fromisoformat(data['end_time'])


    last_sleep = Sleep.query.filter_by(user_id=user_id).order_by(Sleep.end_time.desc()).first()
    wake_window = None
    if last_sleep:
        wake_window = int((start_time - last_sleep.end_time).total_seconds() / 60)


    new_sleep = Sleep(
        user_id=user_id,
        start_time=start_time,
        end_time=end_time,
        wake_window=wake_window,
        notes=data.get('notes')
    )
    db.session.add(new_sleep)
    db.session.commit()
    return jsonify({"message": "Sleep record added!", "wake_window": wake_window}), 201

@app.route('/sleeping/<int:user_id>', methods=['GET'])
def get_sleep_data(user_id):
    sleep_data = Sleep.query.filter_by(user_id=user_id).order_by(Sleep.start_time.desc()).all()
    return jsonify([{
        "id": s.id,
        "start_time": s.start_time.isoformat(),
        "end_time": s.end_time.isoformat(),
        "wake_window": s.wake_window,
        "notes": s.notes
    } for s in sleep_data])

@app.route('/diaper-change/<int:user_id>', methods=['GET'])
def get_diaper_change_data(user_id):
    diaper_change_data = DiaperChange.query.filter_by(user_id=user_id).order_by(DiaperChange.time.desc()).all()
    return jsonify([{
        "id": d.id,
        "type": d.type,
        "time": d.time.isoformat(),
        "notes": d.notes
    } for d in diaper_change_data])

@app.route('/diaper-change/<int:user_id>', methods=['POST'])
def add_diaper_change(user_id):
    data = request.json
    new_diaper_change = DiaperChange(
        user_id=user_id,
        type=data['type'],
        time=datetime.datetime.fromisoformat(data['time']),
        notes=data.get('notes')
    )
    db.session.add(new_diaper_change)
    db.session.commit()
    return jsonify({"message": "Diaper change record added!"}), 201

@app.route('/todo/<int:user_id>', methods=['POST'])
def add_task(user_id):
    data = request.json
    new_task = Todo(
        user_id=user_id,
        time=datetime.datetime.fromisoformat(data['time']),
        notes=data.get('notes')
    )
    db.session.add(new_task)
    db.session.commit()
    return jsonify({"message": "task record added!"}), 201

@app.route('/todo/<int:user_id>', methods=['GET'])
def get_todo_list(user_id):
    todos = Todo.query.filter_by(user_id=user_id).order_by(Todo.time.desc()).all()
    return jsonify([{
        "id": t.id,
        "time": t.time.isoformat(),
        "notes": t.notes,
        "completed": t.completed
    } for t in todos])

@app.route('/todo/<int:user_id>', methods=['DELETE'])
def remove_task(user_id):
    todo = Todo.query.filter_by(id=user_id).first()
    if not todo:
        return jsonify({"message": "Todo not found"}), 404
    
    db.session.delete(todo)
    db.session.commit()
    return jsonify({"message": "Todo deleted successfully"}), 200

@app.route('/todo/<int:todo_id>/toggle', methods=['PATCH'])
def toggle_todo(todo_id):
    try:
        todo = Todo.query.get_or_404(todo_id)
        todo.completed = not todo.completed
        db.session.commit()
        return jsonify({
            'success': True,
            'completed': todo.completed
        }), 200
    except Exception as e:
        print(f"Error toggling todo: {e}")  # Add debugging
        db.session.rollback()
        return jsonify({'success': False}), 500

@app.route('/tummy-time/<int:user_id>', methods=['POST'])
def add_tummy_time(user_id):
    data = request.json
    start_time = datetime.datetime.fromisoformat(data['start_time'])
    end_time = datetime.datetime.fromisoformat(data['end_time'])
    duration = int((end_time - start_time).total_seconds() / 60)

    tummy_time = TummyTime(
        user_id=user_id,
        start_time=start_time,
        end_time=end_time,
        duration=duration,
        notes=data.get('notes')
    )
    db.session.add(tummy_time)
    db.session.commit()
    return jsonify({"message": "Tummy Time session recorded!"}), 201

@app.route('/tummy-time/<int:user_id>', methods=['GET'])
def get_tummy_time_data(user_id):
    tummy_time_data = TummyTime.query.filter_by(user_id=user_id).order_by(TummyTime.start_time.desc()).all()
    return jsonify([{
        "id": t.id,
        "start_time": t.start_time.isoformat(),
        "end_time": t.end_time.isoformat(),
        "duration": t.duration,
        "notes": t.notes
    } for t in tummy_time_data])

@app.route('/calendar/<int:user_id>', methods=['GET'])
def get_calendar(user_id):

    feedings = Feeding.query.filter_by(user_id=user_id).all()
    feeding_events = [{
        "id": f.id,
        "type": "Feeding",
        "start_time": f.start_time.isoformat(),
        "end_time": f.end_time.isoformat(),
        "details": f.type
    } for f in feedings]

    sleeps = Sleep.query.filter_by(user_id=user_id).all()
    sleep_events = [{
        "id": s.id,
        "type": "Sleep",
        "start_time": s.start_time.isoformat(),
        "end_time": s.end_time.isoformat(),
        "details": f"Wake Window: {s.wake_window or 'N/A'} minutes"
    } for s in sleeps]

    reminders = Reminder.query.filter_by(user_id=user_id).all()
    reminder_events = [{
        "id": r.id,
        "type": "Reminder",
        "start_time": r.start_time.isoformat(),
        "end_time": r.reminder_time.isoformat(),
        "details": r.category
    } for r in reminders]

    events = feeding_events + sleep_events + reminder_events
    return jsonify({"events": events}), 200

@app.route('/get-response', methods=['POST'])
def get_response():
    data = request.json
    user_input = data.get('text')

    if not os.getenv("OPENAI_API_KEY"):
        return jsonify({"response": "Error: No OpenAI API key found. Please check your configuration."}), 500

    try:
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",  # Use the model you have access to
            messages=[{"role": "user", "content": user_input}]
        )

        if response and hasattr(response, "choices") and len(response.choices) > 0:
            reply = response.choices[0].message.content
            return jsonify({"response": reply})
        else:
            return jsonify({"response": "Error: Invalid AI response"}), 500

    except Exception as e:
        print(f"OpenAI API Error: {e}")  # Debugging
        return jsonify({"response": "Error: AI service unavailable"}), 500

@app.route("/", methods=["GET"])
def index():
    return "🎉 Baby Tracker API is Live!"


if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    port = int(os.environ.get("PORT", 5000))
    app.run(debug=True, host='0.0.0.0', port=port)


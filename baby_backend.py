from flask import Flask, request, jsonify, make_response
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from flask_bcrypt import Bcrypt
import datetime
import os
from openai import OpenAI
from dotenv import load_dotenv
from firebase_admin import credentials, messaging
import firebase_admin
from apscheduler.schedulers.background import BackgroundScheduler

load_dotenv()

cred = credentials.Certificate('firebase_credentials.json')
firebase_admin.initialize_app(cred)

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
    reminder_time = db.Column(db.DateTime, nullable=True)
    completed = db.Column(db.Boolean, default=False, nullable=False)
    reminder_notified = db.Column(db.Boolean, default=False, nullable=False)

class Reminder(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    category = db.Column(db.String(50), nullable=False)
    reminder_time = db.Column(db.DateTime, nullable=False)
    notified = db.Column(db.Boolean, default=False)

class FCMToken(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    token = db.Column(db.String(255), nullable=False)
    platform = db.Column(db.String(10), nullable=False)


def send_notification(token, title, body):
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title = title,
                body = body       
            ),
            token = token,
        )
        response = messaging.send(message)
        print(f"Notification sent to token: {token}. Response: {response}")
    except Exception as e:
        print(f"Error sending notification: {e}")
        
def send_due_reminders():
    with app.app_context():
        now = datetime.datetime.now(datetime.timezone.utc)
        
        print(f"[DEBUG] Checking reminders at {now.isoformat()}")
        
        # Get todos with reminders that are due in the next minute and haven't been notified
        due_todos = Todo.query.filter(
            Todo.reminder_time != None,
            Todo.completed == False,
            Todo.reminder_notified == False,
            Todo.reminder_time <= now + datetime.timedelta(minutes=1),
            Todo.reminder_time > now - datetime.timedelta(minutes=1)
        ).all()
        
        print(f"[DEBUG] Found {len(due_todos)} due todos in the next minute")
        
        # Process the due todos
        for todo in due_todos:
            tokens = FCMToken.query.filter_by(user_id=todo.user_id).all()
            print(f"[DEBUG] Found {len(tokens)} tokens for user {todo.user_id}")
            
            if not tokens:
                print(f"[WARNING] No FCM tokens found for user {todo.user_id}")
                continue
                
            for token_entry in tokens:
                try:
                    message = messaging.Message(
                        token=token_entry.token,
                        notification=messaging.Notification(
                            title="Task Reminder",
                            body=f"Don't forget: {todo.notes}"
                        ),
                        data={
                            "type": "todo",
                            "id": str(todo.id),
                            "notes": todo.notes
                        }
                    )
                    response = messaging.send(message)
                    print(f"[✅] Reminder sent for Todo ID {todo.id}: {response}")
                    
                    # Mark the todo as notified
                    todo.reminder_notified = True
                    db.session.commit()
                    
                except Exception as e:
                    print(f"[❌] Error sending reminder for Todo ID {todo.id}: {e}")

scheduler = BackgroundScheduler()
scheduler.add_job(send_due_reminders, 'interval', seconds=30)  # Check every 30 seconds
scheduler.start()

# API Endpoints

@app.route('/debug-tokens/<int:user_id>', methods=['GET'])
def debug_tokens(user_id):
    tokens = FCMToken.query.filter_by(user_id=user_id).all()
    return jsonify([{"token": t.token, "platform": t.platform} for t in tokens])

@app.route('/delete-token', methods=['POST'])
def delete_token():
    data = request.json
    token = data.get('token')
    if not token:
        return jsonify({"error": "Missing token"}), 400

    deleted = FCMToken.query.filter_by(token=token).delete()
    db.session.commit()
    return jsonify({"message": f"Deleted {deleted} token(s)"}), 200


@app.route('/test-reminders/<int:user_id>', methods=['POST'])
def test_reminders(user_id):
    # Find all FCM tokens for this user
    tokens = FCMToken.query.filter_by(user_id=user_id).all()
    
    if not tokens:
        return jsonify({"message": "No FCM tokens found for this user"}), 404
    
    # Send a test notification to all user's devices
    success_count = 0
    for token_entry in tokens:
        try:
            message = messaging.Message(
                token=token_entry.token,
                notification=messaging.Notification(
                    title="Test Reminder",
                    body="This is a test reminder notification"
                ),
                data={
                    "type": "test",
                    "id": "test-123"
                }
            )
            response = messaging.send(message)
            print(f"[✅] Test reminder sent to user {user_id} token: {token_entry.token}")
            success_count += 1
        except Exception as e:
            print(f"[❌] Error sending test reminder: {e}")
    
    return jsonify({
        "message": f"Test notifications sent to {success_count} of {len(tokens)} devices"
    }), 200

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

@app.route('/feeding/<int:user_id>', methods=['GET'])
def get_feeding_data(user_id):
    feedings = Feeding.query.filter_by(user_id=user_id).order_by(Feeding.start_time.desc()).all()
    return jsonify([{
        "id": f.id,
        "type": f.type,
        "start_time": f.start_time.isoformat(),
        "end_time": f.end_time.isoformat(),
        "left_breast_duration": f.left_breast_duration,
        "right_breast_duration": f.right_breast_duration,
        "bottle_amount": f.bottle_amount,
        "details": f"Type: {f.type}, Duration: {(f.end_time - f.start_time).total_seconds() / 60:.0f} minutes",
        "notes": f.notes
    } for f in feedings])

@app.route('/feeding/<int:user_id>', methods=['DELETE'])
def delete_feeding(user_id):

    feeding = Feeding.query.filter_by(id=user_id).first()
    if not feeding:
        return jsonify({"error": "Feeding not found"}), 404

    db.session.delete(feeding)
    db.session.commit()
    return jsonify({"message": "Feeding deleted successfully"}), 200

@app.route('/feeding/<int:user_id>', methods=['PUT'])
def update_feeding(user_id):
    data = request.json
    feeding = Feeding.query.filter_by(id=user_id).first()
    if not feeding:
        return jsonify({"error": "Feeding not found"}), 404

    # Update the feeding record with new data
    if 'type' in data:
        feeding.type = data['type']
    if 'left_breast_duration' in data:
        feeding.left_breast_duration = data['left_breast_duration']
    if 'right_breast_duration' in data:
        feeding.right_breast_duration = data['right_breast_duration']
    if 'bottle_amount' in data:
        feeding.bottle_amount = data['bottle_amount']
    if 'start_time' in data:
        feeding.start_time = datetime.datetime.fromisoformat(data['start_time'])
    if 'end_time' in data:
        feeding.end_time = datetime.datetime.fromisoformat(data['end_time'])
    if 'notes' in data:
        feeding.notes = data.get('notes')

    db.session.commit()
    return jsonify({"message": "Feeding updated successfully"}), 200
    
    

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

@app.route('/sleeping/<int:user_id>', methods=['DELETE'])
def delete_sleep(user_id):
    sleep_data = Sleep.query.filter_by(id=user_id).first()
    if not sleep_data:
        return jsonify({"error": "Sleep data not found"}), 404

    db.session.delete(sleep_data)
    db.session.commit()
    return jsonify({"message": "Sleep data deleted successfully"}), 200

@app.route('/sleeping/<int:user_id>', methods=['PUT'])
def update_sleep(user_id):
    data = request.json
    sleep_data = Sleep.query.filter_by(id=user_id).first()
    if not sleep_data:
        return jsonify({"error": "Sleep data not found"}), 404

    # Update the sleep record with new data
    if 'start_time' in data:
        sleep_data.start_time = datetime.datetime.fromisoformat(data['start_time'])
    if 'end_time' in data:
        sleep_data.end_time = datetime.datetime.fromisoformat(data['end_time'])
    if 'notes' in data:
        sleep_data.notes = data.get('notes')
    
    # Recalculate wake window if needed
    if 'start_time' in data and sleep_data.user_id:
        last_sleep = Sleep.query.filter(
            Sleep.user_id == sleep_data.user_id,
            Sleep.end_time < sleep_data.start_time
        ).order_by(Sleep.end_time.desc()).first()
        
        if last_sleep:
            sleep_data.wake_window = int((sleep_data.start_time - last_sleep.end_time).total_seconds() / 60)

    db.session.commit()
    return jsonify({"message": "Sleep data updated successfully"}), 200

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

@app.route('/diaper-change/<int:user_id>', methods=['DELETE'])
def delete_diaper_change(user_id):
    diaper_change = DiaperChange.query.filter_by(id=user_id).first()
    if not diaper_change:
        return jsonify({"error": "Diaper change not found"}), 404

    db.session.delete(diaper_change)
    db.session.commit()
    return jsonify({"message": "Diaper change deleted successfully"}), 200

@app.route('/diaper-change/<int:user_id>', methods=['PUT'])
def update_diaper_change(user_id):
    data = request.json
    diaper_change = DiaperChange.query.filter_by(id=user_id).first()
    if not diaper_change:
        return jsonify({"error": "Diaper change not found"}), 404

    # Update the diaper change record with new data
    if 'type' in data:
        diaper_change.type = data['type']
    if 'time' in data:
        diaper_change.time = datetime.datetime.fromisoformat(data['time'])
    if 'notes' in data:
        diaper_change.notes = data.get('notes')

    db.session.commit()
    return jsonify({"message": "Diaper change updated successfully"}), 200

@app.route('/todo/<int:user_id>', methods=['GET'])
def get_todo_list(user_id):
    todos = Todo.query.filter_by(user_id=user_id).order_by(Todo.time.desc()).all()
    return jsonify([{
        "id": t.id,
        "time": t.time.replace(tzinfo=datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "notes": t.notes,
        "completed": t.completed,
        "reminder_time": t.reminder_time.replace(tzinfo=datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ") if t.reminder_time else None
    } for t in todos])

@app.route('/todo/<int:user_id>', methods=['POST'])
def add_task(user_id):
    data = request.json
    reminder_time = data.get('reminder_time')
    
    # Print the reminder time for debugging
    if reminder_time:
        print(f"[DEBUG] New todo with reminder at: {reminder_time}")
        parsed_time = datetime.datetime.fromisoformat(reminder_time)
        now = datetime.datetime.now(datetime.timezone.utc)
        seconds_until_reminder = (parsed_time.replace(tzinfo=datetime.timezone.utc) - now).total_seconds()
        print(f"[DEBUG] Seconds until reminder: {seconds_until_reminder}")
    
    new_task = Todo(
        user_id=user_id,
        time=datetime.datetime.fromisoformat(data['time']).replace(tzinfo=datetime.timezone.utc),
        notes=data.get('notes'),
        reminder_time=datetime.datetime.fromisoformat(reminder_time).replace(tzinfo=datetime.timezone.utc) if reminder_time else None
    )
    db.session.add(new_task)
    db.session.commit()
    return jsonify({"message": "task record added!"}), 201

@app.route('/todo/<int:user_id>', methods=['DELETE'])
def remove_task(user_id):
    todo = Todo.query.filter_by(id=user_id).first()
    if not todo:
        return jsonify({"message": "Todo not found"}), 404
    
    db.session.delete(todo)
    db.session.commit()
    return jsonify({"message": "Todo deleted successfully"}), 200

@app.route('/todo/<int:todo_id>', methods=['PUT'])
def update_todo(todo_id):
    data = request.json
    todo = Todo.query.filter_by(id=todo_id).first()
    if not todo:
        return jsonify({"error": "Todo not found"}), 404

    # Update the todo record with new data
    if 'time' in data:
        todo.time = datetime.datetime.fromisoformat(data['time']).replace(tzinfo=datetime.timezone.utc)
    if 'notes' in data:
        todo.notes = data.get('notes')
    if 'completed' in data:
        todo.completed = data['completed']
    if 'reminder_time' in data:
        reminder_time = data.get('reminder_time')
        todo.reminder_time = datetime.datetime.fromisoformat(reminder_time).replace(tzinfo=datetime.timezone.utc) if reminder_time else None
        # Reset the notified flag when reminder time is updated
        todo.reminder_notified = False

    db.session.commit()
    return jsonify({"message": "Todo updated successfully"}), 200

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

@app.route('/tummy-time/<int:user_id>', methods=['DELETE'])
def delete_tummy_time(user_id):
    tummy_time = TummyTime.query.filter_by(id=user_id).first()
    if not tummy_time:
        return jsonify({"error": "Tummy time not found"}), 404

    db.session.delete(tummy_time)
    db.session.commit()
    return jsonify({"message": "Tummy time deleted successfully"}), 200

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


@app.route('/register-fcm-token', methods=['POST'])
def register_fcm_token():
    data = request.json
    user_id = data.get('user_id')
    token = data.get('token')
    platform = data.get('platform', 'web')

    if not user_id or not token:
        return jsonify({"message": "User ID and token are required"}), 400

    # Delete any existing token that matches this one
    existing_token = FCMToken.query.filter_by(token=token).first()
    if existing_token:
        # Token already exists, no need to add it again
        print(f"[DEBUG] FCM token already exists for user {user_id}: {token}")
        return jsonify({"message": "FCM token already registered"}), 200
        
    # Option to remove all previous tokens for this user+platform combination
    # Uncomment the line below to use this approach
    FCMToken.query.filter_by(user_id=user_id, platform=platform).delete()
    
    # Add the new token
    db.session.add(FCMToken(user_id=user_id, token=token, platform=platform))
    db.session.commit()

    print(f"[DEBUG] FCM token registered for user {user_id}: {token}")
    return jsonify({"message": "FCM token registered successfully"}), 200


@app.route('/check-reminders', methods=['POST'])
def check_reminders():
    now = datetime.datetime.now(datetime.timezone.utc)
    reminders = Reminder.query.filter(Reminder.reminder_time <= now, Reminder.notified == False).all()

    print(f"[DEBUG] Found {len(reminders)} due reminder objects")

    for r in reminders:
        tokens = FCMToken.query.filter_by(user_id=r.user_id).all()
        for token in tokens:
            try:
                message = messaging.Message(
                    token=token.token,
                    notification=messaging.Notification(
                        title="Reminder",
                        body=f"Category: {r.category} at {r.reminder_time}"
                    )
                )
                response = messaging.send(message)
                print(f"[✅] Reminder sent for reminder ID {r.id} to {token.token}: {response}")
            except Exception as e:
                print(f"[❌] Reminder send failed: {e}")
        r.notified = True
    db.session.commit()

    return jsonify({"message": f"Processed {len(reminders)} reminders"}), 200

        
# @app.route('/homepage/<int:user_id>', methods=['GET'])
# def get_homepage_data(user_id):
#     try:
#         feedings = Feeding.query.filter_by(user_id=user_id).all()
#         diaper_changes = DiaperChange.query.filter_by(user_id=user_id).all()
#         tummy_times = TummyTime.query.filter_by(user_id=user_id).all()
#         sleep = Sleep.query.filter_by(user_id=user_id).all()
        
#         activities = []
#         activities.extend([{
#             "id": f.id,
#             "type": "Feeding",
#             "time": f.start_time.isoformat(),
#             "end_time": f.end_time.isoformat(),
#             "details": f"Type: {f.type}, Duration: {(f.end_time - f.start_time).total_seconds() / 60:.0f} minutes",
#             "notes": f.notes
#         } for f in feedings])

#         activities.extend([{
#             "id": d.id,
#             "type": "Diaper Change",
#             "activity_type": d.type,
#             "time": d.time.isoformat(),
#             "details": f"Type: {d.type}",
#             "notes": d.notes
#         } for d in diaper_changes])

#         activities.extend([{
#             "id": t.id,
#             "type": "Tummy Time",
#             "time": t.start_time.isoformat(),
#             "end_time": t.end_time.isoformat(),
#             "details": f"Duration: {t.duration} minutes",
#             "notes": t.notes
#         } for t in tummy_times])

#         activities.extend([{
#             "id": s.id,
#             "type": "Sleep",
#             "time": s.start_time.isoformat(),
#             "end_time": s.end_time.isoformat(),
#             "details": f"Duration: {(s.end_time - s.start_time).total_seconds() / 60:.0f} minutes",
#             "notes": s.notes
#         } for s in sleep])

#         activities.sort(key=lambda x: x['time'], reverse=True)

#         return jsonify({
#             "success": True,
#             "activities": activities
#         }), 200
    
#     except Exception as e:
#         print(f"Error fetching homepage data: {e}")
#         return jsonify({
#             "success": False,
#             "message": "Error fetching homepage data"
#         }), 500

@app.route('/homepage/<int:user_id>', methods=['GET'])
def get_homepage_data(user_id):
    try:
        # Get pagination parameters from request
        page = request.args.get('page', 1, type=int)
        limit = request.args.get('limit', 10, type=int)

        # Calculate offset
        offset = (page - 1) * limit

        # Get all activities
        feedings = Feeding.query.filter_by(user_id=user_id).all()
        diaper_changes = DiaperChange.query.filter_by(user_id=user_id).all()
        tummy_times = TummyTime.query.filter_by(user_id=user_id).all()
        sleep = Sleep.query.filter_by(user_id=user_id).all()
        
        activities = []
        activities.extend([{
            "id": f.id,
            "type": "Feeding",
            "time": f.start_time.isoformat(),
            "end_time": f.end_time.isoformat(),
            "details": f"Type: {f.type}, Duration: {(f.end_time - f.start_time).total_seconds() / 60:.0f} minutes",
            "notes": f.notes
        } for f in feedings])

        activities.extend([{
            "id": d.id,
            "type": "Diaper Change",
            "activity_type": d.type,
            "time": d.time.isoformat(),
            "details": f"Type: {d.type}",
            "notes": d.notes
        } for d in diaper_changes])

        activities.extend([{
            "id": t.id,
            "type": "Tummy Time",
            "time": t.start_time.isoformat(),
            "end_time": t.end_time.isoformat(),
            "details": f"Duration: {t.duration} minutes",
            "notes": t.notes
        } for t in tummy_times])

        activities.extend([{
            "id": s.id,
            "type": "Sleep",
            "time": s.start_time.isoformat(),
            "end_time": s.end_time.isoformat(),
            "details": f"Duration: {(s.end_time - s.start_time).total_seconds() / 60:.0f} minutes",
            "notes": s.notes
        } for s in sleep])

        # Sort all activities by time
        activities.sort(key=lambda x: x['time'], reverse=True)

        # Get total count before pagination
        total_count = len(activities)

        # Apply pagination
        paginated_activities = activities[offset:offset + limit]

        # Check if there are more items
        has_more = (offset + limit) < total_count

        return jsonify({
            "success": True,
            "activities": paginated_activities,
            "total": total_count,
            "page": page,
            "has_more": has_more
        }), 200
    
    except Exception as e:
        print(f"Error fetching homepage data: {e}")
        return jsonify({
            "success": False,
            "message": "Error fetching homepage data"
        }), 500

@app.route('/test-user-notification/<int:user_id>', methods=['POST'])
def test_user_notification(user_id):
    tokens = FCMToken.query.filter_by(user_id=user_id).all()
    
    if not tokens:
        return jsonify({"error": f"No FCM tokens found for user {user_id}"}), 404
    
    success_count = 0
    for token in tokens:
        try:
            message = messaging.Message(
                notification=messaging.Notification(
                    title="Test Notification",
                    body="This is a test notification from Tracking Tots."
                ),
                token=token.token,
            )
            response = messaging.send(message)
            print(f"[✅] Test notification sent to user {user_id}: {response}")
            success_count += 1
        except Exception as e:
            print(f"[❌] Error sending test notification: {e}")
    
    return jsonify({
        "message": f"Test notifications sent to {success_count} out of {len(tokens)} devices",
        "tokens": [t.token for t in tokens]
    }), 200

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    port = int(os.environ.get("PORT", 5001))
    app.run(debug=True, host='0.0.0.0', port=port)


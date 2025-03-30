import pandas as pd
import sqlite3

# Users Table
users_table = pd.DataFrame({
    "id": ["1", "2", "3"],
    "name": ["John Doe", "Jane Smith", "Alex Brown"],
    "email": ["john@example.com", "jane@example.com", "alex@example.com"],
    "password": ["hashed_pw_1", "hashed_pw_2", "hashed_pw_3"]
})

# Feedings Table
feedings_table = pd.DataFrame({
    "id": ["1", "2", "3"],
    "user_id": ["1", "1", "2"],
    "type": ["Breast", "Bottle", "Breast"],
    "left_breast_duration": [10, None, 12],
    "right_breast_duration": [15, None, 8],
    "bottle_amount": [None, 150, None],
    "start_time": ["2025-02-10 08:00", "2025-02-10 12:30", "2025-02-10 14:00"],
    "end_time": ["2025-02-10 08:25", "2025-02-10 12:45", "2025-02-10 14:20"]
})

# Sleeps Table
sleeps_table = pd.DataFrame({
    "id": ["1", "2"],
    "user_id": ["1", "2"],
    "start_time": ["2025-02-10 22:00", "2025-02-10 21:30"],
    "end_time": ["2025-02-11 06:00", "2025-02-11 05:45"],
    "wake_window": [120, 90]
})

# Diaper Changes Table
diaper_changes_table = pd.DataFrame({
    "id": ["1", "2", "3"],
    "user_id": ["1", "1", "2"],
    "type": ["Wet", "Dirty", "Mixed"],
    "time": ["2025-02-10 09:00", "2025-02-10 12:00", "2025-02-10 14:30"]
})

# Tummy Time Table
tummy_time_table = pd.DataFrame({
    "id": ["1", "2"],
    "user_id": ["1", "2"],
    "duration": [15, 10],
    "time": ["2025-02-10 10:00", "2025-02-10 16:00"]
})

# Printing the tables
print("\n=== Users Table ===")
print(users_table.to_string(index=False))

print("\n=== Feedings Table ===")
print(feedings_table.to_string(index=False))s

print("\n=== Sleeps Table ===")
print(sleeps_table.to_string(index=False))

print("\n=== Diaper Changes Table ===")
print(diaper_changes_table.to_string(index=False))

print("\n=== Tummy Time Table ===")
print(tummy_time_table.to_string(index=False))

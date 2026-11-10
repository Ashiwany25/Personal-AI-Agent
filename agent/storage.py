import sqlite3
from pathlib import Path


class Storage:
    def __init__(self, db_path: str):
        path = Path(db_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        self.db = sqlite3.connect(path)
        self.db.execute("CREATE TABLE IF NOT EXISTS messages (user_id INTEGER, role TEXT, content TEXT, created_at TEXT DEFAULT CURRENT_TIMESTAMP)")
        self.db.execute("CREATE TABLE IF NOT EXISTS notes (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, body TEXT, created_at TEXT DEFAULT CURRENT_TIMESTAMP)")
        self.db.execute("CREATE TABLE IF NOT EXISTS tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, body TEXT, done INTEGER DEFAULT 0)")
        self.db.commit()

    def add_message(self, user_id, role, content):
        self.db.execute("INSERT INTO messages (user_id, role, content) VALUES (?, ?, ?)", (user_id, role, content))
        self.db.commit()

    def history(self, user_id, limit=12):
        rows = self.db.execute("SELECT role, content FROM messages WHERE user_id=? ORDER BY rowid DESC LIMIT ?", (user_id, limit)).fetchall()
        return [{"role": role, "content": content} for role, content in reversed(rows)]

    def clear_history(self, user_id):
        self.db.execute("DELETE FROM messages WHERE user_id=?", (user_id,))
        self.db.commit()

    def add_note(self, user_id, body):
        self.db.execute("INSERT INTO notes (user_id, body) VALUES (?, ?)", (user_id, body))
        self.db.commit()

    def notes(self, user_id):
        return self.db.execute("SELECT id, body FROM notes WHERE user_id=? ORDER BY id DESC LIMIT 20", (user_id,)).fetchall()

    def add_task(self, user_id, body):
        self.db.execute("INSERT INTO tasks (user_id, body) VALUES (?, ?)", (user_id, body))
        self.db.commit()

    def tasks(self, user_id):
        return self.db.execute("SELECT id, body, done FROM tasks WHERE user_id=? ORDER BY id DESC LIMIT 30", (user_id,)).fetchall()

    def complete_task(self, user_id, task_id):
        cur = self.db.execute("UPDATE tasks SET done=1 WHERE id=? AND user_id=?", (task_id, user_id))
        self.db.commit()
        return cur.rowcount > 0

"""Database initialization and connection for RxTracker."""
import sqlite3
import os

DB_PATH = os.getenv("DB_PATH", "rxtracker.db")


def get_db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_db():
    db = get_db()
    db.executescript("""
        CREATE TABLE IF NOT EXISTS medicines (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            name        TEXT NOT NULL,
            dosage      TEXT NOT NULL,
            frequency   TEXT NOT NULL,
            times       TEXT NOT NULL,       -- JSON array of "HH:MM"
            start_date  TEXT NOT NULL,       -- ISO date
            end_date    TEXT,                -- ISO date, NULL = ongoing
            instructions TEXT,
            stock       INTEGER,             -- pill count, NULL = not tracked
            category    TEXT,               -- e.g. 'hypertension', 'diabetes'
            created_at  TEXT DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS dose_logs (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            medicine_id     INTEGER NOT NULL REFERENCES medicines(id),
            scheduled_time  TEXT NOT NULL,   -- ISO datetime "YYYY-MM-DDTHH:MM:SS"
            taken           INTEGER NOT NULL DEFAULT 0,
            taken_at        TEXT,            -- ISO datetime when actually taken
            created_at      TEXT DEFAULT (datetime('now')),
            UNIQUE(medicine_id, scheduled_time)
        );

        CREATE INDEX IF NOT EXISTS idx_doses_medicine ON dose_logs(medicine_id);
        CREATE INDEX IF NOT EXISTS idx_doses_scheduled ON dose_logs(scheduled_time);
    """)
    db.commit()

    # Migration: add 'category' column if it doesn't exist yet (for existing DBs)
    try:
        db.execute("ALTER TABLE medicines ADD COLUMN category TEXT")
        db.commit()
    except Exception:
        pass  # Column already exists

    db.close()

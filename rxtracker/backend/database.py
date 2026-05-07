from sqlalchemy import create_engine, Column, Integer, String, Text, DateTime, ForeignKey, JSON
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
import os
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()

# Use Supabase URL if provided, otherwise fallback to local SQLite
SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./rxtracker.db")

# For SQLite, we need to allow multi-threaded access
if SQLALCHEMY_DATABASE_URL.startswith("sqlite"):
    engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
else:
    engine = create_engine(SQLALCHEMY_DATABASE_URL)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# --- Database Models ---

class Medicine(Base):
    __tablename__ = "medicines"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, index=True) # Supabase User ID (UUID string)
    name = Column(String, index=True)
    dosage = Column(String)
    frequency = Column(String)
    times = Column(JSON)  # List of strings e.g. ["08:00"]
    start_date = Column(String)
    end_date = Column(String, nullable=True)
    instructions = Column(Text, nullable=True)
    stock = Column(Integer, default=0)
    category = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class DoseLog(Base):
    __tablename__ = "dose_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, index=True) # Supabase User ID (UUID string)
    medicine_id = Column(Integer, ForeignKey("medicines.id"))
    taken_at = Column(DateTime, default=datetime.utcnow)
    notes = Column(Text, nullable=True)

class Profile(Base):
    __tablename__ = "profiles"

    user_id = Column(String, primary_key=True, index=True) # Supabase User ID
    full_name = Column(String, nullable=True)
    age = Column(Integer, nullable=True)
    sex = Column(String, nullable=True)
    blood_type = Column(String, nullable=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

# Create all tables
def init_db():
    Base.metadata.create_all(bind=engine)

# Dependency to get DB session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

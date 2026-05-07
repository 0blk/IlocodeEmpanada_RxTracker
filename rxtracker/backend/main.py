"""
RxTracker Backend - FastAPI
Prescription reader + medicine tracker/reminder API
"""

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import base64
import json
import os
from datetime import datetime, date
from database import get_db, init_db
import sqlite3

app = FastAPI(title="RxTracker API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
def startup():
    init_db()

# ─── Models ────────────────────────────────────────────────────────────────────

class Medicine(BaseModel):
    name: str
    dosage: str
    frequency: str          # "once_daily", "twice_daily", "three_times_daily", "every_x_hours"
    times: list[str]        # ["08:00", "20:00"]
    start_date: str         # ISO date
    end_date: Optional[str] = None
    instructions: Optional[str] = None
    stock: Optional[int] = None  # pill count
    category: Optional[str] = None  # e.g. "hypertension", "diabetes"

class MedicineUpdate(BaseModel):
    name: Optional[str] = None
    dosage: Optional[str] = None
    frequency: Optional[str] = None
    times: Optional[list[str]] = None
    end_date: Optional[str] = None
    instructions: Optional[str] = None
    stock: Optional[int] = None
    category: Optional[str] = None

class DoseLog(BaseModel):
    medicine_id: int
    scheduled_time: str     # ISO datetime
    taken: bool
    taken_at: Optional[str] = None  # ISO datetime

# ─── Prescription OCR ──────────────────────────────────────────────────────────

@app.post("/api/prescriptions/scan")
async def scan_prescription(file: UploadFile = File(...)):
    """
    Upload a prescription image and extract medicine info using Gemini Vision.
    Falls back to mock data if GEMINI_API_KEY is not set.
    """
    image_data = await file.read()
    b64_image = base64.standard_b64encode(image_data).decode("utf-8")

    content_type = file.content_type or "image/jpeg"
    api_key = os.getenv("GEMINI_API_KEY", "AIzaSyAUAJLpRPbHzWCzC63TIZjlQQF-jG7BV4I")

    if not api_key:
        return {
            "raw_text": "Mock prescription: Amlodipine 5mg, take once daily for hypertension",
            "medicines": [{
                "name": "Amlodipine",
                "dosage": "5mg",
                "frequency": "once_daily",
                "times": ["08:00"],
                "instructions": "Take in the morning.",
                "duration_days": None,
                "category": "hypertension"
            }],
            "note": "Mock response — set GEMINI_API_KEY environment variable for real OCR"
        }

    import google.generativeai as genai
    import logging

    try:
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel("gemini-1.5-flash-latest")

        prompt = """You are an expert pharmacist and OCR system designed to read handwritten and printed medical prescriptions. Analyze this prescription image with extreme care. 

Extract ALL medicines present in the image and return ONLY valid JSON (no markdown, no explanation). Make sure to catch multiple prescriptions if present. 

Expected JSON format:
{
  "raw_text": "A full, verbatim transcript of all text found on the prescription",
  "medicines": [
    {
      "name": "Corrected medicine name (fix spelling mistakes)",
      "dosage": "e.g. 500mg, 1 tablet, 10ml",
      "frequency": "once_daily|twice_daily|three_times_daily|four_times_daily",
      "times": ["HH:MM"],
      "instructions": "Specific instructions like 'Take with food', 'After meals', 'As needed'",
      "duration_days": null,
      "category": "one of: hypertension|diabetes|antibiotic|cardiac|pain_relief|mental_health|vitamins|respiratory|gastrointestinal|other"
    }
  ]
}

Rules:
1. Pay close attention to medical abbreviations:
   - OD = once_daily
   - BID or BD = twice_daily
   - TID or TDS = three_times_daily
   - QID = four_times_daily
   - PRN = as needed (map to once_daily if required, but add to instructions)
   - PO = by mouth
2. Infer times from frequency: 
   - once_daily=["08:00"]
   - twice_daily=["08:00","20:00"]
   - three_times_daily=["08:00","14:00","20:00"]
   - four_times_daily=["08:00","12:00","16:00","20:00"]
3. Infer category from drug name and class (e.g. Amlodipine->hypertension, Metformin->diabetes). If unsure, use "other".
4. Correct obvious spelling mistakes in medicine names.
5. If there are multiple medicines, ensure EVERY single one is extracted as a separate object in the 'medicines' array.
"""

        image_part = {"mime_type": content_type, "data": base64.b64decode(b64_image)}
        response = model.generate_content([prompt, image_part])
        text = response.text.strip()

        if text.startswith("```"):
            text = text.split("```")[1]
            if text.startswith("json"):
                text = text[4:]

        try:
            parsed = json.loads(text)
        except json.JSONDecodeError:
            parsed = {"raw_text": text, "medicines": [], "parse_error": True}

        return parsed
    except Exception as e:
        logging.error(f"Gemini API Error: {e}")
        return {
            "raw_text": f"Mock prescription (API Error: {str(e)}): Amlodipine 5mg, take once daily for hypertension",
            "medicines": [{
                "name": "Amlodipine",
                "dosage": "5mg",
                "frequency": "once_daily",
                "times": ["08:00"],
                "instructions": "Take in the morning.",
                "duration_days": None,
                "category": "hypertension"
            }],
            "note": "Fell back to mock response due to API error."
        }

# ─── Medicines CRUD ────────────────────────────────────────────────────────────

@app.get("/api/medicines")
def list_medicines():
    db = get_db()
    rows = db.execute(
        "SELECT * FROM medicines ORDER BY created_at DESC"
    ).fetchall()
    db.close()
    return [dict(r) for r in rows]

@app.post("/api/medicines", status_code=201)
def create_medicine(med: Medicine):
    db = get_db()
    cur = db.execute(
        """INSERT INTO medicines (name, dosage, frequency, times, start_date, end_date, instructions, stock, category)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (
            med.name, med.dosage, med.frequency,
            json.dumps(med.times),
            med.start_date, med.end_date,
            med.instructions, med.stock, med.category
        )
    )
    db.commit()
    row = db.execute("SELECT * FROM medicines WHERE id=?", (cur.lastrowid,)).fetchone()
    db.close()
    return dict(row)

@app.get("/api/medicines/{medicine_id}")
def get_medicine(medicine_id: int):
    db = get_db()
    row = db.execute("SELECT * FROM medicines WHERE id=?", (medicine_id,)).fetchone()
    db.close()
    if not row:
        raise HTTPException(404, "Medicine not found")
    return dict(row)

@app.patch("/api/medicines/{medicine_id}")
def update_medicine(medicine_id: int, update: MedicineUpdate):
    db = get_db()
    row = db.execute("SELECT * FROM medicines WHERE id=?", (medicine_id,)).fetchone()
    if not row:
        db.close()
        raise HTTPException(404, "Medicine not found")

    fields = {k: v for k, v in update.dict().items() if v is not None}
    if "times" in fields:
        fields["times"] = json.dumps(fields["times"])

    if not fields:
        db.close()
        return dict(row)

    set_clause = ", ".join(f"{k}=?" for k in fields)
    values = list(fields.values()) + [medicine_id]
    db.execute(f"UPDATE medicines SET {set_clause} WHERE id=?", values)
    db.commit()
    row = db.execute("SELECT * FROM medicines WHERE id=?", (medicine_id,)).fetchone()
    db.close()
    return dict(row)

@app.delete("/api/medicines/{medicine_id}", status_code=204)
def delete_medicine(medicine_id: int):
    db = get_db()
    row = db.execute("SELECT id FROM medicines WHERE id=?", (medicine_id,)).fetchone()
    if not row:
        db.close()
        raise HTTPException(404, "Medicine not found")
    # Delete dose_logs FIRST to satisfy the FK constraint, then the medicine
    db.execute("DELETE FROM dose_logs WHERE medicine_id=?", (medicine_id,))
    db.execute("DELETE FROM medicines WHERE id=?", (medicine_id,))
    db.commit()
    db.close()

# ─── Dose Logging ──────────────────────────────────────────────────────────────

@app.get("/api/doses/today")
def get_today_doses():
    """Get all scheduled doses for today with their log status."""
    today = date.today().isoformat()
    db = get_db()

    medicines = db.execute(
        "SELECT * FROM medicines WHERE start_date <= ? AND (end_date IS NULL OR end_date >= ?)",
        (today, today)
    ).fetchall()

    result = []
    for med in medicines:
        times = json.loads(med["times"])
        for t in times:
            scheduled_dt = f"{today}T{t}:00"
            log = db.execute(
                "SELECT * FROM dose_logs WHERE medicine_id=? AND scheduled_time=?",
                (med["id"], scheduled_dt)
            ).fetchone()

            result.append({
                "medicine_id": med["id"],
                "medicine_name": med["name"],
                "dosage": med["dosage"],
                "instructions": med["instructions"],
                "scheduled_time": scheduled_dt,
                "time_label": t,
                "taken": bool(log["taken"]) if log else False,
                "taken_at": log["taken_at"] if log else None,
                "log_id": log["id"] if log else None,
                "category": med["category"],
            })

    db.close()
    result.sort(key=lambda x: x["scheduled_time"])
    return result

@app.post("/api/doses/log")
def log_dose(dose: DoseLog):
    """Mark a dose as taken or not taken."""
    db = get_db()

    existing = db.execute(
        "SELECT * FROM dose_logs WHERE medicine_id=? AND scheduled_time=?",
        (dose.medicine_id, dose.scheduled_time)
    ).fetchone()

    now = datetime.now().isoformat()

    if existing:
        db.execute(
            "UPDATE dose_logs SET taken=?, taken_at=? WHERE id=?",
            (dose.taken, now if dose.taken else None, existing["id"])
        )
        log_id = existing["id"]
    else:
        cur = db.execute(
            "INSERT INTO dose_logs (medicine_id, scheduled_time, taken, taken_at) VALUES (?, ?, ?, ?)",
            (dose.medicine_id, dose.scheduled_time, dose.taken, now if dose.taken else None)
        )
        log_id = cur.lastrowid

    # Decrement stock if taken
    if dose.taken:
        db.execute(
            "UPDATE medicines SET stock = stock - 1 WHERE id=? AND stock > 0",
            (dose.medicine_id,)
        )

    db.commit()
    log = db.execute("SELECT * FROM dose_logs WHERE id=?", (log_id,)).fetchone()
    db.close()
    result = dict(log)
    result["taken"] = bool(result["taken"])
    return result

@app.get("/api/doses/history")
def get_dose_history(medicine_id: Optional[int] = None, days: int = 7):
    db = get_db()
    if medicine_id:
        rows = db.execute(
            """SELECT dl.*, m.name as medicine_name, m.dosage, m.category
               FROM dose_logs dl JOIN medicines m ON dl.medicine_id = m.id
               WHERE dl.medicine_id=?
               ORDER BY dl.scheduled_time DESC LIMIT ?""",
            (medicine_id, days * 10)
        ).fetchall()
    else:
        rows = db.execute(
            """SELECT dl.*, m.name as medicine_name, m.dosage, m.category
               FROM dose_logs dl JOIN medicines m ON dl.medicine_id = m.id
               ORDER BY dl.scheduled_time DESC LIMIT ?""",
            (days * 20,)
        ).fetchall()
    db.close()
    history = [dict(r) for r in rows]
    for entry in history:
        entry["taken"] = bool(entry["taken"])
    return history

@app.get("/api/doses/stats")
def get_stats():
    """Adherence stats per medicine."""
    db = get_db()
    medicines = db.execute("SELECT * FROM medicines").fetchall()
    result = []
    for med in medicines:
        logs = db.execute(
            "SELECT * FROM dose_logs WHERE medicine_id=?", (med["id"],)
        ).fetchall()
        total = len(logs)
        taken = sum(1 for l in logs if l["taken"])
        result.append({
            "medicine_id": med["id"],
            "medicine_name": med["name"],
            "category": med["category"],
            "total_doses_logged": total,
            "doses_taken": taken,
            "adherence_pct": round((taken / total * 100) if total > 0 else 0, 1),
            "stock": med["stock"],
        })
    db.close()
    return result

@app.get("/health")
def health():
    return {"status": "ok", "time": datetime.now().isoformat()}

"""
RxTracker Backend - FastAPI
Prescription reader + medicine tracker/reminder API
"""

from fastapi import FastAPI, UploadFile, File, HTTPException, Request
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import base64
import json
import os
from dotenv import load_dotenv
from datetime import datetime, date

# Load environment variables from .env file
load_dotenv()
from database import get_db, init_db
import sqlite3
from google import genai
from google.genai import types


app = FastAPI(title="RxTracker API", version="1.0.0")

@app.middleware("http")
async def log_requests(request, call_next):
    import time
    start_time = time.time()
    path = request.url.path
    method = request.method
    if method == "OPTIONS":
        return await call_next(request)
        
    print(f"\n>>> [{method}] {path} - Starting request")
    try:
        response = await call_next(request)
        process_time = (time.time() - start_time) * 1000
        print(f"<<< [{method}] {path} - Completed {response.status_code} ({process_time:.2f}ms)")
        return response
    except Exception as e:
        print(f"!!! [{method}] {path} - Server Error: {e}")
        import traceback
        traceback.print_exc()
        return JSONResponse(status_code=500, content={"error": str(e), "traceback": traceback.format_exc()})

# Catch validation errors (like multipart parsing failures)
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    print(f"!!! Validation Error: {exc}")
    return JSONResponse(
        status_code=422,
        content={"detail": exc.errors(), "body": exc.body},
    )

# CORS must be added AFTER other middlewares to ensure it wraps them correctly
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
def startup():
    init_db()

@app.get("/health")
def health():
    return {"status": "ok", "time": datetime.now().isoformat()}

@app.post("/test-post")
def test_post():
    return {"message": "POST request successful!"}

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
    print("Request received!")
    """
    Upload a prescription image and extract medicine info using Claude Vision.
    Falls back to mock data if ANTHROPIC_API_KEY is not set.
    """
    image_data = await file.read()

    content_type = file.content_type or "image/jpeg"
    api_key = os.getenv("GEMINI_API_KEY")

    if not api_key:
        return {
            "raw_text": "Mock prescription: Amoxicillin 500mg, take 3x daily for 7 days",
            "medicines": [{
                "name": "Amoxicillin",
                "dosage": "500mg",
                "frequency": "three_times_daily",
                "times": ["08:00", "14:00", "20:00"],
                "instructions": "Take with food. Complete full course.",
                "duration_days": 7
            }],
            "note": "Mock response - set GEMINI_API_KEY for real OCR"
        }

    api_key = os.getenv("GEMINI_API_KEY")

    try:
        client = genai.Client(api_key=api_key)
        model_id = "gemini-3-flash-preview"

        prompt = """You are a medical prescription OCR specialist. Carefully analyze this prescription image, which may be handwritten, printed, or a mix of both. Some text may be unclear or abbreviated — use your medical knowledge to interpret common drug names, dosages, and abbreviations (e.g. OD=once daily, BD/BID=twice daily, TDS/TID=three times daily, QID=four times daily, PRN=as needed).

Extract ALL medicines listed and return ONLY valid JSON with no markdown fences, no extra text:

{
  "raw_text": "full transcription of all text visible in the prescription",
  "medicines": [
    {
      "name": "full medicine name",
      "dosage": "e.g. 500mg",
      "frequency": "once_daily|twice_daily|three_times_daily|four_times_daily",
      "times": ["HH:MM"],
      "instructions": "any special instructions (e.g. take with food, after meals)",
      "duration_days": null
    }
  ]
}

Rules:
- If text is illegible, make your best medical interpretation and note it in instructions.
- Infer times from frequency: once_daily=["08:00"], twice_daily=["08:00","20:00"], three_times_daily=["08:00","14:00","20:00"], four_times_daily=["08:00","12:00","16:00","20:00"]
- Never return an empty medicines array if any drug names are visible.
- Return ONLY the raw JSON object, nothing else."""
        
        # Ensure mime_type is valid
        mime_type = content_type
        if not mime_type.startswith("image/"):
            mime_type = "image/jpeg"

        # Construct request using the new google-genai SDK
        response = client.models.generate_content(
            model=model_id,
            contents=[
                types.Content(
                    role="user",
                    parts=[
                        types.Part.from_bytes(data=image_data, mime_type=mime_type),
                        types.Part.from_text(text=prompt),
                    ],
                )
            ],
            config=types.GenerateContentConfig(
                thinking_config=types.ThinkingConfig(
                    thinking_level="HIGH",
                ),
            )
        )
        
        # Extract text from response
        text = ""
        if response.candidates and response.candidates[0].content.parts:
            # For thinking models, the text might be in the last part or combine them
            text = "".join([p.text for p in response.candidates[0].content.parts if p.text])
        
        if not text:
            print("!!! No text found in AI response")
            return {"error": "AI returned empty response", "medicines": []}

        # Robust JSON extraction (existing logic)

        # Robust JSON extraction
        import re
        json_match = re.search(r"\{.*\}", text, re.DOTALL)
        if json_match:
            text = json_match.group(0)
        
        try:
            parsed = json.loads(text)
        except json.JSONDecodeError:
            parsed = {"raw_text": text, "medicines": [], "parse_error": True}

        return parsed

    except Exception as e:
        import traceback
        error_msg = str(e)
        print(f"!!! Error during scan: {error_msg}")
        traceback.print_exc()
        return {
            "error": error_msg,
            "note": f"AI Error: {error_msg}",
            "raw_text": "Error occurred during scan.",
            "medicines": []
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

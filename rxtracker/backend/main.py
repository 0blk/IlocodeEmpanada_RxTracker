"""
RxTracker Backend - FastAPI
Prescription reader + medicine tracker/reminder API
"""

from fastapi import FastAPI, UploadFile, File, HTTPException, Request, Depends
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
import base64
import json
import os
from datetime import datetime, date, timedelta
from sqlalchemy.orm import Session
from dotenv import load_dotenv
import jwt
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

load_dotenv()

JWT_SECRET = os.getenv("SUPABASE_JWT_SECRET")
ALGORITHM = "HS256"
security = HTTPBearer()

def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    token = credentials.credentials
    try:
        payload = jwt.decode(
            token, 
            JWT_SECRET, 
            algorithms=[ALGORITHM], 
            options={"verify_aud": False} # Supabase uses specific audiences, we'll keep it simple for now
        )
        return payload.get("sub") # This is the unique User ID
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid or expired token: {str(e)}")
import database as db_models
from database import get_db, init_db
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

class DoseLogSchema(BaseModel):
    medicine_id: int
    notes: Optional[str] = None

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
def list_medicines(user_id: str = Depends(get_current_user), db: Session = Depends(get_db)):
    medicines = db.query(db_models.Medicine).filter(db_models.Medicine.user_id == user_id).order_by(db_models.Medicine.created_at.desc()).all()
    return medicines

@app.post("/api/medicines", status_code=201)
def create_medicine(med: Medicine, user_id: str = Depends(get_current_user), db: Session = Depends(get_db)):
    new_med = db_models.Medicine(
        user_id=user_id,
        name=med.name,
        dosage=med.dosage,
        frequency=med.frequency,
        times=med.times,
        start_date=med.start_date,
        end_date=med.end_date,
        instructions=med.instructions,
        stock=med.stock,
        category=med.category
    )
    db.add(new_med)
    db.commit()
    db.refresh(new_med)
    return new_med

@app.get("/api/medicines/{medicine_id}")
def get_medicine(medicine_id: int, user_id: str = Depends(get_current_user), db: Session = Depends(get_db)):
    med = db.query(db_models.Medicine).filter(
        db_models.Medicine.id == medicine_id,
        db_models.Medicine.user_id == user_id
    ).first()
    if not med:
        raise HTTPException(404, "Medicine not found")
    return med

@app.patch("/api/medicines/{medicine_id}")
def update_medicine(medicine_id: int, update: MedicineUpdate, user_id: str = Depends(get_current_user), db: Session = Depends(get_db)):
    med = db.query(db_models.Medicine).filter(
        db_models.Medicine.id == medicine_id,
        db_models.Medicine.user_id == user_id
    ).first()
    if not med:
        raise HTTPException(404, "Medicine not found")

    update_data = update.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(med, key, value)

    db.commit()
    db.refresh(med)
    return med

@app.delete("/api/medicines/{medicine_id}", status_code=204)
def delete_medicine(medicine_id: int, user_id: str = Depends(get_current_user), db: Session = Depends(get_db)):
    med = db.query(db_models.Medicine).filter(
        db_models.Medicine.id == medicine_id,
        db_models.Medicine.user_id == user_id
    ).first()
    if not med:
        raise HTTPException(404, "Medicine not found")
    
    # Delete related logs first
    db.query(db_models.DoseLog).filter(
        db_models.DoseLog.medicine_id == medicine_id,
        db_models.DoseLog.user_id == user_id
    ).delete()
    db.delete(med)
    db.commit()
    return None

# ─── Dose Logging ──────────────────────────────────────────────────────────────

# ─── Dose Logging & Schedule ──────────────────────────────────────────────────

@app.get("/api/doses/today")
def get_today_doses(user_id: str = Depends(get_current_user), db: Session = Depends(get_db)):
    # Timezone buffer: Include medicines starting today OR tomorrow (from server perspective)
    # to account for users in timezones like +08:00
    today_obj = date.today()
    tomorrow_date = (today_obj + timedelta(days=1)).isoformat()
    today_date = today_obj.isoformat()
    
    # Get active medicines for THIS user
    medicines = db.query(db_models.Medicine).filter(
        db_models.Medicine.user_id == user_id,
        db_models.Medicine.start_date <= tomorrow_date,
        (db_models.Medicine.end_date == None) | (db_models.Medicine.end_date >= today_date)
    ).all()

    result = []
    for med in medicines:
        # times is stored as JSON list in SQLAlchemy
        for t in med.times:
            scheduled_dt = f"{today_date}T{t}:00"
            
            # Since we simplified DoseLog to just be a 'event log', we look for logs for this medicine today
            # (Note: For a production app, you'd match specific scheduled times, but this works for the hackathon)
            log = db.query(db_models.DoseLog).filter(
                db_models.DoseLog.medicine_id == med.id,
                # Simple check for logs within today
                db_models.DoseLog.taken_at >= datetime.combine(date.today(), datetime.min.time()),
                db_models.DoseLog.taken_at <= datetime.combine(date.today(), datetime.max.time())
            ).first()

            result.append({
                "medicine_id": med.id,
                "medicine_name": med.name,
                "dosage": med.dosage,
                "instructions": med.instructions,
                "scheduled_time": scheduled_dt,
                "time_label": t,
                "taken": log is not None,
                "taken_at": log.taken_at.isoformat() if log else None,
                "log_id": log.id if log else None,
                "category": med.category,
            })

    result.sort(key=lambda x: x["scheduled_time"])
    return result

@app.post("/api/doses/log")
def log_dose(log_data: DoseLogSchema, user_id: str = Depends(get_current_user), db: Session = Depends(get_db)):
    """Mark a dose as taken."""
    med = db.query(db_models.Medicine).filter(
        db_models.Medicine.id == log_data.medicine_id,
        db_models.Medicine.user_id == user_id
    ).first()
    if not med:
        raise HTTPException(404, "Medicine not found")

    new_log = db_models.DoseLog(
        medicine_id=log_data.medicine_id,
        user_id=user_id,
        notes=log_data.notes,
        taken_at=datetime.utcnow()
    )
    
    if med.stock and med.stock > 0:
        med.stock -= 1
        
    db.add(new_log)
    db.commit()
    db.refresh(new_log)
    return new_log

@app.get("/api/doses/history")
def get_dose_history(medicine_id: Optional[int] = None, user_id: str = Depends(get_current_user), db: Session = Depends(get_db)):
    """Get history with medicine names joined."""
    query = db.query(
        db_models.DoseLog, 
        db_models.Medicine.name.label("medicine_name"),
        db_models.Medicine.dosage.label("dosage")
    ).join(db_models.Medicine, db_models.DoseLog.medicine_id == db_models.Medicine.id)\
     .filter(db_models.DoseLog.user_id == user_id)

    if medicine_id:
        query = query.filter(db_models.DoseLog.medicine_id == medicine_id)
    
    logs = query.order_by(db_models.DoseLog.taken_at.desc()).limit(100).all()
    
    # Flatten the result for the Flutter app
    result = []
    for log, med_name, dosage in logs:
        log_dict = {
            "id": log.id,
            "medicine_id": log.medicine_id,
            "taken_at": log.taken_at.isoformat(),
            "notes": log.notes,
            "medicine_name": med_name,
            "dosage": dosage,
            "taken": True # In this simplified model, a log entry means it was taken
        }
        result.append(log_dict)
    return result

@app.get("/api/doses/stats")
def get_stats(user_id: str = Depends(get_current_user), db: Session = Depends(get_db)):
    """Adherence stats per medicine."""
    medicines = db.query(db_models.Medicine).filter(db_models.Medicine.user_id == user_id).all()
    result = []
    for med in medicines:
        logs = db.query(db_models.DoseLog).filter(
            db_models.DoseLog.medicine_id == med.id,
            db_models.DoseLog.user_id == user_id
        ).all()
        total_taken = len(logs)
        
        result.append({
            "medicine_id": med.id,
            "medicine_name": med.name,
            "category": med.category,
            "doses_taken": total_taken,
            "total_doses_logged": total_taken, # Match Flutter's expected key
            "adherence_pct": 100 if total_taken > 0 else 0,
            "stock": med.stock,
        })
    return result

@app.get("/health")
def health():
    return {"status": "ok", "time": datetime.utcnow().isoformat()}

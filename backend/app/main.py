from __future__ import annotations
import io, os, uuid
from datetime import datetime, timezone
from typing import Optional
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image, UnidentifiedImageError
from .vision import inspect_image

app = FastAPI(
    title="AI Car Doctor API",
    version="0.1.0",
    description="Preliminary visual vehicle inspection API. Not a substitute for professional diagnostics."
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict to your app/web origins in production.
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

MAX_BYTES = 10 * 1024 * 1024
ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp"}

@app.get("/")
def root():
    return {"name": "AI Car Doctor API", "docs": "/docs", "health": "/health"}

@app.get("/health")
def health():
    weights = os.getenv("YOLO_WEIGHTS", "models/engine_inspection.pt")
    return {
        "status": "ok",
        "service": "ai-car-doctor",
        "detector_configured": bool(weights and os.path.isfile(weights)),
        "timestamp": datetime.now(timezone.utc).isoformat()
    }

@app.post("/api/v1/diagnose")
async def diagnose(
    image: UploadFile = File(...),
    vehicle_make: Optional[str] = Form(default=None),
    vehicle_model: Optional[str] = Form(default=None),
    vehicle_year: Optional[str] = Form(default=None),
):
    if image.content_type not in ALLOWED_TYPES:
        raise HTTPException(status_code=415, detail="Upload a JPG, PNG, or WEBP image.")
    raw = await image.read(MAX_BYTES + 1)
    if len(raw) > MAX_BYTES:
        raise HTTPException(status_code=413, detail="Image exceeds the 10 MB limit.")
    if not raw:
        raise HTTPException(status_code=400, detail="The uploaded image is empty.")
    try:
        pil_image = Image.open(io.BytesIO(raw)).convert("RGB")
        pil_image.verify()
        pil_image = Image.open(io.BytesIO(raw)).convert("RGB")
    except (UnidentifiedImageError, OSError, ValueError):
        raise HTTPException(status_code=400, detail="The file is not a valid image.")
    if pil_image.width < 160 or pil_image.height < 160:
        raise HTTPException(status_code=400, detail="Image is too small. Use an image at least 160×160 pixels.")

    result = inspect_image(pil_image)
    return {
        "scan_id": str(uuid.uuid4()),
        "created_at": datetime.now(timezone.utc).isoformat(),
        "vehicle": {"make": vehicle_make, "model": vehicle_model, "year": vehicle_year},
        "image": {"width": pil_image.width, "height": pil_image.height},
        **result,
        "disclaimer": (
            "Preliminary visual screening only. This result cannot confirm hidden faults or establish "
            "vehicle roadworthiness. Stop using the vehicle and seek professional help if you notice "
            "smoke, fuel smell, overheating, brake/steering problems, or warning lights."
        )
    }

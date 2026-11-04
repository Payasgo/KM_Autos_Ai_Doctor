from __future__ import annotations
import os
from PIL import Image, ImageStat

def _run_optional_yolo(image):
    weights = os.getenv("YOLO_WEIGHTS", "models/engine_inspection.pt")
    if not os.path.isfile(weights):
        return None
    try:
        from ultralytics import YOLO
        model = YOLO(weights)
        predictions = model.predict(image, conf=0.35, verbose=False)
        found = []
        for prediction in predictions:
            names = prediction.names
            for box in prediction.boxes or []:
                cls_id = int(box.cls[0].item())
                confidence = float(box.conf[0].item())
                found.append({
                    "label": str(names.get(cls_id, cls_id)),
                    "confidence": round(confidence, 3),
                    "box_xyxy": [round(float(v), 1) for v in box.xyxy[0].tolist()]
                })
        return found
    except Exception:
        # Fail closed: don't present an inference failure as a clean inspection.
        return []

def inspect_image(image):
    detections = _run_optional_yolo(image)
    stats = ImageStat.Stat(image.resize((64, 64)))
    brightness = round(sum(stats.mean) / 3, 1)
    quality_notes = []
    if brightness < 45:
        quality_notes.append("Image appears dark; retake in even daylight with the engine off.")
    elif brightness > 225:
        quality_notes.append("Image appears overexposed; avoid direct glare and retake.")
    if min(image.size) < 320:
        quality_notes.append("A higher-resolution image may improve visual inspection.")

    if detections is None:
        return {
            "model_status": "not_configured",
            "summary": "Image received. Automated defect detection is not configured yet.",
            "severity": "unknown",
            "findings": [],
            "component_detections": [],
            "quality_notes": quality_notes,
            "next_steps": [
                "Capture a wide, well-lit photo of the entire engine bay with the engine switched off.",
                "Capture close-up photos of any suspected leak, damaged belt, corroded terminal, or loose connector.",
                "Use a compatible OBD-II scanner to read diagnostic trouble codes for electronic faults.",
                "Have a qualified technician inspect safety-critical or unclear symptoms."
            ]
        }

    return {
        "model_status": "ready" if detections else "inference_unavailable_or_no_detections",
        "summary": (
            "The configured model returned visual labels. These are detections, not confirmed faults."
            if detections else
            "No model detections were returned. This does not mean the vehicle is fault-free."
        ),
        "severity": "review_required" if detections else "unknown",
        "findings": [],
        "component_detections": detections,
        "quality_notes": quality_notes,
        "next_steps": [
            "Review each detected label and bounding box against the original image.",
            "Do not treat component recognition as a defect diagnosis.",
            "Confirm suspected problems with physical inspection and appropriate diagnostic tools."
        ]
    }

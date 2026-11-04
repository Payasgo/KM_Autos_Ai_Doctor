from __future__ import annotations

import os
from functools import lru_cache
from pathlib import Path
from typing import Any

from PIL import Image, ImageStat


def _weights_path() -> Path:
    configured = os.getenv("YOLO_WEIGHTS", "models/engine_inspection.pt")
    path = Path(configured).expanduser()
    if not path.is_absolute():
        path = Path(__file__).resolve().parents[1] / path
    return path.resolve()


@lru_cache(maxsize=2)
def _load_model(weights: str):
    """Load once per process; cache only successful model instances."""
    from ultralytics import YOLO
    return YOLO(weights)


def detector_status() -> dict[str, Any]:
    path = _weights_path()
    if not path.is_file():
        return {
            "configured": False,
            "available": False,
            "weights": str(path),
            "message": "Validated automotive model weights are not installed.",
        }
    try:
        _load_model(str(path))
        return {
            "configured": True,
            "available": True,
            "weights": str(path),
            "message": "Model loaded successfully. Detections are visual labels, not confirmed faults.",
        }
    except ImportError:
        return {
            "configured": True,
            "available": False,
            "weights": str(path),
            "message": "Install the optional ultralytics package to enable inference.",
        }
    except Exception as exc:
        return {
            "configured": True,
            "available": False,
            "weights": str(path),
            "message": f"Model could not be loaded: {type(exc).__name__}: {exc}",
        }


def _run_optional_yolo(image: Image.Image) -> tuple[list[dict[str, Any]], str]:
    path = _weights_path()
    if not path.is_file():
        return [], "not_configured"
    try:
        model = _load_model(str(path))
        predictions = model.predict(image, conf=0.35, verbose=False)
        found: list[dict[str, Any]] = []
        for prediction in predictions:
            names = prediction.names
            boxes = prediction.boxes
            if boxes is None:
                continue
            for box in boxes:
                cls_id = int(box.cls[0].item())
                confidence = float(box.conf[0].item())
                found.append({
                    "label": str(names.get(cls_id, cls_id)),
                    "confidence": round(confidence, 3),
                    "box_xyxy": [round(float(v), 1) for v in box.xyxy[0].tolist()],
                })
        return found, "inference_completed"
    except ImportError:
        return [], "dependency_missing"
    except Exception as exc:
        return [], f"inference_error:{type(exc).__name__}"


def inspect_image(image: Image.Image) -> dict[str, Any]:
    detections, inference_status = _run_optional_yolo(image)
    stats = ImageStat.Stat(image.resize((64, 64)))
    brightness = round(sum(stats.mean) / 3, 1)
    quality_notes: list[str] = []
    if brightness < 45:
        quality_notes.append("Image appears dark; retake in even daylight with the engine off.")
    elif brightness > 225:
        quality_notes.append("Image appears overexposed; avoid direct glare and retake.")
    if min(image.size) < 320:
        quality_notes.append("A higher-resolution image may improve visual inspection.")

    if inference_status != "inference_completed":
        status = (
            "not_configured" if inference_status == "not_configured"
            else inference_status
        )
        summary = (
            "Image received. Automated visual recognition is not configured."
            if status == "not_configured"
            else "The detector could not complete inference. No conclusion can be drawn."
        )
        return {
            "model_status": status,
            "summary": summary,
            "severity": "unknown",
            "findings": [],
            "component_detections": [],
            "quality_notes": quality_notes,
            "next_steps": [
                "Capture a wide, well-lit photo of the engine bay with the engine switched off.",
                "Capture close-up photos of suspected leaks, damaged belts, corroded terminals, or loose connectors.",
                "Use a compatible OBD-II scanner to read diagnostic trouble codes for electronic faults.",
                "Have a qualified technician inspect safety-critical or unclear symptoms.",
            ],
        }

    return {
        "model_status": "inference_completed",
        "summary": (
            "The model returned visual labels. These are component/visual detections, "
            "not confirmed mechanical faults."
            if detections else
            "No labels were detected. This does not mean the vehicle is fault-free."
        ),
        "severity": "review_required" if detections else "unknown",
        "findings": [],
        "component_detections": detections,
        "quality_notes": quality_notes,
        "next_steps": [
            "Review every detected label and bounding box against the original image.",
            "Do not treat component recognition as a defect diagnosis.",
            "Confirm suspected problems with physical inspection and appropriate diagnostic tools.",
        ],
    }

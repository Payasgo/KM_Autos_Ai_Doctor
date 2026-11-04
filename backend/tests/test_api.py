from fastapi.testclient import TestClient
from PIL import Image
import io

from app.main import app

client = TestClient(app)


def _jpeg_bytes(size=(320, 240)):
    stream = io.BytesIO()
    Image.new("RGB", size, "gray").save(stream, format="JPEG")
    return stream.getvalue()


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_rejects_wrong_media_type():
    response = client.post(
        "/api/v1/diagnose",
        files={"image": ("sample.txt", b"not image", "text/plain")},
    )
    assert response.status_code == 415


def test_rejects_invalid_image():
    response = client.post(
        "/api/v1/diagnose",
        files={"image": ("sample.jpg", b"not really a jpeg", "image/jpeg")},
    )
    assert response.status_code == 400


def test_accepts_valid_image_without_model():
    response = client.post(
        "/api/v1/diagnose",
        files={"image": ("sample.jpg", _jpeg_bytes(), "image/jpeg")},
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["scan_id"]
    assert payload["image"] == {"width": 320, "height": 240}
    assert payload["severity"] == "unknown"
    assert "disclaimer" in payload


def test_live_frame_detection_without_model():
    response = client.post(
        "/api/v1/detect-frame",
        files={"image": ("frame.jpg", _jpeg_bytes(), "image/jpeg")},
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["model_status"] == "not_configured"
    assert payload["component_detections"] == []
    assert payload["image"] == {"width": 320, "height": 240}


def test_live_frame_rejects_invalid_image():
    response = client.post(
        "/api/v1/detect-frame",
        files={"image": ("frame.jpg", b"invalid", "image/jpeg")},
    )
    assert response.status_code == 400

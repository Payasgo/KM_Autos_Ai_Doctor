"""Train an Ultralytics detection model from backend/automotive_dataset/data.yaml.

Run from the repository root:
  python -m pip install -r backend/requirements.txt
  python model_training/train.py --epochs 100 --device cpu

Use --device 0 for a supported NVIDIA CUDA GPU.
This trains component detection only; it does not train fault diagnosis.
"""
from __future__ import annotations

import argparse
from pathlib import Path

from ultralytics import YOLO

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "backend" / "automotive_dataset" / "data.yaml"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--epochs", type=int, default=100)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--batch", type=int, default=8)
    parser.add_argument("--device", default="cpu")
    parser.add_argument("--model", default=str(ROOT / "backend" / "yolo26n.pt"))
    args = parser.parse_args()

    if not DATA.is_file():
        raise SystemExit(f"Dataset config not found: {DATA}")
    if not Path(args.model).is_file():
        raise SystemExit(f"Starting checkpoint not found: {args.model}")
    model = YOLO(args.model)
    model.train(
        data=str(DATA),
        epochs=args.epochs,
        imgsz=args.imgsz,
        batch=args.batch,
        device=args.device,
        project=str(ROOT / "runs" / "train"),
        name="automotive_parts",
    )


if __name__ == "__main__":
    main()

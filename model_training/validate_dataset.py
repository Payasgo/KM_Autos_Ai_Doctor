"""Validate the local YOLO detection dataset before training.

Run from repository root:
  python model_training/validate_dataset.py

Checks split directories, image/label pairs, class IDs, normalized boxes,
and rejects polygon/segmentation rows in a detection dataset.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import sys

import yaml
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DATA_YAML = ROOT / "backend" / "automotive_dataset" / "data.yaml"
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", type=Path, default=DATA_YAML)
    args = parser.parse_args()
    config_path = args.data.resolve()
    if not config_path.is_file():
        print(f"ERROR: dataset YAML not found: {config_path}")
        return 2

    config = yaml.safe_load(config_path.read_text(encoding="utf-8"))
    names = config.get("names", [])
    if isinstance(names, dict):
        class_names = {int(k): str(v) for k, v in names.items()}
    else:
        class_names = {i: str(v) for i, v in enumerate(names)}
    nc = int(config.get("nc", len(class_names)))
    if nc != len(class_names) or sorted(class_names) != list(range(nc)):
        print("ERROR: nc and names must define contiguous class IDs 0..nc-1.")
        return 2

    root = Path(config.get("path") or ".")
    if not root.is_absolute():
        root = (config_path.parent / root).resolve()

    errors: list[str] = []
    warnings: list[str] = []
    for split in ("train", "val", "test"):
        split_value = config.get(split)
        if not split_value:
            errors.append(f"{split}: missing path in YAML")
            continue
        image_dir = Path(split_value)
        if not image_dir.is_absolute():
            image_dir = root / image_dir
        label_dir = image_dir.parent.parent / "labels" / image_dir.name
        if not image_dir.is_dir():
            errors.append(f"{split}: image directory missing: {image_dir}")
            continue
        if not label_dir.is_dir():
            errors.append(f"{split}: label directory missing: {label_dir}")
            continue

        images = sorted(p for p in image_dir.rglob("*") if p.suffix.lower() in IMAGE_EXTS)
        if not images:
            errors.append(f"{split}: no supported images found in {image_dir}")
            continue
        image_stems = {p.stem for p in images}
        label_files = {p.stem: p for p in label_dir.rglob("*.txt")}
        missing = sorted(image_stems - set(label_files))
        orphan = sorted(set(label_files) - image_stems)
        if missing:
            errors.append(f"{split}: {len(missing)} images have no matching .txt label (e.g. {missing[:5]})")
        if orphan:
            warnings.append(f"{split}: {len(orphan)} label files have no matching image (e.g. {orphan[:5]})")

        for image_path in images:
            try:
                with Image.open(image_path) as im:
                    im.verify()
            except Exception as exc:
                errors.append(f"{split}: unreadable image {image_path.name}: {exc}")
                continue
            label_path = label_files.get(image_path.stem)
            if not label_path:
                continue
            try:
                for line_no, line in enumerate(label_path.read_text(encoding="utf-8").splitlines(), 1):
                    if not line.strip():
                        continue
                    parts = line.split()
                    if len(parts) != 5:
                        errors.append(
                            f"{split}/{label_path.name}:{line_no}: expected 5 detection values, got {len(parts)} "
                            "(polygon rows require a segmentation model/export)"
                        )
                        continue
                    try:
                        cls = int(parts[0])
                        box = [float(x) for x in parts[1:]]
                    except ValueError:
                        errors.append(f"{split}/{label_path.name}:{line_no}: non-numeric label values")
                        continue
                    if cls < 0 or cls >= nc:
                        errors.append(f"{split}/{label_path.name}:{line_no}: class ID {cls} outside 0..{nc-1}")
                    if any(x < 0 or x > 1 for x in box):
                        errors.append(f"{split}/{label_path.name}:{line_no}: box values must be normalized to 0..1")
                    if box[2] <= 0 or box[3] <= 0:
                        errors.append(f"{split}/{label_path.name}:{line_no}: box width and height must be > 0")
            except OSError as exc:
                errors.append(f"{split}/{label_path.name}: cannot read label: {exc}")

        print(f"{split}: {len(images)} images, {len(label_files)} labels, {len(missing)} missing labels")

    for warning in warnings:
        print(f"WARNING: {warning}")
    for error in errors:
        print(f"ERROR: {error}")
    if errors:
        print(f"Dataset validation FAILED with {len(errors)} error(s). Do not train yet.")
        return 1
    print("Dataset validation PASSED. Review warnings and class mapping before training.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

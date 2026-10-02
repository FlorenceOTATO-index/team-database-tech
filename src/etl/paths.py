"""Shared folder locations, so scripts work no matter where they're run from."""

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = REPO_ROOT / "data" / "raw"
PROCESSED_DIR = REPO_ROOT / "data" / "processed"
LOOKUPS_DIR = PROCESSED_DIR / "lookups"

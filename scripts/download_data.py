"""Download the raw NHTSA FARS 2024 national CSV files into data/raw/.

Usage (from the repo root):
    python scripts/download_data.py           # skips download if files already exist
    python scripts/download_data.py --force   # re-download everything
"""

import argparse
import io
import zipfile
from pathlib import Path

import requests

YEAR = 2024
BASE_URL = f"https://static.nhtsa.gov/nhtsa/downloads/FARS/{YEAR}/National"
ZIPS = [
    f"FARS{YEAR}NationalCSV.zip",           # main tables (accident, vehicle, person, ...)
    f"FARS{YEAR}NationalAuxiliaryCSV.zip",  # ACC_AUX, VEH_AUX, PER_AUX
]

RAW_DIR = Path(__file__).resolve().parent.parent / "data" / "raw"
# One file from each zip, used to decide whether that zip is already downloaded.
MARKER_FILES = {ZIPS[0]: "accident.csv", ZIPS[1]: "ACC_AUX.CSV"}


def download_and_extract(zip_name: str) -> None:
    url = f"{BASE_URL}/{zip_name}"
    print(f"Downloading {url} ...")
    resp = requests.get(url, timeout=300)
    resp.raise_for_status()

    with zipfile.ZipFile(io.BytesIO(resp.content)) as zf:
        for member in zf.infolist():
            if member.is_dir():
                continue
            # The zips put files inside a subfolder; flatten them into data/raw/.
            target = RAW_DIR / Path(member.filename).name
            target.write_bytes(zf.read(member))
            print(f"  -> {target.relative_to(RAW_DIR.parent.parent)}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true", help="re-download even if files exist")
    args = parser.parse_args()

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    for zip_name in ZIPS:
        if not args.force and (RAW_DIR / MARKER_FILES[zip_name]).exists():
            print(f"Skipping {zip_name}: files already in data/raw/ (use --force to re-download)")
            continue
        download_and_extract(zip_name)

    print(f"Done. {len(list(RAW_DIR.glob('*.[cC][sS][vV]')))} CSV files in data/raw/")


if __name__ == "__main__":
    main()

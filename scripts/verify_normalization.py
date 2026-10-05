"""Verification checks for the FARS 2024 normalization analysis.

Run from the repo root:
    python scripts/verify_normalization.py

Covers docs/schema/normalization.md:
  - Step 1: key identification (uniqueness of natural keys)
  - Step 2: 1NF (atomic cells, repeating-group scan)
  - Step 3: 2NF functional-dependency spot-checks

Author: Jue Wang
"""

import csv

import pandas as pd

DATA = "data/processed"
results = []


def check(name, passed, detail=""):
    results.append(passed)
    status = "PASS" if passed else "FAIL"
    print(f"[{status}] {name}" + (f" — {detail}" if detail else ""))


# ---------------------------------------------------------------- 1NF: keys
a = pd.read_csv(f"{DATA}/accident.csv", usecols=["ST_CASE"])
check("accident: ST_CASE unique",
      a["ST_CASE"].nunique() == len(a),
      f"{len(a)} rows")

v = pd.read_csv(f"{DATA}/vehicle.csv", usecols=["ST_CASE", "VEH_NO"])
check("vehicle: (ST_CASE, VEH_NO) unique",
      v.duplicated(subset=["ST_CASE", "VEH_NO"]).sum() == 0,
      f"{len(v)} rows")

p = pd.read_csv(f"{DATA}/person.csv", usecols=["ST_CASE", "VEH_NO", "PER_NO"])
check("person: (ST_CASE, VEH_NO, PER_NO) unique",
      p.duplicated(subset=["ST_CASE", "VEH_NO", "PER_NO"]).sum() == 0,
      f"{len(p)} rows")

# ------------------------------------------------------- 1NF: atomic cells
for fname in ["accident.csv", "vehicle.csv", "person.csv"]:
    with open(f"{DATA}/{fname}", newline="") as fh:
        multi = sum(1 for row in csv.reader(fh)
                    for cell in row if ";" in cell)
    check(f"{fname}: cells hold single values", multi == 0,
          f"{multi} multi-value cells")

# ------------------------------------------------- 1NF: repeating groups
with open(f"{DATA}/vehicle.csv", newline="") as fh:
    header = next(csv.reader(fh))
numbered = [c for c in header if c.rsplit("_", 1)[-1].isdigit()]
print(f"[INFO] vehicle.csv numbered columns: {numbered}")
print("       -> VIN_1..VIN_12 are fixed positional characters of the VIN; "
      "atomic, kept deliberately (splitting further would be "
      "over-normalization).")

# ------------------------------------------------- 2NF: FD spot-checks
a2 = pd.read_csv(f"{DATA}/accident.csv", usecols=["ST_CASE", "STATE"])
check("FD ST_CASE -> STATE",
      a2.groupby("ST_CASE")["STATE"].nunique().max() == 1)

v2 = pd.read_csv(f"{DATA}/vehicle.csv",
                 usecols=["ST_CASE", "HARM_EV", "MONTH"])
check("FD ST_CASE -> HARM_EV (partial dep. in vehicle.csv)",
      v2.groupby("ST_CASE")["HARM_EV"].nunique().max() == 1)
check("FD ST_CASE -> MONTH (partial dep. in vehicle.csv)",
      v2.groupby("ST_CASE")["MONTH"].nunique().max() == 1)

p2 = pd.read_csv(f"{DATA}/person.csv",
                 usecols=["ST_CASE", "VEH_NO", "MOD_YEAR", "HARM_EV"])
check("FD (ST_CASE, VEH_NO) -> MOD_YEAR (partial dep. in person.csv)",
      p2.groupby(["ST_CASE", "VEH_NO"])["MOD_YEAR"].nunique().max() == 1)
check("FD ST_CASE -> HARM_EV (partial dep. in person.csv)",
      p2.groupby("ST_CASE")["HARM_EV"].nunique().max() == 1)

print()
print("ALL CHECKS PASSED" if all(results) else "SOME CHECKS FAILED")

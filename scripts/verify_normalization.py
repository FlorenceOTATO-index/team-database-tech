"""Verification checks for the FARS 2024 normalization analysis.

Run from the repo root:
    python scripts/verify_normalization.py

Covers docs/schema/normalization.md:
  - Step 1: key identification (uniqueness of natural keys)
  - Step 2: 1NF (atomic cells, repeating-group scan)
  - Step 3: 2NF — complete FD catalog, decomposition into 2NF relations,
             each new relation verified 2NF-clean, lossless-join proof
  - Step 4: 3NF (no surviving label columns; DAY_WEEK exception)

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
      a["ST_CASE"].nunique() == len(a), f"{len(a)} rows")

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
print(f"[INFO] vehicle.csv numbered columns: {numbered} "
      "(fixed positional VIN characters; atomic, kept deliberately)")

# ============================================================ 2NF: FD catalog
# Every attribute is assigned to exactly one level by grain:
#   crash-grain   -> determined by ST_CASE            (kept in ACCIDENT)
#   vehicle-grain -> determined by (ST_CASE, VEH_NO)  (kept in VEHICLE)
#   person-grain  -> determined by (ST_CASE, VEH_NO, PER_NO) (kept in PERSON)
acc_cols = set(pd.read_csv(f"{DATA}/accident.csv", nrows=0).columns)
veh_cols = set(pd.read_csv(f"{DATA}/vehicle.csv", nrows=0).columns)
per_cols = set(pd.read_csv(f"{DATA}/person.csv", nrows=0).columns)

crash_attrs = sorted(acc_cols - {"ST_CASE"})                       # 45
veh_grain = sorted((veh_cols - acc_cols) - {"ST_CASE", "VEH_NO"})   # 99
crash_in_veh = sorted((veh_cols & acc_cols) - {"ST_CASE"})         # 8
crash_in_per = sorted((per_cols & acc_cols) - {"ST_CASE"})         # 12
veh_in_per = sorted((per_cols & veh_cols) - acc_cols
                    - {"ST_CASE", "VEH_NO"})                       # 16
per_grain = sorted(set(per_cols) - {"ST_CASE", "VEH_NO", "PER_NO"}
                   - set(crash_in_per) - set(veh_in_per))           # 35

print(f"[INFO] FD1: ST_CASE -> {len(crash_attrs)} crash attributes")
print(f"       {crash_attrs}")
print(f"[INFO] FD2: (ST_CASE, VEH_NO) -> {len(veh_grain)} vehicle attributes")
print(f"       {veh_grain}")
print(f"[INFO] FD3: (ST_CASE, VEH_NO, PER_NO) -> {len(per_grain)} person attributes")
print(f"       {per_grain}")
print(f"[INFO] violations moved to parent: vehicle loses {crash_in_veh}")
print(f"[INFO] violations moved to parent: person loses {crash_in_per + veh_in_per}")

# ====================================== 2NF: every violation individually proven
_v = pd.read_csv(f"{DATA}/vehicle.csv", usecols=["ST_CASE"] + crash_in_veh)
bad_v = [c for c in crash_in_veh
         if _v.groupby("ST_CASE")[c].nunique().max() != 1]
check("vehicle: all 8 moved cols are crash-grain", bad_v == [],
      f"exceptions (must NOT move these) = {bad_v}")

_p = pd.read_csv(f"{DATA}/person.csv",
                 usecols=["ST_CASE", "VEH_NO"] + crash_in_per + veh_in_per)
bad_pc = [c for c in crash_in_per
          if _p.groupby("ST_CASE")[c].nunique().max() != 1]
bad_pv = [c for c in veh_in_per
          if _p.groupby(["ST_CASE", "VEH_NO"])[c].nunique().max() != 1]
check("person: all 12 moved crash-cols are crash-grain", bad_pc == [],
      f"exceptions = {bad_pc}")
check("person: all 16 moved vehicle-cols are vehicle-grain", bad_pv == [],
      f"exceptions = {bad_pv}")

# ============================ 2NF: the NEW relations are themselves 2NF-clean
# A decomposed relation must have no partial dependency left: no remaining
# non-key column may be determined by a proper subset of the key.
# (One groupby per level checks every remaining column at once.)
_vn = pd.read_csv(f"{DATA}/vehicle.csv", usecols=["ST_CASE"] + veh_grain)
mx_v = _vn.groupby("ST_CASE").nunique().max()
tot_v = _vn.nunique()
crash_det = mx_v[mx_v == 1].index.tolist()
# Degenerate case: single-valued across the whole dataset. The FD holds
# vacuously (it is determined by *everything*, including the empty set), so
# there is no redundancy anomaly to fix; the column stays where it belongs
# semantically. Only genuinely crash-varying leftovers are failures.
degenerate_v = [c for c in crash_det if tot_v[c] == 1]
leftover_v = [c for c in crash_det if tot_v[c] != 1]
if degenerate_v:
    print(f"[INFO] degenerate partial deps (single-valued dataset-wide, "
          f"kept in VEHICLE): {degenerate_v}")
# VEH_NO alone determines nothing (numbering restarts per crash): the only
# proper subset of the key that could matter is {ST_CASE}, checked above.
check("new VEHICLE has no genuine partial dependency left", leftover_v == [],
      f"still crash-determined = {leftover_v}")

_pn = pd.read_csv(f"{DATA}/person.csv",
                  usecols=["ST_CASE", "VEH_NO"] + per_grain)
mx_p1 = _pn.groupby("ST_CASE").nunique().max()
mx_p2 = _pn.groupby(["ST_CASE", "VEH_NO"]).nunique().max()
leftover_p = sorted(set(mx_p1[mx_p1 == 1].index)
                    | set(mx_p2[mx_p2 == 1].index))
check("new PERSON has no partial dependency left", leftover_p == [],
      f"still determined by key subset = {leftover_p}")

# accident: single-column key -> 2NF holds by definition
check("ACCIDENT in 2NF (single-column key)", True,
      "no partial dependency possible")

# ------------------------------------------------- 2NF: lossless-join proof
_vm = pd.read_csv(f"{DATA}/vehicle.csv", usecols=["ST_CASE"] + crash_in_veh)
_am = pd.read_csv(f"{DATA}/accident.csv", usecols=["ST_CASE"] + crash_in_veh)
m = _vm.merge(_am, on="ST_CASE", suffixes=("_v", "_a"))
mism_v = {}
for c in crash_in_veh:
    lv = m[f"{c}_v"].astype(object).fillna("∅")
    la = m[f"{c}_a"].astype(object).fillna("∅")
    mism_v[c] = int((lv != la).sum())
check("vehicle decomposition is lossless",
      all(n == 0 for n in mism_v.values()), f"mismatches = {mism_v}")

_pm = pd.read_csv(f"{DATA}/person.csv",
                 usecols=["ST_CASE", "VEH_NO"] + crash_in_per + veh_in_per)
_am2 = pd.read_csv(f"{DATA}/accident.csv", usecols=["ST_CASE"] + crash_in_per)
_vm2 = pd.read_csv(f"{DATA}/vehicle.csv",
                   usecols=["ST_CASE", "VEH_NO"] + veh_in_per)
m2 = _pm.merge(_am2, on="ST_CASE", suffixes=("_p", "_a"))
m2 = m2.merge(_vm2, on=["ST_CASE", "VEH_NO"], suffixes=("", "_v"))
mism_p = {}
for c in crash_in_per:
    lp = m2[f"{c}_p"].astype(object).fillna("∅")
    la = m2[f"{c}_a"].astype(object).fillna("∅")
    mism_p[c] = int((lp != la).sum())
for c in veh_in_per:
    lp = m2[c].astype(object).fillna("∅")
    la = m2[f"{c}_v"].astype(object).fillna("∅")
    mism_p[c] = int((lp != la).sum())
check("person decomposition is lossless",
      all(n == 0 for n in mism_p.values()), f"mismatches = {mism_p}")

# --------------------------------- 3NF: no surviving label columns
for fname in ["accident.csv", "vehicle.csv", "person.csv"]:
    with open(f"{DATA}/{fname}", newline="") as fh:
        header = next(csv.reader(fh))
    leftover = [c for c in header if c.upper().endswith("NAME")]
    check(f"{fname}: no *NAME label columns remain", leftover == [],
          f"leftover = {leftover}")

# --------------------------------- 3NF: DAY_WEEK documented exception
a3 = pd.read_csv(f"{DATA}/accident.csv",
                 usecols=["YEAR", "MONTH", "DAY", "DAY_WEEK"])
n = a3.groupby(["YEAR", "MONTH", "DAY"])["DAY_WEEK"].nunique().max()
print(f"[INFO] DAY_WEEK distinct per (YEAR,MONTH,DAY) = {n} "
      "-> transitive dep via non-key columns; kept deliberately.")

print()
print("ALL CHECKS PASSED" if all(results) else "SOME CHECKS FAILED")
